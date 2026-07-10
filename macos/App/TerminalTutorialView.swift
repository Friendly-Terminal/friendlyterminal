import SwiftUI

struct TerminalTutorialView: View {
    var onHide: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Self.sections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(LocalizedStringKey(section.body))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()
                    .padding(.top, 2)

                Button(action: onHide) {
                    Label("Got it — hide this", systemImage: "checkmark.circle")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Text("You can bring this back anytime from the settings (slider) button above.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    static let sections: [Section] = [
        Section(
            title: "What is the terminal?",
            body: "The terminal lets you control your Mac by typing instructions instead of clicking. You type a **command**, press **Return**, and it runs. The spot where you type is called the *prompt*."
        ),
        Section(
            title: "Where am I?",
            body: "A terminal is always \"inside\" one folder. Type `pwd` and press Return to print the full path of that folder. The folder's name also shows in the bar at the top of this window."
        ),
        Section(
            title: "Looking around",
            body: "Type `ls` to list the files and folders where you are. Use `ls -la` to also see hidden files and extra details. The list on the left shows the same thing visually."
        ),
        Section(
            title: "Moving between folders",
            body: "Use `cd` (change directory) followed by a folder's name to go into it, like `cd Documents`. Type `cd ..` to go up one level, or `cd ~` to jump to your home folder. You can also just click a folder in the sidebar."
        ),
        Section(
            title: "Understanding paths",
            body: "A *path* is the address of a file or folder. `~` means your home folder, `.` means \"here,\" and `..` means \"one folder up.\" Folders in a path are separated by `/`."
        ),
        Section(
            title: "Doing things",
            body: "Commands usually look like `name options target`. For example `mkdir notes` makes a new folder called notes, and `open .` opens the current folder in Finder. Browse the other groups in this menu for ready-to-run examples you can tap."
        ),
        Section(
            title: "Getting unstuck",
            body: "Press the **Up arrow** to bring back a command you ran before. Press **Tab** to auto-complete a file or folder name. Press **Control-C** to stop a command that's running. Add `--help` after a command, or run `man name`, to read what it does."
        ),
        Section(
            title: "A few good habits",
            body: "Nothing happens until you press Return, and commands are case-sensitive. If you're unsure what a command does, ask before running it — especially anything with `rm` (which deletes files) or `sudo` (which runs as administrator)."
        ),
        Section(
            title: "Using Claude Code (AI)",
            body: "Click the **Claude** button in the toolbar to start an AI coding session. Claude can read your files, fix bugs, write code, and answer questions — no command memorization needed. While Claude is running, the sidebar turns into a control panel with clickable Yes / No buttons and slash commands."
        ),
        Section(
            title: "Claude slash commands",
            body: "Inside a Claude session, special commands start with `/`. Type `/clear` to start a fresh conversation, `/compact` to save context when chats get long, `/help` to see all options, and `/exit` to leave Claude and return to the normal terminal."
        ),
    ]
}

#Preview {
    TerminalTutorialView(onHide: {})
        .frame(width: 240, height: 420)
}
