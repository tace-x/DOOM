import AppKit
import Foundation
import DoomCore
import OSLog

private let logger = Logger(subsystem: "doom", category: "selection")

@MainActor
public final class SystemTextAcquirer: TextAcquiring {
    public typealias FrontmostAppProvider = @Sendable () -> (pid: pid_t, bundleIdentifier: String?, localizedName: String?)?

    private let permissions: any PermissionChecking
    private let ownBundleIdentifier: String?
    private let accessibilityReader: any AccessibilitySelectionReading
    private let clipboardFallback: any ClipboardFallbackHandling
    private let frontmostAppProvider: FrontmostAppProvider

    public init(
        permissions: any PermissionChecking,
        ownBundleIdentifier: String? = nil,
        accessibilityReader: any AccessibilitySelectionReading = AccessibilitySelectionReader(),
        clipboardFallback: any ClipboardFallbackHandling = ClipboardFallbackHandler(),
        frontmostAppProvider: @escaping FrontmostAppProvider = {
            NSWorkspace.shared.frontmostApplication.map {
                ($0.processIdentifier, $0.bundleIdentifier, $0.localizedName)
            }
        }
    ) {
        self.permissions = permissions
        self.ownBundleIdentifier = ownBundleIdentifier
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

        if let id = bundleID, let own = ownBundleIdentifier, id == own {
            logger.notice("Acquisition aborted: Source is DOOM own application")
            throw TextAcquisitionError.ownApplication
        }

        let pid = frontApp.pid
        let t0 = Date()

        // Step 3: Accessibility Path
        do throws(TextAcquisitionError) {
            let rawText = try await accessibilityReader.readSelectedText(from: pid, bundleIdentifier: bundleID)
            let selectedText = try SelectionValidator.validate(rawText, source: source, method: .accessibility)
            let elapsed = Date().timeIntervalSince(t0)
            logger.notice("Acquired selection via accessibility in \(String(format: "%.3f", elapsed))s (\(selectedText.characterCount) chars)")
            return selectedText
        } catch {
            switch error {
            case .unsupported, .editorSelectionUnavailable:
                // Step 4: Clipboard Fallback (only on .unsupported or .editorSelectionUnavailable when enabled)
                if copyFallbackEnabled {
                    logger.notice("Accessibility unsupported or editor selection; attempting opt-in clipboard fallback")
                    let (rawText, restoreSkipped) = try await clipboardFallback.acquireViaClipboard(sourcePid: pid)
                    let selectedText = try SelectionValidator.validate(rawText, source: source, method: .clipboard, restoreSkipped: restoreSkipped)
                    let elapsed = Date().timeIntervalSince(t0)
                    logger.notice("Acquired selection via clipboard fallback in \(String(format: "%.3f", elapsed))s (\(selectedText.characterCount) chars)")
                    return selectedText
                } else {
                    logger.notice("Selection unsupported and clipboard fallback is disabled")
                    if error == .editorSelectionUnavailable {
                        throw TextAcquisitionError.clipboardFallbackDisabled
                    }
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
