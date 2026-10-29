import Foundation
import DoomCore
import OSLog
import os

private let logger = Logger(subsystem: "doom", category: "gemini")

public struct RequestDiagnosticReport: Sendable, Equatable {
    public let startTimestamp: String
    public let completionTimestamp: String
    public let endpoint: String
    public let operation: String
    public let model: String
    public let httpStatusCode: Int?
    public let parsedGoogleErrorFormat: Bool
    public let sanitizedProviderErrorCode: String?
    public let sanitizedProviderErrorMessage: String?
    public let internalErrorCase: String

    public init(
        startTimestamp: String,
        completionTimestamp: String,
        endpoint: String,
        operation: String,
        model: String,
        httpStatusCode: Int?,
        parsedGoogleErrorFormat: Bool,
        sanitizedProviderErrorCode: String?,
        sanitizedProviderErrorMessage: String?,
        internalErrorCase: String
    ) {
        self.startTimestamp = startTimestamp
        self.completionTimestamp = completionTimestamp
        self.endpoint = endpoint
        self.operation = operation
        self.model = model
        self.httpStatusCode = httpStatusCode
        self.parsedGoogleErrorFormat = parsedGoogleErrorFormat
        self.sanitizedProviderErrorCode = sanitizedProviderErrorCode
        self.sanitizedProviderErrorMessage = sanitizedProviderErrorMessage
        self.internalErrorCase = internalErrorCase
    }
}

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        // SEC-10: Disallow all redirects to prevent credential leakage to unintended hosts
        completionHandler(nil)
    }
}

public final class GeminiClient: AIResponding, Sendable {
    private let session: URLSession
    private let endpoint: URL
    private let _lastDiagnostics = OSAllocatedUnfairLock<RequestDiagnosticReport?>(initialState: nil)

    public var lastDiagnostics: RequestDiagnosticReport? {
        _lastDiagnostics.withLock { $0 }
    }

    private func recordDiagnostics(_ report: RequestDiagnosticReport) {
        _lastDiagnostics.withLock { $0 = report }
    }

    public static let maxResponseBodyBytes = 2 * 1024 * 1024 // 2 MB cap (GEMINI-11)

