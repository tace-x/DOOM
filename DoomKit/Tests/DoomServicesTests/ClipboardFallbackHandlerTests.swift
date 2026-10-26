import Testing
import Foundation
import AppKit
import DoomCore
@testable import DoomServices

private final class FakePasteboardItem: PasteboardItemDataProviding, @unchecked Sendable {
    let types: [NSPasteboard.PasteboardType]
    let dataMap: [NSPasteboard.PasteboardType: Data]

    init(types: [NSPasteboard.PasteboardType], dataMap: [NSPasteboard.PasteboardType: Data]) {
        self.types = types
        self.dataMap = dataMap
    }

    func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        dataMap[type]
    }
}

private final class FakePasteboardProvider: PasteboardProviding, @unchecked Sendable {
    var changeCount: Int = 10
    var items: [any PasteboardItemDataProviding] = []
    var writtenSnapshots: [[[NSPasteboard.PasteboardType: Data]]] = []
    var stringContent: String? = nil
    var isAccessDenied: Bool = false
    var onReadStringHook: (@Sendable () -> Void)?

    func getPasteboardItems() -> [any PasteboardItemDataProviding] {
        return items
    }

    func clearContents() {
        items = []
        changeCount += 1
    }

    func writeSnapshot(_ snapshot: [[NSPasteboard.PasteboardType: Data]]) {
        writtenSnapshots.append(snapshot)
        changeCount += 1
    }

    func readString() -> String? {
        onReadStringHook?()
        return stringContent
    }

    func simulateAsyncCopy(newChangeCount: Int, string: String, delayMs: Int = 50) {
        Task(priority: .high) {
            if delayMs > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            } else {
                await Task.yield()
            }
            self.stringContent = string
            self.changeCount = newChangeCount
        }
    }
}

@Suite("ClipboardFallbackHandlerTests")
struct ClipboardFallbackHandlerTests {
    @Test("TEXT-T-08: Concealed type aborts fallback before copy")
    @MainActor
    func testConcealedTypeAborts() async {
        let fake = FakePasteboardProvider()
        let concealedItem = FakePasteboardItem(
            types: [ClipboardFallbackHandler.concealedType],
            dataMap: [ClipboardFallbackHandler.concealedType: Data("secret".utf8)]
        )
        fake.items = [concealedItem]

        let handler = ClipboardFallbackHandler(pasteboard: fake)
        await #expect(throws: TextAcquisitionError.clipboardNotPreservable) {
            _ = try await handler.acquireViaClipboard(sourcePid: 1234)
        }
        #expect(fake.writtenSnapshots.isEmpty)
    }

    @Test("TEXT-T-08: Transient type aborts fallback before copy")
    @MainActor
    func testTransientTypeAborts() async {
        let fake = FakePasteboardProvider()
        let transientItem = FakePasteboardItem(
            types: [ClipboardFallbackHandler.transientType],
            dataMap: [ClipboardFallbackHandler.transientType: Data("transient".utf8)]
        )
        fake.items = [transientItem]

        let handler = ClipboardFallbackHandler(pasteboard: fake)
        await #expect(throws: TextAcquisitionError.clipboardNotPreservable) {
            _ = try await handler.acquireViaClipboard(sourcePid: 1234)
        }
    }

    @Test("TEXT-T-08: Unchanged pasteboard changeCount throws clipboardCopyFailed with no restore")
    @MainActor
    func testUnchangedChangeCountFails() async {
        let fake = FakePasteboardProvider()
        fake.items = []
        // changeCount stays unchanged at 10
        let handler = ClipboardFallbackHandler(pasteboard: fake)
        await #expect(throws: TextAcquisitionError.clipboardCopyFailed) {
            _ = try await handler.acquireViaClipboard(sourcePid: 1234)
        }
        #expect(fake.writtenSnapshots.isEmpty)
    }

    @Test("TEXT-09 & TEXT-T-08: Successful fallback returns text and restores clipboard snapshot")
    @MainActor
    func testSuccessfulFallbackRestoresClipboard() async throws {
        let fake = FakePasteboardProvider()
        let originalItem = FakePasteboardItem(
            types: [.string],
            dataMap: [.string: Data("Original clipboard string".utf8)]
        )
        fake.items = [originalItem]
        fake.simulateAsyncCopy(newChangeCount: 11, string: "Copied target text")

        let handler = ClipboardFallbackHandler(pasteboard: fake)
        let (text, restoreSkipped) = try await handler.acquireViaClipboard(sourcePid: 1234)

        #expect(text == "Copied target text")
        #expect(restoreSkipped == false)
        #expect(fake.writtenSnapshots.count == 1)
        #expect(fake.writtenSnapshots.first?.first?[.string] == Data("Original clipboard string".utf8))
    }

    @Test("TEXT-11 & TEXT-T-08: Restore skipped if clipboard changed again after copy")
    @MainActor
    func testRestoreSkippedIfClipboardChangedAgain() async throws {
        let fake = FakePasteboardProvider()
        let originalItem = FakePasteboardItem(
            types: [.string],
            dataMap: [.string: Data("Original clipboard string".utf8)]
        )
        fake.items = [originalItem]
        fake.simulateAsyncCopy(newChangeCount: 11, string: "Copied target text")
        // Hook increments changeCount during readString, simulating external clipboard change
        fake.onReadStringHook = {
            fake.changeCount += 1
        }

        let handler = ClipboardFallbackHandler(pasteboard: fake)
        let (text, restoreSkipped) = try await handler.acquireViaClipboard(sourcePid: 1234)

        #expect(text == "Copied target text")
        #expect(restoreSkipped == true)
        #expect(fake.writtenSnapshots.isEmpty)
    }

    @Test("TEXT-16 & TEXT-T-08: Cancellation after copy still restores clipboard before throwing cancelled")
    @MainActor
    func testCancelAfterCopyStillRestores() async {
        let fake = FakePasteboardProvider()
        let originalItem = FakePasteboardItem(
            types: [.string],
            dataMap: [.string: Data("Original before cancel".utf8)]
        )
        fake.items = [originalItem]
        fake.simulateAsyncCopy(newChangeCount: 11, string: "Copied text before cancel")

        let handler = ClipboardFallbackHandler(pasteboard: fake)

        nonisolated(unsafe) var taskHolder: Task<(text: String, restoreSkipped: Bool), any Error>?
        let task = Task { @MainActor in
            fake.onReadStringHook = {
                taskHolder?.cancel()
            }
            return try await handler.acquireViaClipboard(sourcePid: 1234)
        }
        taskHolder = task

        let result = await task.result
        switch result {
        case .success:
            Issue.record("Expected task to throw cancelled error")
        case .failure(let err):
            #expect((err as? TextAcquisitionError) == .cancelled)
        }

        #expect(fake.writtenSnapshots.count == 1)
        #expect(fake.writtenSnapshots.first?.first?[.string] == Data("Original before cancel".utf8))
    }
}
