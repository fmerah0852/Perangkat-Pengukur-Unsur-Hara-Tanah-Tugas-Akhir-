#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c2c68c192200"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer* pServer = nullptr;
BLECharacteristic* pCharacteristic = nullptr;
bool deviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Client terhubung!");
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Client terputus, mulai iklan ulang...");
      pServer->getAdvertising()->start();
    }
};

void setup() {
  Serial.begin(115200);
  BLEDevice::init("ESP32_NPK_DUMMY");

  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  pService->start();
  pServer->getAdvertising()->start();
  Serial.println("Menunggu koneksi BLE...");
}

void loop() {
  static float n = 30.0, p = 15.0, k = 45.0;

  if (deviceConnected) {
    String payload = "{\"device_id\":\"esp32-npk-dummy\",\"n\":" + String(n,1) +
                     ",\"p\":" + String(p,1) + ",\"k\":" + String(k,1) + "}";
    pCharacteristic->setValue(payload.c_str());
    pCharacteristic->notify();
    Serial.println("Kirim: " + payload);

    n += 0.5;
    p += 0.3;
    k += 0.7;
    if (n > 50) { n = 30; p = 15; k = 45; }

    delay(2000);
  } else {
    delay(1000);
  }
}
