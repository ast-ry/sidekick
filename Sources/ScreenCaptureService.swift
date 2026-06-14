import AppKit
import CoreGraphics
import ScreenCaptureKit
import Vision

enum ScreenCaptureService {
    struct CaptureResult {
        let image: NSImage
        let cgImage: CGImage
        let pngData: Data
    }

    static func capture(scope: SidekickViewModel.CaptureScope, frontmostApplicationPID: pid_t?) async throws -> CaptureResult {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw SidekickError.capturePermissionDenied
        }

        let cgImage: CGImage

        do {
            switch scope {
            case .frontmostWindow:
                cgImage = try await captureFrontmostWindow(frontmostApplicationPID: frontmostApplicationPID)
            case .mainDisplay:
                cgImage = try await captureMainDisplay()
            }
        } catch {
            guard let fallbackImage = CGDisplayCreateImage(CGMainDisplayID()) else {
                throw error
            }
            cgImage = fallbackImage
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            throw SidekickError.pngEncodingFailed
        }

        return CaptureResult(
            image: NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)),
            cgImage: cgImage,
            pngData: pngData
        )
    }

    private static func captureFrontmostWindow(frontmostApplicationPID: pid_t?) async throws -> CGImage {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let targetWindow = preferredWindow(from: availableContent.windows, frontmostApplicationPID: frontmostApplicationPID) else {
            throw SidekickError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: targetWindow)
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(targetWindow.frame.width), 1)
        configuration.height = max(Int(targetWindow.frame.height), 1)
        configuration.showsCursor = true

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private static func captureMainDisplay() async throws -> CGImage {
        let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = availableContent.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? availableContent.displays.first else {
            throw SidekickError.displayNotFound
        }

        let excludedApplications = availableContent.applications.filter { application in
            application.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(display: display, excludingApplications: excludedApplications, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(display.width)
        configuration.height = Int(display.height)
        configuration.showsCursor = true

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private static func preferredWindow(from windows: [SCWindow], frontmostApplicationPID: pid_t?) -> SCWindow? {
        let candidateWindows = windows.filter { window in
            guard window.isOnScreen else { return false }
            guard window.frame.width > 32, window.frame.height > 32 else { return false }
            if let frontmostApplicationPID {
                return window.owningApplication?.processID == frontmostApplicationPID
            }
            return true
        }

        return candidateWindows.max { lhs, rhs in
            lhs.frame.width * lhs.frame.height < rhs.frame.width * rhs.frame.height
        }
    }
}

enum OCRService {
    static func extractText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum ImageFingerprint {
    static func hash(for image: CGImage) -> UInt64 {
        let width = 8
        let height = 8
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return 0
        }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var grays: [UInt8] = []
        grays.reserveCapacity(width * height)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index])
            let green = Double(pixels[index + 1])
            let blue = Double(pixels[index + 2])
            let luminance = UInt8((0.299 * red) + (0.587 * green) + (0.114 * blue))
            grays.append(luminance)
        }

        let total = grays.reduce(into: 0) { partialResult, value in
            partialResult += Int(value)
        }
        let average = Double(total) / Double(grays.count)
        var hash: UInt64 = 0

        for value in grays {
            hash <<= 1
            if Double(value) >= average {
                hash |= 1
            }
        }

        return hash
    }

    static func hammingDistance(lhs: UInt64, rhs: UInt64) -> Int {
        Int((lhs ^ rhs).nonzeroBitCount)
    }
}
