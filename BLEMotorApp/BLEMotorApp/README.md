BLEMotorApp - README
=====================

What this package contains:
- BLEMotorApp.swift   -> App entry file
- ContentView.swift   -> SwiftUI UI with buttons and slider
- BLEManager.swift    -> CoreBluetooth logic (scan, connect, write, subscribe)
- Info.plist          -> Template Info.plist snippet (contains Bluetooth usage description)
- README.md           -> This file with instructions

How to create a runnable Xcode project quickly:
1. Open Xcode (13 or later recommended).
2. File -> New -> Project -> App (iOS) -> Next.
3. Product Name: BLEMotorApp (or whatever you like). Interface: SwiftUI. Language: Swift. Check "Use Core Data" off.
4. Save the new project to your machine.
5. In the Project Navigator, delete the auto-generated files named BLEMotorApp.swift, ContentView.swift, Info.plist (you can keep the LaunchScreen.storyboard).
6. Copy the files from this folder into the Xcode project folder (or drag them into the Project Navigator):
   - BLEMotorApp.swift
   - ContentView.swift
   - BLEManager.swift
7. Open Info.plist in Xcode and add the key 'Privacy - Bluetooth Always Usage Description' (NSBluetoothAlwaysUsageDescription) with the value:
   "This app needs Bluetooth to connect to your Feather device for motor control."
8. Plug your iPhone into the Mac and select it as the run target (CoreBluetooth does not run in Simulator).
9. Build & Run. On first run iOS will ask for Bluetooth permissions — accept them.
10. Tap 'Scan & Connect' and select your Feather device (it should be advertising the NUS service). Use the CW/CCW/STOP buttons and the speed slider to control the motor.

Notes and troubleshooting:
- Make sure your Feather is advertising the Nordic UART service (6E400001-B5A3-F393-E0A9-E50E24DCCA9E).
- Test the Feather with Bluefruit Connect or nRF Connect first to confirm behavior.
- If the app doesn't see the device, ensure Bluetooth is enabled on the iPhone and the Feather is powered and advertising.
- If you want background operation or auto-reconnect features, additional capabilities and code are required.
