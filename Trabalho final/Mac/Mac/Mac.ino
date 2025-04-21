/*
  Lê o MAC de forma confiável em qualquer versão da core
  e imprime também o MAC da interface STA (para ESP‑NOW).
*/
#include <WiFi.h>
#include <Network.h>      // disponível a partir da core 3.0
#include <esp_system.h>   // fallback p/ versões antigas

void setup() {
  Serial.begin(115200);
  delay(400);

  // 1) MAC gravado no eFuse ― vale sempre
  uint8_t baseMac[6];
#if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3,0,0)
  Network.macAddress(baseMac);              // novo método
#else
  esp_efuse_mac_get_default(baseMac);       // core 2.x
#endif
  Serial.printf("Base MAC (eFuse): %02X:%02X:%02X:%02X:%02X:%02X\n",
                baseMac[0], baseMac[1], baseMac[2],
                baseMac[3], baseMac[4], baseMac[5]);

  // 2) Liga somente a interface STA e obtém o MAC real usado no Wi‑Fi/ESP‑NOW
  WiFi.mode(WIFI_MODE_STA);   // habilita Wi‑Fi
  WiFi.STA.begin();           // não precisa conectar
  delay(50);                  // dá tempo para o driver subir

  Serial.print("STA MAC (ESP‑NOW): ");
  Serial.println(WiFi.macAddress());
}

void loop() {}
