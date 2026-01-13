#include <SPI.h>
#include <Adafruit_GFX.h>    
#include <Adafruit_ST7789.h> 
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Stepper.h>
#include <Adafruit_AS5600.h>

// --- Stepper Setup ---
const int stepsPerRevolution = 200;
// Note: Ensure your wiring matches these pins (A0-A3 or D6-D11 depending on labels)
Stepper myStepper(stepsPerRevolution, 6, 9, 10, 11);

// --- Screen Setup ---
Adafruit_ST7789 tft = Adafruit_ST7789(TFT_CS, TFT_DC, TFT_RST);

// --- Sensor Setup ---
Adafruit_AS5600 as5600;
unsigned long lastSensorReadTime = 0;
const unsigned long sensorReadInterval = 100; // Send update every 100ms

// --- Bluetooth Setup ---
BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// --- Command Handling State ---
// We use these to pass data from the Bluetooth task to the Main Loop
String incomingCommand = "";
bool newCommandReceived = false;

#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

// Callback when data is received from Phone
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        // Just save the data and set the flag. 
        // Do NOT run motors here to avoid crashing the Bluetooth stack.
        incomingCommand = rxValue.c_str(); 
        newCommandReceived = true;
      }
    }
};

void updateSensor() {
  // 3. Sensor Tracking & Bluetooth
  if (as5600.isMagnetDetected()) {
      static uint16_t lastRawAngle = 0;
      static long sensorRotations = 0;
      static bool firstRead = true;
      
      // Use getRawAngle for 0-4095 integrity
      uint16_t currentRawAngle = as5600.getRawAngle(); 

      if (firstRead) {
          lastRawAngle = currentRawAngle;
          firstRead = false;
      }

      // Detect Wrap-Around (threshold ~1000 ticks)
      if ((currentRawAngle < 1000) && (lastRawAngle > 3000)) {
          sensorRotations++;
      } else if ((currentRawAngle > 3000) && (lastRawAngle < 1000)) {
          sensorRotations--;
      }
      lastRawAngle = currentRawAngle;

      if (deviceConnected && (millis() - lastSensorReadTime > sensorReadInterval)) {
          lastSensorReadTime = millis();
          
          double totalSensorTicks = (sensorRotations * 4096.0) + currentRawAngle;
          
          // Smooth the total ticks to reduce jitter
          static double smoothedTicks = 0;
          static bool firstRunSmoothed = true;
          
          if (firstRunSmoothed) {
            smoothedTicks = totalSensorTicks;
            firstRunSmoothed = false;
          } else {
            // EMA Smoothing
            smoothedTicks = (0.2 * totalSensorTicks) + (0.8 * smoothedTicks);
          }

          // Calibration: 1 Mech Rev = 4 Sensor Revs = 16384 ticks
          double totalMechRevs = smoothedTicks / 16384.0; 
          
          double currentMechAngle = totalMechRevs * 360.0;
          
          int mechRotations = (int)totalMechRevs;
          double angle0to360 = (currentMechAngle - (mechRotations * 360.0));
          if (angle0to360 < 0) angle0to360 += 360.0;
          
          // Format: "A:123.4 R:5 T:16000" (Added Ticks for debug)
          String dataStr = "A:" + String(angle0to360, 1) + " R:" + String(mechRotations) + " T:" + String((long)smoothedTicks);
          
          pTxCharacteristic->setValue(dataStr.c_str());
          pTxCharacteristic->notify();
      }
  }
}

void clockwise(){
  tft.setCursor(0, 40);
  tft.print("Moving CW...");
  myStepper.setSpeed(50);
  
  // Non-blocking step loop
  int stepsRemaining = stepsPerRevolution;
  int chunkSize = 5; 
  while(stepsRemaining > 0) {
      int s = (stepsRemaining > chunkSize) ? chunkSize : stepsRemaining;
      myStepper.step(s); 
      stepsRemaining -= s;
      updateSensor(); // Check sensor while moving
  }
  
  tft.setCursor(0, 40);
  tft.setTextColor(ST77XX_GREEN);
  tft.print("Done!       ");
  tft.setTextColor(ST77XX_WHITE);
}

