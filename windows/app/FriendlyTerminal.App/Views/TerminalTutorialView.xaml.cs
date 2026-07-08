using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

/// <summary>Beginner tutorial ("Get started") shown inside the command help panel.</summary>
public sealed partial class TerminalTutorialView : UserControl
{
    public event Action? HideRequested;

    private static readonly (string Title, string Body)[] Sections =
    {
        ("What is the terminal?",
         "The terminal lets you control your PC by typing instructions instead of clicking. You type a command, press Enter, and it runs. The spot where you type is called the prompt."),
        ("Where am I?",
         "A terminal is always \"inside\" one folder. Type Get-Location (or pwd) and press Enter to print the full path of that folder. The folder's name also shows in the bar at the top of this window."),
        ("Looking around",
         "Type ls (or Get-ChildItem) to list the files and folders where you are. Add -Force to also see hidden files. The list on the left shows the same thing visually."),
        ("Moving between folders",
         "Use cd followed by a folder's name to go into it, like cd Documents. Type cd .. to go up one level, or cd ~ to jump to your home folder. You can also just click a folder in the sidebar."),
        ("Understanding paths",
         "A path is the address of a file or folder. ~ means your home folder, . means \"here,\" and .. means \"one folder up.\" Folders in a path are separated by \\ on Windows."),
        ("Doing things",
         "Commands usually look like name options target. For example mkdir notes makes a new folder called notes, and Invoke-Item . opens the current folder in Explorer. Browse the other groups in this menu for ready-to-run examples you can tap."),
        ("Getting unstuck",
         "Press the Up arrow to bring back a command you ran before. Press Tab to auto-complete a file or folder name. Press Ctrl+C to stop a command that's running. Add -? after a command, or run Get-Help name, to read what it does."),
        ("A few good habits",
         "Nothing happens until you press Enter. If you're unsure what a command does, ask before running it — especially anything with Remove-Item (which deletes files) or anything run as administrator."),
        ("Using Claude Code (AI)",
         "Click the Claude button in the toolbar to start an AI coding session. Claude can read your files, fix bugs, write code, and answer questions — no command memorization needed. While Claude is running, the sidebar turns into a control panel with clickable buttons."),
        ("Claude slash commands",
         "Inside a Claude session, special commands start with /. Type /clear to start a fresh conversation, /compact to save context when chats get long, /help to see all options, and /exit to leave Claude and return to the normal terminal."),
    };

    public TerminalTutorialView()
    {
        InitializeComponent();
        foreach (var (title, body) in Sections)
        {
            var section = new StackPanel { Spacing = 4 };
            section.Children.Add(new TextBlock
            {
                Text = title,
                FontSize = 12,
                FontWeight = Microsoft.UI.Text.FontWeights.SemiBold,
            });
            section.Children.Add(new TextBlock
            {
                Text = body,
                FontSize = 11,
                Opacity = 0.7,
                TextWrapping = TextWrapping.Wrap,
                LineHeight = 16,
            });
            SectionsPanel.Children.Add(section);
        }
    }

    private void OnHide(object sender, RoutedEventArgs e) => HideRequested?.Invoke();
}
