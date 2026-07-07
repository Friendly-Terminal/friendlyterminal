using FriendlyTerminal.Core.Help;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FriendlyTerminal.App.Views;

public sealed partial class CommandHelpView : UserControl
{
    private SessionState? _session;
    private CommandCategory? _selected;
    private bool _showingTutorial;
    private string _search = "";
    private readonly HelpSettings _settings = HelpSettings.Instance;

    // Category icon-key -> Segoe Fluent Icons code point (verified against Microsoft Learn).
    private static readonly Dictionary<string, int> CategoryGlyphs = new()
    {
        ["folder"] = 0xE8B7,
        ["file"] = 0xE8A5,
        ["github"] = 0xE943,
        ["ai"] = 0xE99A,
        ["search"] = 0xE721,
        ["system"] = 0xE977,
        ["network"] = 0xE968,
        ["lock"] = 0xE72E,
        ["cpu"] = 0xEEA1,
        ["archive"] = 0xF012,
        ["text"] = 0xE8C1,
        ["edit"] = 0xE70F,
        ["package"] = 0xE7B8,
        ["cube"] = 0xE7B8,
        ["python"] = 0xEC7A,
        ["node"] = 0xEC7A,
        ["store"] = 0xE7BF,
        ["docker"] = 0xE950,
        ["env"] = 0xE713,
        ["remote"] = 0xE8AF,
        ["disk"] = 0xEDA2,
        ["more"] = 0xE712,
    };

    public SessionState? Session
    {
        get => _session;
        set => _session = value;
    }

    public CommandHelpView()
    {
        InitializeComponent();
        Render();
    }

    private static string GlyphOf(string key) =>
        CategoryGlyphs.TryGetValue(key, out var code) ? char.ConvertFromUtf32(code) : char.ConvertFromUtf32(0xE7C3);

    private void OnSearchChanged(object sender, TextChangedEventArgs e)
    {
        _search = SearchBox.Text;
        Render();
    }

    private void OnBack(object sender, RoutedEventArgs e)
    {
        _search = "";
        _selected = null;
        _showingTutorial = false;
        SearchBox.Text = "";
        Render();
    }

    private void OnCategoryClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not CategoryTile tile) return;
        if (tile.Category is null)
        {
            _showingTutorial = true;
            if (TutorialHost.Content is null)
            {
                var tutorial = new TerminalTutorialView();
                tutorial.HideRequested += () =>
                {
                    _settings.SetTutorialVisible(false);
                    _showingTutorial = false;
                    Render();
                };
                TutorialHost.Content = tutorial;
            }
        }
        else
        {
            _selected = tile.Category;
        }
        Render();
    }

    private void OnCommandClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not CommandRow row || _session is null) return;

        // Load the command into the command bar for editing, matching the macOS
        // behavior. Dangerous commands are flagged with a warning icon, not run.
        _session.PrefillCommand(row.Command);
    }

    private async void OnSettings(object sender, RoutedEventArgs e)
    {
        var list = new StackPanel { Spacing = 2 };

        var tutorialToggle = new ToggleSwitch
        {
            Header = "Get started  (beginner tutorial)",
            IsOn = _settings.TutorialVisible,
            HorizontalContentAlignment = HorizontalAlignment.Stretch,
        };
        tutorialToggle.Toggled += (s, _) => _settings.SetTutorialVisible(((ToggleSwitch)s).IsOn);
        list.Children.Add(tutorialToggle);

        foreach (var category in CommandCatalog.All)
        {
            var toggle = new ToggleSwitch
            {
                Header = $"{category.Name}  ({category.Commands.Count})",
                IsOn = _settings.IsEnabled(category.Id),
                Tag = category.Id,
                HorizontalContentAlignment = HorizontalAlignment.Stretch,
            };
            toggle.Toggled += (s, _) =>
            {
                var t = (ToggleSwitch)s;
                _settings.SetEnabled((string)t.Tag, t.IsOn);
            };
            list.Children.Add(toggle);
        }

        var dialog = new ContentDialog
        {
            Title = "Command groups",
            Content = new ScrollViewer
            {
                Content = list,
                MaxHeight = 420,
                VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            },
            CloseButtonText = "Done",
            XamlRoot = XamlRoot,
        };

        await dialog.ShowAsync();

        // A category the user turned off should not stay open behind the dialog.
        if (_selected is not null && !_settings.IsEnabled(_selected.Id))
            _selected = null;
        if (_showingTutorial && !_settings.TutorialVisible)
            _showingTutorial = false;
        Render();
    }

    private void Render()
    {
        var drilled = _selected is not null || _showingTutorial;
        var searching = !drilled && !string.IsNullOrWhiteSpace(_search);
        var atRoot = !drilled && !searching;

        SearchBox.Visibility = drilled ? Visibility.Collapsed : Visibility.Visible;
        BackButton.Visibility = (drilled || searching) ? Visibility.Visible : Visibility.Collapsed;
        SettingsButton.Visibility = atRoot ? Visibility.Visible : Visibility.Collapsed;
        TitleText.Text = _showingTutorial
            ? "Get started"
            : (_selected is not null ? _selected.Name : (searching ? "Search" : "Help with commands"));

        EmptyState.Visibility = Visibility.Collapsed;
        TutorialHost.Visibility = _showingTutorial ? Visibility.Visible : Visibility.Collapsed;

        if (_showingTutorial)
        {
            CategoryGrid.Visibility = Visibility.Collapsed;
            CommandList.Visibility = Visibility.Collapsed;
        }
        else if (drilled)
        {
            CategoryGrid.Visibility = Visibility.Collapsed;
            CommandList.Visibility = Visibility.Visible;
            CommandList.ItemsSource = _selected!.Commands
                .Select(i => new CommandRow(i.Command, i.Detail, null, i.IsDangerous))
                .ToList();
        }
        else if (searching)
        {
            CategoryGrid.Visibility = Visibility.Collapsed;
            CommandList.Visibility = Visibility.Visible;
            CommandList.ItemsSource = CommandSearch.Search(CommandCatalog.All, _search)
                .Select(h => new CommandRow(h.Item.Command, h.Item.Detail, h.Category.Name, h.Item.IsDangerous))
                .ToList();
        }
        else
        {
            var tiles = new List<CategoryTile>();
            if (_settings.TutorialVisible)
                tiles.Add(new CategoryTile("Get started", char.ConvertFromUtf32(0xE7BE), null));
            tiles.AddRange(CommandCatalog.All
                .Where(c => _settings.IsEnabled(c.Id))
                .Select(c => new CategoryTile(c.Name, GlyphOf(c.Icon), c)));
            CommandList.Visibility = Visibility.Collapsed;
            CategoryGrid.Visibility = tiles.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            EmptyState.Visibility = tiles.Count > 0 ? Visibility.Collapsed : Visibility.Visible;
            CategoryGrid.ItemsSource = tiles;
        }
    }
}

internal sealed record CategoryTile(string Name, string Glyph, CommandCategory? Category);

internal sealed record CommandRow(string Command, string Detail, string? Badge, bool IsDangerous)
{
    public Visibility DangerVisibility => IsDangerous ? Visibility.Visible : Visibility.Collapsed;
    public Visibility BadgeVisibility => string.IsNullOrEmpty(Badge) ? Visibility.Collapsed : Visibility.Visible;
}
