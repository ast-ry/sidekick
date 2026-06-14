import Foundation

func debugLog(_ line: String) {
    print("SidekickLog \(line)")
    LogStore.shared.append(line: line)
}

struct LogStore {
    static let shared = LogStore()

    private let urls: [URL]

    init() {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("Logs/Sidekick", isDirectory: true)
        var collected: [URL] = []
        if let dir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            collected.append(dir.appendingPathComponent("sidekick.log"))
        }
        collected.append(URL(fileURLWithPath: "/tmp/sidekick.log"))
        urls = collected
    }

    func append(line: String) {
        let data = Data((line + "\n").utf8)

        for url in urls {
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: url.path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url)
            }
        }
    }
}
