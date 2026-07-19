import Foundation
import XCTest
@testable import SidekickApp

final class LogStoreTests: XCTestCase {
    func testCreatesPrivateLogAndRotatesIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LogStore(directoryURL: root, maxBytes: 10)

        store.append(line: "123456789")
        store.append(line: "next")

        let current = root.appendingPathComponent("sidekick.log")
        let rotated = root.appendingPathComponent("sidekick.log.1")
        XCTAssertEqual(try String(contentsOf: current, encoding: .utf8), "next\n")
        XCTAssertEqual(try String(contentsOf: rotated, encoding: .utf8), "123456789\n")

        let directoryMode = try posixMode(at: root)
        let fileMode = try posixMode(at: current)
        XCTAssertEqual(directoryMode, 0o700)
        XCTAssertEqual(fileMode, 0o600)
    }

    func testDoesNotFollowSymlinkAtLogPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = root.appendingPathComponent("destination.txt")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("unchanged".utf8).write(to: destination)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("sidekick.log"),
            withDestinationURL: destination
        )

        LogStore(directoryURL: root).append(line: "secret")

        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "unchanged")
    }

    func testDoesNotFollowDanglingSymlinkAtLogPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let destination = root.appendingPathComponent("missing.txt")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("sidekick.log"),
            withDestinationURL: destination
        )

        LogStore(directoryURL: root).append(line: "secret")

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    private func posixMode(at url: URL) throws -> Int {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.posixPermissions] as? NSNumber)?.intValue ?? -1
    }
}
