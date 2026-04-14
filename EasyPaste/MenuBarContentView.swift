import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var store: ClipboardStore
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            shortcutSection
            accessibilitySection
            clipboardPreview
            actionButtons
        }
        .padding()
        .frame(width: 340)
        .background(
            LinearGradient(
                colors: [EasyPasteTheme.cream, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            coordinator.refreshAccessibilityStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [EasyPasteTheme.accent, EasyPasteTheme.accentSoft],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("EasyPaste")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.ink)

                Text("全局快捷键唤起剪贴板历史")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(EasyPasteTheme.cocoa)
            }
        }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("快捷键", systemImage: "command")

            Text("当前：\(coordinator.shortcutMenuLabel)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(EasyPasteTheme.cocoa)

            ShortcutRecorderView(shortcut: coordinator.shortcut) { configuration in
                coordinator.updateShortcut(configuration)
            }

            Text("至少包含 Command、Option 或 Control 之一。")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(EasyPasteTheme.muted)
        }
        .padding(14)
        .background(cardBackground())
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("自动回填", systemImage: "arrow.turn.down.left")

            Text(coordinator.isAccessibilityTrusted ? "已授权，回车后会尝试切回原应用并粘贴。" : "未授权时只能复制内容。点一次“开启权限”后，系统会把 EasyPaste 注册到“辅助功能”列表。")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(EasyPasteTheme.cocoa)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statusBadge

                Spacer()

                if !coordinator.isAccessibilityTrusted {
                    HStack(spacing: 8) {
                        Button("打开设置") {
                            coordinator.beginAccessibilitySetup()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(EasyPasteTheme.accent, in: Capsule())

                        Button("刷新") {
                            coordinator.refreshAccessibilityStatus()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(EasyPasteTheme.cocoa)
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground(highlighted: !coordinator.isAccessibilityTrusted))
    }

    private var clipboardPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("当前剪贴板", systemImage: "sparkles")

            Text(store.clipboardText.isEmpty ? "当前没有可用文本" : store.clipboardText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(EasyPasteTheme.ink)
                .lineLimit(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(cardBackground())
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                coordinator.showPanel()
            } label: {
                HStack {
                    Image(systemName: "rectangle.grid.1x2.fill")
                    Text("打开剪贴板")
                    Spacer()
                    Text(coordinator.shortcutDisplayText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.18), in: Capsule())
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [EasyPasteTheme.accent, Color(red: 0.74, green: 0.34, blue: 0.16)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)

            Button("退出 EasyPaste") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(EasyPasteTheme.cocoa)
        }
    }

    private var statusBadge: some View {
        Text(coordinator.isAccessibilityTrusted ? "已授权" : "未授权")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(coordinator.isAccessibilityTrusted ? Color(red: 0.12, green: 0.43, blue: 0.24) : EasyPasteTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    coordinator.isAccessibilityTrusted
                        ? Color(red: 0.87, green: 0.96, blue: 0.89)
                        : EasyPasteTheme.accentSoft.opacity(0.72)
                )
            )
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(EasyPasteTheme.accent)
    }

    private func cardBackground(highlighted: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(highlighted ? EasyPasteTheme.accent.opacity(0.4) : EasyPasteTheme.line, lineWidth: 1)
            )
    }
}