    public init(
        session: URLSession? = nil,
        endpoint: URL = GeminiConfiguration.endpoint
    ) {
        self.endpoint = endpoint
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.httpCookieStorage = nil
            config.urlCredentialStorage = nil
            config.httpShouldSetCookies = false
            config.timeoutIntervalForRequest = 60.0
            config.timeoutIntervalForResource = 60.0
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        }
    }

    public func respond(to request: GenerationRequest, apiKey: APIKey) async throws(GenerationError) -> GenerationResult {
        let t0 = Date()
        logger.notice("Gemini request started with model: \(request.model.rawValue, privacy: .public)")

        // Check cancellation before network call
        if Task.isCancelled {
            logger.notice("Gemini request cancelled before dispatch")
            throw GenerationError.cancelled
        }

        // 1. Construct Wire Request
        let wirePayload = InteractionWireRequest(
            model: request.model.rawValue,
            input: request.text.value,
            systemInstruction: request.systemInstruction,
            generationConfig: InteractionWireRequest.GenerationConfig(
                thinkingLevel: request.thinkingLevel.rawValue,
                maxOutputTokens: request.maxOutputTokens
            ),
            store: false,
            stream: false
        )

        let requestBody: Data
        do {
            requestBody = try JSONEncoder().encode(wirePayload)
        } catch {
            logger.error("Failed to encode request payload")
            throw GenerationError.badRequest(code: "encoding_failed")
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        // GEMINI-02: Key strictly placed in x-goog-api-key header; never in URL or body
        urlRequest.setValue(apiKey.accessKey(), forHTTPHeaderField: "x-goog-api-key")
        urlRequest.httpBody = requestBody

        // 2. Perform Network Call
        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (data, rawResponse) = try await session.data(for: urlRequest)
            guard let http = rawResponse as? HTTPURLResponse else {
                let elapsed = Date().timeIntervalSince(t0)
                logger.error("Transport returned non-HTTP response after \(String(format: "%.3f", elapsed))s")
                throw GenerationError.transport(code: -1)
            }
            responseData = data
            httpResponse = http
        } catch let urlError as URLError {
            let tEnd = Date()
            let elapsed = tEnd.timeIntervalSince(t0)
            let stage: String
            switch urlError.code {
            case .cancelled:
                stage = "cancelled"
            case .timedOut:
                stage = "timeout"
            case .notConnectedToInternet:
                stage = "connection/DNS"
            case .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted, .clientCertificateRejected:
                stage = "TLS handshake"
            default:
                stage = "transport"
            }
            let mappedError: GenerationError
            let failureCategory: String
            if urlError.code == .cancelled {
                mappedError = .cancelled
                failureCategory = "cancellation"
                logger.notice("Gemini request cancelled in flight: elapsed=\(String(format: "%.3f", elapsed))s")
            } else if urlError.code == .timedOut {
                mappedError = .timedOut
                failureCategory = "timeout"
                logger.error("Gemini request timed out: stage=\(stage, privacy: .public), origin=URLSession.timeoutIntervalForRequest(60s), elapsed=\(String(format: "%.3f", elapsed))s")
            } else if urlError.code == .notConnectedToInternet {
                mappedError = .offline
                failureCategory = "network failure (offline)"
                logger.error("Gemini request offline: stage=\(stage, privacy: .public), code=\(urlError.errorCode), elapsed=\(String(format: "%.3f", elapsed))s")
            } else if urlError.code == .secureConnectionFailed || urlError.code == .serverCertificateHasBadDate || urlError.code == .serverCertificateUntrusted || urlError.code == .clientCertificateRejected {
                mappedError = .transport(code: urlError.errorCode)
                failureCategory = "TLS handshake failure"
                logger.error("Gemini TLS error: stage=\(stage, privacy: .public), code=\(urlError.errorCode), elapsed=\(String(format: "%.3f", elapsed))s")
            } else {
                mappedError = .transport(code: urlError.errorCode)
                failureCategory = "network transport failure (\(urlError.errorCode))"
                logger.error("Gemini transport error: stage=\(stage, privacy: .public), code=\(urlError.errorCode), elapsed=\(String(format: "%.3f", elapsed))s")
            }

            let startISO = ISO8601DateFormatter().string(from: t0)
            let endISO = ISO8601DateFormatter().string(from: tEnd)
            let diag = RequestDiagnosticReport(
                startTimestamp: startISO,
                completionTimestamp: endISO,
                endpoint: endpoint.absoluteString,
                operation: "POST interactions (stateless)",
                model: request.model.rawValue,
                httpStatusCode: nil,
                parsedGoogleErrorFormat: false,
                sanitizedProviderErrorCode: failureCategory,
                sanitizedProviderErrorMessage: "Transport stage: \(stage)",
                internalErrorCase: String(describing: mappedError)
            )
            recordDiagnostics(diag)
            throw mappedError
        } catch {
            let tEnd = Date()
            let elapsed = tEnd.timeIntervalSince(t0)
            let startISO = ISO8601DateFormatter().string(from: t0)
            let endISO = ISO8601DateFormatter().string(from: tEnd)
            let mappedError = GenerationError.transport(code: -1)
            let diag = RequestDiagnosticReport(
                startTimestamp: startISO,
                completionTimestamp: endISO,
                endpoint: endpoint.absoluteString,
                operation: "POST interactions (stateless)",
                model: request.model.rawValue,
                httpStatusCode: nil,
                parsedGoogleErrorFormat: false,
                sanitizedProviderErrorCode: "unexpected_transport_error",
                sanitizedProviderErrorMessage: "Unexpected error during transport",
                internalErrorCase: String(describing: mappedError)
            )
            recordDiagnostics(diag)
            logger.error("Unexpected error during Gemini transport after \(String(format: "%.3f", elapsed))s")
            throw mappedError
        }

        let elapsed = Date().timeIntervalSince(t0)

        // 3. Response Size Guard (2 MB ceiling)
        if responseData.count > Self.maxResponseBodyBytes {
            logger.error("Response body exceeded 2 MB cap: \(responseData.count) bytes")
            throw GenerationError.malformedResponse
        }

        // Check cancellation after receiving response
        if Task.isCancelled {
            logger.notice("Gemini request cancelled after network reception")
            throw GenerationError.cancelled
        }

        let statusCode = httpResponse.statusCode

        // 4. Handle HTTP Status Codes
        if statusCode == 200 {
            do {
                let responseObj = try JSONDecoder().decode(InteractionWireResponse.self, from: responseData)

                // Check if response contains an error block or status == "failed"
                if let errPayload = responseObj.error {
                    let sanitizedMsg = sanitizeErrorMessage(errPayload.message)
                    let err = mapErrorCode(code: errPayload.codeString, message: sanitizedMsg, statusCode: 200, headers: httpResponse.allHeaderFields)
                    logger.error("Gemini 200 response contained error: \(errPayload.codeString ?? "unknown")")
                    throw err
                }

                if responseObj.status == "failed" {
                    logger.error("Gemini interaction failed with status 'failed'")
                    throw GenerationError.malformedResponse
                }

                // Extract output text from the LAST step of type "model_output"
                guard let steps = responseObj.steps else {
                    logger.error("Gemini response missing steps")
                    throw GenerationError.malformedResponse
                }

                guard let lastOutputStep = steps.last(where: { $0.type == "model_output" }) else {
                    logger.error("Gemini response missing model_output step")
                    throw GenerationError.emptyResponse
                }

                let textParts: [String] = (lastOutputStep.content ?? [])
                    .filter { $0.type == "text" }
                    .compactMap { $0.text }

                let fullText = textParts.joined()
                let trimmedText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmedText.isEmpty else {
                    logger.error("Gemini response produced empty text output")
                    throw GenerationError.emptyResponse
                }

                let isTruncated = (responseObj.status == "incomplete")
                let usage = responseObj.usage.map {
                    TokenUsage(
                        totalInputTokens: $0.totalInputTokens ?? 0,
                        totalOutputTokens: $0.totalOutputTokens ?? 0,
                        totalThoughtTokens: $0.totalThoughtTokens ?? 0,
                        totalTokens: $0.totalTokens ?? 0
                    )
                }

                let inTokens = usage?.totalInputTokens ?? 0
                let outTokens = usage?.totalOutputTokens ?? 0
                logger.notice("Gemini request completed: status \(statusCode), \(String(format: "%.3f", elapsed))s, \(trimmedText.count) chars, tokens in:\(inTokens) out:\(outTokens)")

                let startISO = ISO8601DateFormatter().string(from: t0)
                let endISO = ISO8601DateFormatter().string(from: Date())
                let diag = RequestDiagnosticReport(
                    startTimestamp: startISO,
                    completionTimestamp: endISO,
                    endpoint: endpoint.absoluteString,
                    operation: "POST interactions (stateless)",
                    model: request.model.rawValue,
                    httpStatusCode: 200,
                    parsedGoogleErrorFormat: true,
                    sanitizedProviderErrorCode: nil,
                    sanitizedProviderErrorMessage: nil,
                    internalErrorCase: "none (success)"
                )
                recordDiagnostics(diag)

                return GenerationResult(
                    text: trimmedText,
                    isTruncated: isTruncated,
                    usage: usage
                )
            } catch let genError as GenerationError {
                throw genError
            } catch {
                logger.error("Failed to decode JSON response from Gemini")
                throw GenerationError.malformedResponse
            }
        } else {
            // Non-200 HTTP response
            let tEnd = Date()
            let (errorCode, errorMessage, parsedGoogleFormat) = parseErrorPayload(from: responseData)
            let mapped = mapErrorCode(code: errorCode, message: errorMessage, statusCode: statusCode, headers: httpResponse.allHeaderFields)
            let startISO = ISO8601DateFormatter().string(from: t0)
            let endISO = ISO8601DateFormatter().string(from: tEnd)
            let diag = RequestDiagnosticReport(
                startTimestamp: startISO,
                completionTimestamp: endISO,
                endpoint: endpoint.absoluteString,
                operation: "POST interactions (stateless)",
                model: request.model.rawValue,
                httpStatusCode: statusCode,
                parsedGoogleErrorFormat: parsedGoogleFormat,
                sanitizedProviderErrorCode: errorCode,
                sanitizedProviderErrorMessage: errorMessage,
                internalErrorCase: String(describing: mapped)
            )
            recordDiagnostics(diag)
            logger.error("Gemini request failed: HTTP \(statusCode), code=\(errorCode ?? "none", privacy: .public), message=\(errorMessage ?? "none", privacy: .public), parsedGoogle=\(parsedGoogleFormat), selectedCase=\(String(describing: mapped), privacy: .public), elapsed=\(String(format: "%.3f", elapsed))s")
            throw mapped
        }
    }

    private func sanitizeErrorMessage(_ message: String?) -> String? {
        guard let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty else {
            return nil
        }
        let truncated = String(message.prefix(300))
        let sanitized = truncated.replacingOccurrences(
            of: "AIza[0-9A-Za-z-_]{35}",
            with: "[REDACTED_KEY]",
            options: .regularExpression
        )
        return sanitized
    }

    private func parseErrorPayload(from data: Data) -> (code: String?, message: String?, parsedGoogleFormat: Bool) {
        if let wrapper = try? JSONDecoder().decode(InteractionErrorWrapper.self, from: data), let err = wrapper.error {
            return (err.codeString, sanitizeErrorMessage(err.message), true)
        }
        if let array = try? JSONDecoder().decode([InteractionErrorWrapper].self, from: data), let first = array.first, let err = first.error {
            return (err.codeString, sanitizeErrorMessage(err.message), true)
        }
        // Fallback for proxy or gateway responses formatting error or message as a string
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let str = dict["error"] as? String {
                return (nil, sanitizeErrorMessage(str), true)
            }
            if let msg = dict["message"] as? String {
                return (nil, sanitizeErrorMessage(msg), true)
            }
        }
        return (nil, nil, false)
    }

    private func mapErrorCode(code: String?, message: String? = nil, statusCode: Int, headers: [AnyHashable: Any]) -> GenerationError {
        // Detect invalid API key returned by Google: HTTP 400 or 401 with API_KEY_INVALID or message
        if code == "API_KEY_INVALID" || (statusCode == 400 && message?.localizedCaseInsensitiveContains("API key") == true) {
            return .invalidAPIKey
        }

        // Blocked codes check (can occur at any status or 200 failed)
        if let code = code {
            switch code {
            case "safety":
                return .blocked(reason: .safety)
            case "recitation":
                return .blocked(reason: .recitation)
            case "prohibited_content":
                return .blocked(reason: .prohibitedContent)
            case "spii":
                return .blocked(reason: .spii)
            case "blocklist":
                return .blocked(reason: .blocklist)
            case "language":
                return .blocked(reason: .language)
            case "content_blocked":
                return .blocked(reason: .other)
            default:
                break
            }
        }

        switch statusCode {
        case 400:
            if code == "failed_precondition" {
                return .unavailableForAccount
            }
            return .badRequest(code: code)
        case 401:
            return .invalidAPIKey
        case 402:
            return .paymentRequired
        case 403:
            return .permissionDenied
        case 404:
            return .modelNotFound
        case 429:
            if code == "quota_exceeded" || code == "RESOURCE_EXHAUSTED" || message?.localizedCaseInsensitiveContains("quota") == true {
                return .quotaExceeded
            }
            // Parse Retry-After header if present (case-insensitive for HTTP/2 headers)
            var retryDuration: Duration? = nil
            let retryHeaderValue: String? = {
                for (k, v) in headers {
                    if let keyStr = k as? String, keyStr.caseInsensitiveCompare("Retry-After") == .orderedSame {
                        return v as? String
                    }
                }
                return nil
            }()
            if let retryHeader = retryHeaderValue, let seconds = Int(retryHeader.trimmingCharacters(in: .whitespaces)) {
                let clamped = max(1, min(60, seconds))
                retryDuration = .seconds(clamped)
            } else {
                retryDuration = .seconds(10)
            }
            return .rateLimited(retryAfter: retryDuration)
        case 499:
            return .cancelled
        case 500, 502, 503, 504:
            return .server(status: statusCode, code: code, message: message)
        default:
            if (400...499).contains(statusCode) {
                return .badRequest(code: code)
            } else if (500...599).contains(statusCode) {
                return .server(status: statusCode, code: code, message: message)
            } else {
                return .malformedResponse
            }
        }
    }
}

