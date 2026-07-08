using System.Collections.Specialized;
using System.ComponentModel;
using System.Diagnostics;
using FriendlyTerminal.App.Models;
using FriendlyTerminal.Core.Platform;
using Microsoft.VisualBasic.FileIO;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using Windows.ApplicationModel.DataTransfer;

namespace FriendlyTerminal.App.Views;

public sealed partial class FileSidebarView : UserControl
{
    private SessionState? _session;
    private static readonly PowerShellQuoter Quoter = new();

    public SessionState? Session
    {
        get => _session;
        set
        {
            if (_session is not null)
            {
                _session.Files.CollectionChanged -= FilesChanged;
                _session.PropertyChanged -= SessionPropertyChanged;
            }
            _session = value;
            if (_session is null) return;
            FileList.ItemsSource = _session.Files;
            _session.Files.CollectionChanged += FilesChanged;
            _session.PropertyChanged += SessionPropertyChanged;
            UpdateHeader();
            UpdateToggle();
            UpdateFooter();
        }
    }

    public FileSidebarView()
    {
        InitializeComponent();
    }

    private void FilesChanged(object? sender, NotifyCollectionChangedEventArgs e) => UpdateFooter();

    private void SessionPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        if (e.PropertyName == nameof(SessionState.CurrentDirectory))
            UpdateHeader();
        else if (e.PropertyName == nameof(SessionState.ShowHidden))
            UpdateToggle();
    }

    private void UpdateHeader()
    {
        PathText.Text = _session?.CurrentDirectory ?? "";
    }

    private void UpdateToggle()
    {
        HiddenToggle.IsChecked = _session?.ShowHidden ?? false;
    }

    private void UpdateFooter()
    {
        var n = _session?.Files.Count ?? 0;
        FooterText.Text = $"{n} item" + (n == 1 ? "" : "s");
        EmptyState.Visibility = n == 0 ? Visibility.Visible : Visibility.Collapsed;
    }

    private void OnToggleHidden(object sender, RoutedEventArgs e)
    {
        if (_session is not null)
            _session.ShowHidden = !_session.ShowHidden;
    }

    private void OnItemClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not FileEntry entry || _session is null) return;
        if (entry.IsDirectory)
            _session.SendToShell?.Invoke($"Set-Location {Quoter.Quote(entry.Path)}\n");
        else
            OpenWithDefault(entry.Path);
    }

    private void OnItemRightTapped(object sender, RightTappedRoutedEventArgs e)
    {
        if (_session is null) return;
        if (e.OriginalSource is not FrameworkElement fe || fe.DataContext is not FileEntry entry) return;
        BuildMenu(entry).ShowAt(fe, e.GetPosition(fe));
        e.Handled = true;
    }

    private MenuFlyout BuildMenu(FileEntry entry)
    {
        var flyout = new MenuFlyout();

        var open = new MenuFlyoutItem { Text = entry.IsDirectory ? "Open in Terminal" : "Open" };
        open.Click += (_, _) =>
        {
            if (entry.IsDirectory)
                _session?.SendToShell?.Invoke($"Set-Location {Quoter.Quote(entry.Path)}\n");
            else
                OpenWithDefault(entry.Path);
        };

        var reveal = new MenuFlyoutItem { Text = "Reveal in Explorer" };
        reveal.Click += (_, _) => Process.Start("explorer.exe", $"/select,\"{entry.Path}\"");

        var copy = new MenuFlyoutItem { Text = "Copy path" };
        copy.Click += (_, _) => CopyText(entry.Path);

        var copyName = new MenuFlyoutItem { Text = "Copy name" };
        copyName.Click += (_, _) => CopyText(entry.Name);

        var rename = new MenuFlyoutItem { Text = "Rename…" };
        rename.Click += async (_, _) => await RenameAsync(entry);

        var trash = new MenuFlyoutItem { Text = "Move to Recycle Bin" };
        trash.Click += (_, _) =>
        {
            try
            {
                if (entry.IsDirectory)
                    FileSystem.DeleteDirectory(entry.Path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
                else
                    FileSystem.DeleteFile(entry.Path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
                _session?.RefreshFiles();
            }
            catch { }
        };

        flyout.Items.Add(open);
        flyout.Items.Add(reveal);
        flyout.Items.Add(copy);
        flyout.Items.Add(copyName);
        flyout.Items.Add(new MenuFlyoutSeparator());
        flyout.Items.Add(rename);
        flyout.Items.Add(trash);
        return flyout;
    }

    private async Task RenameAsync(FileEntry entry)
    {
        var box = new TextBox { Text = entry.Name, SelectionStart = entry.Name.Length };
        var dialog = new ContentDialog
        {
            Title = $"Rename \"{entry.Name}\"",
            Content = box,
            PrimaryButtonText = "Rename",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
            XamlRoot = XamlRoot,
        };
        if (await dialog.ShowAsync() != ContentDialogResult.Primary) return;

        var newName = box.Text.Trim();
        if (newName.Length == 0 || newName == entry.Name) return;
        try
        {
            var dir = System.IO.Path.GetDirectoryName(entry.Path)!;
            var dest = System.IO.Path.Combine(dir, newName);
            if (entry.IsDirectory)
                System.IO.Directory.Move(entry.Path, dest);
            else
                System.IO.File.Move(entry.Path, dest);
            _session?.RefreshFiles();
        }
        catch { }
    }

    private static void OpenWithDefault(string path)
    {
        try { Process.Start(new ProcessStartInfo(path) { UseShellExecute = true }); }
        catch { }
    }

    private static void CopyText(string text)
    {
        try
        {
            var package = new DataPackage { RequestedOperation = DataPackageOperation.Copy };
            package.SetText(text);
            Clipboard.SetContent(package);
        }
        catch { }
    }
}
