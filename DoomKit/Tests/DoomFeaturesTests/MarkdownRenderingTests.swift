import Testing
import SwiftUI
@testable import DoomCore
@testable import DoomFeatures

@Suite("MarkdownRenderingTests")
@MainActor
struct MarkdownRenderingTests {

    @Test("UI-36 / SEC-11: Hyperlinks are stripped of clickable URLs and underlined")
    func testHyperlinksAreStrippedAndUnderlined() {
        let markdown = "Visit [Google Search](https://google.com) or [Apple](https://apple.com) now."
        let attributed = ResponsePresentationView.formatMarkdown(markdown)

        // Verify that NO run retains a clickable link (SEC-11)
        for run in attributed.runs {
            #expect(run.link == nil, "All interactive link attributes must be removed from formatted markdown")
        }

        // Verify that the link text exists in the attributed string
        let plain = String(attributed.characters)
        #expect(plain.contains("Google Search"))
        #expect(plain.contains("Apple"))

        // Verify that at least one run has underline styling applied (UI-36)
        let hasUnderline = attributed.runs.contains { run in
            run.underlineStyle != nil
        }
        #expect(hasUnderline, "Stripped links must have underline styling applied")
    }

    @Test("Inline markdown formatting like bold, italic, and code are parsed")
    func testInlineFormattingParsed() {
        let markdown = "This has **bold text**, *italic text*, and `inline code`."
        let attributed = ResponsePresentationView.formatMarkdown(markdown)
        let plain = String(attributed.characters)

        #expect(plain.contains("bold text"))
        #expect(plain.contains("italic text"))
        #expect(plain.contains("inline code"))

        // Assert that formatting is parsed rather than left as raw asterisks or backticks
        #expect(!plain.contains("**bold text**"))
        #expect(!plain.contains("`inline code`"))
    }

    @Test("Whitespace and newlines are preserved in inline parsing")
    func testWhitespaceAndNewlinesPreserved() {
        let multiline = "Line 1\n\nLine 2 with    spaces\nLine 3"
        let attributed = ResponsePresentationView.formatMarkdown(multiline)
        let plain = String(attributed.characters)

        #expect(plain.contains("Line 1"))
        #expect(plain.contains("Line 2 with    spaces"))
        #expect(plain.contains("Line 3"))
    }

    @Test("Plain text without markdown formatting passes through cleanly")
    func testPlainTextPassesThrough() {
        let plain = "This is a simple plain text response without any special syntax."
        let attributed = ResponsePresentationView.formatMarkdown(plain)

        #expect(String(attributed.characters) == plain)
        for run in attributed.runs {
            #expect(run.link == nil)
        }
    }
}
