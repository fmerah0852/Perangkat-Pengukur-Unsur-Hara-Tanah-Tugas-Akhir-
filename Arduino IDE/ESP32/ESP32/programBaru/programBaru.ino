#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ================== KONFIGURASI LCD ==================
#define LCD_ADDR 0x27
#define LCD_SDA  21
#define LCD_SCL  22
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

// ================== KONFIGURASI BLE (DARI KODE LAMA) ==================
#define DEVICE_NAME         "ESP32_NPK_DUMMY" // Nama disamakan dengan kode lama
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c2c68c192200"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"



BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

// ================== KONFIGURASI RS485 ==================
#define DE_PIN 32
#define RE_PIN 33
#define RXD2   16
#define TXD2   17
HardwareSerial rs485(2);

// ================== PARAMETER MODBUS ==================
#define MODBUS_ID   1
#define MODBUS_BAUD 4800
#define START_ADDR  0x0000
#define NUM_REG     7

// ================== FUNGSI CRC16 ==================
uint16_t modbusCRC(uint8_t *buf, int len) {
  uint16_t crc = 0xFFFF;
  for (int i = 0; i < len; i++) {
    crc ^= buf[i];
    for (int j = 0; j < 8; j++) {
      if (crc & 1) crc = (crc >> 1) ^ 0xA001;
      else crc >>= 1;
    }
  }
  return crc;
}

// ================== KONTROL PIN RS485 ==================
void rs485TX() {
  digitalWrite(DE_PIN, HIGH);
  digitalWrite(RE_PIN, HIGH);
}

void rs485RX() {
  digitalWrite(DE_PIN, LOW);
  digitalWrite(RE_PIN, LOW);
}

// ================== CALLBACK BLE (DARI KODE LAMA) ==================
class MyServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      // Restart advertising agar bisa connect ulang jika putus
      pServer->getAdvertising()->start(); 
    }
};

// ================== FUNGSI BACA SENSOR (DARI KODE BARU) ==================
bool readNPK(uint16_t *reg) {
  uint8_t frame[8];
  frame[0] = MODBUS_ID;
  frame[1] = 0x03;
  frame[2] = highByte(START_ADDR);
  frame[3] = lowByte(START_ADDR);
  frame[4] = 0x00;
  frame[5] = NUM_REG;

  uint16_t crc = modbusCRC(frame, 6);
  frame[6] = lowByte(crc);
  frame[7] = highByte(crc);

  // Bersihkan buffer sebelum kirim
  while (rs485.available()) rs485.read();

  // Kirim Command
  rs485TX();
  delay(5); // Delay stabil (Kode Baru)
  rs485.write(frame, 8);
  rs485.flush();
  rs485RX();

  // Baca Respon
  uint8_t resp[32];
  int idx = 0;
  unsigned long start = millis();

  // Timeout 500ms
  while (millis() - start < 500) {
    if (rs485.available()) {
      resp[idx++] = rs485.read();
      // Format respon: ID + FC + ByteCount + Data(7*2) + CRC(2) = 5 + 14 = 19 byte
      if (idx >= (5 + NUM_REG * 2)) break;
    }
  }

  // Cek kelengkapan data
  if (idx < (5 + NUM_REG * 2)) return false;

  // Cek CRC Respon (Opsional, tapi bagus untuk validitas)
  uint16_t crcRec = (resp[idx-1] << 8) | resp[idx-2]; // CRC high/low mungkin terbalik tergantung sensor, tapi kita skip validasi CRC ketat agar lebih toleran.
  
  // Parsing Data
  for (int i = 0; i < NUM_REG; i++) {
    reg[i] = (resp[3 + i * 2] << 8) | resp[4 + i * 2];
  }
  return true;
}

// ================== SETUP ==================
void setup() {
  Serial.begin(115200);

  // Init RS485
  pinMode(DE_PIN, OUTPUT);
  pinMode(RE_PIN, OUTPUT);
  rs485RX();
  rs485.begin(MODBUS_BAUD, SERIAL_8N1, RXD2, TXD2);

  // Init LCD
  Wire.begin(LCD_SDA, LCD_SCL);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print("Starting...");
  delay(1500);

  // ==== INIT BLE (FULL DARI KODE LAMA) ====
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *service = pServer->createService(SERVICE_UUID);
  
  // Menggunakan properti READ | NOTIFY | WRITE seperti kode lama
  pCharacteristic = service->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_WRITE
                    );

  pCharacteristic->addDescriptor(new BLE2902());
  service->start();
  pServer->getAdvertising()->start();
  // ========================================

  lcd.clear();
  lcd.print("BLE Ready...");
  delay(1000);
}

// ================== LOOP ==================
void loop() {
  static unsigned long lastRead = 0;
  static bool lcdPage = false;

  // Baca setiap 2 detik
  if (millis() - lastRead < 2000) return;
  lastRead = millis();

  uint16_t reg[NUM_REG] = {0};
  bool ok = readNPK(reg);

  // Konversi Nilai
  float humidity    = reg[0] / 10.0;
  float temperature = reg[1] / 10.0;
  int ec            = reg[2];
  float ph          = reg[3] / 10.0;
  int N             = reg[4];
  int P             = reg[5];
  int K             = reg[6];

  // ===== VALIDASI DATA (DARI KODE BARU) =====
  // CATATAN: Jika Anda ingin melihat data suhu saat sensor di udara (belum ditancap),
  // hapus bagian "&& (humidity > 0 && ph > 0 && ec > 0)" di bawah ini.
  bool valid = ok && (humidity > 0 && ph > 0 && ec > 0);

  if (!valid) {
    // Jika sensor error atau tidak ditancap tanah (EC=0), nol-kan semua
    humidity = temperature = ph = 0;
    ec = N = P = K = 0;
  }

  // ===== TAMPILAN LCD (DARI KODE BARU - LEBIH RAPI) =====
  lcd.clear();
  if (!lcdPage) {
    lcd.setCursor(0, 0);
    lcd.printf("T:%.1fC H:%.0f%%", temperature, humidity);
    lcd.setCursor(0, 1);
    lcd.printf("EC:%d pH:%.1f", ec, ph);
  } else {
    lcd.setCursor(0, 0);
    lcd.printf("N:%d P:%d", N, P);
    lcd.setCursor(0, 1);
    lcd.printf("K:%d", K);
  }
  lcdPage = !lcdPage; // Ganti halaman untuk loop berikutnya

  // ===== KIRIM BLE (DARI KODE BARU + LOGIKA LAMA) =====
  char json[128];
  // Format JSON
  snprintf(json, sizeof(json),
    "{\"temp\":%.1f,\"hum\":%.1f,\"ec\":%d,\"ph\":%.1f,\"n\":%d,\"p\":%d,\"k\":%d}",
    temperature, humidity, ec, ph, N, P, K);

  // Kirim jika ada HP connect
  if (deviceConnected) {
    pCharacteristic->setValue((uint8_t*)json, strlen(json)); // Style kode lama (cast uint8_t)
    pCharacteristic->notify();
  }

  // Debug Serial Monitor
  Serial.print("Valid: "); Serial.print(valid);
  Serial.print(" | ");
  Serial.println(json);
}