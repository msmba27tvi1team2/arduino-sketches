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

// MARK: - Go to High Intent
struct GoToHighIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to High"
    static var description = IntentDescription("Moves the motor to the High calibration position for 5 seconds.")
    
    func perform() async throws -> some IntentResult {
        let isSwapped = UserDefaults.standard.bool(forKey: "isSwapped")
        // High = Up direction
        let commandString = isSwapped ? "CW" : "CCW"
        
        try await BLEManager.shared.runMotorForDuration(direction: commandString, seconds: 5.0)
        return .result()
    }
}

// MARK: - Go to Low Intent
struct GoToLowIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Low"
    static var description = IntentDescription("Moves the motor to the Low calibration position for 5 seconds.")
    
    func perform() async throws -> some IntentResult {
        let isSwapped = UserDefaults.standard.bool(forKey: "isSwapped")
        // Low = Down direction
        let commandString = isSwapped ? "CCW" : "CW"
        
        try await BLEManager.shared.runMotorForDuration(direction: commandString, seconds: 5.0)
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
            intent: GoToHighIntent(),
            phrases: [
                "Go to high using \(.applicationName)",
                "Set motor to high with \(.applicationName)",
                "Move to high position on \(.applicationName)"
            ],
            shortTitle: "Go to High",
            systemImageName: "arrow.up.circle"
        )
        
        AppShortcut(
            intent: GoToLowIntent(),
            phrases: [
                "Go to low using \(.applicationName)",
                "Set motor to low with \(.applicationName)",
                "Move to low position on \(.applicationName)"
            ],
            shortTitle: "Go to Low",
            systemImageName: "arrow.down.circle"
        )
    }
}
