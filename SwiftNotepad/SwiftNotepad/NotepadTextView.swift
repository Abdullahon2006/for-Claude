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

        // Font & text
        textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = false
        textView.allowsUndo = true

        // Disable auto-corrections that interfere with code/markdown
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        // Layout
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: .greatestFiniteMagnitude
        )

        // Scroll
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        // Load initial content
        textView.string = appState.content
        context.coordinator.highlighter.highlight(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard
            let textView = scrollView.documentView as? NSTextView,
            !context.coordinator.isEditing,
            textView.string != appState.content
        else { return }

        let sel = textView.selectedRange()
        textView.string = appState.content
        context.coordinator.highlighter.highlight(textView)
        let safeLocation = min(sel.location, textView.string.utf16.count)
        textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        let appState: AppState
        let highlighter = SyntaxHighlighter()
        var isEditing = false
        weak var textView: NSTextView?

        init(appState: AppState) {
            self.appState = appState
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            isEditing = true
            appState.content = tv.string
            appState.markModified()
            highlighter.highlight(tv)
            isEditing = false
        }
    }
}
