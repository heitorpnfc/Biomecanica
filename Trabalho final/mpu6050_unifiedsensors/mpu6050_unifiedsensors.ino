#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

// =======================
// Cria o objeto para o sensor MPU6050
// =======================
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
    // newAngle: ângulo medido (por exemplo, do acelerômetro)
    // newRate: taxa (do giroscópio) em °/s
    // dt: intervalo de tempo (segundos)
    double getAngle(double newAngle, double newRate, double dt) {
      // Predição:
      rate = newRate - bias;
      angle += dt * rate;
      
      P[0][0] += dt * (dt * P[1][1] - P[0][1] - P[1][0] + Q_angle);
      P[0][1] -= dt * P[1][1];
      P[1][0] -= dt * P[1][1];
      P[1][1] += Q_bias * dt;
      
      // Atualização:
      double S = P[0][0] + R_measure;
      double K[2];
      K[0] = P[0][0] / S;
      K[1] = P[1][0] / S;
      
      double y = newAngle - angle;
      angle += K[0] * y;
      bias  += K[1] * y;
      
      double P00_temp = P[0][0];
      double P01_temp = P[0][1];
      
      P[0][0] -= K[0] * P00_temp;
      P[0][1] -= K[0] * P01_temp;
      P[1][0] -= K[1] * P00_temp;
      P[1][1] -= K[1] * P01_temp;
      
      return angle;
    }
    
    // Define o ângulo inicial
    void setAngle(double angle) {
      this->angle = angle;
    }
    
    double getRate() {
      return rate;
    }
  
  private:
    double Q_angle;    // Variância do ruído do processo (aceleração)
    double Q_bias;     // Variância do ruído do processo (bias do giroscópio)
    double R_measure;  // Variância do ruído da medição
    
    double angle;      // Ângulo filtrado
    double bias;       // Bias estimado do giroscópio
    double rate;       // Taxa sem o bias
    
    double P[2][2];    // Matriz de covariância do erro
};

// =======================
// Instâncias dos filtros para Roll (X) e Pitch (Y)
// =======================
Kalman kalmanX; // para Roll
Kalman kalmanY; // para Pitch

// Variáveis para controle do tempo
unsigned long timer;
double yawAngle = 0;  // Integração para Yaw

void setup() {
  Serial.begin(115200);
  Wire.begin(); // Ajuste se necessário (ex.: Wire.begin(21,22) no ESP32)
  
  // Inicializa o MPU6050
  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("Erro ao conectar com o MPU6050!");
    while (1);
  }
  
  // Leitura inicial para calibrar o ângulo inicial do Kalman
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
  
  // Cálculo dos ângulos iniciais a partir do acelerômetro
  double rollAcc  = atan2(ay, az) * 180.0 / PI;
  double pitchAcc = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0 / PI;
  
  kalmanX.setAngle(rollAcc);
  kalmanY.setAngle(pitchAcc);
  
  timer = micros();
}

void loop() {
  // Leitura dos valores brutos do MPU6050
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);
  
  // Conversão dos valores brutos para unidades físicas
  double AccX = ax / 16384.0;  // aceleração em "g"
  double AccY = ay / 16384.0;
  double AccZ = az / 16384.0;
  
  double GyroX = gx / 131.0;     // °/s
  double GyroY = gy / 131.0;     // °/s
  double GyroZ = gz / 131.0;     // °/s
  
  // Calcula o intervalo de tempo (dt) em segundos
  unsigned long now = micros();
  double dt = (now - timer) / 1000000.0;
  timer = now;
  
  // Cálculo dos ângulos do acelerômetro (em graus)
  double rollAcc  = atan2(AccY, AccZ) * 180.0 / PI;
  double pitchAcc = atan2(-AccX, sqrt(AccY * AccY + AccZ * AccZ)) * 180.0 / PI;
  
  // Aplicação do filtro Kalman para Roll e Pitch
  double roll  = kalmanX.getAngle(rollAcc, GyroX, dt);
  double pitch = kalmanY.getAngle(pitchAcc, GyroY, dt);
  
  // Integração simples para Yaw (atenção à deriva!)
  yawAngle += GyroZ * dt;
  double yaw = yawAngle;
  
  // Conversão das acelerações para m/s²
  double ax_m_s2 = AccX * 9.81;
  double ay_m_s2 = AccY * 9.81;
  double az_m_s2 = AccZ * 9.81;
  
  // Converte roll e pitch para radianos
  double rollRad  = roll  * (PI / 180.0);
  double pitchRad = pitch * (PI / 180.0);
  
  // Estima o vetor da gravidade no referencial do sensor
  // (Ajuste os sinais se necessário, conforme a orientação do seu hardware)
  double gravX = 9.81 * sin(pitchRad);
  double gravY = -9.81 * sin(rollRad) * cos(pitchRad);
  double gravZ = 9.81 * cos(rollRad) * cos(pitchRad);
  
  // Subtrai a gravidade para obter a aceleração linear
  double ax_lin = ax_m_s2 - gravX;
  double ay_lin = ay_m_s2 - gravY;
  double az_lin = az_m_s2 - gravZ;
  
  // Envia os dados no formato CSV: Yaw, Pitch, Roll, ax_lin, ay_lin, az_lin
  Serial.print(yaw);      
  Serial.print(",");
  Serial.print(pitch);    
  Serial.print(",");
  Serial.print(roll);     
  Serial.print(",");
  Serial.print(ax_lin);   
  Serial.print(",");
  Serial.print(ay_lin);   
  Serial.print(",");
  Serial.println(az_lin);
  
  // Pequeno atraso para não saturar a serial
  delay(10);
}
