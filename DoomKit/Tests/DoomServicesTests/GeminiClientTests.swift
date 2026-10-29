import Testing
import Foundation
@testable import DoomCore
@testable import DoomServices

private final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("StubURLProtocol.requestHandler was not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeTestClient(endpoint: URL = GeminiConfiguration.endpoint) -> GeminiClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    return GeminiClient(session: session, endpoint: endpoint)
}

private func makeSampleRequest(text: String = "Hello Gemini") -> GenerationRequest {
    let selectedText = SelectedText(
        value: text,
        characterCount: text.count,
        source: SourceApplication(localizedName: "Safari", bundleIdentifier: "com.apple.Safari"),
        method: .accessibility
    )
    return GenerationRequest.make(text: selectedText)
}

private func extractBodyData(from request: URLRequest) -> Data {
    if let data = request.httpBody {
        return data
    }
    guard let stream = request.httpBodyStream else {
        return Data()
    }
    stream.open()
    defer { stream.close() }
    var result = Data()
    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read > 0 {
            result.append(buffer, count: read)
        } else {
            break
        }
    }
    return result
}

private let validAPIKey = APIKey(validating: "TEST-KEY-1234567890abcdefghijklmnopqrst")!

@Suite("GeminiClient Tests", .serialized)
struct GeminiClientTests {

