import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()

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
                         Text("\(rotations)")
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
            
            Spacer()
            
            // Motor Controls
            // Motor Controls
            HStack(spacing: 60) {
                // CW Button (Hold to repeat)
                Text("CW")
                    .font(.title2.bold())
                    .frame(width: 80, height: 80)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                ble.startRepeatingCommand("CW")
                            }
                            .onEnded { _ in
                                ble.stopRepeatingCommand()
                            }
                    )
                
                // CCW Button (Hold to repeat)
                Text("CCW")
                    .font(.title2.bold())
                    .frame(width: 80, height: 80)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 4)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                ble.startRepeatingCommand("CCW")
                            }
                            .onEnded { _ in
                                ble.stopRepeatingCommand()
                            }
                    )
            }
            .padding(.bottom, 40)
            
            Spacer()
        }
        .padding()
    }
    func parseSensorData(_ data: String) -> (Double, Int, Int) {
        // Format e.g. "A:123.4 R:5 T:16000"
        let components = data.components(separatedBy: " ")
        var angle = 0.0
        var rotations = 0
        var ticks = 0
        
        for comp in components {
            if comp.starts(with: "A:") {
                let val = comp.dropFirst(2)
                angle = Double(val) ?? 0.0
            } else if comp.starts(with: "R:") {
                let val = comp.dropFirst(2)
                rotations = Int(val) ?? 0
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
