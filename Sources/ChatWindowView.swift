import SwiftUI

struct ChatWindowView: View {
    @ObservedObject var viewModel: SidekickViewModel

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.uiText("Sidekick チャット", "Sidekick Chat"))
                        .font(.title3.weight(.semibold))
                    Text(viewModel.detectedReason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.uiText("最新キャプチャ", "Latest Capture"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Group {
                        if let image = viewModel.previewImage {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            ContentUnavailableView(viewModel.uiText("キャプチャなし", "No Capture"), systemImage: "display")
                        }
                    }
                    .frame(width: 180, height: 110)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(viewModel.uiText("最新キャプチャを会話に含める", "Include latest capture in chat"), isOn: $viewModel.includeLatestCaptureInChat)
                    Text(viewModel.localizedStatus(viewModel.chatStatus))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(viewModel.uiText("チャットを開いている間は監視を一時停止します。", "Monitoring pauses while this chat window is open."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.chatMessages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role == .assistant ? "Sidekick" : "You")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(message.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(message.role == .assistant ? Color.orange.opacity(0.14) : Color.blue.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if viewModel.isChatBusy {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id("chat-bottom")
                    }
                    .onAppear {
                        scrollToBottom(with: proxy, animated: false)
                    }
                    .onChange(of: viewModel.chatMessages.count) { _, _ in
                        scrollToBottom(with: proxy)
                    }
                    .onChange(of: viewModel.isChatBusy) { _, _ in
                        scrollToBottom(with: proxy)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(viewModel.uiText("その話もう少し聞かせて", "Tell me a bit more"), text: $viewModel.chatDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
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
                .disabled(viewModel.chatDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isChatBusy)
            }
        }
        .padding(16)
        .frame(minWidth: 420, minHeight: 520)
        .onAppear {
            viewModel.pauseMonitoringForChat()
        }
    }

    private func scrollToBottom(with proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo("chat-bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("chat-bottom", anchor: .bottom)
        }
    }
}
