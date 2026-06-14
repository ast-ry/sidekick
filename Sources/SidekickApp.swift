import AppKit
import Darwin
import SwiftUI
import UserNotifications

@main
struct SidekickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = SidekickViewModel()
    private let singleInstanceGuard = SingleInstanceGuard()

    var body: some Scene {
        WindowGroup("Sidekick", id: "dashboard") {
            ContentView(viewModel: viewModel, openChat: {
                appDelegate.openChatWindow()
            })
                .frame(minWidth: 980, minHeight: 720)
                .onAppear {
                    if !singleInstanceGuard.acquire() {
                        appDelegate.presentDuplicateLaunchAlertAndTerminate()
                    }
                    appDelegate.configure(with: viewModel)
                }
        }

        MenuBarExtra("Sidekick", systemImage: viewModel.isMonitoring ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack") {
            StatusMenuView(
                viewModel: viewModel,
                openDashboard: {
                    appDelegate.openDashboardWindow()
                },
                openChat: {
                    appDelegate.openChatWindow()
                }
            )
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var viewModel: SidekickViewModel?
    private var didPresentWelcomeOverlay = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    @MainActor
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        openDashboardWindow()
        return true
    }

    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openDashboardWindow()
        return true
    }

    @MainActor
    func presentDuplicateLaunchAlertAndTerminate() {
        let alert = NSAlert()
        alert.messageText = "Sidekick is already running."
        alert.informativeText = "Close the existing Sidekick process before starting a new one from another terminal."
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }

    @MainActor
    func configure(with viewModel: SidekickViewModel) {
        guard self.viewModel !== viewModel else { return }
        self.viewModel = viewModel
        viewModel.log("AppDelegate configured. bundle=\(Bundle.main.bundleURL.lastPathComponent)")
        ChatWindowManager.shared.update(viewModel: viewModel)
        OverlayWindowManager.shared.update(viewModel: viewModel)
        viewModel.feedbackNotificationHandler = { [weak self] payload in
            Task { @MainActor in
                self?.deliverNotification(payload)
            }
        }
        viewModel.feedbackOverlayHandler = { payload in
            Task { @MainActor in
                OverlayWindowManager.shared.show(payload: payload)
            }
        }
        viewModel.inspectNotificationsHandler = { [weak self] in
            Task { @MainActor in
                self?.viewModel?.log("AppDelegate inspectNotificationsHandler invoked.")
            }
            self?.inspectNotifications()
        }

        guard Bundle.main.bundleURL.pathExtension == "app" else {
            viewModel.notificationStatus = "swift run では通知不可"
            viewModel.notificationsEnabled = false
            viewModel.log("Notifications disabled because app is not launched from .app bundle.")
            return
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        viewModel.log("UNUserNotificationCenter delegate assigned.")
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if let error {
                    viewModel.notificationStatus = "通知エラー: \(error.localizedDescription)"
                    viewModel.notificationsEnabled = false
                    viewModel.log("Notification authorization error: \(error.localizedDescription)")
                    return
                }

                viewModel.notificationsEnabled = granted
                viewModel.notificationStatus = granted ? "許可済み" : "未許可"
                viewModel.log("Notification authorization completed. granted=\(granted)")
            }
        }

        center.getNotificationSettings { settings in
            let authorizationStatus = settings.authorizationStatus
            DispatchQueue.main.async {
                switch authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    viewModel.notificationsEnabled = true
                    viewModel.notificationStatus = "許可済み"
                    viewModel.log("Notification settings resolved as authorized.")
                case .denied:
                    viewModel.notificationsEnabled = false
                    viewModel.notificationStatus = "拒否済み"
                    viewModel.log("Notification settings resolved as denied.")
                case .notDetermined:
                    viewModel.notificationsEnabled = false
                    viewModel.notificationStatus = "未決定"
                    viewModel.log("Notification settings not determined yet.")
                @unknown default:
                    viewModel.notificationsEnabled = false
                    viewModel.notificationStatus = "不明"
                    viewModel.log("Notification settings returned unknown state.")
                }
            }
        }

        let openChatAction = UNNotificationAction(
            identifier: "OPEN_CHAT",
            title: viewModel.uiText("チャットを開く", "Open Chat"),
            options: [.foreground]
        )
        let category = UNNotificationCategory(identifier: "SIDEKICK_FEEDBACK", actions: [openChatAction], intentIdentifiers: [])
        center.setNotificationCategories([category])
        viewModel.log("Notification category registered. id=SIDEKICK_FEEDBACK action=OPEN_CHAT")

        presentWelcomeOverlayIfNeeded()
    }

    @MainActor
    private func deliverNotification(_ payload: SidekickViewModel.FeedbackNotificationPayload) {
        let requestID = UUID().uuidString
        viewModel?.log("Delivering notification: title=\(payload.title) request=\(requestID)")
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.categoryIdentifier = "SIDEKICK_FEEDBACK"

        let request = UNNotificationRequest(identifier: requestID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            let message: String
            if let error {
                message = "Notification add failed. request=\(requestID) error=\(error.localizedDescription)"
            } else {
                message = "Notification queued successfully. request=\(requestID)"
            }
            debugLog(message)

            DispatchQueue.main.async {
                (NSApp.delegate as? AppDelegate)?.viewModel?.log(message)
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let requestIdentifier = notification.request.identifier
        let categoryIdentifier = notification.request.content.categoryIdentifier
        debugLog("Notification will present. request=\(requestIdentifier) category=\(categoryIdentifier)")
        DispatchQueue.main.async {
            (NSApp.delegate as? AppDelegate)?.viewModel?.log(
                "Notification will present. request=\(requestIdentifier) category=\(categoryIdentifier)"
            )
        }
        return UNNotificationPresentationOptions(arrayLiteral: .banner, .sound, .list)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let actionIdentifier = response.actionIdentifier
        let requestIdentifier = response.notification.request.identifier
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        debugLog("Notification response received. request=\(requestIdentifier) category=\(categoryIdentifier) action=\(actionIdentifier)")
        await MainActor.run {
            ChatWindowManager.shared.log(
                "Notification response received. request=\(requestIdentifier) category=\(categoryIdentifier) action=\(actionIdentifier)"
            )
            if actionIdentifier == UNNotificationDismissActionIdentifier {
                ChatWindowManager.shared.log("Notification was dismissed.")
                return
            }
            ChatWindowManager.shared.showCurrent()
        }
    }

    @MainActor
    func openChatWindow() {
        ChatWindowManager.shared.log("openChatWindow invoked. current app windows=\(NSApp.windows.count)")
        ChatWindowManager.shared.showCurrent()
    }

    @MainActor
    func openDashboardWindow() {
        viewModel?.log("openDashboardWindow invoked.")
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Sidekick" }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            return
        }

        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @MainActor
    private func inspectNotifications() {
        viewModel?.log("AppDelegate inspectNotifications started.")
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let count = requests.count
            let lines = requests.map { request in
                "Pending request id=\(request.identifier) category=\(request.content.categoryIdentifier)"
            }
            debugLog("Pending notifications callback count=\(count)")
            lines.forEach { debugLog($0) }
            DispatchQueue.main.async {
                let delegate = NSApp.delegate as? AppDelegate
                delegate?.viewModel?.log("Pending notifications count=\(count)")
                for line in lines {
                    delegate?.viewModel?.log(line)
                }
            }
        }

        center.getDeliveredNotifications { notifications in
            let count = notifications.count
            let lines = notifications.suffix(5).map { notification in
                "Delivered request id=\(notification.request.identifier) category=\(notification.request.content.categoryIdentifier)"
            }
            debugLog("Delivered notifications callback count=\(count)")
            lines.forEach { debugLog($0) }
            DispatchQueue.main.async {
                let delegate = NSApp.delegate as? AppDelegate
                delegate?.viewModel?.log("Delivered notifications count=\(count)")
                for line in lines {
                    delegate?.viewModel?.log(line)
                }
            }
        }
    }

    @MainActor
    private func presentWelcomeOverlayIfNeeded() {
        guard !didPresentWelcomeOverlay, let viewModel else { return }
        didPresentWelcomeOverlay = true
        viewModel.feedbackDeliveryMode = .overlay
        viewModel.assistantResponse = currentWelcomeMessage
        viewModel.lastFeedbackLabel = DateFormatter.localizedString(from: .now, dateStyle: .none, timeStyle: .short)
        viewModel.chatMessages = [SidekickViewModel.ChatEntry(role: .assistant, text: currentWelcomeMessage)]

        if let dashboard = NSApp.windows.first(where: { $0.title == "Sidekick" }) {
            dashboard.orderOut(nil)
        }

        OverlayWindowManager.shared.show(
            payload: SidekickViewModel.FeedbackNotificationPayload(
                title: "Sidekick",
                body: currentWelcomeMessage
            )
        )
    }

    @MainActor
    private var currentWelcomeMessage: String {
        viewModel?.welcomePrompt ?? (viewModel?.uiText("やあ、Sidekickです。", "Hey, this is Sidekick.") ?? "Hey, this is Sidekick.")
    }
}