void counterclockwise(){
  tft.setCursor(0, 40);
  tft.print("Moving CCW...");
  myStepper.setSpeed(50);
  
  // Non-blocking step loop
  int stepsRemaining = stepsPerRevolution;
  int chunkSize = 5; 
  while(stepsRemaining > 0) {
      int s = (stepsRemaining > chunkSize) ? chunkSize : stepsRemaining;
      myStepper.step(-s); 
      stepsRemaining -= s;
      updateSensor(); // Check sensor while moving
  }
  
  tft.setCursor(0, 40);
  tft.setTextColor(ST77XX_GREEN);
  tft.print("Done!       ");
  tft.setTextColor(ST77XX_WHITE);
}

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

void setup() {
  Serial.begin(115200);

  // 1. Start Screen
  pinMode(TFT_BACKLITE, OUTPUT);
  digitalWrite(TFT_BACKLITE, HIGH);
  tft.init(135, 240);
  tft.setRotation(3);
  tft.fillScreen(ST77XX_BLACK);
  tft.setTextColor(ST77XX_WHITE);
  tft.setTextSize(3);
  tft.setCursor(10, 10);
  tft.print("Waiting...");

  // 2. Start Bluetooth
  BLEDevice::init("Feather S3 Stepper");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
                    CHARACTERISTIC_UUID_TX,
                    BLECharacteristic::PROPERTY_NOTIFY
                  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic * pRxCharacteristic = pService->createCharacteristic(
                       CHARACTERISTIC_UUID_RX,
                       BLECharacteristic::PROPERTY_WRITE
                     );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  pService->start();
  pServer->getAdvertising()->start();

  // 3. Start Sensor
  if (!as5600.begin()) {
    Serial.println("Could not find AS5600 sensor, check wiring!");
    tft.setCursor(0, 100);
    tft.setTextColor(ST77XX_RED);
    tft.print("No Sensor!");
    tft.setTextColor(ST77XX_WHITE);
  } else {
    as5600.setPowerMode(AS5600_POWER_MODE_NOM);
    as5600.setHysteresis(AS5600_HYSTERESIS_3LSB); // Enable Hysteresis to reduce noise
    as5600.setOutputStage(AS5600_OUTPUT_STAGE_ANALOG_FULL);
    as5600.setSlowFilter(AS5600_SLOW_FILTER_16X);
    as5600.setFastFilterThresh(AS5600_FAST_FILTER_THRESH_SLOW_ONLY);
    as5600.setZPosition(0);
    as5600.setMPosition(4095);
    as5600.setMaxAngle(4095);
  }
}

void loop() {
  // 1. Handle New Commands
  if (newCommandReceived) {
    // Reset flag immediately so we don't repeat
    newCommandReceived = false; 

    // Print raw command to screen
    tft.fillScreen(ST77XX_BLACK);
    tft.setCursor(0, 0);
    tft.print(incomingCommand);
    Serial.println("Command: " + incomingCommand);

    // Motor Logic
    // We trim() to remove any invisible newlines from the phone
    incomingCommand.trim();
    
    if (incomingCommand == "CW") {
      clockwise();
    } 
    else if (incomingCommand == "CCW") {
      counterclockwise();
    }
  }

  // 2. Handle Disconnect/Reconnect
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); 
      pServer->startAdvertising(); 
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
      tft.fillScreen(ST77XX_GREEN); 
      delay(500);
      tft.fillScreen(ST77XX_BLACK);
      tft.setCursor(0,0);
      tft.print("Connected!");
  }

  // 3. Sensor Tracking & Bluetooth
  updateSensor();
}