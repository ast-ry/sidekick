import XCTest
@testable import SidekickApp

final class EndpointSecurityPolicyTests: XCTestCase {
    func testAllowsLoopbackHTTP() throws {
        let url = try EndpointSecurityPolicy.validatedURL(
            from: "http://127.0.0.1:1234/v1",
            format: .chatCompletions
        )

        XCTAssertEqual(url.absoluteString, "http://127.0.0.1:1234/v1/chat/completions")
    }

    func testAllowsIPv6LoopbackHTTP() throws {
        let url = try EndpointSecurityPolicy.validatedURL(
            from: "http://[::1]:1234/v1/chat/completions",
            format: .responses
        )

        XCTAssertEqual(url.absoluteString, "http://[::1]:1234/v1/responses")
    }

    func testRejectsRemoteHTTP() {
        XCTAssertThrowsError(
            try EndpointSecurityPolicy.validatedURL(
                from: "http://example.com/v1/chat/completions",
                format: .chatCompletions
            )
        ) { error in
            guard case SidekickError.insecureRemoteEndpoint = error else {
                return XCTFail("Expected insecureRemoteEndpoint, got \(error)")
            }
        }
    }

    func testAllowsRemoteHTTPS() throws {
        let url = try EndpointSecurityPolicy.validatedURL(
            from: "https://example.com/v1/responses",
            format: .chatCompletions
        )

        XCTAssertEqual(url.absoluteString, "https://example.com/v1/chat/completions")
    }

    func testRejectsEmbeddedCredentials() {
        XCTAssertThrowsError(
            try EndpointSecurityPolicy.validatedURL(
                from: "https://user:password@example.com/v1/responses",
                format: .responses
            )
        ) { error in
            guard case SidekickError.endpointCredentialsNotAllowed = error else {
                return XCTFail("Expected endpointCredentialsNotAllowed, got \(error)")
            }
        }
    }

    func testRejectsUnsupportedScheme() {
        XCTAssertThrowsError(
            try EndpointSecurityPolicy.validatedURL(
                from: "ftp://example.com/v1/responses",
                format: .responses
            )
        ) { error in
            guard case SidekickError.unsupportedEndpointScheme = error else {
                return XCTFail("Expected unsupportedEndpointScheme, got \(error)")
            }
        }
    }
}
