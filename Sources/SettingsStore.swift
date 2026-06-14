import Foundation

enum SettingsKey {
    static let prefix = "dev.astry.sidekick."

    static let baseURL = prefix + "baseURL"
    static let modelName = prefix + "modelName"
    static let interfaceLanguage = prefix + "interfaceLanguage"
    static let outputLanguage = prefix + "outputLanguage"
    static let apiFormat = prefix + "apiFormat"
    static let analysisMode = prefix + "analysisMode"
    static let captureScope = prefix + "captureScope"
    static let feedbackMode = prefix + "feedbackMode"
    static let feedbackDeliveryMode = prefix + "feedbackDeliveryMode"
    static let agentMode = prefix + "agentMode"
    static let toneMode = prefix + "toneMode"
    static let companionStyle = prefix + "companionStyle"
    static let monitoringIntervalSeconds = prefix + "monitoringIntervalSeconds"
    static let monitoringHeartbeatCycles = prefix + "monitoringHeartbeatCycles"
    static let monitoringResumeDelaySeconds = prefix + "monitoringResumeDelaySeconds"
    static let overlayOpacity = prefix + "overlayOpacity"
    static let includeLatestCaptureInChat = prefix + "includeLatestCaptureInChat"

    static let monitoringPrompt = prefix + "monitoringPrompt"
    static let chatPrompt = prefix + "chatPrompt"
    static let classificationPrompt = prefix + "classificationPrompt"
    static let welcomePrompt = prefix + "welcomePrompt"
    static let neutralTonePrompt = prefix + "neutralTonePrompt"
    static let casualTonePrompt = prefix + "casualTonePrompt"
    static let quietCompanionPrompt = prefix + "quietCompanionPrompt"
    static let chattyCompanionPrompt = prefix + "chattyCompanionPrompt"
    static let funFactCompanionPrompt = prefix + "funFactCompanionPrompt"
}

extension UserDefaults {
    func enumValue<T: RawRepresentable>(forKey key: String) -> T? where T.RawValue == String {
        guard let rawValue = string(forKey: key) else { return nil }
        return T(rawValue: rawValue)
    }

    func doubleValue(forKey key: String) -> Double? {
        object(forKey: key) == nil ? nil : double(forKey: key)
    }

    func boolValue(forKey key: String) -> Bool? {
        object(forKey: key) == nil ? nil : bool(forKey: key)
    }
}
