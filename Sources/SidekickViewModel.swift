import AppKit
import Combine
import CoreGraphics
import Foundation

@MainActor
final class SidekickViewModel: ObservableObject {
    enum InterfaceLanguage: String, CaseIterable, Identifiable {
        case system
        case japanese
        case english

        var id: String { rawValue }
    }

    enum OutputLanguage: String, CaseIterable, Identifiable {
        case system
        case japanese
        case english

        var id: String { rawValue }
    }

    enum CaptureScope: String, CaseIterable, Identifiable {
        case frontmostWindow
        case mainDisplay

        var id: String { rawValue }

        var label: String {
            switch self {
            case .frontmostWindow:
                return "前面ウィンドウ"
            case .mainDisplay:
                return "ディスプレイ全体"
            }
        }
    }

    enum APIFormat: String, CaseIterable, Identifiable {
        case chatCompletions
        case responses

        var id: String { rawValue }

        var label: String {
            switch self {
            case .chatCompletions:
                return "Chat"
            case .responses:
                return "Responses"
            }
        }
    }

    enum AnalysisMode: String, CaseIterable, Identifiable {
        case ocrOnly
        case imageOnly
        case hybrid

        var id: String { rawValue }

        var label: String {
            switch self {
            case .ocrOnly:
                return "OCRのみ"
            case .imageOnly:
                return "画像のみ"
            case .hybrid:
                return "OCR+画像"
            }
        }

        var requiresOCR: Bool {
            switch self {
            case .ocrOnly, .hybrid:
                return true
            case .imageOnly:
                return false
            }
        }

        var requiresImage: Bool {
            switch self {
            case .ocrOnly:
                return false
            case .imageOnly, .hybrid:
                return true
            }
        }

        var promptDescription: String {
            switch self {
            case .ocrOnly:
                return "ocr_only"
            case .imageOnly:
                return "image_only"
            case .hybrid:
                return "hybrid"
            }
        }
    }

    enum FeedbackMode: String, CaseIterable, Identifiable {
        case support
        case companion

        var id: String { rawValue }

        var label: String {
            switch self {
            case .support:
                return "支援重視"
            case .companion:
                return "伴走重視"
            }
        }
    }

    enum AgentMode: String, CaseIterable, Identifiable {
        case auto
        case assist
        case companion
        case silent

        var id: String { rawValue }

        var label: String {
            switch self {
            case .auto:
                return "Auto"
            case .assist:
                return "Assist"
            case .companion:
                return "Companion"
            case .silent:
                return "Silent"
            }
        }
    }

    enum ToneMode: String, CaseIterable, Identifiable {
        case neutral
        case casual

        var id: String { rawValue }

        var label: String {
            switch self {
            case .neutral:
                return "落ち着き"
            case .casual:
                return "砕けた感じ"
            }
        }
    }

    enum CompanionStyle: String, CaseIterable, Identifiable {
        case quiet
        case chatty
        case funFact

        var id: String { rawValue }

        var label: String {
            switch self {
            case .quiet:
                return "静かめ"
            case .chatty:
                return "おしゃべり"
            case .funFact:
                return "小ネタあり"
            }
        }
    }

    enum FeedbackDeliveryMode: String, CaseIterable, Identifiable {
        case notification
        case overlay

        var id: String { rawValue }

        var label: String {
            switch self {
            case .notification:
                return "通知"
            case .overlay:
                return "オーバーレイ"
            }
        }
    }

    enum OverlayStatusLevel {
        case idle
        case working
        case warning

