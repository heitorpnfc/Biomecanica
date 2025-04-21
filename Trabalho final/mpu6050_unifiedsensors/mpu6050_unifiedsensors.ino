#include <WiFi.h>
#include <WebServer.h>
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

// Configurações de Wi‑Fi
const char* ssid = "Martins 6";
const char* password = "17031998";

// Instancia o servidor HTTP na porta 80
WebServer server(80);

// Cria o objeto para o sensor MPU6050
MPU6050 mpu;

// =======================
// Filtro Kalman Simples
// =======================
class Kalman {
  public:
    Kalman() {
      Q_angle = 0.001;
      Q_bias  = 0.003;
      R_measure = 0.03;
      angle = 0;
      bias = 0;
      P[0][0] = 0;
      P[0][1] = 0;
      P[1][0] = 0;
      P[1][1] = 0;
    }
    
    // Atualiza e retorna o ângulo filtrado.
    double getAngle(double newAngle, double newRate, double dt) {
      double rate = newRate - bias;
      angle += dt * rate;
      
      // Atualiza a matriz de covariância
      P[0][0] += dt * (dt * P[1][1] - P[0][1] - P[1][0] + Q_angle);
      P[0][1] -= dt * P[1][1];
      P[1][0] -= dt * P[1][1];
      P[1][1] += Q_bias * dt;
      
      // Calcula o ganho de Kalman
      double S = P[0][0] + R_measure;
      double K0 = P[0][0] / S;
      double K1 = P[1][0] / S;
      
      // Atualiza o ângulo com a medição
      double y = newAngle - angle;
      angle += K0 * y;
      bias  += K1 * y;
      
      // Atualiza a matriz de covariância
      double P00_temp = P[0][0];
      double P01_temp = P[0][1];
      P[0][0] -= K0 * P00_temp;
      P[0][1] -= K0 * P01_temp;
      P[1][0] -= K1 * P00_temp;
      P[1][1] -= K1 * P01_temp;
      
      return angle;
    }
    
  private:
    double Q_angle, Q_bias, R_measure;
    double angle, bias;
    double P[2][2];
};

Kalman kalmanX; // Para Roll
Kalman kalmanY; // Para Pitch

unsigned long previousTime = 0;
double yawAngle = 0;  // Integração para Yaw
const float PI_F = 3.14159265358979323846;

// Função para enviar cabeçalhos CORS
void sendCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "*");
}

// Endpoint para requisições OPTIONS (necessário para CORS)
void handleOptions() {
  sendCORSHeaders();
  server.send(200);
}

// Endpoint raiz: mensagem simples
void handleRoot() {
  sendCORSHeaders();
  server.send(200, "text/plain", "Conectado com ESP32_S3 via WiFi!");
}

// Endpoint /imu: retorna os dados do MPU6050 no formato JSON
void handleIMU() {
  unsigned long currentTime = millis();
  double dt = (currentTime - previousTime) / 1000.0;
  previousTime = currentTime;
  
  // Leitura do sensor MPU6050
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
  
  // Conversão dos valores para unidades físicas
  double AccX = ax / 16384.0;
  double AccY = ay / 16384.0;
  double AccZ = az / 16384.0;
  
  double GyroX = gx / 131.0;
  double GyroY = gy / 131.0;
  double GyroZ = gz / 131.0;
  
  // Cálculo dos ângulos do acelerômetro (em graus)
  double rollAcc  = atan2(AccY, AccZ) * 180.0 / PI_F;
  double pitchAcc = atan2(-AccX, sqrt(AccY * AccY + AccZ * AccZ)) * 180.0 / PI_F;
  
  // Aplicação dos filtros Kalman para Roll e Pitch
  double roll  = kalmanX.getAngle(rollAcc, GyroX, dt);
  double pitch = kalmanY.getAngle(pitchAcc, GyroY, dt);
  
  // Integração para Yaw (atenção: suscetível à deriva)
  yawAngle += GyroZ * dt;
  double yaw = yawAngle;
  
  // Conversão das acelerações para m/s²
  double ax_m = AccX * 9.81;
  double ay_m = AccY * 9.81;
  double az_m = AccZ * 9.81;
  
  // Monta o JSON com os dados
  String jsonData = "{";
  jsonData += "\"yaw\":" + String(yaw, 2) + ",";
  jsonData += "\"pitch\":" + String(pitch, 2) + ",";
  jsonData += "\"roll\":" + String(roll, 2) + ",";
  jsonData += "\"ax\":" + String(ax_m, 2) + ",";
  jsonData += "\"ay\":" + String(ay_m, 2) + ",";
  jsonData += "\"az\":" + String(az_m, 2);
  jsonData += "}";
  
  sendCORSHeaders();
  server.send(200, "application/json", jsonData);
}

void setup() {
  Serial.begin(115200);
  Wire.begin();
  
  // Inicializa o MPU6050
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("Erro ao conectar com o MPU6050!");
    // Opcional: while(1);
  }
  
  // Conecta à rede Wi‑Fi
  Serial.print("Conectando ao WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("Conectado! IP: ");
  Serial.println(WiFi.localIP());
  
  // Configura os endpoints do servidor HTTP
  server.on("/", HTTP_GET, handleRoot);
  server.on("/", HTTP_OPTIONS, handleOptions);
  server.on("/imu1", HTTP_GET, handleIMU);
  server.on("/imu1", HTTP_OPTIONS, handleOptions);
  
  server.begin();
  Serial.println("Servidor HTTP iniciado, aguardando conexões...");
  
  previousTime = millis();
}

void loop() {
  server.handleClient();
  delay(10);
}
