import SwiftUI

struct ContentView: View {
    @StateObject private var ble = BLEManager()
    @State private var speed: Double = 255.0

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(ble.statusText)
                    .padding(.bottom, 4)
                if !ble.discoveredDevices.isEmpty {
                    Text("Devices seen during scan:")
                        .font(.headline)
                    ForEach(ble.discoveredDevices, id: \.self) { device in
                        Text(device)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            HStack {
                Button("Scan & Connect") {
                    ble.startScan()
                }
                .disabled(ble.connected)
                Button("Disconnect") {
                    ble.disconnect()
                }.disabled(!ble.connected)
            }
            HStack {
                Button(action: { ble.sendCommand("CW") }) {
                    Text("CW")
                        .frame(minWidth: 60)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Button(action: { ble.sendCommand("STOP") }) {
                    Text("STOP")
                        .frame(minWidth: 60)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Button(action: { ble.sendCommand("CCW") }) {
                    Text("CCW")
                        .frame(minWidth: 60)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            VStack {
                Text("Speed: \(Int(speed))")
                Slider(value: $speed, in: 0...255, step: 1) {
                    Text("Speed")
                } minimumValueLabel: { Text("0") } maximumValueLabel: { Text("255") }
                Button("Set Speed") {
                    let s = Int(speed)
                    ble.sendCommand("S:\(s)")
                }.padding(.top, 8)
            }.padding()
            VStack(alignment: .leading) {
                Text("Last message from Feather:")
                Text(ble.lastReceived)
                    .font(.body)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }.padding()
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
