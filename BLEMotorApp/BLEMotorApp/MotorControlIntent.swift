import AppIntents
import Foundation

// MARK: - General Move Intent
struct MoveMotorIntent: AppIntent {
    static var title: LocalizedStringResource = "Move Motor"
    static var description = IntentDescription("Moves the motor in a specific direction for a set time.")

    @Parameter(title: "Direction")
    var direction: MotorDirection
    
    @Parameter(title: "Duration (seconds)", default: 1.0)
    var duration: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Move motor \(\.$direction) for \(\.$duration) seconds")
    }

    func perform() async throws -> some IntentResult {
        let isSwapped = UserDefaults.standard.bool(forKey: "isSwapped")
        let commandString = resolveCommand(direction: direction, isSwapped: isSwapped)
        try await BLEManager.shared.runMotorForDuration(direction: commandString, seconds: duration)
        return .result()
    }
}

// MARK: - Open Intent (Uses Default Duration)
struct OpenMotorIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Motor"
    static var description = IntentDescription("Opens the motor (Up direction) using the default duration.")
    
    func perform() async throws -> some IntentResult {
        let isSwapped = UserDefaults.standard.bool(forKey: "isSwapped")
        // Open = Up
        let commandString = isSwapped ? "CW" : "CCW"
        
        let duration = UserDefaults.standard.double(forKey: "defaultDuration")
        // Handle case where default might be 0 if not set, though AppStorage usually handles valid defaults in app context.
        // In Extension context, simple defaults might return 0 if never set. Key matches ContentView.
        let finalDuration = duration > 0 ? duration : 5.0
        
        try await BLEManager.shared.runMotorForDuration(direction: commandString, seconds: finalDuration)
        return .result()
    }
}

// MARK: - Close Intent (Uses Default Duration)
struct CloseMotorIntent: AppIntent {
    static var title: LocalizedStringResource = "Close Motor"
    static var description = IntentDescription("Closes the motor (Down direction) using the default duration.")
    
    func perform() async throws -> some IntentResult {
        let isSwapped = UserDefaults.standard.bool(forKey: "isSwapped")
        // Close = Down
        let commandString = isSwapped ? "CCW" : "CW"
        
        let duration = UserDefaults.standard.double(forKey: "defaultDuration")
        let finalDuration = duration > 0 ? duration : 5.0
        
        try await BLEManager.shared.runMotorForDuration(direction: commandString, seconds: finalDuration)
        return .result()
    }
}

// MARK: - Helpers & Types
func resolveCommand(direction: MotorDirection, isSwapped: Bool) -> String {
    switch direction {
    case .up:
        return isSwapped ? "CW" : "CCW"
    case .down:
        return isSwapped ? "CCW" : "CW"
    }
}

enum MotorDirection: String, AppEnum {
    case up
    case down
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Direction"
    
    static var caseDisplayRepresentations: [MotorDirection : DisplayRepresentation] = [
        .up: DisplayRepresentation(title: "Up", subtitle: "High/Open"),
        .down: DisplayRepresentation(title: "Down", subtitle: "Low/Close")
    ]
}

struct MotorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MoveMotorIntent(),
            phrases: [
                "Set motor \(\.$direction) using \(.applicationName)",
                "Move motor \(\.$direction) with \(.applicationName)",
                "Run motor \(\.$direction) on \(.applicationName)"
            ],
            shortTitle: "Move Motor",
            systemImageName: "arrow.up.and.down.circle"
        )
        
        AppShortcut(
            intent: OpenMotorIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open motor using \(.applicationName)",
                "Open blinds with \(.applicationName)"
            ],
            shortTitle: "Open Motor",
            systemImageName: "arrow.up.circle"
        )
        
        AppShortcut(
            intent: CloseMotorIntent(),
            phrases: [
                "Close \(.applicationName)",
                "Close motor using \(.applicationName)",
                "Close blinds with \(.applicationName)"
            ],
            shortTitle: "Close Motor",
            systemImageName: "arrow.down.circle"
        )
    }
}
