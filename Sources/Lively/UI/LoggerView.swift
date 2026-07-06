import SwiftUI

public struct LoggerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var logStore = LogStore.shared
    @State private var isExpanded = false
    @State private var isCopied = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("View and copy application logs for troubleshooting.")
                    .font(LivelyBrand.Typography.caption)
                    .foregroundStyle(LivelyBrand.mutedForeground)

                Spacer()

                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Hide Logs" : "View Logs")
                            .font(LivelyBrand.Typography.caption)
                        Group {
                            if !reduceMotion {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                                    .contentTransition(.symbolEffect(.replace))
                            } else {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScaleButtonStyle())
                .accessibilityLabel(isExpanded ? "Hide logs" : "Show logs")
                .background(
                    RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                        .strokeBorder(LivelyBrand.border.opacity(0.35))
                )
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(logStore.entries) { entry in
                                    Text(entry.text)
                                        .font(LivelyBrand.Typography.footnote.monospaced())
                                        .foregroundStyle(entry.isError ? LivelyBrand.destructive : LivelyBrand.mutedForeground)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(entry.id)
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: 150)
                        .background(LivelyBrand.logBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                                .strokeBorder(LivelyBrand.border.opacity(0.2))
                        )
                        .padding(.horizontal, 12)
                        .onChange(of: logStore.entries.count) { _, newCount in
                            if let last = logStore.entries.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            if let last = logStore.entries.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }

                    HStack {
                        Text(logStore.entries.contains(where: \.isError) ? "Errors present in log" : "Log ready")
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(LivelyBrand.mutedForeground)

                        Spacer()

                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(logStore.allLogsFormatted, forType: .string)

                            isCopied = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(2))
                                isCopied = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if isCopied {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LivelyBrand.primary)
                                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                                }
                                Text(isCopied ? "Copied" : "Copy Logs")
                                    .contentTransition(.opacity)
                            }
                            .animation(reduceMotion ? nil : LivelyBrand.Motion.fast, value: isCopied)
                            .font(LivelyBrand.Typography.caption)
                            .foregroundStyle(isCopied ? LivelyBrand.primary : LivelyBrand.foreground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .frame(minWidth: 32, minHeight: 32)
                        }
                        .buttonStyle(PressScaleButtonStyle())
                        .background(
                            RoundedRectangle(cornerRadius: LivelyBrand.Radius.sm)
                                .strokeBorder(isCopied ? LivelyBrand.primary : LivelyBrand.border.opacity(0.35))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -8)),
                    removal: .opacity.combined(with: .offset(y: -4))
                ))
            }
        }
        .animation(reduceMotion ? nil : LivelyBrand.Motion.normal, value: isExpanded)
    }
}