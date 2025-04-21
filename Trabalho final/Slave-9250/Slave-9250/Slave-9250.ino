#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <MPU9250_asukiaaa.h>
#include <math.h>

// ——— Configurações Wi‑Fi —————————————————————————————————
const char* ssid     = "Martins 6";
const char* password = "17031998";
WebServer server(80);

// ——— Objeto MPU9250 —————————————————————————————————————
MPU9250_asukiaaa mpu;

// ——— Parâmetros Madgwick 9DoF ——————————————————————————
const float sampleFreq = 100.0f;  // Hz
const float beta       = 0.1f;    // ganho do filtro

// ——— Estado do filtro (quaternion) ———————————————————————
float q0 = 1, q1 = 0, q2 = 0, q3 = 0;

// ——— Tempo entre atualizações ——————————————————————————
unsigned long lastMicros = 0;

// ——— Bias do gyro Z (calibrado no setup) ——————————————
float biasRawZ = 0;

// ——— Hard‑iron do magnetômetro (preencha após calibração) —————
float magBiasX = 0, magBiasY = 0, magBiasZ = 0;

// ——— Utilitário: inverso de raiz quadrada rápida —————————
inline float invSqrt(float x) { return 1.0f / sqrtf(x); }

// ——— Madgwick 9DoF completo —————————————————————————
void Madgwick9DoF(float gx, float gy, float gz,
                  float ax, float ay, float az,
                  float mx, float my, float mz) {
  float recipNorm, s0, s1, s2, s3;
  float qDot1, qDot2, qDot3, qDot4, hx, hy, _2bx, _2bz;
  // pré‑calcula produtos de q
  float _2q0 = 2*q0, _2q1 = 2*q1, _2q2 = 2*q2, _2q3 = 2*q3;
  float q0q0 = q0*q0, q1q1 = q1*q1, q2q2 = q2*q2, q3q3 = q3*q3;
  float q0q1 = q0*q1, q0q2 = q0*q2, q0q3 = q0*q3;
  float q1q2 = q1*q2, q1q3 = q1*q3, q2q3 = q2*q3;
  float _2q0q1 = 2*q0q1, _2q0q2 = 2*q0q2, _2q0q3 = 2*q0q3;
  float _2q1q2 = 2*q1q2, _2q1q3 = 2*q1q3, _2q2q3 = 2*q2q3;

  // 1) derivada do quaternion via giroscópio
  qDot1 = 0.5f * (-q1*gx - q2*gy - q3*gz);
  qDot2 = 0.5f * ( q0*gx + q2*gz - q3*gy);
  qDot3 = 0.5f * ( q0*gy - q1*gz + q3*gx);
  qDot4 = 0.5f * ( q0*gz + q1*gy - q2*gx);

  // 2) normaliza acelerômetro
  recipNorm = invSqrt(ax*ax + ay*ay + az*az);
  ax *= recipNorm; ay *= recipNorm; az *= recipNorm;

  // 3) normaliza magnetômetro
  recipNorm = invSqrt(mx*mx + my*my + mz*mz);
  mx *= recipNorm; my *= recipNorm; mz *= recipNorm;

  // 4) calc referência do campo magnético
  hx = mx*(q0q0 - q1q1 - q2q2 + q3q3)
     + my*(_2q0q1 + _2q2q3)
     + mz*(_2q0q2 - _2q1q3);
  hy = mx*(_2q0q1 - _2q2q3)
     + my*(q0q0 - q1q1 + q2q2 - q3q3)
     + mz*(_2q0q3 + _2q1q2);
  _2bx = sqrtf(hx*hx + hy*hy);
  _2bz = mx*(_2q0q2 + _2q1q3)
       + my*(_2q2q3 - _2q0q1)
       + mz*(q0q0 - q1q1 - q2q2 + q3q3);

  // 5) gradiente de correção
  s0 = -_2q2*(2*(q1*q3 - q0*q2) - ax)
       + _2q1*(2*(q0*q1 + q2*q3) - ay)
       - _2bz*q2*(_2bx*(0.5f - q2q2 - q3q3) + _2bz*(q1q3 - q0*q2) - mx)
       + (-_2bx*q3 + _2bz*q1)*(_2bx*(q1q2 - q0q3) + _2bz*(q0q1 + q2q3) - my)
       + _2bx*q2*(_2bx*(q0q2 + q1q3) + _2bz*(0.5f - q1q1 - q2q2) - mz);

  s1 =  _2q3*(2*(q1*q3 - q0*q2) - ax)
       + _2q0*(2*(q0*q1 + q2*q3) - ay)
       - 4*q1*(1 - 2*(q1q1+q2q2) - az)
       + _2bz*q3*(_2bx*(0.5f - q2q2 - q3q3) + _2bz*(q1q3 - q0*q2) - mx)
       + (_2bx*q2 + _2bz*q0)*(_2bx*(q1q2 - q0q3) + _2bz*(q0q1 + q2q3) - my)
       + (_2bx*q3 - 4*_2bz*q1)*(_2bx*(q0q2 + q1q3) + _2bz*(0.5f - q1q1 - q2q2) - mz);

  s2 = -_2q0*(2*(q1*q3 - q0*q2) - ax)
       + _2q3*(2*(q0*q1 + q2*q3) - ay)
       - 4*q2*(1 - 2*(q1q1+q2q2) - az)
       + (-4*_2bx*q2 - _2bz*q0)*(_2bx*(0.5f - q2q2 - q3q3) + _2bz*(q1q3 - q0*q2) - mx)
       + (_2bx*q1 + _2bz*q3)*(_2bx*(q1q2 - q0*q3) + _2bz*(q0*q1 + q2*q3) - my)
       + (_2bx*q0 - 4*_2bz*q2)*(_2bx*(q0*q2 + q1*q3) + _2bz*(0.5f - q1q1 - q2q2) - mz);

  s3 =  _2q1*(2*(q1*q3 - q0*q2) - ax)
       + _2q2*(2*(q0*q1 + q2*q3) - ay)
       + (-4*_2bx*q3 + _2bz*q1)*(_2bx*(0.5f - q2q2 - q3q3) + _2bz*(q1q3 - q0*q2) - mx)
       + (-_2bx*q0 + _2bz*q2)*(_2bx*(q1q2 - q0*q3) + _2bz*(q0*q1 + q2*q3) - my)
       + _2bx*q1*(_2bx*(q0*q2 + q1*q3) + _2bz*(0.5f - q1q1 - q2q2) - mz);

  recipNorm = invSqrt(s0*s0 + s1*s1 + s2*s2 + s3*s3);
  s0 *= recipNorm; s1 *= recipNorm; s2 *= recipNorm; s3 *= recipNorm;

  // 6) aplica correção e integra
  qDot1 -= beta * s0;  qDot2 -= beta * s1;
  qDot3 -= beta * s2;  qDot4 -= beta * s3;

  float dt = 1.0f / sampleFreq;
  q0 += qDot1*dt;  q1 += qDot2*dt;
  q2 += qDot3*dt;  q3 += qDot4*dt;

  // 7) normaliza
  recipNorm = invSqrt(q0*q0 + q1*q1 + q2*q2 + q3*q3);
  q0 *= recipNorm;  q1 *= recipNorm;
  q2 *= recipNorm;  q3 *= recipNorm;
}

