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

        // Set content BEFORE the delegate so the assignment doesn't trigger
        // delegate callbacks during SwiftUI's init phase.
        textView.string = appState.content

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
        textView.isAutomaticQuoteSubstitutionEnabled  = false
        textView.isAutomaticDashSubstitutionEnabled   = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled     = false
        textView.isGrammarCheckingEnabled             = false
        textView.isContinuousSpellCheckingEnabled     = false

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

        context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync content when changed externally (file open, new file).
        // Nil out the delegate first so our programmatic text/selection changes
        // don't fire callbacks during SwiftUI's view-update phase.
        if !context.coordinator.isEditing && textView.string != appState.content {
            textView.delegate = nil
            let sel  = textView.selectedRange()
            textView.string = appState.content
            let safe = min(sel.location, textView.string.utf16.count)
            textView.setSelectedRange(NSRange(location: safe, length: 0))
            context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)
            context.coordinator.lastFontSize = appState.fontSize
            textView.delegate = context.coordinator
            return
        }

        // Re-highlight when font size changes (also suppress delegate for setSelectedRange side-effects).
        if context.coordinator.lastFontSize != appState.fontSize {
            textView.delegate = nil
            context.coordinator.lastFontSize = appState.fontSize
            textView.font = NSFont.monospacedSystemFont(ofSize: appState.fontSize, weight: .regular)
            context.coordinator.highlighter.highlight(textView, fontSize: appState.fontSize)
            textView.delegate = context.coordinator
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
            // Capture values synchronously on the AppKit thread…
            let text     = tv.string
            let location = tv.selectedRange().location
            isEditing = true
            // …then apply syntax highlighting synchronously (pure NSTextStorage work)…
            highlighter.highlight(tv, fontSize: appState.fontSize)
            // …then defer @Published mutations to the next run-loop pass so they
            // never fire while SwiftUI is mid-update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.content = text
                self.appState.markModified()
                self.appState.updateStats(text: text)
                self.appState.updateCursorPosition(text: text, location: location)
                self.isEditing = false
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            let text     = tv.string
            let location = tv.selectedRange().location
            DispatchQueue.main.async { [weak self] in
                self?.appState.updateCursorPosition(text: text, location: location)
            }
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
