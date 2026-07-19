import Foundation

enum SidekickError: LocalizedError {
    case invalidEndpoint
    case unsupportedEndpointScheme
    case insecureRemoteEndpoint
    case endpointCredentialsNotAllowed
    case remoteFailure(String)
    case capturePermissionDenied
    case displayNotFound
    case windowNotFound
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "LM Studio endpoint URL is invalid."
        case .unsupportedEndpointScheme:
            return "The endpoint must use HTTP or HTTPS."
        case .insecureRemoteEndpoint:
            return "HTTP is allowed only for localhost. Use HTTPS for remote endpoints."
        case .endpointCredentialsNotAllowed:
            return "Do not include credentials in the endpoint URL."
        case .remoteFailure(let body):
            return "LM Studio request failed: \(body)"
        case .capturePermissionDenied:
            return "Screen Recording permission was denied. Enable it in System Settings > Privacy & Security > Screen Recording."
        case .displayNotFound:
            return "No capturable display was found."
        case .windowNotFound:
            return "The frontmost window could not be identified for capture."
        case .pngEncodingFailed:
            return "Failed to encode the captured image."
        }
    }
}