final class SingleInstanceGuard {
    private var lockFileDescriptor: Int32 = -1

    func acquire() -> Bool {
        if lockFileDescriptor != -1 {
            return true
        }

        let path = "/tmp/sidekick.lock"
        lockFileDescriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

        guard lockFileDescriptor != -1 else {
            return true
        }

        if flock(lockFileDescriptor, LOCK_EX | LOCK_NB) == 0 {
            return true
        }

        close(lockFileDescriptor)
        lockFileDescriptor = -1
        return false
    }

    deinit {
        if lockFileDescriptor != -1 {
            flock(lockFileDescriptor, LOCK_UN)
            close(lockFileDescriptor)
        }
    }
}

private struct StatusMenuView: View {
    @ObservedObject var viewModel: SidekickViewModel
    let openDashboard: () -> Void
    let openChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.isMonitoring ? viewModel.uiText("監視中", "Monitoring") : viewModel.uiText("待機中", "Idle"))
                .font(.headline)
            Text(viewModel.assistantResponse.isEmpty ? viewModel.uiText("まだフィードバックはありません。", "No feedback yet.") : viewModel.assistantResponse)
                .font(.footnote)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button(viewModel.uiText("設定を開く", "Open Settings")) {
                viewModel.log("Menu action: open settings")
                openDashboard()
            }

            Button(viewModel.uiText("チャットを開く", "Open Chat")) {
                viewModel.log("Menu action: open chat")
                openChat()
            }

            Button(viewModel.isMonitoring ? viewModel.uiText("モニタリングを停止", "Stop Monitoring") : viewModel.uiText("モニタリングを開始", "Start Monitoring")) {
                viewModel.toggleMonitoring()
            }

            Divider()

            Button(viewModel.uiText("終了", "Quit")) {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 320)
    }
}