    @Test("GEMINI-01 & GEMINI-02 & GEMINI-03: Request shape, headers, and metadata exclusion")
    func requestShapeAndExclusion() async throws {
        final class RequestBox: @unchecked Sendable {
            var request: URLRequest?
            var bodyData: Data?
        }
        let box = RequestBox()

        StubURLProtocol.requestHandler = { req in
            box.request = req
            box.bodyData = extractBodyData(from: req)
            let json = """
            {
              "id": "int-123",
              "status": "completed",
              "steps": [
                {
                  "type": "model_output",
                  "content": [
                    { "type": "text", "text": "This is the response." }
                  ]
                }
              ]
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        let request = makeSampleRequest(text: "Secret user text")
        let result = try await client.respond(to: request, apiKey: validAPIKey)

        #expect(result.text == "This is the response.")
        guard let req = box.request, let bodyData = box.bodyData else {
            Issue.record("Request or body data not intercepted")
            return
        }

        // GEMINI-01: Correct endpoint and method
        #expect(req.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/interactions")
        #expect(req.httpMethod == "POST")

        // GEMINI-02: Key strictly in x-goog-api-key header; absent from URL and body
        #expect(req.value(forHTTPHeaderField: "x-goog-api-key") == validAPIKey.accessKey())
        #expect(req.url?.query == nil)

        // GEMINI-03: Body contains only allowed keys
        let bodyString = String(data: bodyData, encoding: .utf8) ?? ""
        #expect(!bodyString.contains(validAPIKey.accessKey()))
        #expect(!bodyString.contains("Safari"))
        #expect(!bodyString.contains("com.apple.Safari"))

        guard let jsonDict = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            Issue.record("Body is not a JSON dictionary")
            return
        }
        let keys = Set(jsonDict.keys)
        let allowedKeys: Set<String> = ["model", "input", "system_instruction", "generation_config", "store", "stream"]
        #expect(keys == allowedKeys)

        // Verification of store: false, stream: false, temperature omitted
        #expect(jsonDict["store"] as? Bool == false)
        #expect(jsonDict["stream"] as? Bool == false)
        #expect(jsonDict["temperature"] == nil)

        let genConfig = jsonDict["generation_config"] as? [String: Any]
        #expect(genConfig?["thinking_level"] as? String == "low")
        #expect(genConfig?["max_output_tokens"] as? Int == 4096)
        #expect(genConfig?["temperature"] == nil)
    }

    @Test("GEMINI-09: Parsing extracts last model_output step and ignores thought steps")
    func parseMultipleSteps() async throws {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "id": "int-456",
              "status": "completed",
              "steps": [
                {
                  "type": "thought",
                  "content": [
                    { "type": "text", "text": "Thinking internal thoughts..." }
                  ]
                },
                {
                  "type": "model_output",
                  "content": [
                    { "type": "text", "text": "Intermediate draft" }
                  ]
                },
                {
                  "type": "thought",
                  "content": [
                    { "type": "text", "text": "Refining answer..." }
                  ]
                },
                {
                  "type": "model_output",
                  "content": [
                    { "type": "text", "text": "Final concise " },
                    { "type": "text", "text": "explanation." }
                  ]
                }
              ],
              "usage": {
                "total_input_tokens": 12,
                "total_output_tokens": 8,
                "total_thought_tokens": 20,
                "total_tokens": 40
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        let result = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)

        #expect(result.text == "Final concise explanation.")
        #expect(result.isTruncated == false)
        #expect(result.usage?.totalInputTokens == 12)
        #expect(result.usage?.totalOutputTokens == 8)
        #expect(result.usage?.totalThoughtTokens == 20)
        #expect(result.usage?.totalTokens == 40)
    }

    @Test("GEMINI-10: URLError.timedOut maps to GenerationError.timedOut")
    func timeoutMapping() async {
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected timeout error")
        } catch {
            #expect(error == .timedOut)
        }
    }

    @Test("GEMINI-11: Response body exceeding 2 MB throws malformedResponse")
    func responseOver2MBThrows() async {
        StubURLProtocol.requestHandler = { req in
            let largeData = Data(repeating: UInt8(ascii: "A"), count: 2 * 1024 * 1024 + 1)
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, largeData)
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected malformedResponse for > 2 MB payload")
        } catch {
            #expect(error == .malformedResponse)
        }
    }

    @Test("GEMINI-13: URLError.notConnectedToInternet maps to GenerationError.offline")
    func offlineMapping() async {
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected offline error")
        } catch {
            #expect(error == .offline)
        }
    }

    @Test("GEMINI-14: Network connection lost maps to GenerationError.transport")
    func transportMapping() async {
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.networkConnectionLost)
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected transport error")
        } catch {
            if case .transport(let code) = error {
                #expect(code == URLError.networkConnectionLost.rawValue)
            } else {
                Issue.record("Expected .transport, got \(error)")
            }
        }
    }

    @Test("GEMINI-15: 429 rate limit with Retry-After header maps to rateLimited(retryAfter:)")
    func rateLimitWithRetryAfter() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "rate_limit_exceeded",
                "message": "Resource has been exhausted"
              }
            }
            """
            let headers = ["Retry-After": "25"]
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: headers)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected rateLimited error")
        } catch {
            #expect(error == .rateLimited(retryAfter: .seconds(25)))
        }
    }

    @Test("GEMINI-16: 429 quota_exceeded maps to quotaExceeded")
    func quotaExceededMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "quota_exceeded",
                "message": "Quota limit reached"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected quotaExceeded error")
        } catch {
            #expect(error == .quotaExceeded)
        }
    }

    @Test("GEMINI-17: 401 maps to invalidAPIKey")
    func invalidAPIKeyMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "authentication",
                "message": "API key not valid"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected invalidAPIKey error")
        } catch {
            #expect(error == .invalidAPIKey)
        }
    }

    @Test("GEMINI-18: 403 maps to permissionDenied")
    func permissionDeniedMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "permission_denied",
                "message": "Permission denied"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected permissionDenied error")
        } catch {
            #expect(error == .permissionDenied)
        }
    }

    @Test("GEMINI-19: 404 maps to modelNotFound")
    func modelNotFoundMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "model_not_found",
                "message": "Model not found"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected modelNotFound error")
        } catch {
            #expect(error == .modelNotFound)
        }
    }

    @Test("GEMINI-20: 400 failed_precondition maps to unavailableForAccount")
    func failedPreconditionMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "failed_precondition",
                "message": "Precondition failed"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected unavailableForAccount error")
        } catch {
            #expect(error == .unavailableForAccount)
        }
    }

    @Test("GEMINI-21: 402 maps to paymentRequired")
    func paymentRequiredMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "payment_required",
                "message": "Payment required"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 402, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected paymentRequired error")
        } catch {
            #expect(error == .paymentRequired)
        }
    }

    @Test("GEMINI-22: 500, 503, 504 map to server(status:)")
    func serverErrorsMapping() async {
        for code in [500, 503, 504] {
            StubURLProtocol.requestHandler = { req in
                let json = """
                {
                  "error": {
                    "code": "api_error",
                    "message": "Internal error"
                  }
                }
                """
                let resp = HTTPURLResponse(url: req.url!, statusCode: code, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            }

            let client = makeTestClient()
            do {
                _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
                Issue.record("Expected server error for status \(code)")
            } catch {
                #expect(error == .server(status: code))
            }
        }
    }

    @Test("GEMINI-23: Blocked safety/recitation codes map to blocked(reason:)")
    func blockedCodesMapping() async {
        let cases: [(String, BlockReason)] = [
            ("safety", .safety),
            ("recitation", .recitation),
            ("prohibited_content", .prohibitedContent),
            ("spii", .spii),
            ("blocklist", .blocklist),
            ("language", .language),
            ("content_blocked", .other)
        ]

        for (codeStr, reason) in cases {
            StubURLProtocol.requestHandler = { req in
                let json = """
                {
                  "error": {
                    "code": "\(codeStr)",
                    "message": "Content blocked"
                  }
                }
                """
                let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data(json.utf8))
            }

            let client = makeTestClient()
            do {
                _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
                Issue.record("Expected blocked error for code \(codeStr)")
            } catch {
                #expect(error == .blocked(reason: reason))
            }
        }
    }

    @Test("GEMINI-24: Empty text output throws emptyResponse")
    func emptyResponseOutput() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "id": "int-789",
              "status": "completed",
              "steps": [
                {
                  "type": "model_output",
                  "content": [
                    { "type": "text", "text": "   " }
                  ]
                }
              ]
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected emptyResponse error")
        } catch {
            #expect(error == .emptyResponse)
        }
    }

    @Test("GEMINI-24: Malformed JSON throws malformedResponse")
    func malformedJSONResponse() async {
        StubURLProtocol.requestHandler = { req in
            let garbage = "Not valid JSON at all"
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(garbage.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected malformedResponse error")
        } catch {
            #expect(error == .malformedResponse)
        }
    }

    @Test("GEMINI-27: HTTP 400 with API_KEY_INVALID detail maps to invalidAPIKey")
    func invalidAPIKeyDetailsMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": 400,
                "message": "API key not valid. Please pass a valid API key.",
                "status": "INVALID_ARGUMENT",
                "details": [
                  {
                    "@type": "type.googleapis.com/google.rpc.ErrorInfo",
                    "reason": "API_KEY_INVALID"
                  }
                ]
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected invalidAPIKey error")
        } catch {
            #expect(error == .invalidAPIKey)
        }
    }

    @Test("GEMINI-28: HTTP 429 with RESOURCE_EXHAUSTED maps to quotaExceeded")
    func rateLimitResourceExhaustedMapping() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": 429,
                "message": "Resource exhausted",
                "status": "RESOURCE_EXHAUSTED"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected quotaExceeded error")
        } catch {
            #expect(error == .quotaExceeded)
        }
    }

    @Test("GEMINI-29: URLError.cancelled and Task cancellation throw GenerationError.cancelled")
    func cancellationMapping() async {
        // In-flight URLError.cancelled
        StubURLProtocol.requestHandler = { _ in
            throw URLError(.cancelled)
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected cancelled error")
        } catch {
            #expect(error == .cancelled)
        }

        // Pre-cancelled task
        let preCancelledTask = Task {
            try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
        }
        preCancelledTask.cancel()
        do {
            _ = try await preCancelledTask.value
            Issue.record("Expected cancelled error for pre-cancelled task")
        } catch let err as GenerationError {
            #expect(err == .cancelled)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("GEMINI-30: Interaction status == 'failed' throws malformedResponse")
    func interactionStatusFailedThrows() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "id": "int-fail",
              "status": "failed"
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected malformedResponse error")
        } catch {
            #expect(error == .malformedResponse)
        }
    }

    @Test("GEMINI-31: HTTP 503 with service_unavailable payload maps to server(status: 503) and captures diagnostics")
    func serviceUnavailableHighDemandMapping() async {
        let expectedMsg = "gemini-3.8-flash is currently experiencing high demand, spikes in demand are usually temporary. Please try again later."
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": "service_unavailable",
                "message": "\(expectedMsg)"
              }
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected server(status: 503) error")
        } catch {
            #expect(error == .server(status: 503))
            if case .server(let status, let code, let msg) = error {
                #expect(status == 503)
                #expect(code == "service_unavailable")
                #expect(msg == expectedMsg)
            } else {
                Issue.record("Expected .server case with associated values")
            }
        }

        let diag = client.lastDiagnostics
        #expect(diag != nil)
        #expect(diag?.httpStatusCode == 503)
        #expect(diag?.parsedGoogleErrorFormat == true)
        #expect(diag?.sanitizedProviderErrorCode == "service_unavailable")
        #expect(diag?.sanitizedProviderErrorMessage == expectedMsg)
    }

    @Test("HARDEN-04: HTTP 429 parses lowercase retry-after header correctly")
    func testCaseInsensitiveRetryAfterHeader() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": 429,
                "message": "Resource exhausted",
                "status": "RESOURCE_EXHAUSTED"
              }
            }
            """
            // Send lowercase "retry-after" as commonly emitted by HTTP/2 proxies
            let headers = ["retry-after": "7"]
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: "HTTP/2", headerFields: headers)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected quotaExceeded error")
        } catch {
            #expect(error == .quotaExceeded)
        }

        // Test with non-quota rate limit to check retryAfter duration parsing
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "error": {
                "code": 429,
                "message": "Too many requests",
                "status": "RATE_LIMIT_EXCEEDED"
              }
            }
            """
            let headers = ["retry-after": "7"]
            let resp = HTTPURLResponse(url: req.url!, statusCode: 429, httpVersion: "HTTP/2", headerFields: headers)!
            return (resp, Data(json.utf8))
        }

        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected rateLimited error")
        } catch {
            #expect(error == .rateLimited(retryAfter: .seconds(7)))
        }
    }

    @Test("HARDEN-05: Proxy or gateway string error payload parsed without decoding error")
    func testProxyStringErrorPayload() async {
        StubURLProtocol.requestHandler = { req in
            let json = """
            {
              "message": "Bad Gateway from upstream proxy"
            }
            """
            let resp = HTTPURLResponse(url: req.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!
            return (resp, Data(json.utf8))
        }

        let client = makeTestClient()
        do {
            _ = try await client.respond(to: makeSampleRequest(), apiKey: validAPIKey)
            Issue.record("Expected server(status: 502) error")
        } catch {
            #expect(error == .server(status: 502))
        }

        let diag = client.lastDiagnostics
        #expect(diag?.httpStatusCode == 502)
        #expect(diag?.sanitizedProviderErrorMessage == "Bad Gateway from upstream proxy")
    }
}

