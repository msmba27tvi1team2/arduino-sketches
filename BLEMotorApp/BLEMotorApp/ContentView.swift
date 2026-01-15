import SwiftUI

struct ContentView: View {
    @ObservedObject private var ble = BLEManager.shared
    
    // Persistent calibration state using AppStorage
    @AppStorage("isCalibrated") private var isCalibrated = false
    @AppStorage("highRotation") private var highRotation: Double = 0.0
    @AppStorage("lowRotation") private var lowRotation: Double = 0.0
    @AppStorage("isSwapped") private var isSwapped = false
    
    // Temporary state
    @State private var isAutoPositioning = false
    @State private var targetRotation: Double? = nil
    @State private var positioningTolerance: Double = 0.05
    @State private var isButtonPressed = false
    @State private var showDebugDialog = false
    
    // Setup phase temporary values (before saving to persistent storage)
    @State private var tempHighRotation: Double? = nil
    @State private var tempLowRotation: Double? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Debug Button
            HStack {
                Spacer()
                Button(action: { showDebugDialog = true }) {
                    HStack {
                        Image(systemName: "ant.circle")
                        Text("Debug")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.bordered)
            }
            
            // Sensor Data Display - Always visible
            let (angle, rotations, ticks) = !ble.lastReceived.isEmpty ? parseSensorData(ble.lastReceived) : (0.0, 0.0, 0)
            
            HStack {
                // Compass Visual - Compact
                CompassView(angle: angle)
                
                Spacer()
                
                // Text Info - Only Rotations
                VStack(alignment: .trailing) {
                    Text("Rotations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", rotations))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .onChange(of: rotations) { _, newRotation in
                checkAutoPositioning(currentRotation: newRotation)
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
            
            // Phase-dependent UI
            if !isCalibrated {
                // SETUP/CALIBRATION PHASE
                setupPhaseView(rotations: rotations)
            } else {
                // NORMAL OPERATION PHASE
                operationPhaseView(rotations: rotations)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showDebugDialog) {
            debugView()
        }
    }
    
    // MARK: - Setup Phase View
    @ViewBuilder
    private func setupPhaseView(rotations: Double) -> some View {
        VStack(spacing: 16) {
            Text("Initial Setup & Calibration")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Use the UP/DOWN buttons to move the motor to set your Low and High positions")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
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
                
                // Directional Controls - Side by side
                HStack(spacing: 20) {
                    // UP Button
                    Text("UP")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 80, height: 80)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isButtonPressed {
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
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 80, height: 80)
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isButtonPressed {
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
            .padding(.vertical)
            
            // Calibration Buttons
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack {
                        Button("Set Low") {
                            tempLowRotation = rotations
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .frame(maxWidth: .infinity)
                        
                        if let low = tempLowRotation {
                            Text("Low: \(String(format: "%.1f", low))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack {
                        Button("Set High") {
                            tempHighRotation = rotations
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .frame(maxWidth: .infinity)
                        
                        if let high = tempHighRotation {
                            Text("High: \(String(format: "%.1f", high))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Complete Setup Button
                Button(action: completeSetup) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete Setup")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(tempLowRotation == nil || tempHighRotation == nil)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Operation Phase View
    @ViewBuilder
    private func operationPhaseView(rotations: Double) -> some View {
        VStack(spacing: 16) {
            Text("Motor Control")
                .font(.title2)
                .fontWeight(.bold)
            
            // Progress Bar showing position between Low and High
            VStack(spacing: 8) {
                Text("Position")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        
                        // Progress indicator
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(progressPercentage(current: rotations)))))
                            .cornerRadius(8)
                    }
                }
                .frame(height: 30)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("\(String(format: "%.0f%%", progressPercentage(current: rotations) * 100))")
                        .font(.caption)
                        .fontWeight(.bold)
                    Spacer()
                    Text("High")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Quick Position Controls
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: { goToPosition(lowRotation) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32))
                            Text("Go to Low")
                                .font(.headline)
                            Text("\(String(format: "%.1f", lowRotation))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(isAutoPositioning)
                    
                    Button(action: { goToPosition(highRotation) }) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                            Text("Go to High")
                                .font(.headline)
                            Text("\(String(format: "%.1f", highRotation))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(isAutoPositioning)
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
                    .padding(.vertical, 8)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // Re-calibrate Button
            Button(action: startRecalibration) {
                HStack {
                    Image(systemName: "arrow.clockwise.circle")
                    Text("Re-Calibrate")
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
    }
    
    // MARK: - Debug View
    @ViewBuilder
    private func debugView() -> some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Connection Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Status")
                            .font(.headline)
                        Text(ble.statusText)
                            .font(.body)
                            .foregroundColor(.secondary)
                        Text(ble.connected ? "✓ Connected" : "✗ Not Connected")
                            .font(.caption)
                            .foregroundColor(ble.connected ? .green : .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    
                    // Discovered Devices
                    if !ble.discoveredDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Discovered Devices")
                                .font(.headline)
                            ForEach(ble.discoveredDevices, id: \.self) { device in
                                Text(device)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    // Error Log
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Error Log")
                                .font(.headline)
                            Spacer()
                            if !ble.errorLog.isEmpty {
                                Button("Clear") {
                                    ble.errorLog.removeAll()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        if ble.errorLog.isEmpty {
                            Text("No errors")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            ForEach(ble.errorLog.reversed(), id: \.self) { error in
                                Text(error)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Debug Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showDebugDialog = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func completeSetup() {
        guard let low = tempLowRotation, let high = tempHighRotation else { return }
        
        // Save to persistent storage
        lowRotation = low
        highRotation = high
        isCalibrated = true
        
        // Clear temporary values
        tempLowRotation = nil
        tempHighRotation = nil
    }
    
    func startRecalibration() {
        isCalibrated = false
        tempLowRotation = nil
        tempHighRotation = nil
    }
    
    func progressPercentage(current: Double) -> Double {
        // Calculate position between low and high as a percentage (0.0 to 1.0)
        let range = highRotation - lowRotation
        
        if abs(range) < 0.001 {
            return 0.0
        }
        
        let progress = (current - lowRotation) / range
        return max(0.0, min(1.0, progress)) // Clamp between 0 and 1
    }
    
    func getCurrentSensorData() -> (Double, Double, Int)? {
        if !ble.lastReceived.isEmpty {
            return parseSensorData(ble.lastReceived)
        }
        return nil
    }
    
    func goToPosition(_ target: Double) {
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
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                .frame(width: 50, height: 50)
            
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .foregroundColor(.blue)
                .rotationEffect(.degrees(visualAngle))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: visualAngle)
        }
        .onAppear {
            visualAngle = angle
        }
        .onChange(of: angle) { _, newValue in
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
