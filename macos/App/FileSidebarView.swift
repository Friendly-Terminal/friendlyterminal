import AppKit
import QuickLookUI
import SwiftUI

@MainActor private func openQuickLook(url: URL) {
    let panel = QLPreviewPanel.shared()
    panel?.currentPreviewItemIndex = 0
    QuickLookDataSource.shared.url = url
    panel?.dataSource = QuickLookDataSource.shared
    panel?.makeKeyAndOrderFront(nil)
}

@MainActor private final class QuickLookDataSource: NSObject, @preconcurrency QLPreviewPanelDataSource, @unchecked Sendable {
    static let shared = QuickLookDataSource()
    var url: URL?

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { url != nil ? 1 : 0 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as NSURL?
    }
}

struct FileSidebarView: View {
    @Environment(SessionState.self) private var session
    @State private var selectedItemID: UUID?
    @State private var showHidden: Bool = false
    @State private var itemToDelete: FileItem?
    @State private var showDeleteConfirm: Bool = false
    @State private var quickLookURL: URL?
    @State private var renameItem: FileItem?
    @State private var renameText: String = ""

    private var visibleItems: [FileItem] {
        showHidden ? session.fileItems : session.fileItems.filter { !$0.isHidden }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showHidden.toggle()
                } label: {
                    Image(systemName: showHidden ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(showHidden ? "Hide hidden files" : "Show hidden files")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if visibleItems.isEmpty {
                Spacer()
                Text("Empty folder")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(visibleItems) { item in
                            SidebarRowView(item: item, isSelected: selectedItemID == item.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    handleTap(item)
                                }
                                .contextMenu {
                                    sidebarContextMenu(for: item)
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            HStack {
                Text("\(visibleItems.count) item\(visibleItems.count == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .confirmationDialog(
            "Move \"\(itemToDelete?.name ?? "")\" to Trash?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                if let item = itemToDelete {
                    moveToTrash(item)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action moves the item to the Trash.")
        }
        .sheet(isPresented: Binding(get: { renameItem != nil }, set: { if !$0 { renameItem = nil } })) {
            RenameSheetView(
                originalName: renameItem?.name ?? "",
                currentText: $renameText
            ) { newName in
                if let item = renameItem {
                    renameFile(item, to: newName)
                }
                renameItem = nil
            } onCancel: {
                renameItem = nil
            }
        }
        .onChange(of: quickLookURL) { _, url in
            if let url { openQuickLook(url: url) }
        }
    }

    private func handleTap(_ item: FileItem) {
        selectedItemID = item.id
        if item.isDirectory {
            session.navigateShellTo(item.path)
        } else {
            quickLookURL = URL(fileURLWithPath: item.path)
        }
    }

    @ViewBuilder
    private func sidebarContextMenu(for item: FileItem) -> some View {
        if item.isDirectory {
            Button("Open in Terminal") {
                session.navigateShellTo(item.path)
            }
        } else {
            Button("Quick Look") {
                quickLookURL = URL(fileURLWithPath: item.path)
            }
        }

        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
        }

        Button("Open with Default App") {
            NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
        }

        Divider()

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.path, forType: .string)
        }

        Button("Copy Name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.name, forType: .string)
        }

        Divider()

        Button("Rename…") {
            renameText = item.name
            renameItem = item
        }

        Button("Move to Trash", role: .destructive) {
            itemToDelete = item
            showDeleteConfirm = true
        }
    }

    private func moveToTrash(_ item: FileItem) {
        let url = URL(fileURLWithPath: item.path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        session.refreshFileItems()
    }

    private func renameFile(_ item: FileItem, to newName: String) {
        let src = URL(fileURLWithPath: item.path)
        let dst = src.deletingLastPathComponent().appendingPathComponent(newName)
        try? FileManager.default.moveItem(at: src, to: dst)
        session.refreshFileItems()
    }
}

private struct SidebarRowView: View {
    let item: FileItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.systemImage)
                .font(.system(size: 12))
                .foregroundStyle(item.isDirectory ? .blue : .secondary)
                .frame(width: 16)

            Text(item.name)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !item.isDirectory {
                Text(item.sizeFormatted)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

private struct RenameSheetView: View {
    let originalName: String
    @Binding var currentText: String
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename \"\(originalName)\"")
                .font(.headline)

            TextField("New name", text: $currentText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 300)
                .onSubmit { confirm() }

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: confirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(currentText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
    }

    private func confirm() {
        let trimmed = currentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
    }
}

#Preview {
    FileSidebarView()
        .environment(SessionState())
        .frame(width: 220, height: 500)
}
