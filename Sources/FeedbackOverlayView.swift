import SwiftUI

struct OverlayFeedbackView: View {
    @ObservedObject var viewModel: SidekickViewModel
    let title: String
    let message: String
    let resizeForChatState: (Bool) -> Void
    let closeOverlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if viewModel.isOverlayChatExpanded {
                foldedContextBar
            } else {
                feedbackCard
            }
            actionRow

            if viewModel.isOverlayChatExpanded {
                expandedChat
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundCard)
        .onAppear {
            resizeForChatState(viewModel.isOverlayChatExpanded)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.95), Color.red.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                overlayStatusPill

                Button(action: closeOverlay) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(viewModel.uiText("Sidekickを終了", "Quit Sidekick"))
            }
        }
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Sidekick")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange.opacity(0.95))
            }

            ScrollView {
                Text(viewModel.displayedOverlayMessage.isEmpty ? message : viewModel.displayedOverlayMessage)
                    .font(.body.weight(.medium))
                    .lineSpacing(3)
                    .foregroundStyle(Color.primary.opacity(0.96))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(
                minHeight: viewModel.isOverlayChatExpanded ? 170 : max(72, CGFloat(viewModel.overlayMessageHeight)),
                maxHeight: viewModel.isOverlayChatExpanded ? 190 : max(72, CGFloat(viewModel.overlayMessageHeight))
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.black.opacity(0.14), lineWidth: 1.2)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 3)
    }

    private var historyControls: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.browseOlderConversation()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.9))
            .clipShape(Circle())
            .disabled(!viewModel.canBrowseOlderConversations)
            .opacity(viewModel.canBrowseOlderConversations ? 1 : 0.4)

            Text(viewModel.conversationHistoryIndicator)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 44)
                .multilineTextAlignment(.center)

            Button {
                viewModel.browseNewerConversation()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(Color.white.opacity(0.9))
            .clipShape(Circle())
            .disabled(!viewModel.canBrowseNewerConversations)
            .opacity(viewModel.canBrowseNewerConversations ? 1 : 0.4)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button(primaryActionTitle) {
                if isWelcomeOverlayAction {
                    viewModel.startMonitoring()
                    return
                }

                if !viewModel.isOverlayChatExpanded, viewModel.selectedConversation != nil {
                    viewModel.resumeSelectedConversation()
                    DispatchQueue.main.async {
                        resizeForChatState(true)
                    }
                    return
                }

                let nextValue = !viewModel.isOverlayChatExpanded
                if nextValue {
                    viewModel.pauseMonitoringForChat()
                } else {
                    viewModel.releaseOverlayConversationPin()
                    viewModel.resumeMonitoringAfterChatIfNeeded()
                }
                viewModel.isOverlayChatExpanded = nextValue
                DispatchQueue.main.async {
                    resizeForChatState(nextValue)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.95), Color.red.opacity(0.82)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .foregroundStyle(.white)

            Spacer()

            if !viewModel.isOverlayChatExpanded, !viewModel.recentConversations.isEmpty {
                historyControls
            }
        }
    }

    private var isWelcomeOverlayAction: Bool {
        !viewModel.isMonitoring && !viewModel.isOverlayChatExpanded && message == viewModel.welcomePrompt
    }

    private var primaryActionTitle: String {
        if viewModel.isOverlayChatExpanded {
            return viewModel.uiText("元に戻す", "Back")
        }

        if isWelcomeOverlayAction {
            return viewModel.uiText("モニタリングを開始", "Start Monitoring")
        }

        return viewModel.uiText("チャットする", "Chat")
    }

    private var foldedContextBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "message.badge.filled.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.orange.opacity(0.95))
            Text(viewModel.uiText("この話題でチャット中", "Chatting about this topic"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.uiText("固定中", "Pinned"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.08))
        }
    }

    private var overlayStatusPill: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.overlayStatusLevel.symbolName)
                .font(.caption.weight(.semibold))
            Text(viewModel.localizedStatus(viewModel.overlayStatusSummary))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(statusTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(statusBackgroundColor)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(statusBorderColor, lineWidth: 1)
        }
        .help(viewModel.overlayStatusDetail.isEmpty ? viewModel.localizedStatus(viewModel.overlayStatusSummary) : "\(viewModel.localizedStatus(viewModel.overlayStatusSummary))\n\(viewModel.overlayStatusDetail)")
    }

    private var expandedChat: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                capturePreview

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(viewModel.uiText("最新キャプチャを会話に含める", "Include latest capture in chat"), isOn: $viewModel.includeLatestCaptureInChat)
                        .toggleStyle(.checkbox)
                    Text(viewModel.localizedStatus(viewModel.chatStatus))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(overlayChatMessages.suffix(6)) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role == .assistant ? "Sidekick" : "You")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(message.role == .assistant ? Color.orange.opacity(0.95) : Color.blue.opacity(0.9))
                                Text(message.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(message.role == .assistant ? Color.orange.opacity(0.12) : Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("overlay-chat-bottom")
                    }
                    .onAppear {
                        scrollToOverlayBottom(with: proxy, animated: false)
                    }
                    .onChange(of: overlayChatMessages.count) { _, _ in
                        scrollToOverlayBottom(with: proxy)
                    }
                    .onChange(of: viewModel.isChatBusy) { _, _ in
                        scrollToOverlayBottom(with: proxy)
                    }
                }
            }
            .frame(minHeight: 220, maxHeight: 320)

            HStack(alignment: .bottom, spacing: 8) {
                TextField(viewModel.uiText("メッセージを入力", "Type a message"), text: $viewModel.chatDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit {
                        Task {
                            await viewModel.sendChatMessage()
                        }
                    }

                Button(viewModel.uiText("送信", "Send")) {
                    Task {
                        await viewModel.sendChatMessage()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.orange.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(viewModel.chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isChatBusy)
                .opacity(viewModel.chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isChatBusy ? 0.55 : 1)
            }

            if viewModel.isChatBusy {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.uiText("返信中…", "Replying..."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private var capturePreview: some View {
        Group {
            if let image = viewModel.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.06))
                    Image(systemName: "display")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 126, height: 84)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.black.opacity(0.08))
        }
    }

    private var backgroundCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.965, green: 0.965, blue: 0.955))

            LinearGradient(
                colors: [
                    Color.orange.opacity(0.07),
                    Color.red.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.black.opacity(0.16), lineWidth: 1.1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }

    private var statusTextColor: Color {
        switch viewModel.overlayStatusLevel {
        case .idle:
            return Color(red: 0.12, green: 0.45, blue: 0.24)
        case .working:
            return Color(red: 0.72, green: 0.36, blue: 0.02)
        case .warning:
            return Color(red: 0.72, green: 0.16, blue: 0.12)
        }
    }

    private var statusBackgroundColor: Color {
        switch viewModel.overlayStatusLevel {
        case .idle:
            return Color(red: 0.91, green: 0.97, blue: 0.92)
        case .working:
            return Color(red: 0.99, green: 0.94, blue: 0.86)
        case .warning:
            return Color(red: 0.99, green: 0.9, blue: 0.88)
        }
    }

    private var statusBorderColor: Color {
        switch viewModel.overlayStatusLevel {
        case .idle:
            return Color(red: 0.7, green: 0.85, blue: 0.72)
        case .working:
            return Color(red: 0.9, green: 0.74, blue: 0.46)
        case .warning:
            return Color(red: 0.88, green: 0.58, blue: 0.53)
        }
    }

    private var overlayChatMessages: [SidekickViewModel.ChatEntry] {
        return viewModel.chatMessages
    }

    private func scrollToOverlayBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("overlay-chat-bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("overlay-chat-bottom", anchor: .bottom)
        }
    }
}
