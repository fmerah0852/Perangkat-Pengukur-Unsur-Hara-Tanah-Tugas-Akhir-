#include <Arduino.h>

// ================== KONFIGURASI PIN RS485 ==================
#define DE_PIN    32
#define RE_PIN    33
#define RS485_RX  16
#define RS485_TX  17

// Gunakan Serial2 untuk ESP32
HardwareSerial &rs485 = Serial2;

// ================== PARAMETER MODBUS ==================
const uint32_t MODBUS_BAUD   = 4800;   // Pastikan baudrate sesuai spesifikasi sensor
const uint8_t  MODBUS_ID     = 1;      // ID Slave Sensor
const uint16_t START_ADDR    = 0x0000; // Alamat awal register
const uint16_t NUM_REGISTERS = 7;      // Jumlah data (Hum, Temp, EC, pH, N, P, K)

// ================== FUNGSI CRC16 ==================
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

// ================== KONTROL PIN RS485 ==================
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

// ================== FUNGSI BACA MODBUS ==================
bool readHoldingRegisters(uint8_t id, uint16_t startAddr, uint16_t qty,
                          uint8_t *respBuf, uint8_t &respLen)
{
  uint8_t frame[8];
  // Menyusun Request Frame
  frame[0] = id;           // Slave ID
  frame[1] = 0x03;         // Function Code (Read Holding Registers)
  frame[2] = highByte(startAddr);
  frame[3] = lowByte(startAddr);
  frame[4] = highByte(qty);
  frame[5] = lowByte(qty);

  // Hitung CRC request
  uint16_t crc = modbusCRC(frame, 6);
  frame[6] = lowByte(crc);
  frame[7] = highByte(crc);

  // Kirim Request
  clearRs485Buffer();
  rs485ToTX();
  delayMicroseconds(200); // Delay stabilitas
  rs485.write(frame, 8);
  rs485.flush();          // Tunggu pengiriman selesai
  delayMicroseconds(200);
  rs485ToRX();            // Pindah ke mode Terima (Receive)

  // Baca Respon
  uint8_t idx = 0;
  // Rumus panjang respon: ID + FC + ByteCount + (Qty*2) + CRC(2)
  uint8_t expected = 5 + qty * 2; 
  unsigned long start = millis();

  // Timeout 500ms
  while ((millis() - start) < 500 && idx < expected) {
    if (rs485.available()) {
      respBuf[idx++] = rs485.read();
    }
  }
  respLen = idx;

  // Validasi Panjang Data
  if (respLen < expected) {
    Serial.print("Timeout/Data Kurang. Diterima: ");
    Serial.println(respLen);
    return false;
  }

  // Validasi CRC Respon
  uint16_t crcCalc = modbusCRC(respBuf, respLen - 2);
  uint16_t crcResp = respBuf[respLen - 2] | (respBuf[respLen - 1] << 8);
  
  if (crcResp != crcCalc) {
    Serial.println("CRC Error!");
    return false;
  }

  return true;
}

// ================== SETUP ==================
void setup() {
  // Serial Monitor untuk debug ke Laptop
  Serial.begin(115200);
  while (!Serial);
  Serial.println("\n=== TES SENSOR RS485 NPK ===");

  // Setup Pin RS485
  pinMode(DE_PIN, OUTPUT);
  pinMode(RE_PIN, OUTPUT);
  rs485ToRX(); // Default mode receive

  // Setup Serial2 untuk RS485 Modbus
  rs485.begin(MODBUS_BAUD, SERIAL_8N1, RS485_RX, RS485_TX);
}

// ================== LOOP ==================
void loop() {
  uint8_t resp[40];
  uint8_t respLen = 0;

  Serial.println("\n--- Membaca Sensor... ---");

  if (readHoldingRegisters(MODBUS_ID, START_ADDR, NUM_REGISTERS, resp, respLen)) {
    // Parsing Data (Sesuai urutan register NPK umum)
    // Byte 3 & 4 = Register 1, dst...
    
    // Register 0: Humidity (0.1 %)
    uint16_t rawHum = (resp[3] << 8) | resp[4];
    float humidity = rawHum / 10.0;

    // Register 1: Temperature (0.1 C)
    uint16_t rawTemp = (resp[5] << 8) | resp[6];
    float temperature = rawTemp / 10.0;

    // Register 2: Conductivity (uS/cm)
    uint16_t cond = (resp[7] << 8) | resp[8];

    // Register 3: pH (0.1)
    uint16_t rawPh = (resp[9] << 8) | resp[10];
    float ph = rawPh / 10.0;

    // Register 4: Nitrogen (mg/kg)
    uint16_t valN = (resp[11] << 8) | resp[12];

    // Register 5: Phosphorus (mg/kg)
    uint16_t valP = (resp[13] << 8) | resp[14];

    // Register 6: Potassium (mg/kg)
    uint16_t valK = (resp[15] << 8) | resp[16];

    // Tampilkan di Serial Monitor
    Serial.print("Kelembaban : "); Serial.print(humidity); Serial.println(" %");
    Serial.print("Suhu       : "); Serial.print(temperature); Serial.println(" C");
    Serial.print("Konduktivitas: "); Serial.print(cond); Serial.println(" uS/cm");
    Serial.print("pH Tanah   : "); Serial.print(ph); Serial.println("");
    Serial.print("Nitrogen   : "); Serial.print(valN); Serial.println(" mg/kg");
    Serial.print("Fosfor     : "); Serial.print(valP); Serial.println(" mg/kg");
    Serial.print("Kalium     : "); Serial.print(valK); Serial.println(" mg/kg");
    
  } else {
    Serial.println("Gagal membaca sensor (Cek wiring atau Power Supply)");
  }



  delay(2000); // Tunggu 2 detik sebelum membaca ulang
}