import Foundation

func debugLog(_ line: String) {
    print("SidekickLog \(line)")
    LogStore.shared.append(line: line)
}

final class LogStore: @unchecked Sendable {
    static let shared = LogStore()

    private let fileManager: FileManager
    private let directoryURL: URL?
    private let maxBytes: Int
    private let lock = NSLock()

    init(directoryURL: URL? = nil, maxBytes: Int = 1_048_576, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.maxBytes = maxBytes
        self.directoryURL = directoryURL ?? fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/Sidekick", isDirectory: true)
    }

    func append(line: String) {
        guard let directoryURL else { return }
        let data = Data((line + "\n").utf8)

        lock.lock()
        defer { lock.unlock() }

        do {
            try prepareDirectory(directoryURL)
            let logURL = directoryURL.appendingPathComponent("sidekick.log")
            try rotateIfNeeded(logURL, incomingBytes: data.count)
            guard try prepareLogFile(logURL) else { return }

            let handle = try FileHandle(forWritingTo: logURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            print("SidekickLog Failed to write application log: \(error.localizedDescription)")
        }
    }

    private func prepareDirectory(_ url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func prepareLogFile(_ url: URL) throws -> Bool {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else { return false }
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return fileManager.createFile(
                atPath: url.path,
                contents: nil,
                attributes: [.posixPermissions: 0o600]
            )
        }
    }

    private func rotateIfNeeded(_ url: URL, incomingBytes: Int) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber,
              size.intValue + incomingBytes > maxBytes else {
            return
        }

        let rotatedURL = url.appendingPathExtension("1")
        if fileManager.fileExists(atPath: rotatedURL.path) {
            try fileManager.removeItem(at: rotatedURL)
        }
        try fileManager.moveItem(at: url, to: rotatedURL)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: rotatedURL.path)
    }
}