        var symbolName: String {
            switch self {
            case .idle:
                return "checkmark.circle.fill"
            case .working:
                return "arrow.triangle.2.circlepath.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    @Published var baseURL = "http://127.0.0.1:1234/v1/chat/completions"
    @Published var modelName = "local-model"
    @Published var interfaceLanguage: InterfaceLanguage = .system
    @Published var outputLanguage: OutputLanguage = .system
    @Published var monitoringPrompt = """
    あなたは macOS 上で動くデスクトップ支援アシスタントです。
    画面の文脈、変化、ユーザーの作業状況を見ながらフィードバックしてください。
    回答は簡潔にし、観測できる事実とそこから自然に言える支援だけを述べてください。
    画面上のエラーや問題が見える場合は、それを明示してください。
    OCR や画像が不完全な場合は、不確かな点も明記してください。
    """
    @Published var chatPrompt = """
    あなたは今このユーザーと同じ画面を見ながら会話している相手です。
    直前の文脈を踏まえて、自然に返してください。
    長すぎず、会話として自然な密度で答えてください。
    """
    @Published var classificationPrompt = """
    You are a situation-classification layer for a desktop companion agent.
    Infer what the user is likely doing and what kind of response is appropriate from the screen context and recent changes.
    Return JSON only. Do not include markdown fences. Do not include any text before or after the JSON.

    Required JSON schema:
    {
      "user_state": "work|trouble|focus|enjoy|idle|uncertain",
      "user_intent": "short_snake_case_label",
      "response_mode": "assist|empathize|companion|celebrate|commentary|fun_fact|silent",
      "should_interrupt": true,
      "confidence": "low|medium|high",
      "reason": "short sentence grounded in observable context"
    }

    Rules:
    - If the user appears concentrated and there is no clear need to speak, set "response_mode" to "silent" and "should_interrupt" to false.
    - If errors, repeated struggle, or blocked progress are visible, prefer "assist" or "empathize".
    - If the user seems to be enjoying entertainment content, "companion", "celebrate", "commentary", or "fun_fact" is acceptable.
    - Use "fun_fact" when a short relevant observation, framing, or small insight would make the moment more enjoyable or useful. It does not need to be trivia.
    - Be conservative. If uncertain, do not interrupt unless the user explicitly asked.
    - If companion_style is "fun_fact", bias slightly toward "fun_fact" or "commentary" for entertainment, videos, games, streams, or cultural content.
    - If the estimated continuous session is long, occasional gentle break suggestions are acceptable.
    """
    @Published var welcomePrompt = """
    やあ、Sidekickです。
    ここには今見てる画面に合わせたひとことが流れていくよ。気になるのがあったら「チャットする」からそのまま話しかけて。
    """
    @Published var neutralTonePrompt = "丁寧すぎず落ち着いた日本語で、短く自然に話してください。"
    @Published var casualTonePrompt = "友達が隣で一緒に画面を見ているような、少し砕けた自然な日本語で話してください。敬語に寄りすぎず、1〜2文を基本にしてください。"
    @Published var quietCompanionPrompt = "同じ画面を一緒に見ている相手として、短い相づちや軽い共感を中心に返してください。邪魔になりそうなら黙ってください。"
    @Published var chattyCompanionPrompt = "同じ画面を一緒に見ている相手として、軽い共感や反応を交えつつ、短く自然にコメントしてください。盛り上がる場面では少しテンションを上げても構いません。"
    @Published var funFactCompanionPrompt = "同じ画面を一緒に見ている相手として、軽い共感や反応を交えつつ、関連する背景知識や小ネタ、ちょっとした気づきを短く添えてください。確信が低いことは断定せず『かも』で留めてください。無理に毎回知識をひねり出す必要はありませんが、言えそうな小ネタや背景がある場面では積極的に出して構いません。長時間同じ作業が続いていそうなら、さりげない休憩のひとことを入れても構いません。"
    @Published var apiFormat: APIFormat = .chatCompletions
    @Published var analysisMode: AnalysisMode = .imageOnly
    @Published var captureScope: CaptureScope = .mainDisplay
    @Published var feedbackMode: FeedbackMode = .companion
    @Published var feedbackDeliveryMode: FeedbackDeliveryMode = .notification
    @Published var agentMode: AgentMode = .auto
    @Published var toneMode: ToneMode = .casual
    @Published var companionStyle: CompanionStyle = .funFact
    @Published var monitoringIntervalSeconds = 60.0
    @Published var monitoringHeartbeatCycles = 4.0
    @Published var monitoringResumeDelaySeconds = 10.0
    @Published var overlayOpacity = 1.0
    @Published var overlayMessageHeight = 230.0
    @Published var isMonitoring = false
    @Published var monitoringStatus = "停止中"
    @Published var notificationStatus = "未設定"
    @Published var notificationsEnabled = false
    @Published var frontmostAppName = "-"
    @Published var windowTitle = "-"
    @Published var captureStatus = "Idle"
    @Published var lastCaptureLabel = "Never"
    @Published var lastFeedbackLabel = "Never"
    @Published var ocrText = ""
    @Published var assistantResponse = ""
    @Published var changeSummary = "まだ比較対象がありません。"
    @Published var detectedState = "-"
    @Published var detectedIntent = "-"
    @Published var detectedResponseMode = "-"
    @Published var detectedConfidence = "-"
    @Published var detectedReason = "-"
    @Published var chatDraft = ""
    @Published var chatMessages: [ChatEntry] = []
    @Published var isChatBusy = false
    @Published var includeLatestCaptureInChat = true
    @Published var chatStatus = "待機中"
    @Published var isOverlayChatExpanded = false
    @Published var appLog = "ログはまだありません。"
    @Published var previewImage: NSImage?
    @Published var errorMessage: String?
    @Published var overlayStatusLevel: OverlayStatusLevel = .idle
    @Published var overlayStatusSummary = "待機中"
    @Published var overlayStatusDetail = ""
    @Published var isBusy = false
    @Published private(set) var recentConversations: [ConversationSnapshot] = []
    @Published var selectedConversationIndex = 0

    private let defaultMonitoringPromptJA = """
    あなたは macOS 上で動くデスクトップ支援アシスタントです。
    画面の文脈、変化、ユーザーの作業状況を見ながらフィードバックしてください。
    回答は簡潔にし、観測できる事実とそこから自然に言える支援だけを述べてください。
    画面上のエラーや問題が見える場合は、それを明示してください。
    OCR や画像が不完全な場合は、不確かな点も明記してください。
    """

    private let defaultMonitoringPromptEN = """
    You are a desktop companion assistant running on macOS.
    Watch the screen context, changes, and the user's working situation, then provide feedback.
    Keep responses concise and grounded in observable facts and natural next-step support.
    If visible errors or problems appear on screen, point them out clearly.
    If OCR or image understanding is incomplete, mention uncertainty instead of guessing.
    """

    private let defaultChatPromptJA = """
    あなたは今このユーザーと同じ画面を見ながら会話している相手です。
    直前の文脈を踏まえて、自然に返してください。
    長すぎず、会話として自然な密度で答えてください。
    """

    private let defaultChatPromptEN = """
    You are someone chatting with the user while looking at the same screen.
    Respond naturally based on the immediate context.
    Keep replies conversational and not overly long.
    """

    private let defaultClassificationPrompt = """
    You are a situation-classification layer for a desktop companion agent.
    Infer what the user is likely doing and what kind of response is appropriate from the screen context and recent changes.
    Return JSON only. Do not include markdown fences. Do not include any text before or after the JSON.

    Required JSON schema:
    {
      "user_state": "work|trouble|focus|enjoy|idle|uncertain",
      "user_intent": "short_snake_case_label",
      "response_mode": "assist|empathize|companion|celebrate|commentary|fun_fact|silent",
      "should_interrupt": true,
      "confidence": "low|medium|high",
      "reason": "short sentence grounded in observable context"
    }

    Rules:
    - If the user appears concentrated and there is no clear need to speak, set "response_mode" to "silent" and "should_interrupt" to false.
    - If errors, repeated struggle, or blocked progress are visible, prefer "assist" or "empathize".
    - If the user seems to be enjoying entertainment content, "companion", "celebrate", "commentary", or "fun_fact" is acceptable.
    - Use "fun_fact" when a short relevant observation, framing, or small insight would make the moment more enjoyable or useful. It does not need to be trivia.
    - Be conservative. If uncertain, do not interrupt unless the user explicitly asked.
    - If companion_style is "fun_fact", bias slightly toward "fun_fact" or "commentary" for entertainment, videos, games, streams, or cultural content.
    - If the estimated continuous session is long, occasional gentle break suggestions are acceptable.
    """

    private let defaultWelcomePromptJA = """
    やあ、Sidekickです。
    ここには今見てる画面に合わせたひとことが流れていくよ。気になるのがあったら「チャットする」からそのまま話しかけて。
    """

    private let defaultWelcomePromptEN = """
    Hey, this is Sidekick.
    You'll see little reactions here based on what's on your screen. If something catches your attention, just hit "Chat" and keep going from there.
    """

    private let defaultNeutralTonePromptJA = "丁寧すぎず落ち着いた日本語で、短く自然に話してください。"
    private let defaultNeutralTonePromptEN = "Use calm, natural English. Keep it short and avoid sounding overly formal."
    private let defaultCasualTonePromptJA = "友達が隣で一緒に画面を見ているような、少し砕けた自然な日本語で話してください。敬語に寄りすぎず、1〜2文を基本にしてください。"
    private let defaultCasualTonePromptEN = "Speak in natural, slightly casual English, like a friend reacting beside the user. Default to one or two sentences."
    private let defaultQuietCompanionPromptJA = "同じ画面を一緒に見ている相手として、短い相づちや軽い共感を中心に返してください。邪魔になりそうなら黙ってください。"
    private let defaultQuietCompanionPromptEN = "Act like someone quietly watching the same screen. Favor short acknowledgements and light empathy, and stay silent if speaking would be distracting."
    private let defaultChattyCompanionPromptJA = "同じ画面を一緒に見ている相手として、軽い共感や反応を交えつつ、短く自然にコメントしてください。盛り上がる場面では少しテンションを上げても構いません。"
    private let defaultChattyCompanionPromptEN = "Act like someone watching the same screen with the user. Add light reactions and empathy, and keep comments short and natural. It's fine to get a bit more upbeat when the moment calls for it."
    private let defaultFunFactCompanionPromptJA = "同じ画面を一緒に見ている相手として、軽い共感や反応を交えつつ、関連する背景知識や小ネタ、ちょっとした気づきを短く添えてください。確信が低いことは断定せず『かも』で留めてください。無理に毎回知識をひねり出す必要はありませんが、言えそうな小ネタや背景がある場面では積極的に出して構いません。長時間同じ作業が続いていそうなら、さりげない休憩のひとことを入れても構いません。"
    private let defaultFunFactCompanionPromptEN = "Act like someone watching the same screen with the user. Mix in light reactions with short bits of background knowledge, small observations, or little tidbits when they fit. If confidence is low, avoid stating things as certain. You do not need to force trivia every time, but if a useful tidbit or bit of context fits, feel free to add it. If the user seems to have been working for a long stretch, a gentle break suggestion is fine."

    var usesEnglishUI: Bool {
        switch interfaceLanguage {
        case .english:
            return true
        case .japanese:
            return false
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("en") == true
        }
    }

    var usesEnglishOutput: Bool {
        switch outputLanguage {
        case .english:
            return true
        case .japanese:
            return false
        case .system:
            return Locale.preferredLanguages.first?.hasPrefix("en") == true
        }
    }

    private var lastCapturePNGData: Data?
    private var monitoringTask: Task<Void, Never>?
    private var previousObservation: ScreenObservation?
    private var lastFeedbackDate: Date?
    private var monitoringCycleIndex = 0
    private var latestTopicContext = ""
    private var currentSessionStartedAt: Date?
    private var shouldResumeMonitoringAfterChat = false
    private var resumeMonitoringTask: Task<Void, Never>?
    private var isOverlayConversationPinned = false
    private var activeConversationID: UUID?
    var shouldDelayMonitoringResumeHandler: (() -> Bool)?
    var feedbackNotificationHandler: ((FeedbackNotificationPayload) -> Void)?
    var feedbackOverlayHandler: ((FeedbackNotificationPayload) -> Void)?
    var inspectNotificationsHandler: (() -> Void)?
    private let logStore = LogStore()
    private var settingsCancellables: Set<AnyCancellable> = []

    init() {
        loadPersistedSettings()
        observeSettingsForPersistence()
    }

    deinit {
        monitoringTask?.cancel()
        resumeMonitoringTask?.cancel()
    }

    private func loadPersistedSettings() {
        let defaults = UserDefaults.standard

        baseURL = defaults.string(forKey: SettingsKey.baseURL) ?? baseURL
        modelName = defaults.string(forKey: SettingsKey.modelName) ?? modelName
        interfaceLanguage = defaults.enumValue(forKey: SettingsKey.interfaceLanguage) ?? interfaceLanguage
        outputLanguage = defaults.enumValue(forKey: SettingsKey.outputLanguage) ?? outputLanguage
        apiFormat = defaults.enumValue(forKey: SettingsKey.apiFormat) ?? apiFormat
        analysisMode = defaults.enumValue(forKey: SettingsKey.analysisMode) ?? analysisMode
        captureScope = defaults.enumValue(forKey: SettingsKey.captureScope) ?? captureScope
        feedbackMode = defaults.enumValue(forKey: SettingsKey.feedbackMode) ?? feedbackMode
        feedbackDeliveryMode = defaults.enumValue(forKey: SettingsKey.feedbackDeliveryMode) ?? feedbackDeliveryMode
        agentMode = defaults.enumValue(forKey: SettingsKey.agentMode) ?? agentMode
        toneMode = defaults.enumValue(forKey: SettingsKey.toneMode) ?? toneMode
        companionStyle = defaults.enumValue(forKey: SettingsKey.companionStyle) ?? companionStyle
        monitoringIntervalSeconds = defaults.doubleValue(forKey: SettingsKey.monitoringIntervalSeconds) ?? monitoringIntervalSeconds
        monitoringHeartbeatCycles = defaults.doubleValue(forKey: SettingsKey.monitoringHeartbeatCycles) ?? monitoringHeartbeatCycles
        monitoringResumeDelaySeconds = defaults.doubleValue(forKey: SettingsKey.monitoringResumeDelaySeconds) ?? monitoringResumeDelaySeconds
        overlayOpacity = defaults.doubleValue(forKey: SettingsKey.overlayOpacity) ?? overlayOpacity
        includeLatestCaptureInChat = defaults.boolValue(forKey: SettingsKey.includeLatestCaptureInChat) ?? includeLatestCaptureInChat

        monitoringPrompt = defaults.string(forKey: SettingsKey.monitoringPrompt) ?? monitoringPrompt
        chatPrompt = defaults.string(forKey: SettingsKey.chatPrompt) ?? chatPrompt
        classificationPrompt = defaults.string(forKey: SettingsKey.classificationPrompt) ?? classificationPrompt
        welcomePrompt = defaults.string(forKey: SettingsKey.welcomePrompt) ?? welcomePrompt
        neutralTonePrompt = defaults.string(forKey: SettingsKey.neutralTonePrompt) ?? neutralTonePrompt
        casualTonePrompt = defaults.string(forKey: SettingsKey.casualTonePrompt) ?? casualTonePrompt
        quietCompanionPrompt = defaults.string(forKey: SettingsKey.quietCompanionPrompt) ?? quietCompanionPrompt
        chattyCompanionPrompt = defaults.string(forKey: SettingsKey.chattyCompanionPrompt) ?? chattyCompanionPrompt
        funFactCompanionPrompt = defaults.string(forKey: SettingsKey.funFactCompanionPrompt) ?? funFactCompanionPrompt
    }

    private func observeSettingsForPersistence() {
        let defaults = UserDefaults.standard

        $baseURL.dropFirst().sink { defaults.set($0, forKey: SettingsKey.baseURL) }.store(in: &settingsCancellables)
        $modelName.dropFirst().sink { defaults.set($0, forKey: SettingsKey.modelName) }.store(in: &settingsCancellables)
        $interfaceLanguage.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.interfaceLanguage) }.store(in: &settingsCancellables)
        $outputLanguage.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.outputLanguage) }.store(in: &settingsCancellables)
        $apiFormat.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.apiFormat) }.store(in: &settingsCancellables)
        $analysisMode.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.analysisMode) }.store(in: &settingsCancellables)
        $captureScope.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.captureScope) }.store(in: &settingsCancellables)
        $feedbackMode.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.feedbackMode) }.store(in: &settingsCancellables)
        $feedbackDeliveryMode.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.feedbackDeliveryMode) }.store(in: &settingsCancellables)
        $agentMode.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.agentMode) }.store(in: &settingsCancellables)
        $toneMode.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.toneMode) }.store(in: &settingsCancellables)
        $companionStyle.dropFirst().sink { defaults.set($0.rawValue, forKey: SettingsKey.companionStyle) }.store(in: &settingsCancellables)
        $monitoringIntervalSeconds.dropFirst().sink { defaults.set($0, forKey: SettingsKey.monitoringIntervalSeconds) }.store(in: &settingsCancellables)
        $monitoringHeartbeatCycles.dropFirst().sink { defaults.set($0, forKey: SettingsKey.monitoringHeartbeatCycles) }.store(in: &settingsCancellables)
        $monitoringResumeDelaySeconds.dropFirst().sink { defaults.set($0, forKey: SettingsKey.monitoringResumeDelaySeconds) }.store(in: &settingsCancellables)
        $overlayOpacity.dropFirst().sink { defaults.set($0, forKey: SettingsKey.overlayOpacity) }.store(in: &settingsCancellables)
        $includeLatestCaptureInChat.dropFirst().sink { defaults.set($0, forKey: SettingsKey.includeLatestCaptureInChat) }.store(in: &settingsCancellables)

        $monitoringPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.monitoringPrompt) }.store(in: &settingsCancellables)
        $chatPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.chatPrompt) }.store(in: &settingsCancellables)
        $classificationPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.classificationPrompt) }.store(in: &settingsCancellables)
        $welcomePrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.welcomePrompt) }.store(in: &settingsCancellables)
        $neutralTonePrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.neutralTonePrompt) }.store(in: &settingsCancellables)
        $casualTonePrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.casualTonePrompt) }.store(in: &settingsCancellables)
        $quietCompanionPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.quietCompanionPrompt) }.store(in: &settingsCancellables)
        $chattyCompanionPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.chattyCompanionPrompt) }.store(in: &settingsCancellables)
        $funFactCompanionPrompt.dropFirst().sink { defaults.set($0, forKey: SettingsKey.funFactCompanionPrompt) }.store(in: &settingsCancellables)
    }

    func log(_ message: String) {
        let line = "[\(Self.timestampFormatter.string(from: .now))] \(message)"
        debugLog(line)
        if appLog == "ログはまだありません。" {
            appLog = line
        } else {
            appLog += "\n" + line
        }

        let lines = appLog.split(separator: "\n")
        if lines.count > 120 {
            appLog = lines.suffix(120).joined(separator: "\n")
        }

        logStore.append(line: line)
    }

    func uiText(_ japanese: String, _ english: String) -> String {
        usesEnglishUI ? english : japanese
    }

    func label(for language: InterfaceLanguage) -> String {
        switch language {
        case .system:
            return uiText("システム", "System")
        case .japanese:
            return uiText("日本語", "Japanese")
        case .english:
            return uiText("英語", "English")
        }
    }

    func label(for language: OutputLanguage) -> String {
        switch language {
        case .system:
            return uiText("システム追従", "Follow System")
        case .japanese:
            return uiText("日本語", "Japanese")
        case .english:
            return uiText("英語", "English")
        }
    }

    func label(for value: CaptureScope) -> String {
        switch value {
        case .frontmostWindow:
            return uiText("前面ウィンドウ", "Frontmost Window")
        case .mainDisplay:
            return uiText("ディスプレイ全体", "Entire Display")
        }
    }

    func label(for value: APIFormat) -> String {
        switch value {
        case .chatCompletions:
            return "Chat"
        case .responses:
            return "Responses"
        }
    }

    func label(for value: AnalysisMode) -> String {
        switch value {
        case .ocrOnly:
            return uiText("OCRのみ", "OCR Only")
        case .imageOnly:
            return uiText("画像のみ", "Image Only")
        case .hybrid:
            return uiText("OCR+画像", "OCR + Image")
        }
    }

    func label(for value: FeedbackMode) -> String {
        switch value {
        case .support:
            return uiText("支援重視", "Support")
        case .companion:
            return uiText("伴走重視", "Companion")
        }
    }

    func label(for value: AgentMode) -> String {
        switch value {
        case .auto:
            return "Auto"
        case .assist:
            return "Assist"
        case .companion:
            return "Companion"
        case .silent:
            return "Silent"
        }
    }

    func label(for value: ToneMode) -> String {
        switch value {
        case .neutral:
            return uiText("落ち着き", "Calm")
        case .casual:
            return uiText("砕けた感じ", "Casual")
        }
    }

    func label(for value: CompanionStyle) -> String {
        switch value {
        case .quiet:
            return uiText("静かめ", "Quiet")
        case .chatty:
            return uiText("おしゃべり", "Chatty")
        case .funFact:
            return uiText("小ネタあり", "Tidbits")
        }
    }

    func label(for value: FeedbackDeliveryMode) -> String {
        switch value {
        case .notification:
            return uiText("通知", "Notification")
        case .overlay:
            return uiText("オーバーレイ", "Overlay")
        }
    }

    var selectedConversation: ConversationSnapshot? {
        guard recentConversations.indices.contains(selectedConversationIndex) else { return nil }
        return recentConversations[selectedConversationIndex]
    }

    var displayedOverlayMessage: String {
        selectedConversation?.feedbackText ?? assistantResponse
    }

    var canBrowseOlderConversations: Bool {
        selectedConversationIndex < recentConversations.count - 1
    }

    var canBrowseNewerConversations: Bool {
        selectedConversationIndex > 0
    }

    var conversationHistoryIndicator: String {
        guard !recentConversations.isEmpty else { return "0 / 0" }
        return "\(selectedConversationIndex + 1) / \(recentConversations.count)"
    }

    func localizedStatus(_ text: String) -> String {
        guard usesEnglishUI else { return text }

        if text.hasPrefix("通知エラー: ") {
            let detail = String(text.dropFirst("通知エラー: ".count))
            return "Notification Error: \(detail)"
        }

        switch text {
        case "Idle", "Ready", "Captured", "Failed", "Unknown":
            return text
        case "Screen Recording permission required":
            return "Screen Recording permission required"
        case "停止中":
            return "Stopped"
        case "起動中":
            return "Starting"
        case "監視中":
            return "Monitoring"
        case "変化を検出":
            return "Change Detected"
        case "変化待ち":
            return "Waiting for Change"
        case "監視エラー":
            return "Monitoring Error"
        case "チャット中に一時停止":
            return "Paused for Chat"
        case "チャット終了待ち":
            return "Waiting After Chat"
        case "オーバーレイ操作中のため再開待ち":
            return "Waiting While Overlay Is Active"
        case "Sidekickが前面のため再開待ち":
            return "Waiting Because Sidekick Is Frontmost"
        case "Sidekickが前面のためスキップ":
            return "Skipped Because Sidekick Is Frontmost"
        case "未設定":
            return "Not Set"
        case "未許可":
            return "Not Allowed"
        case "許可済み":
            return "Allowed"
        case "拒否済み":
            return "Denied"
        case "未決定":
            return "Not Determined"
        case "不明":
            return "Unknown"
        case "swift run では通知不可":
            return "Notifications unavailable via swift run"
        case "通知未許可":
            return "Notifications not allowed"
        case "待機中":
            return "Idle"
        case "送信中":
            return "Sending"
        case "最新キャプチャ込みで返信":
            return "Replied with Latest Capture"
        case "返信しました":
            return "Replied"
        case "チャット送信エラー":
            return "Chat Error"
        case "画面を確認中":
            return "Checking Screen"
        case "Sidekick前面のため待機":
            return "Waiting Because Sidekick Is Frontmost"
        case "チャット中":
            return "In Chat"
        case "応答を待っています":
            return "Waiting for Response"
        case "更新しました":
            return "Updated"
        case "返信中":
            return "Replying"
        case "応答に失敗しました":
            return "Response Failed"
        case "処理に失敗しました":
            return "Processing Failed"
        case "返信に失敗しました":
            return "Reply Failed"
        default:
            return text
        }
    }

    func applyJapanesePromptDefaults() {
        monitoringPrompt = defaultMonitoringPromptJA
        chatPrompt = defaultChatPromptJA
        classificationPrompt = defaultClassificationPrompt
        welcomePrompt = defaultWelcomePromptJA
        neutralTonePrompt = defaultNeutralTonePromptJA
        casualTonePrompt = defaultCasualTonePromptJA
        quietCompanionPrompt = defaultQuietCompanionPromptJA
        chattyCompanionPrompt = defaultChattyCompanionPromptJA
        funFactCompanionPrompt = defaultFunFactCompanionPromptJA
    }

    func applyEnglishPromptDefaults() {
        monitoringPrompt = defaultMonitoringPromptEN
        chatPrompt = defaultChatPromptEN
        classificationPrompt = defaultClassificationPrompt
        welcomePrompt = defaultWelcomePromptEN
        neutralTonePrompt = defaultNeutralTonePromptEN
        casualTonePrompt = defaultCasualTonePromptEN
        quietCompanionPrompt = defaultQuietCompanionPromptEN
        chattyCompanionPrompt = defaultChattyCompanionPromptEN
        funFactCompanionPrompt = defaultFunFactCompanionPromptEN
    }

    func sendTestFeedback() {
        let payload = FeedbackNotificationPayload(
            title: feedbackDeliveryMode == .notification ? uiText("Sidekick テスト通知", "Sidekick Test Notification") : uiText("Sidekick テスト表示", "Sidekick Test Overlay"),
            body: uiText("現在の表示モードは「\(label(for: feedbackDeliveryMode))」です。ここから監視フィードバックを流せます。", "Current delivery mode is \"\(label(for: feedbackDeliveryMode))\". Monitoring feedback will appear here.")
        )

        switch feedbackDeliveryMode {
        case .notification:
            guard notificationsEnabled else {
                notificationStatus = "通知未許可"
                return
            }
            feedbackNotificationHandler?(payload)
        case .overlay:
            feedbackOverlayHandler?(payload)
        }
    }

    func setOverlayStatus(level: OverlayStatusLevel, summary: String, detail: String = "") {
        overlayStatusLevel = level
        overlayStatusSummary = summary
        overlayStatusDetail = detail
    }

    func inspectNotifications() {
        log("ViewModel inspectNotifications invoked. handlerSet=\(inspectNotificationsHandler != nil)")
        inspectNotificationsHandler?()
    }

    func browseOlderConversation() {
        guard canBrowseOlderConversations else { return }
        selectedConversationIndex += 1
        applySelectedConversationPreview()
    }

    func browseNewerConversation() {
        guard canBrowseNewerConversations else { return }
        selectedConversationIndex -= 1
        applySelectedConversationPreview()
    }

    func resumeSelectedConversation() {
        guard let snapshot = selectedConversation else { return }
        pauseMonitoringForChat()
        latestTopicContext = snapshot.topicContext
        assistantResponse = snapshot.feedbackText
        chatMessages = snapshot.chatMessages
        previewImage = snapshot.previewImage
        lastCapturePNGData = snapshot.screenshotPNGData
        frontmostAppName = snapshot.appName
        windowTitle = snapshot.windowTitle
        lastFeedbackLabel = snapshot.feedbackLabel
        activeConversationID = snapshot.id
        isOverlayChatExpanded = true
        chatStatus = uiText("待機中", "Idle")
        log("Resumed conversation from history. index=\(selectedConversationIndex)")
    }

    func refreshFrontmostContext() {
        let app = NSWorkspace.shared.frontmostApplication
        frontmostAppName = app?.localizedName ?? "Unknown"
        windowTitle = activeWindowTitle(for: app?.processIdentifier)
        captureStatus = CGPreflightScreenCaptureAccess() ? "Ready" : "Screen Recording permission required"
    }

    func captureScreen() async {
        await runCapturePipeline(trigger: .manualCapture)
    }

    func captureAndAnalyze() async {
        await runCapturePipeline(trigger: .manualAsk)
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func startMonitoring() {
        resumeMonitoringTask?.cancel()
        monitoringTask?.cancel()
        monitoringStatus = "起動中"
        isMonitoring = true
        monitoringCycleIndex = 0

        monitoringTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                await self.runCapturePipeline(trigger: .monitoring)

                do {
                    let nanoseconds = UInt64(max(self.monitoringIntervalSeconds, 3) * 1_000_000_000)
                    try await Task.sleep(nanoseconds: nanoseconds)
                } catch {
                    break
                }
            }
        }
    }

    func stopMonitoring() {
        resumeMonitoringTask?.cancel()
        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
        monitoringStatus = "停止中"
    }

    func pauseMonitoringForChat() {
        isOverlayConversationPinned = true
        if isMonitoring {
            shouldResumeMonitoringAfterChat = true
            stopMonitoring()
            monitoringStatus = "チャット中に一時停止"
            log("Monitoring paused for chat.")
        } else {
            shouldResumeMonitoringAfterChat = false
        }
    }

    func releaseOverlayConversationPin() {
        isOverlayConversationPinned = false
    }

    func resumeMonitoringAfterChatIfNeeded() {
        isOverlayConversationPinned = false
        guard shouldResumeMonitoringAfterChat else { return }
        shouldResumeMonitoringAfterChat = false
        resumeMonitoringTask?.cancel()
        monitoringStatus = "チャット終了待ち"
        let delaySeconds = max(monitoringResumeDelaySeconds, 1)
        log("Scheduling monitoring resume after chat close. delay=\(Int(delaySeconds))s")

        resumeMonitoringTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                return
            }

            while !Task.isCancelled {
                await MainActor.run {
                    self.refreshFrontmostContext()
                }

                let shouldDelayForOverlay = await MainActor.run {
                    self.shouldDelayMonitoringResumeHandler?() ?? false
                }
                if shouldDelayForOverlay {
                    await MainActor.run {
                        self.monitoringStatus = "オーバーレイ操作中のため再開待ち"
                    }

                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                    } catch {
                        return
                    }
                    continue
                }

                let frontmostAppName = await MainActor.run { self.frontmostAppName }
                if frontmostAppName != "Sidekick" {
                    break
                }

                await MainActor.run {
                    self.monitoringStatus = "Sidekickが前面のため再開待ち"
                }

                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }

            await MainActor.run {
                self.log("Resuming monitoring after chat close.")
                self.startMonitoring()
            }
        }
    }

    private func runCapturePipeline(trigger: CaptureTrigger) async {
        isBusy = true
        defer { isBusy = false }
        errorMessage = nil
        setOverlayStatus(level: .working, summary: "画面を確認中")
        refreshFrontmostContext()

        if trigger == .monitoring, frontmostAppName == "Sidekick" {
            monitoringStatus = "Sidekickが前面のためスキップ"
            setOverlayStatus(level: .idle, summary: "Sidekick前面のため待機")
            return
        }

        do {
            let snapshot = try await captureSnapshot()
            if trigger == .monitoring && isOverlayConversationPinned {
                log("Discarded monitoring capture because overlay conversation is pinned.")
                setOverlayStatus(level: .idle, summary: "チャット中")
                return
            }
            updateSessionStart(with: snapshot.observation)
            let currentObservation = snapshot.observation
            let changeReport = compare(currentObservation, to: previousObservation)
            apply(snapshot: snapshot, changeReport: changeReport, trigger: trigger)

            if trigger == .manualCapture {
                previousObservation = currentObservation
                setOverlayStatus(level: .idle, summary: "Captured")
                return
            }

            let agentDecision = try await classifyObservation(
                currentObservation: currentObservation,
                changeReport: changeReport,
                trigger: trigger,
                screenshotPNGData: snapshot.pngData
            )
            if trigger == .monitoring && isOverlayConversationPinned {
                log("Discarded monitoring analysis because overlay conversation is pinned.")
                setOverlayStatus(level: .idle, summary: "チャット中")
                return
            }
            apply(agentDecision: agentDecision)

            if shouldRequestFeedback(for: trigger, changeReport: changeReport, agentDecision: agentDecision) {
                setOverlayStatus(level: .working, summary: "応答を待っています")
                let response = try await LMStudioService().send(
                    request: LMStudioRequest(
                        endpoint: baseURL,
                        model: modelName,
                        apiFormat: apiFormat,
                        systemPrompt: buildSystemPrompt(trigger: trigger, agentDecision: agentDecision),
                        userPrompt: buildUserPrompt(currentObservation: currentObservation, changeReport: changeReport, trigger: trigger, agentDecision: agentDecision),
                        screenshotPNGData: analysisMode.requiresImage ? snapshot.pngData : nil
                )
            )
                if trigger == .monitoring && isOverlayConversationPinned {
                    log("Discarded monitoring feedback because overlay conversation is pinned.")
                    setOverlayStatus(level: .idle, summary: "チャット中")
                    previousObservation = currentObservation
                    return
                }
                let sanitizedResponse = sanitizeModelResponse(response)
                assistantResponse = sanitizedResponse
                lastFeedbackDate = .now
                lastFeedbackLabel = Self.timestampFormatter.string(from: .now)
                let topicContext = buildTopicContext(
                    currentObservation: currentObservation,
                    changeReport: changeReport,
                    agentDecision: agentDecision,
                    latestResponse: sanitizedResponse
                )
                storeLatestTopicContext(topicContext, assistantResponse: sanitizedResponse)
                if trigger == .monitoring {
                    let payload = FeedbackNotificationPayload(
                        title: notificationTitle(for: agentDecision),
                        body: sanitizedResponse
                    )
                    switch feedbackDeliveryMode {
                    case .notification:
                        feedbackNotificationHandler?(payload)
                    case .overlay:
                        feedbackOverlayHandler?(payload)
                    }
                }
                setOverlayStatus(level: .idle, summary: "更新しました")
            } else if trigger == .monitoring {
                monitoringStatus = "変化待ち"
                setOverlayStatus(level: .idle, summary: "変化待ち")
            }

            previousObservation = currentObservation
        } catch {
            captureStatus = "Failed"
            monitoringStatus = isMonitoring ? "監視エラー" : monitoringStatus
            errorMessage = error.localizedDescription
            setOverlayStatus(
                level: .warning,
                summary: trigger == .monitoring ? "応答に失敗しました" : "処理に失敗しました",
                detail: error.localizedDescription
            )
        }
    }

    private func captureSnapshot() async throws -> CapturedSnapshot {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown"
        let title = activeWindowTitle(for: app?.processIdentifier)

        let capture = try await ScreenCaptureService.capture(
            scope: captureScope,
            frontmostApplicationPID: app?.processIdentifier
        )

        let extractedOCR: String
        if analysisMode.requiresOCR {
            extractedOCR = try await OCRService.extractText(from: capture.cgImage)
        } else {
            extractedOCR = ""
        }

        let fingerprint = ImageFingerprint.hash(for: capture.cgImage)
        let observation = ScreenObservation(
            capturedAt: .now,
            appName: appName,
            windowTitle: title,
            ocrText: extractedOCR,
            imageFingerprint: fingerprint
        )

        return CapturedSnapshot(
            image: capture.image,
            cgImage: capture.cgImage,
            pngData: capture.pngData,
            observation: observation
        )
    }

    private func apply(snapshot: CapturedSnapshot, changeReport: ScreenObservationChange, trigger: CaptureTrigger) {
        previewImage = snapshot.image
        lastCapturePNGData = snapshot.pngData
        frontmostAppName = snapshot.observation.appName
        windowTitle = snapshot.observation.windowTitle
        lastCaptureLabel = Self.timestampFormatter.string(from: snapshot.observation.capturedAt)
        ocrText = snapshot.observation.ocrText
        changeSummary = changeReport.summary
        captureStatus = "Captured"

        if trigger == .monitoring {
            monitoringCycleIndex += 1
            monitoringStatus = changeReport.isMeaningful ? uiText("変化を検出", "Change detected") : uiText("監視中", "Monitoring")
        }
    }

    private func shouldRequestFeedback(for trigger: CaptureTrigger, changeReport: ScreenObservationChange, agentDecision: AgentDecision) -> Bool {
        if agentMode == .silent {
            return false
        }

        switch trigger {
        case .manualCapture:
            return false
        case .manualAsk:
            return true
        case .monitoring:
            if !agentDecision.shouldInterrupt && !changeReport.isMeaningful {
                return false
            }

            if changeReport.isMeaningful {
                return true
            }

            guard let lastFeedbackDate else {
                return true
            }

            let heartbeatSeconds = max(monitoringIntervalSeconds, 3) * max(monitoringHeartbeatCycles, 1)
            return Date().timeIntervalSince(lastFeedbackDate) >= heartbeatSeconds
        }
    }

    private func buildUserPrompt(currentObservation: ScreenObservation, changeReport: ScreenObservationChange, trigger: CaptureTrigger, agentDecision: AgentDecision) -> String {
        let ocrSection: String
        if analysisMode.requiresOCR {
            ocrSection = """

            OCR text:
            \(currentObservation.ocrText.isEmpty ? "(none)" : currentObservation.ocrText)
            """
        } else {
            ocrSection = "\nOCR text:\n(not included)"
        }

        let previousContext: String
        if let previousObservation {
            previousContext = """

            Previous app: \(previousObservation.appName)
            Previous window: \(previousObservation.windowTitle)
            Previous capture: \(Self.timestampFormatter.string(from: previousObservation.capturedAt))
            """
        } else {
            previousContext = "\nPrevious capture: (none)"
        }

        let sessionContext = "\nEstimated continuous session:\n\(continuousSessionDescription(for: currentObservation))"

        return """
        Trigger: \(trigger.promptLabel)
        Frontmost app: \(currentObservation.appName)
        Window title: \(currentObservation.windowTitle)
        Captured at: \(Self.timestampFormatter.string(from: currentObservation.capturedAt))
        Analysis mode: \(analysisMode.promptDescription)
        Change summary: \(changeReport.summary)
        Significant change: \(changeReport.isMeaningful ? "yes" : "no")\(previousContext)\(sessionContext)\(ocrSection)
        Agent state: \(agentDecision.userState)
        Agent intent: \(agentDecision.userIntent)
        Agent response mode: \(agentDecision.responseMode)
        Agent confidence: \(agentDecision.confidence)
        Agent reason: \(agentDecision.reason)
        """
    }

    private func buildSystemPrompt(trigger: CaptureTrigger, agentDecision: AgentDecision) -> String {
        let modeInstruction: String
        switch analysisMode {
        case .ocrOnly:
            modeInstruction = "OCR テキストのみが渡されます。画像は渡されません。OCR の欠落や誤認識を考慮して回答してください。"
        case .imageOnly:
            modeInstruction = "スクリーンショット画像が渡されます。OCR テキストは渡されません。画面の見た目から内容を判断して支援してください。"
        case .hybrid:
            modeInstruction = "スクリーンショット画像と OCR テキストの両方が渡されます。矛盾する場合は画像を優先しつつ、不確かな点を明示してください。"
        }

        let feedbackInstruction: String
        switch effectiveFeedbackMode(from: agentDecision) {
        case .support:
            feedbackInstruction = "実務支援を優先し、次に取るべき行動、エラーの原因候補、集中を助ける短い提案を返してください。"
        case .companion:
            feedbackInstruction = companionInstruction(for: agentDecision)
        }

        let toneInstruction = toneInstructionText()

        let triggerInstruction: String
        switch trigger {
        case .manualCapture:
            triggerInstruction = "これは手動キャプチャです。回答は不要です。"
        case .manualAsk:
            triggerInstruction = "これはユーザーが明示的に助言を求めたリクエストです。必要なら少し踏み込んだ提案をして構いません。"
        case .monitoring:
            triggerInstruction = "これは定期監視からのリクエストです。変化が小さいときは一言の状況共有や短い声かけにとどめ、大きい変化があるときだけ具体的支援を増やしてください。"
        }

        return """
        \(monitoringPrompt)

        出力言語:
        \(outputLanguageInstruction())

        現在の入力モード:
        \(modeInstruction)

        フィードバック方針:
        \(feedbackInstruction)

        口調:
        \(toneInstruction)

        エージェント判断:
        user_state=\(agentDecision.userState)
        user_intent=\(agentDecision.userIntent)
        response_mode=\(agentDecision.responseMode)
        confidence=\(agentDecision.confidence)
        should_interrupt=\(agentDecision.shouldInterrupt ? "true" : "false")
        reason=\(agentDecision.reason)

        リクエスト種別:
        \(triggerInstruction)
        """
    }

    private func classifyObservation(
        currentObservation: ScreenObservation,
        changeReport: ScreenObservationChange,
        trigger: CaptureTrigger,
        screenshotPNGData: Data
    ) async throws -> AgentDecision {
        let forcedDecision = forcedAgentDecision(for: trigger)
        if let forcedDecision {
            return forcedDecision
        }

        let jsonResponse = try await LMStudioService().send(
            request: LMStudioRequest(
                endpoint: baseURL,
                model: modelName,
                apiFormat: apiFormat,
                systemPrompt: buildClassificationSystemPrompt(),
                userPrompt: buildClassificationUserPrompt(
                    currentObservation: currentObservation,
                    changeReport: changeReport,
                    trigger: trigger
                ),
                screenshotPNGData: analysisMode.requiresImage ? screenshotPNGData : nil
            )
        )

        let parsed = try AgentDecisionParser.parse(jsonResponse)
        return adjusted(agentDecision: parsed, trigger: trigger, changeReport: changeReport)
    }

    private func buildClassificationSystemPrompt() -> String {
        """
        \(classificationPrompt)

        \(classificationReasonLanguageInstruction())
        """
    }

    private func buildClassificationUserPrompt(currentObservation: ScreenObservation, changeReport: ScreenObservationChange, trigger: CaptureTrigger) -> String {
        let ocrSection: String
        if analysisMode.requiresOCR {
            ocrSection = """

            OCR text:
            \(currentObservation.ocrText.isEmpty ? "(none)" : currentObservation.ocrText)
            """
        } else {
            ocrSection = "\nOCR text:\n(not included)"
        }

        return """
        Trigger: \(trigger.promptLabel)
        Frontmost app: \(currentObservation.appName)
        Window title: \(currentObservation.windowTitle)
        Tone mode: \(toneMode.rawValue)
        Companion style: \(companionStyle.rawValue)
        Analysis mode: \(analysisMode.promptDescription)
        Estimated continuous session: \(continuousSessionDescription(for: currentObservation))
        Change summary: \(changeReport.summary)
        Significant change: \(changeReport.isMeaningful ? "yes" : "no")\(ocrSection)
        """
    }

    private func forcedAgentDecision(for trigger: CaptureTrigger) -> AgentDecision? {
        switch agentMode {
        case .silent:
            return AgentDecision(
                userState: "uncertain",
                userIntent: "observe_only",
                responseMode: "silent",
                shouldInterrupt: false,
                confidence: "high",
                reason: "Agent Mode が Silent に固定されています。"
            )
        case .assist:
            return AgentDecision(
                userState: "work",
                userIntent: "get_help",
                responseMode: "assist",
                shouldInterrupt: trigger != .manualCapture,
                confidence: "high",
                reason: "Agent Mode が Assist に固定されています。"
            )
        case .companion:
            return AgentDecision(
                userState: "focus",
                userIntent: "stay_together",
                responseMode: "companion",
                shouldInterrupt: trigger != .manualCapture,
                confidence: "high",
                reason: "Agent Mode が Companion に固定されています。"
            )
        case .auto:
            return nil
        }
    }

    private func apply(agentDecision: AgentDecision) {
        detectedState = agentDecision.userState
        detectedIntent = agentDecision.userIntent
        detectedResponseMode = agentDecision.responseMode
        detectedConfidence = agentDecision.confidence
        detectedReason = agentDecision.reason
    }

    func sendChatMessage() async {
        let userInput = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userInput.isEmpty else { return }

        chatDraft = ""
        chatMessages.append(ChatEntry(role: .user, text: userInput))
        syncActiveConversationSnapshot()
        isChatBusy = true
        chatStatus = uiText("送信中", "Sending")
        setOverlayStatus(level: .working, summary: uiText("返信中", "Replying"))
        defer { isChatBusy = false }

        do {
            let response = try await LMStudioService().send(
                request: LMStudioRequest(
                    endpoint: baseURL,
                    model: modelName,
                    apiFormat: apiFormat,
                    systemPrompt: buildChatSystemPrompt(),
                    userPrompt: buildChatUserPrompt(with: userInput),
                    screenshotPNGData: includeLatestCaptureInChat ? lastCapturePNGData : nil
                )
            )
            let sanitizedResponse = sanitizeModelResponse(response)
            chatMessages.append(ChatEntry(role: .assistant, text: sanitizedResponse))
            syncActiveConversationSnapshot()
            chatStatus = includeLatestCaptureInChat && lastCapturePNGData != nil ? uiText("最新キャプチャ込みで返信", "Replied with Latest Capture") : uiText("返信しました", "Replied")
            setOverlayStatus(level: .idle, summary: uiText("返信しました", "Replied"))
        } catch {
            chatMessages.append(ChatEntry(role: .assistant, text: uiText("今ちょっと返せなかった。", "I couldn't reply just now.") + " \(error.localizedDescription)"))
            syncActiveConversationSnapshot()
            chatStatus = uiText("チャット送信エラー", "Chat Error")
            setOverlayStatus(level: .warning, summary: uiText("返信に失敗しました", "Reply Failed"), detail: error.localizedDescription)
        }
    }

    private func buildChatSystemPrompt() -> String {
        """
        \(chatPrompt)
        \(outputLanguageInstruction())
        \(toneInstructionText())
        """
    }

    private func buildChatUserPrompt(with userInput: String) -> String {
        let history = chatMessages.suffix(8).map { entry in
            "\(entry.role.rawValue): \(entry.text)"
        }.joined(separator: "\n")

        return """
        Latest topic context:
        \(latestTopicContext.nonEmpty ?? "(none)")

        Latest capture included:
        \(includeLatestCaptureInChat && lastCapturePNGData != nil ? "yes" : "no")

        Recent conversation:
        \(history.nonEmpty ?? "(none)")

        User follow-up:
        \(userInput)
        """
    }

    private func buildTopicContext(
        currentObservation: ScreenObservation,
        changeReport: ScreenObservationChange,
        agentDecision: AgentDecision,
        latestResponse: String
    ) -> String {
        """
        Frontmost app: \(currentObservation.appName)
        Window title: \(currentObservation.windowTitle)
        Change summary: \(changeReport.summary)
        Agent state: \(agentDecision.userState)
        Agent intent: \(agentDecision.userIntent)
        Agent response mode: \(agentDecision.responseMode)
        Agent reason: \(agentDecision.reason)
        Last feedback: \(latestResponse)
        """
    }

    private func storeLatestTopicContext(_ topicContext: String, assistantResponse: String) {
        latestTopicContext = topicContext
        chatMessages = [ChatEntry(role: .assistant, text: assistantResponse)]
        let snapshot = ConversationSnapshot(
            feedbackText: assistantResponse,
            topicContext: topicContext,
            chatMessages: chatMessages,
            previewImage: previewImage,
            screenshotPNGData: lastCapturePNGData,
            appName: frontmostAppName,
            windowTitle: windowTitle,
            feedbackLabel: lastFeedbackLabel
        )
        recentConversations.insert(snapshot, at: 0)
        if recentConversations.count > 5 {
            recentConversations = Array(recentConversations.prefix(5))
        }
        activeConversationID = snapshot.id
        selectedConversationIndex = 0
    }

    private func notificationTitle(for agentDecision: AgentDecision) -> String {
        switch agentDecision.responseMode {
        case "assist":
            return "Sidekick: 手伝えそう"
        case "empathize":
            return "Sidekick: ちょっと気になった"
        case "celebrate":
            return "Sidekick: それ盛り上がるね"
        case "commentary":
            return "Sidekick: ちょいコメント"
        case "fun_fact":
            return "Sidekick: 小ネタ"
        default:
            return "Sidekick"
        }
    }

    private func effectiveFeedbackMode(from agentDecision: AgentDecision) -> FeedbackMode {
        switch agentDecision.responseMode {
        case "assist":
            return .support
        case "empathize", "companion", "celebrate", "commentary", "fun_fact", "silent":
            return .companion
        default:
            return feedbackMode
        }
    }

    private func adjusted(agentDecision: AgentDecision, trigger: CaptureTrigger, changeReport: ScreenObservationChange) -> AgentDecision {
        guard companionStyle == .funFact else {
            return agentDecision
        }

        guard agentDecision.confidence != "low" else {
            return agentDecision
        }

        guard agentDecision.responseMode != "assist", agentDecision.responseMode != "silent" else {
            return agentDecision
        }

        let entertainmentLikeState = agentDecision.userState == "enjoy" || agentDecision.userState == "focus"
        let entertainmentLikeIntent = agentDecision.userIntent.contains("watch")
            || agentDecision.userIntent.contains("view")
            || agentDecision.userIntent.contains("listen")
            || agentDecision.userIntent.contains("enjoy")

        guard entertainmentLikeState || entertainmentLikeIntent else {
            return agentDecision
        }

        let upgradedMode: String
        if changeReport.isMeaningful || trigger == .manualAsk {
            upgradedMode = "fun_fact"
        } else {
            upgradedMode = "commentary"
        }

        return AgentDecision(
            userState: agentDecision.userState,
            userIntent: agentDecision.userIntent,
            responseMode: upgradedMode,
            shouldInterrupt: agentDecision.shouldInterrupt || trigger == .manualAsk,
            confidence: agentDecision.confidence,
            reason: agentDecision.reason + " Companion Style が小ネタありなので反応を少し強めています。"
        )
    }

    private func toneInstructionText() -> String {
        switch toneMode {
        case .neutral:
            return neutralTonePrompt
        case .casual:
            return casualTonePrompt
        }
    }

    private func outputLanguageInstruction() -> String {
        usesEnglishOutput
            ? "Write the response in natural English."
            : "必ず自然な日本語で回答してください。"
    }

    private func sanitizeModelResponse(_ response: String) -> String {
        let horizontalRulePattern = #"(?m)^[ \t]*(?:---+|\*\*\*+)[ \t]*\n?"#
        let sanitized = response
            .replacingOccurrences(of: horizontalRulePattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return sanitized.isEmpty ? response.trimmingCharacters(in: .whitespacesAndNewlines) : sanitized
    }

    private func syncActiveConversationSnapshot() {
        guard let activeConversationID,
              let index = recentConversations.firstIndex(where: { $0.id == activeConversationID }) else { return }

        recentConversations[index].chatMessages = chatMessages
        recentConversations[index].previewImage = previewImage
        recentConversations[index].screenshotPNGData = lastCapturePNGData
        recentConversations[index].appName = frontmostAppName
        recentConversations[index].windowTitle = windowTitle
        recentConversations[index].feedbackLabel = lastFeedbackLabel
    }

    private func applySelectedConversationPreview() {
        guard let snapshot = selectedConversation, !isOverlayChatExpanded else { return }
        assistantResponse = snapshot.feedbackText
        previewImage = snapshot.previewImage
        frontmostAppName = snapshot.appName
        windowTitle = snapshot.windowTitle
        lastFeedbackLabel = snapshot.feedbackLabel
        overlayMessageHeight = max(72, min(300, Double(snapshot.feedbackText.count) * 0.55))
    }

    private func classificationReasonLanguageInstruction() -> String {
        usesEnglishOutput
            ? "Write the value of \"reason\" in English."
            : "Write the value of \"reason\" in Japanese."
    }

    private func companionInstruction(for agentDecision: AgentDecision) -> String {
        let base: String
        switch companionStyle {
        case .quiet:
            base = quietCompanionPrompt
        case .chatty:
            base = chattyCompanionPrompt
        case .funFact:
            base = funFactCompanionPrompt
        }

        switch agentDecision.responseMode {
        case "commentary":
            return base + " 今回は一緒に見ている感じのコメントを優先してください。"
        case "fun_fact":
            return base + " 今回は短い背景知識や小ネタを優先してください。"
        case "celebrate":
            return base + " 今回は楽しさを共有する反応を優先してください。"
        case "empathize":
            return base + " 今回はねぎらいや共感を少し強めてください。"
        default:
            return base
        }
    }

    private func updateSessionStart(with observation: ScreenObservation) {
        guard let previousObservation else {
            currentSessionStartedAt = observation.capturedAt
            return
        }

        let sameApp = previousObservation.appName == observation.appName
        let sameWindow = previousObservation.windowTitle == observation.windowTitle
        let closeEnough = observation.capturedAt.timeIntervalSince(previousObservation.capturedAt) <= max(monitoringIntervalSeconds * 2.5, 180)

        if sameApp && sameWindow && closeEnough {
            currentSessionStartedAt = currentSessionStartedAt ?? previousObservation.capturedAt
        } else {
            currentSessionStartedAt = observation.capturedAt
        }
    }

    private func continuousSessionDescription(for observation: ScreenObservation) -> String {
        guard let currentSessionStartedAt else {
            return "unknown"
        }

        let seconds = max(0, Int(observation.capturedAt.timeIntervalSince(currentSessionStartedAt)))
        let minutes = seconds / 60
        if minutes < 1 {
            return "less_than_1_minute"
        }
        if minutes < 60 {
            return "\(minutes)_minutes"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        return "\(hours)_hours_\(remainder)_minutes"
    }

    private func compare(_ current: ScreenObservation, to previous: ScreenObservation?) -> ScreenObservationChange {
        guard let previous else {
            return ScreenObservationChange(
                isMeaningful: true,
                summary: "初回キャプチャです。現在の画面を基準にします。"
            )
        }

        var items: [String] = []
        var meaningful = false

        if current.appName != previous.appName {
            items.append("アプリが \(previous.appName) から \(current.appName) に変わりました。")
            meaningful = true
        }

        if current.windowTitle != previous.windowTitle {
            items.append("ウィンドウタイトルが変わりました。")
            meaningful = true
        }

        let imageDistance = ImageFingerprint.hammingDistance(lhs: current.imageFingerprint, rhs: previous.imageFingerprint)
        if imageDistance >= 12 {
            items.append("画面の見た目が大きく変わりました。")
            meaningful = true
        } else if imageDistance >= 4 {
            items.append("画面表示に小さな変化があります。")
        }

        let ocrChangeRatio = textChangeRatio(from: previous.ocrText, to: current.ocrText)
        if analysisMode.requiresOCR {
            if ocrChangeRatio >= 0.45 {
                items.append("OCR テキストの内容が大きく変わりました。")
                meaningful = true
            } else if ocrChangeRatio >= 0.15 {
                items.append("OCR テキストに一部変化があります。")
            }
        }

        if items.isEmpty {
            items.append("前回キャプチャから大きな変化は見られません。")
        }

        return ScreenObservationChange(isMeaningful: meaningful, summary: items.joined(separator: " "))
    }

    private func textChangeRatio(from previous: String, to current: String) -> Double {
        let left = normalizeForComparison(previous)
        let right = normalizeForComparison(current)

        if left == right { return 0 }
        if left.isEmpty || right.isEmpty { return 1 }

        let leftTokens = Set(left.split(separator: " ").map(String.init))
        let rightTokens = Set(right.split(separator: " ").map(String.init))
        let union = leftTokens.union(rightTokens)
        guard !union.isEmpty else { return 0 }
        let intersection = leftTokens.intersection(rightTokens)
        return 1 - (Double(intersection.count) / Double(union.count))
    }

    private func normalizeForComparison(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func activeWindowTitle(for processIdentifier: pid_t?) -> String {
        guard let processIdentifier else { return "Unknown" }
        let options = CGWindowListOption.optionOnScreenOnly.union(.excludeDesktopElements)
        let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        for window in windowInfo {
            let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard ownerPID == processIdentifier, layer == 0 else { continue }

            let title = (window[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let title, !title.isEmpty {
                return title
            }
        }

        return "Unknown"
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

extension SidekickViewModel {
    enum CaptureTrigger: Equatable {
        case manualCapture
        case manualAsk
        case monitoring

        var promptLabel: String {
            switch self {
            case .manualCapture:
                return "manual_capture"
            case .manualAsk:
                return "manual_ask"
            case .monitoring:
                return "monitoring"
            }
        }
    }

    struct ScreenObservation {
        let capturedAt: Date
        let appName: String
        let windowTitle: String
        let ocrText: String
        let imageFingerprint: UInt64
    }

    struct ScreenObservationChange {
        let isMeaningful: Bool
        let summary: String
    }

    struct AgentDecision {
        let userState: String
        let userIntent: String
        let responseMode: String
        let shouldInterrupt: Bool
        let confidence: String
        let reason: String
    }

    struct FeedbackNotificationPayload {
        let title: String
        let body: String
    }

    struct ConversationSnapshot: Identifiable {
        let id = UUID()
        var feedbackText: String
        var topicContext: String
        var chatMessages: [ChatEntry]
        var previewImage: NSImage?
        var screenshotPNGData: Data?
        var appName: String
        var windowTitle: String
        var feedbackLabel: String
    }

    struct ChatEntry: Identifiable {
        enum Role: String {
            case user
            case assistant
        }

        let id = UUID()
        let role: Role
        let text: String
    }

    struct CapturedSnapshot {
        let image: NSImage
        let cgImage: CGImage
        let pngData: Data
        let observation: ScreenObservation
    }
}
