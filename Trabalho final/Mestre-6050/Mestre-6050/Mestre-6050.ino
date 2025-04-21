#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

// ===== Wi‑Fi =====
const char* ssid     = "Martins 6";
const char* password = "17031998";
WebServer server(80);

// ===== MPU6050 e Madgwick =====
MPU6050 mpu;
const float sampleFreq = 100.0f; // Hz
const float beta       = 0.1f;   // ganho do filtro

// Quaternion (estado interno)
float q0 = 1, q1 = 0, q2 = 0, q3 = 0;
unsigned long lastMicros = 0;

// Bias bruto de gz
float biasRawZ = 0;

// Normalização rápida
float invSqrt(float x) {
  return 1.0f / sqrtf(x);
}

// Madgwick AHRS (IMU‑only)
void MadgwickAHRSupdateIMU(float gx, float gy, float gz,
                           float ax, float ay, float az) {
  float recipNorm;
  float s0, s1, s2, s3;
  float qDot1, qDot2, qDot3, qDot4;

  // 1) derivada quaternion pela taxa de giro
  qDot1 = 0.5f * (-q1*gx - q2*gy - q3*gz);
  qDot2 = 0.5f * ( q0*gx + q2*gz - q3*gy);
  qDot3 = 0.5f * ( q0*gy - q1*gz + q3*gx);
  qDot4 = 0.5f * ( q0*gz + q1*gy - q2*gx);

  // 2) normaliza acelerômetro
  recipNorm = invSqrt(ax*ax + ay*ay + az*az);
  ax *= recipNorm; ay *= recipNorm; az *= recipNorm;

  // 3) gradiente de correção
  float _2q0 = 2.0f*q0, _2q1 = 2.0f*q1, _2q2 = 2.0f*q2, _2q3 = 2.0f*q3;
  float _4q0 = 4.0f*q0, _4q1 = 4.0f*q1, _4q2 = 4.0f*q2;
  float _8q1 = 8.0f*q1, _8q2 = 8.0f*q2;
  float q0q0 = q0*q0, q1q1 = q1*q1, q2q2 = q2*q2, q3q3 = q3*q3;

  s0 = _4q0*q2q2 + _2q2*ax + _4q0*q1q1 - _2q1*ay;
  s1 = _4q1*q3q3 - _2q3*ax + 4.0f*q0q0*q1 - _2q0*ay + _4q1*az - _8q1*q1q1 - _8q1*q2q2;
  s2 = 4.0f*q0q0*q2 + _2q0*ax + _4q2*q3q3 - _2q3*ay + _4q2*az - _8q2*q1q1 - _8q2*q2q2;
  s3 = 4.0f*q1q1*q3 - _2q1*ax + 4.0f*q2q2*q3 - _2q2*ay;

  recipNorm = invSqrt(s0*s0 + s1*s1 + s2*s2 + s3*s3);
  s0 *= recipNorm; s1 *= recipNorm; s2 *= recipNorm; s3 *= recipNorm;

  // 4) aplica correção
  qDot1 -= beta * s0;
  qDot2 -= beta * s1;
  qDot3 -= beta * s2;
  qDot4 -= beta * s3;

  // 5) integração
  float dt = 1.0f / sampleFreq;
  q0 += qDot1 * dt;
  q1 += qDot2 * dt;
  q2 += qDot3 * dt;
  q3 += qDot4 * dt;

  // 6) normaliza quaternion
  recipNorm = invSqrt(q0*q0 + q1*q1 + q2*q2 + q3*q3);
  q0 *= recipNorm; q1 *= recipNorm; q2 *= recipNorm; q3 *= recipNorm;
}

// ===== CORS =====
void sendCORS() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
}

// OPTIONS handler
void handleOptions() {
  sendCORS();
  server.send(200);
}

// “Ping” handler
void handleRoot() {
  sendCORS();
  server.send(200, "text/plain", "ESP32 MPU6050 YPR server");
}

// /imu handler
void handleIMU() {
  sendCORS();

  // calcula dt
  unsigned long now = micros();
  float dt = (now - lastMicros) * 1e-6f;
  lastMicros = now;

  // lê sensor
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

  // converte e subtrai bias Z
  float accelX = ax / 16384.0f;
  float accelY = ay / 16384.0f;
  float accelZ = az / 16384.0f;
  const float deg2rad = M_PI / 180.0f;
  float gyroX = gx / 131.0f * deg2rad;
  float gyroY = gy / 131.0f * deg2rad;
  float gyroZ = (gz - biasRawZ) / 131.0f * deg2rad;

  // atualiza estado quaternion
  MadgwickAHRSupdateIMU(gyroX, gyroY, gyroZ, accelX, accelY, accelZ);

  // extrai YPR
  float yaw = atan2f(2*(q1*q2 + q0*q3),
                     q0*q0 + q1*q1 - q2*q2 - q3*q3)
              * 180.0f/M_PI;
  float pitch = asinf(fmaxf(-1.0f, fminf(1.0f, 2*(q0*q2 - q1*q3))))
                * 180.0f/M_PI;
  float roll = atan2f(2*(q0*q1 + q2*q3),
                      q0*q0 - q1*q1 - q2*q2 + q3*q3)
               * 180.0f/M_PI;

  // monta JSON
  String json = "{";
  json += "\"yaw\":"   + String(yaw,   2) + ",";
  json += "\"pitch\":" + String(pitch, 2) + ",";
  json += "\"roll\":"  + String(roll,  2);
  json += "}";

  server.send(200, "application/json", json);
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("MPU6050 não encontrado!");
    while (1) { delay(10); }
  }

  // calibra bias do gyro Z
  Serial.println("Calibrando gyro Z, mantenha parado...");
  long sum = 0;
  for (int i = 0; i < 500; i++) {
    int16_t ax, ay, az, gx, gy, gz;
    mpu.getMotion6(&ax,&ay,&az,&gx,&gy,&gz);
    sum += gz;
    delay(5);
  }
  biasRawZ = sum / 500.0f;
  Serial.print("Bias bruto Z = "); Serial.println(biasRawZ);

  // conecta Wi‑Fi
  Serial.print("Conectando em "); Serial.print(ssid);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(250); Serial.print(".");
  }
  Serial.println();
  Serial.print("IP: "); Serial.println(WiFi.localIP());

  // configura endpoints
  server.on("/", HTTP_GET, handleRoot);
  server.on("/", HTTP_OPTIONS, handleOptions);
  server.on("/imu", HTTP_GET, handleIMU);
  server.on("/imu", HTTP_OPTIONS, handleOptions);
  server.begin();
  Serial.println("Servidor HTTP iniciado!");

  lastMicros = micros();
}

void loop() {
  server.handleClient();
}
