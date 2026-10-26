import AppKit
import Foundation
import DoomCore
import OSLog

private let logger = Logger(subsystem: "com.tace.doom", category: "selection")

@MainActor
public final class SystemTextAcquirer: TextAcquiring {
    public typealias FrontmostAppProvider = @Sendable () -> (pid: pid_t, bundleIdentifier: String?, localizedName: String?)?

    private let permissions: any PermissionChecking
    private let accessibilityReader: any AccessibilitySelectionReading
    private let clipboardFallback: any ClipboardFallbackHandling
    private let frontmostAppProvider: FrontmostAppProvider

    public init(
        permissions: any PermissionChecking,
        accessibilityReader: any AccessibilitySelectionReading = AccessibilitySelectionReader(),
        clipboardFallback: any ClipboardFallbackHandling = ClipboardFallbackHandler(),
        frontmostAppProvider: @escaping FrontmostAppProvider = {
            NSWorkspace.shared.frontmostApplication.map {
                ($0.processIdentifier, $0.bundleIdentifier, $0.localizedName)
            }
        }
    ) {
        self.permissions = permissions
        self.accessibilityReader = accessibilityReader
        self.clipboardFallback = clipboardFallback
        self.frontmostAppProvider = frontmostAppProvider
    }

    public func acquireSelection(copyFallbackEnabled: Bool) async throws(TextAcquisitionError) -> SelectedText {
        // Step 1: Verify Accessibility Trust
        guard permissions.accessibilityState() == .granted else {
            logger.notice("Acquisition aborted: Accessibility permission not granted")
            throw TextAcquisitionError.accessibilityNotGranted
        }

        // Step 2: Frontmost application inspection
        guard let frontApp = frontmostAppProvider() else {
            logger.notice("Acquisition failed: No source application frontmost")
            throw TextAcquisitionError.noSourceApplication
        }

        let bundleID = frontApp.bundleIdentifier
        let appName = frontApp.localizedName
        let source = SourceApplication(localizedName: appName, bundleIdentifier: bundleID)

        if let id = bundleID, id == Bundle.main.bundleIdentifier || id == "com.tace.doom" {
            logger.notice("Acquisition aborted: Source is DOOM own application")
            throw TextAcquisitionError.ownApplication
        }

        let pid = frontApp.pid
        let t0 = Date()

        // Step 3: Accessibility Path
        do {
            let rawText = try await accessibilityReader.readSelectedText(from: pid, bundleIdentifier: bundleID)
            let selectedText = try SelectionValidator.validate(rawText, source: source, method: .accessibility)
            let elapsed = Date().timeIntervalSince(t0)
            logger.notice("Acquired selection via accessibility in \(String(format: "%.3f", elapsed))s (\(selectedText.characterCount) chars)")
            return selectedText
        } catch let error {
            switch error {
            case .unsupported:
                // Step 4: Clipboard Fallback (only on .unsupported when enabled)
                if copyFallbackEnabled {
                    logger.notice("Accessibility unsupported; attempting opt-in clipboard fallback")
                    let (rawText, _) = try await clipboardFallback.acquireViaClipboard(sourcePid: pid)
                    let selectedText = try SelectionValidator.validate(rawText, source: source, method: .clipboard)
                    let elapsed = Date().timeIntervalSince(t0)
                    logger.notice("Acquired selection via clipboard fallback in \(String(format: "%.3f", elapsed))s (\(selectedText.characterCount) chars)")
                    return selectedText
                } else {
                    logger.notice("Selection unsupported and clipboard fallback is disabled")
                    throw error
                }
            default:
                // Definitive empty, secure field, timeout, or access denial: never fallback
                logger.notice("Selection acquisition ended with error: \(error)")
                throw error
            }
        }
    }
}
