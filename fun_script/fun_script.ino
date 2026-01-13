#include <SPI.h>
#include <Adafruit_GFX.h>    
#include <Adafruit_ST7789.h> 
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Stepper.h>

// --- Stepper Setup ---
const int stepsPerRevolution = 200;
// Note: Ensure your wiring matches these pins (A0-A3 or D6-D11 depending on labels)
Stepper myStepper(stepsPerRevolution, 6, 9, 10, 11);

// --- Screen Setup ---
Adafruit_ST7789 tft = Adafruit_ST7789(TFT_CS, TFT_DC, TFT_RST);

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

void clockwise(){
  // Update screen to show what's happening
  tft.setCursor(0, 40);
  tft.print("Moving CW...");
  
  myStepper.setSpeed(50);
  myStepper.step(stepsPerRevolution);
  
  tft.setCursor(0, 40);
  tft.setTextColor(ST77XX_GREEN);
  tft.print("Done!       ");
  tft.setTextColor(ST77XX_WHITE);
}

void counterclockwise(){
  tft.setCursor(0, 40);
  tft.print("Moving CCW...");
  
  myStepper.setSpeed(50);
  myStepper.step(-stepsPerRevolution);
  
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
}