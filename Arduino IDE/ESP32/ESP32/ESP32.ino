#include <Arduino.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ================== LCD CONFIG ==================
#define LCD_ADDR 0x27   // Alamat I2C LCD (0x27 atau 0x3F)
#define LCD_SDA  21     // SDA ESP32
#define LCD_SCL  22     // SCL ESP32
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);

// ================== BLE CONFIG ==================
#define DEVICE_NAME         "ESP32_NPK_DUMMY"
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c2c68c192200"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic; 
bool deviceConnected = false;

// ================== RS485 PIN ==================
#define DE_PIN    32
#define RE_PIN    33
#define RS485_RX  16
#define RS485_TX  17

HardwareSerial &rs485 = Serial2;

// ================== MODBUS PARAMETER ==================
const uint32_t MODBUS_BAUD   = 4800;
const uint8_t  MODBUS_ID     = 1;
const uint16_t START_ADDR    = 0x0000; // 0x0000..0x0006 (7 register)
const uint16_t NUM_REGISTERS = 7;

// ================== CRC16 ==================
uint16_t modbusCRC(const uint8_t *data, uint8_t len) {
  uint16_t crc = 0xFFFF;
  for (uint8_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t j = 0; j < 8; j++) {
      if (crc & 0x0001) crc = (crc >> 1) ^ 0xA001;
      else crc >>= 1;
    }
  }
  return crc;
}

// ================== RS485 HELPERS ==================
void rs485ToTX() {
  digitalWrite(DE_PIN, HIGH);
  digitalWrite(RE_PIN, HIGH);
}

void rs485ToRX() {
  digitalWrite(DE_PIN, LOW);
  digitalWrite(RE_PIN, LOW);
}

void clearRs485Buffer() {
  while (rs485.available()) rs485.read();
}

// ================== MODBUS READ FUNCTION ==================
bool readHoldingRegisters(uint8_t id, uint16_t startAddr, uint16_t qty,
                          uint8_t *respBuf, uint8_t &respLen)
{
  uint8_t frame[8];
  frame[0] = id;           // slave ID
  frame[1] = 0x03;         // function code FC03
  frame[2] = highByte(startAddr);
  frame[3] = lowByte(startAddr);
  frame[4] = highByte(qty);
  frame[5] = lowByte(qty);

  uint16_t crc = modbusCRC(frame, 6);
  frame[6] = lowByte(crc);
  frame[7] = highByte(crc);

  clearRs485Buffer();
  rs485ToTX();
  delayMicroseconds(200);
  rs485.write(frame, 8);
  rs485.flush();
  delayMicroseconds(200);
  rs485ToRX();

  uint8_t idx = 0;
  uint8_t expected = 5 + qty * 2; // ID + FC + byteCount + (qty*2) + CRC(2)
  unsigned long start = millis();

  while ((millis() - start) < 500 && idx < expected) {
    if (rs485.available()) {
      respBuf[idx++] = rs485.read();
    }
  }
  respLen = idx;

  if (respLen < expected) return false;

  uint16_t crcCalc = modbusCRC(respBuf, respLen - 2);
  uint16_t crcResp = respBuf[respLen - 2] | (respBuf[respLen - 1] << 8);
  if (crcResp != crcCalc) return false;

  return true;
}

// ================== BLE CALLBACK ==================
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) { deviceConnected = true; }
  void onDisconnect(BLEServer *pServer) { deviceConnected = false; }
};

// ================== SETUP ==================
void setup() {
  Serial.begin(115200);

  // RS485 control
  pinMode(DE_PIN, OUTPUT);
  pinMode(RE_PIN, OUTPUT);
  rs485ToRX();

  rs485.begin(MODBUS_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);

  // ==== LCD ====
  Wire.begin(LCD_SDA, LCD_SCL);
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Starting...");
  delay(1500);

  // ==== BLE INIT ====
  BLEDevice::init(DEVICE_NAME);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *service = pServer->createService(SERVICE_UUID);
  pCharacteristic = service->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ   |
      BLECharacteristic::PROPERTY_NOTIFY |
      BLECharacteristic::PROPERTY_WRITE
  );

  pCharacteristic->addDescriptor(new BLE2902());
  service->start();
  pServer->getAdvertising()->start();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("BLE Ready...");
  delay(1000);
}

// ================== LOOP ==================
void loop() {
  static unsigned long lastRead = 0;
  static bool lcdPage = false;      // false = halaman 1, true = halaman 2

  if (millis() - lastRead < 2000) return; // baca tiap 2 detik
  lastRead = millis();

  uint8_t resp[40];
  uint8_t respLen = 0;

  if (!readHoldingRegisters(MODBUS_ID, START_ADDR, NUM_REGISTERS, resp, respLen)) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Sensor Error");
    Serial.println("Sensor Error (Modbus read failed)");
    return;
  }

  // Parse 7 register (0x0000..0x0006)
  uint16_t reg[NUM_REGISTERS];
  for (int i = 0; i < NUM_REGISTERS; i++) {
    reg[i] = (resp[3 + 2*i] << 8) | resp[4 + 2*i];
  }

  float humidity    = reg[0] / 10.0; // %
  float temperature = reg[1] / 10.0; // °C
  uint16_t cond     = reg[2];        // uS/cm
  float ph          = reg[3] / 10.0; // pH
  uint16_t N        = reg[4];        // mg/kg
  uint16_t P        = reg[5];        // mg/kg
  uint16_t K        = reg[6];        // mg/kg

  // ================== LCD DISPLAY (2 halaman) ==================
  char line1[17];
  char line2[17];

  if (!lcdPage) {
    // Halaman 1: T, H, pH, EC
    snprintf(line1, sizeof(line1), "T:%.1fC H:%.1f", temperature, humidity);
    snprintf(line2, sizeof(line2), "pH:%.1f EC:%d", ph, cond);
  } else {
    // Halaman 2: N, P, K
    snprintf(line1, sizeof(line1), "N:%d P:%d", N, P);
    snprintf(line2, sizeof(line2), "K:%d", K);
  }

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print(line1);
  lcd.setCursor(0, 1);
  lcd.print(line2);

  lcdPage = !lcdPage;  // toggle halaman tiap baca

  // ================== KIRIM KE BLE (FORMAT JSON) ==================
  // JSON: {"temp":..,"hum":..,"ec":..,"ph":..,"n":..,"p":..,"k":..}
  char json[160];
  snprintf(json, sizeof(json),
           "{\"temp\":%.1f,\"hum\":%.1f,\"ec\":%d,\"ph\":%.1f,\"n\":%d,\"p\":%d,\"k\":%d}",
           temperature, humidity, cond, ph, N, P, K);

  if (deviceConnected) {
    pCharacteristic->setValue((uint8_t*)json, strlen(json));
    pCharacteristic->notify();
  }

  Serial.println(json);
}