// ——— CORS & Handlers ———————————————————————————————
void sendCORS() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
}
void handleOptions() { sendCORS(); server.send(200); }
void handleRoot() {
  sendCORS();
  server.send(200, "text/plain", "ESP32 MPU9250 9DoF ready");
}
void handleIMU() {
  sendCORS();
  unsigned long now = micros();
  float dt = (now - lastMicros)*1e-6f;
  lastMicros = now;

  mpu.setWire(&Wire);
  mpu.accelUpdate(); mpu.gyroUpdate(); mpu.magUpdate();

  float ax = mpu.accelX(), ay = mpu.accelY(), az = mpu.accelZ();
  const float d2r = M_PI/180.0f;
  float gx = (mpu.gyroX())*d2r;
  float gy = (mpu.gyroY())*d2r;
  float gz = (mpu.gyroZ()-biasRawZ)*d2r;

  float mx = mpu.magX()-magBiasX;
  float my = mpu.magY()-magBiasY;
  float mz = mpu.magZ()-magBiasZ;

  Madgwick9DoF(gx,gy,gz, ax,ay,az, mx,my,mz);

  float yaw   = atan2f(2*(q1*q2+q0*q3), q0*q0+q1*q1-q2*q2-q3*q3)*180/M_PI;
  float pitch = asinf(fmaxf(-1,fminf(1,2*(q0*q2-q1*q3))))*180/M_PI;
  float roll  = atan2f(2*(q0*q1+q2*q3), q0*q0-q1*q1-q2*q2+q3*q3)*180/M_PI;

  String j = "{\"yaw\":"+String(yaw,2)+
             ",\"pitch\":"+String(pitch,2)+
             ",\"roll\":"+String(roll,2)+"}";
  server.send(200, "application/json", j);
}

// ——— setup & loop —————————————————————————————————————
void setup() {
  Serial.begin(115200);
  delay(100);

  Wire.begin(21,22);
  Wire.setClock(400000);
  delay(50);

  mpu.setWire(&Wire);
  mpu.beginAccel(); mpu.beginGyro(); mpu.beginMag();
  delay(100);

  // calib gyro Z
  float sumZ=0;
  for(int i=0;i<500;i++){ mpu.gyroUpdate(); sumZ+=mpu.gyroZ(); delay(5); }
  biasRawZ = sumZ/500.0f;

  lastMicros = micros();

  WiFi.begin(ssid,password);
  while(WiFi.status()!=WL_CONNECTED) delay(250), Serial.print(".");
  Serial.println("\nIP: "+WiFi.localIP().toString());

  server.on("/", HTTP_GET, handleRoot);
  server.on("/", HTTP_OPTIONS, handleOptions);
  server.on("/imu2", HTTP_GET, handleIMU);
  server.on("/imu2", HTTP_OPTIONS, handleOptions);
  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}
