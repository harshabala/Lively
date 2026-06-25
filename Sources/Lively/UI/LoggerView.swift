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
                    .font(.system(size: 12))
                    .foregroundStyle(LivelyBrand.mutedForeground)

                Spacer()

                Button {
                    isExpanded.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Hide Logs" : "View Logs")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .background(RoundedRectangle(cornerRadius: 6).strokeBorder(LivelyBrand.border.opacity(0.35)))
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(logStore.entries.enumerated()), id: \.offset) { index, log in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(log)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(log.contains("ERROR:") ? LivelyBrand.destructive : LivelyBrand.mutedForeground)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .id(index)
                                }
                            }
                            .padding(12)
                        }
                        .frame(height: 150)
                        .background(Color.black.opacity(0.03))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(LivelyBrand.border.opacity(0.2))
                        )
                        .padding(.horizontal, 12)
                        .onChange(of: logStore.entries.count) { _, newCount in
                            if newCount > 0 {
                                proxy.scrollTo(newCount - 1, anchor: .bottom)
                            }
                        }
                        .onAppear {
                            if logStore.entries.count > 0 {
                                proxy.scrollTo(logStore.entries.count - 1, anchor: .bottom)
                            }
                        }
                    }

                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(logStore.entries.contains(where: { $0.contains("ERROR:") }) ? Color.red : Color.green)
                                .frame(width: 8, height: 8)
                            Text(logStore.entries.contains(where: { $0.contains("ERROR:") }) ? "Issues found" : "No issues found")
                                .font(.system(size: 12))
                                .foregroundStyle(LivelyBrand.mutedForeground)
                        }

                        Spacer()

                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(logStore.allLogsFormatted, forType: .string)

                            isCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                isCopied = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if isCopied {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LivelyBrand.primary)
                                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                                }
                                Text(isCopied ? "Copied" : "Copy Logs")
                                    .contentTransition(.opacity)
                            }
                            .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.2), value: isCopied)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isCopied ? LivelyBrand.primary : LivelyBrand.foreground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .background(RoundedRectangle(cornerRadius: 6).strokeBorder(isCopied ? LivelyBrand.primary : LivelyBrand.border.opacity(0.35)))
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
