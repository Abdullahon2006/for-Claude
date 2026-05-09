import SwiftUI

struct StatusBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            Text("Line \(appState.cursorLine), Col \(appState.cursorColumn)")
                .padding(.leading, 12)
            Spacer()
            Text("\(appState.wordCount) words")
            sep
            Text("\(appState.charCount) chars")
                .padding(.trailing, 12)
        }
        .font(.system(size: 11, design: .monospaced))
        .foregroundStyle(.secondary)
        .frame(height: 22)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var sep: some View {
        Text("  |  ").foregroundStyle(.tertiary)
    }
}
