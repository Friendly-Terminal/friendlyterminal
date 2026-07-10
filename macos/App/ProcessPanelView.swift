import SwiftUI

struct ProcessPanelView: View {
    @State private var monitor = ProcessMonitor()
    @State private var confirmKillID: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if monitor.entries.isEmpty && !monitor.isBusy {
                emptyState
            } else {
                processList
            }
        }
        .frame(width: 460, height: 500)
        .onAppear { monitor.startAutoRefresh() }
        .onDisappear { monitor.stopAutoRefresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.accentColor)

            Text("What's Running")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            if monitor.isBusy {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 18)
            } else {
                Button {
                    confirmKillID = nil
                    monitor.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            Button("Done") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 13))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var processList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(monitor.entries) { entry in
                    processRow(entry)
                    Divider().opacity(0.5)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func processRow(_ entry: RunningProcess) -> some View {
        HStack(spacing: 10) {
            Text(":\(entry.port)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(entry.isWebServer ? Color.accentColor : Color.secondary)
                )
                .frame(minWidth: 54, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.friendlyName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(entry.command)  ·  PID \(entry.pid)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                if entry.isWebServer {
                    Button {
                        if let url = URL(string: "http://localhost:\(entry.port)") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open", systemImage: "safari")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(ProcessActionStyle(color: .accentColor))
                    .help("Open in browser")
                }

                if confirmKillID == entry.id {
                    Button("Kill?") {
                        confirmKillID = nil
                        monitor.kill(entry)
                    }
                    .buttonStyle(ProcessActionStyle(color: .red))

                    Button("Cancel") { confirmKillID = nil }
                        .buttonStyle(ProcessActionStyle(color: .secondary))
                } else {
                    Button {
                        confirmKillID = entry.id
                    } label: {
                        Label("Kill", systemImage: "xmark.circle")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(ProcessActionStyle(color: .secondary))
                    .help("Send SIGTERM to stop this process")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("Nothing listening on a port")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Start a dev server and it'll appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ProcessActionStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color == .secondary ? Color.secondary : Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(color == .secondary
                          ? Color(nsColor: .controlBackgroundColor)
                          : color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(color == .secondary
                            ? Color(nsColor: .separatorColor).opacity(0.5)
                            : Color.clear, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    ProcessPanelView()
}