@MainActor
final class ChatWindowManager {
    static let shared = ChatWindowManager()

    private var controller: NSWindowController?
    private var currentViewModel: SidekickViewModel?

    func update(viewModel: SidekickViewModel) {
        currentViewModel = viewModel
    }

    func showCurrent() {
        guard let currentViewModel else {
            debugLog("ChatWindowManager.showCurrent called without a configured viewModel.")
            return
        }
        show(viewModel: currentViewModel)
    }

    func log(_ message: String) {
        debugLog(message)
        currentViewModel?.log(message)
    }

    func show(viewModel: SidekickViewModel) {
        currentViewModel = viewModel
        viewModel.log("ChatWindowManager.show called. existingWindow=\(controller?.window != nil)")
        if let window = controller?.window {
            viewModel.pauseMonitoringForChat()
            if let hostingController = window.contentViewController as? NSHostingController<ChatWindowView> {
                hostingController.rootView = ChatWindowView(viewModel: viewModel)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            viewModel.log("Reused existing chat window. visible=\(window.isVisible)")
            return
        }

        let hostingController = NSHostingController(rootView: ChatWindowView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Sidekick Chat"
        window.setContentSize(NSSize(width: 460, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let controller = NSWindowController(window: window)
        self.controller = controller

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentViewModel?.resumeMonitoringAfterChatIfNeeded()
                self?.controller = nil
            }
        }

        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        viewModel.log("Created new chat window. visible=\(window.isVisible) appWindows=\(NSApp.windows.count)")
    }
}

@MainActor
final class OverlayWindowManager {
    static let shared = OverlayWindowManager()

    private var controller: NSWindowController?
    private var currentViewModel: SidekickViewModel?
    private var currentPayload: SidekickViewModel.FeedbackNotificationPayload?

    func update(viewModel: SidekickViewModel) {
        currentViewModel = viewModel
        viewModel.shouldDelayMonitoringResumeHandler = { [weak self] in
            self?.isInteracting == true
        }
    }

    func show(payload: SidekickViewModel.FeedbackNotificationPayload) {
        guard let currentViewModel else {
            debugLog("OverlayWindowManager.show called without configured viewModel.")
            return
        }

        currentPayload = payload
        if !currentViewModel.isOverlayChatExpanded {
            currentViewModel.overlayMessageHeight = messageHeight(for: payload.body)
        }
        currentViewModel.log("OverlayWindowManager.show called.")
        let contentView = OverlayFeedbackView(
            viewModel: currentViewModel,
            title: "Sidekick",
            message: payload.body,
            resizeForChatState: { [weak self] isExpanded in
                self?.resize(isExpanded: isExpanded)
            },
            closeOverlay: {
                NSApp.terminate(nil)
            }
        )

        if let window = controller?.window,
           let hostingController = window.contentViewController as? NSHostingController<OverlayFeedbackView> {
            hostingController.rootView = contentView
            applyAppearance(to: window, viewModel: currentViewModel)
            if !currentViewModel.isOverlayChatExpanded {
                resize(isExpanded: false)
            }
            if !window.isVisible {
                position(window: window)
                window.orderFrontRegardless()
            }
            return
        }

        let hostingController = NSHostingController(rootView: contentView)
        let panel = NSPanel(contentViewController: hostingController)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.minSize = NSSize(width: 320, height: 220)
        applyAppearance(to: panel, viewModel: currentViewModel)
        panel.setContentSize(collapsedSize(for: currentViewModel))

        let controller = NSWindowController(window: panel)
        self.controller = controller
        position(window: panel)
        controller.showWindow(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        if currentViewModel?.isOverlayChatExpanded == true {
            currentViewModel?.isOverlayChatExpanded = false
            currentViewModel?.resumeMonitoringAfterChatIfNeeded()
        }
        controller?.window?.orderOut(nil)
    }

    func refreshAppearance() {
        guard let window = controller?.window, let currentViewModel else { return }
        applyAppearance(to: window, viewModel: currentViewModel)
    }

    private var isInteracting: Bool {
        guard let window = controller?.window else { return false }
        return window.isVisible && (window.isKeyWindow || window.isMainWindow)
    }

    private func position(window: NSWindow) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let origin = NSPoint(
            x: visible.maxX - size.width - 24,
            y: visible.maxY - size.height - 24
        )
        window.setFrameOrigin(origin)
    }

    private func collapsedSize(for viewModel: SidekickViewModel) -> NSSize {
        let messageHeight = CGFloat(viewModel.overlayMessageHeight)
        let totalHeight = max(210, min(460, messageHeight + 56))
        return NSSize(width: 420, height: totalHeight)
    }

    private var expandedSize: NSSize {
        NSSize(width: 420, height: 700)
    }

    private func resize(isExpanded: Bool) {
        guard let window = controller?.window, let currentViewModel else { return }
        let collapsed = collapsedSize(for: currentViewModel)
        let targetSize = isExpanded
            ? NSSize(width: window.frame.width, height: expandedSize.height)
            : NSSize(width: window.frame.width, height: collapsed.height)
        var frame = window.frame
        let deltaHeight = targetSize.height - frame.size.height
        frame.origin.y -= deltaHeight
        frame.size = targetSize
        window.setFrame(frame, display: true, animate: false)
        applyAppearance(to: window, viewModel: currentViewModel)
    }

    private func applyAppearance(to window: NSWindow, viewModel: SidekickViewModel) {
        window.alphaValue = CGFloat(viewModel.overlayOpacity)
    }

    private func messageHeight(for message: String) -> Double {
        let width: CGFloat = 420 - 68
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let rect = (message as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        let lineHeight = font.ascender - font.descender + font.leading
        let estimatedLineCount = max(1, Int(round(rect.height / max(lineHeight, 1))))
        let basePadding: Double
        switch estimatedLineCount {
        case 1...2:
            basePadding = 8
        case 3...4:
            basePadding = 14
        default:
            basePadding = 24
        }
        let estimated = ceil(rect.height) + basePadding
        return max(72, min(300, estimated))
    }
}
