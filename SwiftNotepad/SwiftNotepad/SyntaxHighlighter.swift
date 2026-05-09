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

        static let dark = Theme(
            foreground: NSColor(srgbRed: 0.87, green: 0.87, blue: 0.87, alpha: 1),
            heading:    NSColor(srgbRed: 0.40, green: 0.78, blue: 1.00, alpha: 1),
            bold:       NSColor(srgbRed: 1.00, green: 0.85, blue: 0.50, alpha: 1),
            italic:     NSColor(srgbRed: 0.76, green: 0.90, blue: 0.56, alpha: 1),
            code:       NSColor(srgbRed: 0.92, green: 0.58, blue: 0.48, alpha: 1),
            link:       NSColor(srgbRed: 0.40, green: 0.70, blue: 1.00, alpha: 1),
            comment:    NSColor(srgbRed: 0.50, green: 0.60, blue: 0.50, alpha: 1),
            keyword:    NSColor(srgbRed: 0.82, green: 0.52, blue: 0.92, alpha: 1),
            string:     NSColor(srgbRed: 0.60, green: 0.90, blue: 0.60, alpha: 1),
            number:     NSColor(srgbRed: 0.90, green: 0.72, blue: 0.40, alpha: 1)
        )

        static let light = Theme(
            foreground: NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1),
            heading:    NSColor(srgbRed: 0.00, green: 0.38, blue: 0.80, alpha: 1),
            bold:       NSColor(srgbRed: 0.60, green: 0.28, blue: 0.00, alpha: 1),
            italic:     NSColor(srgbRed: 0.28, green: 0.50, blue: 0.18, alpha: 1),
            code:       NSColor(srgbRed: 0.80, green: 0.10, blue: 0.10, alpha: 1),
            link:       NSColor(srgbRed: 0.00, green: 0.30, blue: 0.80, alpha: 1),
            comment:    NSColor(srgbRed: 0.40, green: 0.50, blue: 0.40, alpha: 1),
            keyword:    NSColor(srgbRed: 0.50, green: 0.00, blue: 0.70, alpha: 1),
            string:     NSColor(srgbRed: 0.00, green: 0.50, blue: 0.10, alpha: 1),
            number:     NSColor(srgbRed: 0.70, green: 0.38, blue: 0.00, alpha: 1)
        )
    }

    // MARK: - Pre-compiled rules

    private struct Rule {
        let regex: NSRegularExpression
        let color: KeyPath<Theme, NSColor>
        let bold: Bool
        let italic: Bool

        init(_ pattern: String, _ color: KeyPath<Theme, NSColor>,
             _ options: NSRegularExpression.Options = [],
             bold: Bool = false, italic: Bool = false) {
            // Force-try is safe: all patterns are compile-time constants
            self.regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.color = color
            self.bold  = bold
            self.italic = italic
        }
    }

    private let rules: [Rule]
    private let keywordRegex: NSRegularExpression

    // MARK: - Init (compile once)

    init() {
        let kw = [
            "func","class","struct","enum","let","var","if","else","guard",
            "for","while","return","import","protocol","extension","switch",
            "case","break","continue","true","false","nil","self","super",
            "init","deinit","override","public","private","internal",
            "fileprivate","open","static","final","lazy","mutating",
            "associatedtype","typealias","throw","throws","try","catch","defer",
            "def","pass","lambda","with","as","in","is","not","and","or",
            "function","const","type","interface","namespace","using","new",
            "delete","void","async","await","yield","from",
        ]
        keywordRegex = try! NSRegularExpression(
            pattern: "\\b(" + kw.joined(separator: "|") + ")\\b"
        )

        rules = [
            // Code blocks before inline so inner patterns don't fire inside them
            Rule(#"^```[\s\S]*?^```"#,            \.code,    [.anchorsMatchLines]),
            Rule(#"`[^`\n]+`"#,                   \.code),
            Rule(#"^#{1,6}[ \t].+$"#,             \.heading, [.anchorsMatchLines], bold: true),
            Rule(#"\*\*(?!\s)(?:[^*]|\*(?!\*))+\*\*|__(?!\s)(?:[^_]|_(?!_))+__"#,
                                                   \.bold,    [], bold: true),
            Rule(#"(?<!\*)\*(?!\*|\s)[^*\n]+(?<!\s)\*(?!\*)|(?<!_)_(?!_|\s)[^_\n]+(?<!\s)_(?!_)"#,
                                                   \.italic,  [], italic: true),
            Rule(#"\[([^\]\n]+)\]\([^\)\n]+\)"#,  \.link),
            Rule(#"//[^\n]*"#,                     \.comment),
            Rule(#"(?<![\w/:#])#[^\n]*"#,          \.comment),   // shell/Python, not URLs/hex
            Rule(#""(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'"#, \.string),
            Rule(#"\b\d+(?:\.\d+)?\b"#,           \.number),
        ]
    }

    // MARK: - Public

    func highlight(_ textView: NSTextView, fontSize: CGFloat = 14) {
        guard let storage = textView.textStorage, !textView.string.isEmpty else { return }

        let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let theme  = isDark ? Theme.dark : Theme.light
        let text   = textView.string
        let full   = NSRange(text.startIndex..., in: text)

        storage.beginEditing()

        storage.addAttribute(.foregroundColor, value: theme.foreground,          range: full)
        storage.addAttribute(.font,            value: monoFont(size: fontSize),  range: full)

        // Keywords
        keywordRegex.enumerateMatches(in: text, range: full) { m, _, _ in
            guard let r = m?.range else { return }
            storage.addAttribute(.foregroundColor, value: theme.keyword, range: r)
        }

        // All other rules (later rules override earlier ones for overlapping ranges)
        for rule in rules {
            rule.regex.enumerateMatches(in: text, range: full) { m, _, _ in
                guard let r = m?.range else { return }
                storage.addAttribute(.foregroundColor, value: theme[keyPath: rule.color], range: r)
                if rule.bold || rule.italic {
                    storage.addAttribute(.font,
                                         value: monoFont(size: fontSize, bold: rule.bold, italic: rule.italic),
                                         range: r)
                }
            }
        }

        storage.endEditing()
    }

    // MARK: - Private

    private func monoFont(size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let base = NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
        guard italic else { return base }
        let desc = base.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: desc, size: size) ?? base
    }
}
