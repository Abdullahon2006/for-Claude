import SwiftUI
import AppKit

struct NotepadTextView: NSViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Font
        textView.font = NSFont.monospacedSystemFont(ofSize: appState.fontSize, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true

        // Built-in find bar (Cmd+F / Cmd+G / Cmd+H work automatically)
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Disable smart corrections
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled  = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled    = false
        textView.isGrammarCheckingEnabled            = false
        textView.isContinuousSpellCheckingEnabled    = false

        // Layout
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable   = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers    = true

        textView.string = appState.content
        context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync content when changed externally (file open, new file)
        if !context.coordinator.isEditing && textView.string != appState.content {
            let sel = textView.selectedRange()
            textView.string = appState.content
            let safe = min(sel.location, textView.string.utf16.count)
            textView.setSelectedRange(NSRange(location: safe, length: 0))
            context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)
            context.coordinator.lastFontSize = appState.fontSize
            return
        }

        // Re-highlight when font size changes
        if context.coordinator.lastFontSize != appState.fontSize {
            context.coordinator.lastFontSize = appState.fontSize
            textView.font = NSFont.monospacedSystemFont(ofSize: appState.fontSize, weight: .regular)
            context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        let appState: AppState
        let highlighter = SyntaxHighlighter()
        var isEditing = false
        var lastFontSize: CGFloat = 14
        weak var textView: NSTextView?

        init(appState: AppState) {
            self.appState = appState
            self.lastFontSize = appState.fontSize
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            appState.content = tv.string
            appState.markModified()
            appState.updateStats(text: tv.string)
            highlighter.highlight(tv, fontSize: appState.fontSize)
            appState.updateCursorPosition(in: tv)
            isEditing = false
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            appState.updateCursorPosition(in: tv)
        }

        // Auto-indent: on Return, preserve current line's leading whitespace
        func textView(_ textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            guard sel == #selector(NSResponder.insertNewline(_:)) else { return false }
            let nsStr     = textView.string as NSString
            let lineRange = nsStr.lineRange(for: NSRange(location: textView.selectedRange().location, length: 0))
            let line      = nsStr.substring(with: lineRange)
            let indent    = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            textView.insertText("\n" + indent, replacementRange: textView.selectedRange())
            return true
        }
    }
}
