import AppKit

final class SyntaxHighlighter {

    // MARK: - Theme

    struct Theme {
        var foreground: NSColor
        var heading: NSColor
        var bold: NSColor
        var italic: NSColor
        var code: NSColor
        var link: NSColor
        var comment: NSColor
        var keyword: NSColor
        var string: NSColor
        var number: NSColor
        var punctuation: NSColor

        static let dark = Theme(
            foreground:  NSColor(srgbRed: 0.87, green: 0.87, blue: 0.87, alpha: 1),
            heading:     NSColor(srgbRed: 0.40, green: 0.78, blue: 1.00, alpha: 1),
            bold:        NSColor(srgbRed: 1.00, green: 0.85, blue: 0.50, alpha: 1),
            italic:      NSColor(srgbRed: 0.76, green: 0.90, blue: 0.56, alpha: 1),
            code:        NSColor(srgbRed: 0.92, green: 0.58, blue: 0.48, alpha: 1),
            link:        NSColor(srgbRed: 0.40, green: 0.70, blue: 1.00, alpha: 1),
            comment:     NSColor(srgbRed: 0.50, green: 0.60, blue: 0.50, alpha: 1),
            keyword:     NSColor(srgbRed: 0.82, green: 0.52, blue: 0.92, alpha: 1),
            string:      NSColor(srgbRed: 0.60, green: 0.90, blue: 0.60, alpha: 1),
            number:      NSColor(srgbRed: 0.90, green: 0.72, blue: 0.40, alpha: 1),
            punctuation: NSColor(srgbRed: 0.60, green: 0.60, blue: 0.60, alpha: 1)
        )

        static let light = Theme(
            foreground:  NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1),
            heading:     NSColor(srgbRed: 0.00, green: 0.38, blue: 0.80, alpha: 1),
            bold:        NSColor(srgbRed: 0.60, green: 0.28, blue: 0.00, alpha: 1),
            italic:      NSColor(srgbRed: 0.28, green: 0.50, blue: 0.18, alpha: 1),
            code:        NSColor(srgbRed: 0.80, green: 0.10, blue: 0.10, alpha: 1),
            link:        NSColor(srgbRed: 0.00, green: 0.30, blue: 0.80, alpha: 1),
            comment:     NSColor(srgbRed: 0.40, green: 0.50, blue: 0.40, alpha: 1),
            keyword:     NSColor(srgbRed: 0.50, green: 0.00, blue: 0.70, alpha: 1),
            string:      NSColor(srgbRed: 0.00, green: 0.50, blue: 0.10, alpha: 1),
            number:      NSColor(srgbRed: 0.70, green: 0.38, blue: 0.00, alpha: 1),
            punctuation: NSColor(srgbRed: 0.50, green: 0.50, blue: 0.50, alpha: 1)
        )
    }

    // MARK: - Public

    func highlight(_ textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme = isDark ? Theme.dark : Theme.light
        let text = textView.string
        guard !text.isEmpty else { return }
        let fullRange = NSRange(text.startIndex..., in: text)

        storage.beginEditing()

        // Base reset
        storage.addAttribute(.foregroundColor, value: theme.foreground, range: fullRange)
        storage.addAttribute(.font, value: monoFont(size: 14, bold: false), range: fullRange)

        // Order matters: later rules override earlier ones for overlapping ranges.
        // Code blocks first so inline rules don't fire inside them.
        apply(#"^```[\s\S]*?^```"#,          storage, text, theme.code,      [.anchorsMatchLines])
        apply(#"`[^`\n]+`"#,                 storage, text, theme.code)
        apply(#"^#{1,6}[ \t].+$"#,          storage, text, theme.heading,   [.anchorsMatchLines], bold: true)
        apply(#"\*\*(?!\s)(?:[^*]|\*(?!\*))+\*\*|__(?!\s)(?:[^_]|_(?!_))+__"#,
                                             storage, text, theme.bold,    [], bold: true)
        apply(#"(?<!\*)\*(?!\*|\s)(?:[^*\n])+(?<!\s)\*(?!\*)|(?<!_)_(?!_|\s)(?:[^_\n])+(?<!\s)_(?!_)"#,
                                             storage, text, theme.italic,  [], italic: true)
        apply(#"\[([^\]\n]+)\]\([^\)\n]+\)"#, storage, text, theme.link)
        apply(#"//[^\n]*"#,                  storage, text, theme.comment)
        apply(#"#[^\n]*"#,                   storage, text, theme.comment)  // Shell/Python comments
        applyKeywords(storage, text, theme.keyword)
        apply(#""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'"#, storage, text, theme.string)
        apply(#"\b\d+(?:\.\d+)?\b"#,        storage, text, theme.number)

        storage.endEditing()
    }

    // MARK: - Private

    private let keywords: [String] = [
        // Swift
        "func", "class", "struct", "enum", "let", "var", "if", "else", "guard",
        "for", "while", "return", "import", "protocol", "extension", "switch",
        "case", "break", "continue", "true", "false", "nil", "self", "super",
        "init", "deinit", "override", "public", "private", "internal",
        "fileprivate", "open", "static", "final", "lazy", "mutating",
        "associatedtype", "typealias", "throw", "throws", "try", "catch", "defer",
        // Python / JS / general
        "def", "pass", "lambda", "with", "as", "in", "is", "not", "and", "or",
        "function", "const", "type", "interface", "namespace", "using", "new",
        "delete", "void", "async", "await", "yield", "from",
    ]

    private func applyKeywords(_ storage: NSTextStorage, _ text: String, _ color: NSColor) {
        let pattern = "\\b(" + keywords.joined(separator: "|") + ")\\b"
        apply(pattern, storage, text, color)
    }

    private func apply(
        _ pattern: String,
        _ storage: NSTextStorage,
        _ text: String,
        _ color: NSColor,
        _ options: NSRegularExpression.Options = [],
        bold: Bool = false,
        italic: Bool = false
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
        let fullRange = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: fullRange) { match, _, _ in
            guard let range = match?.range else { return }
            storage.addAttribute(.foregroundColor, value: color, range: range)
            if bold || italic {
                storage.addAttribute(.font, value: monoFont(size: 14, bold: bold, italic: italic), range: range)
            }
        }
    }

    private func monoFont(size: CGFloat, bold: Bool, italic: Bool = false) -> NSFont {
        let base = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        if italic {
            let traits = base.fontDescriptor.withSymbolicTraits(.italic)
            return NSFont(descriptor: traits, size: size) ?? base
        }
        return base
    }
}