// MARK: - Wire Formats (private to DoomServices)

private struct InteractionWireRequest: Encodable {
    let model: String
    let input: String
    let systemInstruction: String
    let generationConfig: GenerationConfig
    let store: Bool
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case systemInstruction = "system_instruction"
        case generationConfig = "generation_config"
        case store
        case stream
    }

    struct GenerationConfig: Encodable {
        let thinkingLevel: String
        let maxOutputTokens: Int

        enum CodingKeys: String, CodingKey {
            case thinkingLevel = "thinking_level"
            case maxOutputTokens = "max_output_tokens"
        }
    }
}

private struct InteractionWireResponse: Decodable {
    let id: String?
    let model: String?
    let status: String?
    let steps: [InteractionWireStep]?
    let usage: InteractionWireUsage?
    let error: InteractionWireErrorPayload?
}

private struct InteractionWireStep: Decodable {
    let type: String
    let content: [InteractionWireContent]?
}

private struct InteractionWireContent: Decodable {
    let type: String
    let text: String?
}

private struct InteractionWireUsage: Decodable {
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let totalThoughtTokens: Int?
    let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalThoughtTokens = "total_thought_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct InteractionErrorWrapper: Decodable {
    let error: InteractionWireErrorPayload?
}

private struct InteractionErrorDetail: Decodable {
    let reason: String?
}

private enum IntOrString: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .string("")
        }
    }

    var stringValue: String {
        switch self {
        case .int(let i): return String(i)
        case .string(let s): return s
        }
    }
}

private struct InteractionWireErrorPayload: Decodable {
    let code: IntOrString?
    let message: String?
    let status: String?
    let details: [InteractionErrorDetail]?

    var codeString: String? {
        if let details = details, let reason = details.compactMap(\.reason).first {
            return reason
        }
        if let s = status, !s.isEmpty {
            return s
        }
        return code?.stringValue
    }
}
