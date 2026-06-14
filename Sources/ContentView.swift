import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: SidekickViewModel
    let openChat: () -> Void

    @State private var selectedPage: SettingsPage = .overview
    @State private var selectedPrompt: PromptPage = .monitoring

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $selectedPage) { page in
                Label(page.title(viewModel), systemImage: page.systemImage)
                    .tag(page)
            }
            .navigationTitle("Sidekick")
            .navigationSplitViewColumnWidth(min: 220, ideal: 240)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    pageHeader
                    detailContent
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .toolbar {
                Button(viewModel.uiText("前面情報を更新", "Refresh Context")) {
                    viewModel.refreshFrontmostContext()
                }
            }
        }
        .onAppear {
            viewModel.refreshFrontmostContext()
        }
        .onChange(of: viewModel.overlayOpacity) { _, _ in
            OverlayWindowManager.shared.refreshAppearance()
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(selectedPage.title(viewModel), systemImage: selectedPage.systemImage)
                .font(.largeTitle.weight(.bold))
            Spacer()
            if viewModel.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedPage {
        case .overview:
            overviewPage
        case .connection:
            connectionPage
        case .behavior:
            behaviorPage
        case .prompts:
            promptsPage
        case .diagnostics:
            diagnosticsPage
        }
    }

    private var overviewPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            quickStatusGrid

            HStack(alignment: .top, spacing: 16) {
                infoGroup(title: viewModel.uiText("最新フィードバック", "Latest Feedback"), systemImage: "text.bubble") {
                    Text(viewModel.assistantResponse.isEmpty ? viewModel.uiText("まだフィードバックはありません。", "No feedback yet.") : viewModel.assistantResponse)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                infoGroup(title: viewModel.uiText("変化サマリー", "Change Summary"), systemImage: "waveform.path.ecg") {
                    Text(viewModel.changeSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            infoGroup(title: viewModel.uiText("エージェント判断", "Agent Decision"), systemImage: "sparkles") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("State", value: viewModel.detectedState)
                    LabeledContent("Intent", value: viewModel.detectedIntent)
                    LabeledContent("Response", value: viewModel.detectedResponseMode)
                    LabeledContent("Confidence", value: viewModel.detectedConfidence)
                    LabeledContent("Reason", value: viewModel.detectedReason)
                }
            }
        }
    }

    private var connectionPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(title: "LM Studio", systemImage: "server.rack") {
                labeledControl(viewModel.uiText("Base URL", "Base URL")) {
                    TextField("http://127.0.0.1:1234/v1/chat/completions", text: $viewModel.baseURL)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                }

                labeledControl(viewModel.uiText("モデル", "Model")) {
                    TextField("local-model", text: $viewModel.modelName)
                        .textFieldStyle(.roundedBorder)
                        .disableAutocorrection(true)
                }

                labeledControl(viewModel.uiText("API形式", "API Format")) {
                    Picker("", selection: $viewModel.apiFormat) {
                        ForEach(SidekickViewModel.APIFormat.allCases) { format in
                            Text(viewModel.label(for: format)).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            settingsGroup(title: viewModel.uiText("言語", "Language"), systemImage: "globe") {
                labeledControl(viewModel.uiText("UI言語", "Interface Language")) {
                    Picker("", selection: $viewModel.interfaceLanguage) {
                        ForEach(SidekickViewModel.InterfaceLanguage.allCases) { language in
                            Text(viewModel.label(for: language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                labeledControl(viewModel.uiText("出力言語", "Output Language")) {
                    Picker("", selection: $viewModel.outputLanguage) {
                        ForEach(SidekickViewModel.OutputLanguage.allCases) { language in
                            Text(viewModel.label(for: language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }

    private var behaviorPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(title: viewModel.uiText("画面入力", "Screen Input"), systemImage: "display") {
                labeledControl(viewModel.uiText("キャプチャ範囲", "Capture Scope")) {
                    Picker("", selection: $viewModel.captureScope) {
                        ForEach(SidekickViewModel.CaptureScope.allCases) { scope in
                            Text(viewModel.label(for: scope)).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                labeledControl(viewModel.uiText("解析モード", "Analysis Mode")) {
                    Picker("", selection: $viewModel.analysisMode) {
                        ForEach(SidekickViewModel.AnalysisMode.allCases) { mode in
                            Text(viewModel.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            settingsGroup(title: viewModel.uiText("反応", "Response"), systemImage: "sparkles") {
                labeledControl(viewModel.uiText("エージェントモード", "Agent Mode")) {
                    Picker("", selection: $viewModel.agentMode) {
                        ForEach(SidekickViewModel.AgentMode.allCases) { mode in
                            Text(viewModel.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                labeledControl(viewModel.uiText("フィードバック方針", "Feedback Mode")) {
                    Picker("", selection: $viewModel.feedbackMode) {
                        ForEach(SidekickViewModel.FeedbackMode.allCases) { mode in
                            Text(viewModel.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(viewModel.agentMode != .auto)
                }

                labeledControl(viewModel.uiText("口調", "Tone")) {
                    Picker("", selection: $viewModel.toneMode) {
                        ForEach(SidekickViewModel.ToneMode.allCases) { mode in
                            Text(viewModel.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                labeledControl(viewModel.uiText("会話スタイル", "Companion Style")) {
                    Picker("", selection: $viewModel.companionStyle) {
                        ForEach(SidekickViewModel.CompanionStyle.allCases) { style in
                            Text(viewModel.label(for: style)).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            settingsGroup(title: viewModel.uiText("モニタリング", "Monitoring"), systemImage: "waveform.path.ecg") {
                labeledControl(viewModel.uiText("表示方法", "Delivery")) {
                    Picker("", selection: $viewModel.feedbackDeliveryMode) {
                        ForEach(SidekickViewModel.FeedbackDeliveryMode.allCases) { mode in
                            Text(viewModel.label(for: mode)).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if viewModel.feedbackDeliveryMode == .overlay {
                    sliderControl(
                        title: viewModel.uiText("オーバーレイ透明度", "Overlay Opacity"),
                        valueText: "\(Int(viewModel.overlayOpacity * 100))%",
                        value: $viewModel.overlayOpacity,
                        range: 0.9...1.0,
                        step: 0.02
                    )
                }

                sliderControl(
                    title: viewModel.uiText("間隔", "Interval"),
                    valueText: viewModel.uiText("\(Int(viewModel.monitoringIntervalSeconds)) 秒", "\(Int(viewModel.monitoringIntervalSeconds)) sec"),
                    value: $viewModel.monitoringIntervalSeconds,
                    range: 5...60,
                    step: 1
                )

                sliderControl(
                    title: viewModel.uiText("ハートビート", "Heartbeat"),
                    valueText: viewModel.uiText("\(Int(viewModel.monitoringHeartbeatCycles)) サイクルごと", "every \(Int(viewModel.monitoringHeartbeatCycles)) cycles"),
                    value: $viewModel.monitoringHeartbeatCycles,
                    range: 1...12,
                    step: 1
                )

                sliderControl(
                    title: viewModel.uiText("再開ディレイ", "Resume Delay"),
                    valueText: viewModel.uiText("\(Int(viewModel.monitoringResumeDelaySeconds)) 秒", "\(Int(viewModel.monitoringResumeDelaySeconds)) sec"),
                    value: $viewModel.monitoringResumeDelaySeconds,
                    range: 1...10,
                    step: 1
                )
            }
        }
    }

    private var promptsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(title: viewModel.uiText("既定文", "Defaults"), systemImage: "arrow.counterclockwise") {
                HStack(spacing: 10) {
                    Button(viewModel.uiText("日本語の既定文に戻す", "Apply Japanese Defaults")) {
                        viewModel.applyJapanesePromptDefaults()
                    }

                    Button(viewModel.uiText("英語の既定文に切り替える", "Apply English Defaults")) {
                        viewModel.applyEnglishPromptDefaults()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            settingsGroup(title: viewModel.uiText("編集", "Edit"), systemImage: "text.alignleft") {
                labeledControl(viewModel.uiText("プロンプト", "Prompt")) {
                    Picker("", selection: $selectedPrompt) {
                        ForEach(PromptPage.allCases) { prompt in
                            Text(prompt.title).tag(prompt)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(maxWidth: 260, alignment: .trailing)
                }

                TextEditor(text: promptBinding(for: selectedPrompt))
                    .font(.body.monospaced())
                    .frame(minHeight: selectedPrompt.editorHeight)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.12))
                    }
            }
        }
    }

    private var diagnosticsPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsGroup(title: viewModel.uiText("クイック操作", "Quick Actions"), systemImage: "bolt") {
                HStack(spacing: 12) {
                    Button(viewModel.uiText("画面をキャプチャ", "Capture Screen")) {
                        Task {
                            await viewModel.captureScreen()
                        }
                    }
                    .keyboardShortcut("k", modifiers: [.command])

                    Button(viewModel.uiText("Sidekickに聞く", "Ask Sidekick")) {
                        Task {
                            await viewModel.captureAndAnalyze()
                        }
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(viewModel.isBusy)

                    Button(viewModel.isMonitoring ? viewModel.uiText("モニタリングを停止", "Stop Monitoring") : viewModel.uiText("モニタリングを開始", "Start Monitoring")) {
                        viewModel.toggleMonitoring()
                    }
                    .disabled(viewModel.isBusy)

                    Button(viewModel.uiText("チャットを開く", "Open Chat")) {
                        viewModel.log("Dashboard action: open chat")
                        openChat()
                    }

                    Button(viewModel.uiText("テスト表示", "Test Feedback")) {
                        viewModel.sendTestFeedback()
                    }

                    Button(viewModel.uiText("通知を確認", "Inspect Notifications")) {
                        viewModel.log("Dashboard action: inspect notifications")
                        viewModel.inspectNotifications()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage = viewModel.errorMessage {
                infoGroup(title: viewModel.uiText("エラー", "Error"), systemImage: "exclamationmark.triangle") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                screenshotPanel
                transcriptPanel
            }

            infoGroup(title: viewModel.uiText("アプリログ", "App Log"), systemImage: "scroll") {
                ScrollView {
                    Text(viewModel.appLog)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 320)
            }
        }
    }

    private var screenshotPanel: some View {
        infoGroup(title: viewModel.uiText("最新キャプチャ", "Latest Capture"), systemImage: "display") {
            Group {
                if let image = viewModel.previewImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView(viewModel.uiText("キャプチャなし", "No Capture"), systemImage: "display")
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var transcriptPanel: some View {
        infoGroup(title: "OCR", systemImage: "doc.text.viewfinder") {
            ScrollView {
                Text(viewModel.ocrText.isEmpty ? viewModel.uiText("まだ OCR テキストはありません。", "No OCR text extracted yet.") : viewModel.ocrText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var quickStatusGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
            statusTile(title: viewModel.uiText("モニタリング", "Monitoring"), value: viewModel.localizedStatus(viewModel.monitoringStatus), systemImage: viewModel.isMonitoring ? "waveform.circle.fill" : "pause.circle")
            statusTile(title: viewModel.uiText("表示方法", "Delivery"), value: viewModel.label(for: viewModel.feedbackDeliveryMode), systemImage: "rectangle.on.rectangle")
            statusTile(title: viewModel.uiText("前面アプリ", "Frontmost App"), value: viewModel.frontmostAppName, systemImage: "app.badge")
            statusTile(title: viewModel.uiText("最終フィードバック", "Last Feedback"), value: viewModel.lastFeedbackLabel, systemImage: "clock")
        }
    }

    private func statusTile(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func settingsGroup<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func infoGroup<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func labeledControl<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Text(title)
                .font(.body.weight(.medium))
                .frame(width: 180, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func sliderControl(title: String, valueText: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.body.weight(.medium))
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func promptBinding(for page: PromptPage) -> Binding<String> {
        switch page {
        case .monitoring:
            return $viewModel.monitoringPrompt
        case .chat:
            return $viewModel.chatPrompt
        case .classification:
            return $viewModel.classificationPrompt
        case .welcome:
            return $viewModel.welcomePrompt
        case .neutralTone:
            return $viewModel.neutralTonePrompt
        case .casualTone:
            return $viewModel.casualTonePrompt
        case .quietCompanion:
            return $viewModel.quietCompanionPrompt
        case .chattyCompanion:
            return $viewModel.chattyCompanionPrompt
        case .funFactCompanion:
            return $viewModel.funFactCompanionPrompt
        }
    }
}

private enum SettingsPage: String, CaseIterable, Identifiable {
    case overview
    case connection
    case behavior
    case prompts
    case diagnostics

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview:
            return "gauge.with.dots.needle.67percent"
        case .connection:
            return "server.rack"
        case .behavior:
            return "slider.horizontal.3"
        case .prompts:
            return "text.quote"
        case .diagnostics:
            return "stethoscope"
        }
    }

    @MainActor
    func title(_ viewModel: SidekickViewModel) -> String {
        switch self {
        case .overview:
            return viewModel.uiText("概要", "Overview")
        case .connection:
            return viewModel.uiText("接続と言語", "Connection")
        case .behavior:
            return viewModel.uiText("ふるまい", "Behavior")
        case .prompts:
            return viewModel.uiText("プロンプト", "Prompts")
        case .diagnostics:
            return viewModel.uiText("診断", "Diagnostics")
        }
    }
}

private enum PromptPage: String, CaseIterable, Identifiable {
    case monitoring
    case chat
    case classification
    case welcome
    case neutralTone
    case casualTone
    case quietCompanion
    case chattyCompanion
    case funFactCompanion

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monitoring:
            return "Monitoring"
        case .chat:
            return "Chat"
        case .classification:
            return "Classification"
        case .welcome:
            return "Welcome"
        case .neutralTone:
            return "Tone: Neutral"
        case .casualTone:
            return "Tone: Casual"
        case .quietCompanion:
            return "Companion: Quiet"
        case .chattyCompanion:
            return "Companion: Chatty"
        case .funFactCompanion:
            return "Companion: Insight"
        }
    }

    var editorHeight: CGFloat {
        switch self {
        case .classification:
            return 260
        case .monitoring, .funFactCompanion:
            return 210
        case .chattyCompanion:
            return 170
        default:
            return 140
        }
    }
}
