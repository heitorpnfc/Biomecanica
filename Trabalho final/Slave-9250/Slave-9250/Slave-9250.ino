#include <WiFi.h>
#include <esp_now.h>

// MAC do ESP Mestre
uint8_t masterAddress[] = {0xCC, 0xBA, 0x97, 0x15, 0x45, 0x34};

typedef struct {
  int number;
} Message;

// callback de recebimento (Mestre → Escravo)
void onDataRecv(const esp_now_recv_info_t *info, const uint8_t *data, int len) {
  Message msg;
  memcpy(&msg, data, sizeof(msg));
  Serial.print("Slave: recebeu ");
  Serial.println(msg.number);

  // soma +1 e envia de volta
  msg.number++;
  Serial.print("Slave: enviando de volta ");
  Serial.println(msg.number);
  esp_now_send(info->src_addr, (uint8_t *)&msg, sizeof(msg));
}

// callback de envio (Escravo → Mestre)
void onDataSent(const uint8_t *mac_addr, esp_now_send_status_t status) {
  Serial.print("Slave: status de envio para ");
  for (int i = 0; i < 6; i++) {
    if (i) Serial.print(':');
    Serial.printf("%02X", mac_addr[i]);
  }
  Serial.print(" = ");
  Serial.println(status == ESP_NOW_SEND_SUCCESS ? "SUCESSO" : "FALHOU");
}

void setup() {
  Serial.begin(115200);
  Serial.println("Slave: setup iniciado");  // <-- flag de início
  WiFi.mode(WIFI_STA);
  WiFi.disconnect();

  if (esp_now_init() != ESP_OK) {
    Serial.println("Slave: falha ao iniciar ESP-NOW");
    return;
  }

  esp_now_register_recv_cb(onDataRecv);
  esp_now_register_send_cb(onDataSent);

  // adiciona peer (mestre)
  esp_now_peer_info_t peer = {};
  memcpy(peer.peer_addr, masterAddress, 6);
  peer.channel = 0;
  peer.encrypt = false;
  if (esp_now_add_peer(&peer) != ESP_OK) {
    Serial.println("Slave: falha ao adicionar peer");
  }
}

void loop() {
  // tudo funciona via callbacks
}
