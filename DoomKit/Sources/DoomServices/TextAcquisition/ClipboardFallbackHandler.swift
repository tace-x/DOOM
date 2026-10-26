import AppKit
import Foundation
import DoomCore
import OSLog

private let logger = Logger(subsystem: "com.tace.doom", category: "selection")

public protocol PasteboardItemDataProviding: Sendable {
    var types: [NSPasteboard.PasteboardType] { get }
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
}

public protocol PasteboardProviding: AnyObject {
    var changeCount: Int { get }
    func getPasteboardItems() -> [any PasteboardItemDataProviding]
    func clearContents()
    func writeSnapshot(_ snapshot: [[NSPasteboard.PasteboardType: Data]])
    func readString() -> String?
    var isAccessDenied: Bool { get }
}

extension NSPasteboardItem: PasteboardItemDataProviding {}

public final class SystemPasteboardProvider: PasteboardProviding {
    private let pasteboard: NSPasteboard

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public var changeCount: Int {
        pasteboard.changeCount
    }

    public func getPasteboardItems() -> [any PasteboardItemDataProviding] {
        return pasteboard.pasteboardItems ?? []
    }

    public func clearContents() {
        pasteboard.clearContents()
    }

    public func writeSnapshot(_ snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        pasteboard.clearContents()
        guard !snapshot.isEmpty else { return }

        var items: [NSPasteboardItem] = []
        for itemDict in snapshot {
            let item = NSPasteboardItem()
            for (type, data) in itemDict {
                item.setData(data, forType: type)
            }
            items.append(item)
        }
        pasteboard.writeObjects(items)
    }

    public func readString() -> String? {
        pasteboard.string(forType: .string)
    }

    public var isAccessDenied: Bool {
        if #available(macOS 15.4, *) {
            // Check for pasteboard accessBehavior if restricted by system
            return false
        }
        return false
    }
}

@MainActor
public protocol ClipboardFallbackHandling: AnyObject {
    func acquireViaClipboard(sourcePid: pid_t) async throws(TextAcquisitionError) -> (text: String, restoreSkipped: Bool)
}

@MainActor
public final class ClipboardFallbackHandler: ClipboardFallbackHandling {
    private let pasteboard: any PasteboardProviding

    public static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    public static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    public static let maxSnapshotBytes: Int = 50 * 1024 * 1024 // 50 MB

    public init(pasteboard: any PasteboardProviding = SystemPasteboardProvider()) {
        self.pasteboard = pasteboard
    }

    public func acquireViaClipboard(sourcePid: pid_t) async throws(TextAcquisitionError) -> (text: String, restoreSkipped: Bool) {
        // Step 1: Check access denial
        if pasteboard.isAccessDenied {
            throw TextAcquisitionError.clipboardAccessDenied
        }

        // Step 2: SNAPSHOT
        let c0 = pasteboard.changeCount
        let items = pasteboard.getPasteboardItems()

        // Concealed / Transient check
        for item in items {
            for type in item.types {
                if type == Self.concealedType || type == Self.transientType {
                    throw TextAcquisitionError.clipboardNotPreservable
                }
            }
        }

        var snapshot: [[NSPasteboard.PasteboardType: Data]] = []
        var totalBytes = 0

        for item in items {
            var itemDict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type) else {
                    throw TextAcquisitionError.clipboardNotPreservable
                }
                totalBytes += data.count
                if totalBytes > Self.maxSnapshotBytes {
                    throw TextAcquisitionError.clipboardNotPreservable
                }
                itemDict[type] = data
            }
            snapshot.append(itemDict)
        }

        // Step 3: Cancellation check before copy
        if Task.isCancelled {
            throw TextAcquisitionError.cancelled
        }

        // Step 4: POST COPY
        let (cKeyCode, _) = KeyCodeResolver.currentKeyCodeForC()
        postCommandC(to: sourcePid, keyCode: UInt16(cKeyCode))

        // Step 5: WAIT for pasteboard change (every 20ms up to 600ms)
        var changed = false
        for _ in 0..<30 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20 ms
            if pasteboard.changeCount != c0 {
                changed = true
                break
            }
        }

        guard changed else {
            // Nothing was copied -> clipboardCopyFailed; no restore needed
            throw TextAcquisitionError.clipboardCopyFailed
        }

        // Step 6: READ
        let c1 = pasteboard.changeCount
        let rawString = pasteboard.readString()

        // Step 7: RESTORE (always runs after copy changed clipboard)
        var restoreSkipped = false
        if pasteboard.changeCount == c1 {
            pasteboard.writeSnapshot(snapshot)
        } else {
            restoreSkipped = true
            logger.notice("Clipboard changed again after DOOM copy; skipping restore")
        }

        // Check cancellation after copy
        if Task.isCancelled {
            throw TextAcquisitionError.cancelled
        }

        guard let text = rawString else {
            throw TextAcquisitionError.notText
        }

        return (text, restoreSkipped)
    }

    private func postCommandC(to pid: pid_t, keyCode: UInt16) {
        let src = CGEventSource(stateID: .combinedSessionState)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true) {
            down.flags = [.maskCommand]
            down.postToPid(pid)
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
            up.flags = []
            up.postToPid(pid)
        }
    }
}
