import Carbon
import SwiftUI

struct ShortcutRecorderView: View {
    let shortcut: ShortcutConfiguration
    let onSave: (ShortcutConfiguration) -> Void

    @State private var isRecording = false

    var body: some View {
        Button {
            isRecording = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "keyboard")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isRecording ? .white : EasyPasteTheme.accent)

                Text(isRecording ? "按下新的组合键" : shortcut.displayText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isRecording ? .white : EasyPasteTheme.ink)

                Spacer(minLength: 0)

                Text(isRecording ? "Esc 取消" : "点击修改")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(isRecording ? Color.white.opacity(0.82) : EasyPasteTheme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
        .background {
            if isRecording {
                LocalKeyEventMonitor { event in
                    handleKeyEvent(event)
                }
            }
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                isRecording
                    ? LinearGradient(
                        colors: [EasyPasteTheme.accent, Color(red: 0.71, green: 0.28, blue: 0.13)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.88), Color.white.opacity(0.62)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(isRecording ? Color.white.opacity(0.18) : EasyPasteTheme.line, lineWidth: 1)
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return true
        }

        guard let configuration = ShortcutConfiguration.from(event: event) else {
            return true
        }

        isRecording = false
        onSave(configuration)
        return true
    }
}
