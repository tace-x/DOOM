import SwiftUI

public struct ResponsePresentationView: View {
    public let text: String

    public init(text: String) {
        self.text = text
    }

    public var attributedContent: AttributedString {
        Self.formatMarkdown(text)
    }

    public static func formatMarkdown(_ raw: String) -> AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            var attributed = try AttributedString(markdown: raw, options: options)

            // Remove interactive links and replace with accentText underline per UI_SPECIFICATION.md §3.6
            for run in attributed.runs {
                if run.link != nil {
                    let range = run.range
                    attributed[range].link = nil
                    attributed[range].underlineStyle = Text.LineStyle(pattern: .solid, color: DoomTheme.accentText)
                }
            }
            return attributed
        } catch {
            return AttributedString(raw)
        }
    }

    public var body: some View {
        Text(attributedContent)
            .font(.system(.body))
            .lineSpacing(2)
            .foregroundStyle(DoomTheme.textPrimary)
            .textSelection(.enabled)
            .accessibilityLabel(text)
    }
}
