import SwiftUI

struct BreadcrumbBarView: View {
    @Environment(SessionState.self) private var session
    @Environment(Workspace.self) private var workspace

    var body: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    workspace.sidebarVisible.toggle()
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Toggle sidebar")

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(Array(session.breadcrumbs.enumerated()), id: \.element.id) { index, crumb in
                            HStack(spacing: 2) {
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }

                                Button(crumb.name) {
                                    session.navigateShellTo(crumb.path)
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 12, weight: index == session.breadcrumbs.count - 1 ? .semibold : .regular))
                                .foregroundStyle(index == session.breadcrumbs.count - 1 ? .primary : .secondary)
                                .id(crumb.id)
                            }
                        }
                    }
                }
                .onChange(of: session.breadcrumbs.last?.id) { _, newID in
                    if let id = newID {
                        withAnimation { proxy.scrollTo(id, anchor: .trailing) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                session.refreshFileItems()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { workspace.addPane() }
            } label: {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .foregroundStyle(workspace.canAddPane ? .secondary : .tertiary)
            }
            .buttonStyle(.plain)
            .disabled(!workspace.canAddPane)
            .help("Add another terminal")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
    }
}

#Preview {
    BreadcrumbBarView()
        .environment(SessionState())
        .environment(Workspace())
        .frame(width: 600)
}
