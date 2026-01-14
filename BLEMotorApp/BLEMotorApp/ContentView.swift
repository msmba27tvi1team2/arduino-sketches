import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    
    // Calibration state
    @State private var highRotation: Double? = nil
    @State private var lowRotation: Double? = nil
    @State private var isAutoPositioning = false
    @State private var targetRotation: Double? = nil
    @State private var positioningTolerance: Double = 0.05
    @State private var isButtonPressed = false
    @AppStorage("isSwapped") private var isSwapped = false

    var body: some View {
        VStack(spacing: 20) {
            // Status Section
            VStack(alignment: .leading, spacing: 8) {
                Text(ble.statusText)
                    .font(.headline)
                    .padding(.bottom, 4)
                
                if !ble.discoveredDevices.isEmpty {
                    Text("Devices seen:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    ForEach(ble.discoveredDevices, id: \.self) { device in
                        Text(device)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Sensor Data Display
            if !ble.lastReceived.isEmpty {
                 let (angle, rotations, ticks) = parseSensorData(ble.lastReceived)
                 
                 HStack {
                     // Compass Visual
                     CompassView(angle: angle)
                     
                     Spacer()
                     
                     // Text Info
                     VStack(alignment: .trailing) {
                         Text("Angle")
                             .font(.caption)
                             .foregroundColor(.secondary)
                         Text(String(format: "%.1f°", angle))
                             .font(.title2.monospaced())
                             .bold()
                         
                         Text("Rotations")
                             .font(.caption)
                             .foregroundColor(.secondary)
                             .padding(.top, 4)
                         Text(String(format: "%.1f", rotations))
                             .font(.title2.monospaced())
                             .bold()
                             
                         Text("Ticks")
                             .font(.caption2)
                             .foregroundColor(.secondary)
                             .padding(.top, 4)
                         Text("\(ticks)")
                             .font(.system(.body, design: .monospaced))
                     }
                 }
                 .padding()
                 .background(Color.blue.opacity(0.1))
                 .cornerRadius(12)
                 .onChange(of: rotations) { newRotation in
                     checkAutoPositioning(currentRotation: newRotation)
                 }
            }
            
            // Connection Controls
            HStack(spacing: 20) {
                Button("Scan & Connect") {
                    ble.startScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ble.connected)
                
                Button("Disconnect") {
                    ble.disconnect()
                }
                .buttonStyle(.bordered)
                .disabled(!ble.connected)
            }
            
            // Calibration Section
            VStack(spacing: 12) {
                Text("Calibration")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    VStack {
                        Button("Set Low") {
                            if let (_, rotations, _) = getCurrentSensorData() {
                                lowRotation = rotations
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                        
                        if let low = lowRotation {
                            Text("Low: \(String(format: "%.1f", low))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack {
                        Button("Set High") {
                            if let (_, rotations, _) = getCurrentSensorData() {
                                highRotation = rotations
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                        
                        if let high = highRotation {
                            Text("High: \(String(format: "%.1f", high))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    Button("Go to Low") {
                        goToPosition(lowRotation)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(lowRotation == nil || isAutoPositioning || !ble.connected)
                    
                    Button("Go to High") {
                        goToPosition(highRotation)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(highRotation == nil || isAutoPositioning || !ble.connected)
                }
                
                if isAutoPositioning {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Moving to target...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Stop") {
                            stopAutoPositioning()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            // Motor Controls
            HStack(spacing: 30) {
                // Swap Control
                Button(action: {
                    isSwapped.toggle()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.title2)
                        Text(isSwapped ? "Swapped" : "Normal")
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .padding(8)
                    .frame(width: 80, height: 80)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
                
                // Directional Controls
                VStack(spacing: 20) {
                    // UP Button
                    Text("UP")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 100, height: 100)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isAutoPositioning && !isButtonPressed {
                                        isButtonPressed = true
                                        ble.startMotor(isSwapped ? "CW" : "CCW")
                                    }
                                }
                                .onEnded { _ in
                                    isButtonPressed = false
                                    ble.stopMotor()
                                }
                        )
                    
                    // DOWN Button
                    Text("DOWN")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 100, height: 100)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isAutoPositioning && !isButtonPressed {
                                        isButtonPressed = true
                                        ble.startMotor(isSwapped ? "CCW" : "CW")
                                    }
                                }
                                .onEnded { _ in
                                    isButtonPressed = false
                                    ble.stopMotor()
                                }
                        )
                }
            }
            .padding(.bottom, 20)
            
            Spacer()
        }
        .padding()
    }
    
    func getCurrentSensorData() -> (Double, Double, Int)? {
        if !ble.lastReceived.isEmpty {
            return parseSensorData(ble.lastReceived)
        }
        return nil
    }
    
    func goToPosition(_ target: Double?) {
        guard let target = target else { return }
        targetRotation = target
        isAutoPositioning = true
        
        // Start moving in the appropriate direction
        if let (_, currentRotation, _) = getCurrentSensorData() {
            let direction = target > currentRotation ? "CW" : "CCW"
            ble.startMotor(direction)
        }
    }
    
    func checkAutoPositioning(currentRotation: Double) {
        guard isAutoPositioning, let target = targetRotation else { return }
        
        // Check if we've reached the target (within tolerance)
        if abs(currentRotation - target) <= positioningTolerance {
            stopAutoPositioning()
        }
    }
    
    func stopAutoPositioning() {
        isAutoPositioning = false
        targetRotation = nil
        ble.stopMotor()
    }
    
    func parseSensorData(_ data: String) -> (Double, Double, Int) {
        // Format e.g. "A:123.4 R:2.4 T:1800"
        let components = data.components(separatedBy: " ")
        var angle = 0.0
        var rotations = 0.0
        var ticks = 0
        
        for comp in components {
            if comp.starts(with: "A:") {
                let val = comp.dropFirst(2)
                angle = Double(val) ?? 0.0
            } else if comp.starts(with: "R:") {
                let val = comp.dropFirst(2)
                rotations = Double(val) ?? 0.0
            } else if comp.starts(with: "T:") {
                let val = comp.dropFirst(2)
                ticks = Int(val) ?? 0
            }
        }
        return (angle, rotations, ticks)
    }
}

struct CompassView: View {
    var angle: Double
    @State private var visualAngle: Double = 0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                .frame(width: 80, height: 80)
            
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 70, height: 70)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(visualAngle))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visualAngle)
        }
        .onAppear {
            visualAngle = angle
        }
        .onChange(of: angle) { newValue in
            let currentMod = visualAngle.truncatingRemainder(dividingBy: 360)
            let normalizedCurrent = currentMod < 0 ? currentMod + 360 : currentMod
            
            var delta = newValue - normalizedCurrent
            
            // Shortest path logic
            if delta > 180 {
                delta -= 360
            } else if delta < -180 {
                delta += 360
            }
            
            visualAngle += delta
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
