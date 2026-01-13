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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
