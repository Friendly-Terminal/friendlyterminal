using System.ComponentModel;
using System.Runtime.CompilerServices;
using FriendlyTerminal.Core.Output;
using FriendlyTerminal.Core.Undo;

namespace FriendlyTerminal.App.Models;

/// <summary>One command and its captured output, shown as a card in the block list.</summary>
public sealed class CommandBlock : INotifyPropertyChanged
{
    public Guid Id { get; } = Guid.NewGuid();
    public string Command { get; }
    public string Cwd { get; }
    public DateTime StartedAt { get; } = DateTime.Now;

    private string _plainText = "";
    private int? _exitCode;
    private RenderKind _renderKind = new RenderKind.PlainText();
    private UndoPlan? _undoPlan;
    private bool _isUndone;

    public CommandBlock(string command, string cwd)
    {
        Command = command;
        Cwd = cwd;
    }

    public string PlainText
    {
        get => _plainText;
        set => SetField(ref _plainText, value);
    }

    public int? ExitCode
    {
        get => _exitCode;
        set
        {
            if (SetField(ref _exitCode, value))
            {
                OnPropertyChanged(nameof(IsRunning));
                OnPropertyChanged(nameof(Succeeded));
                OnPropertyChanged(nameof(Failed));
            }
        }
    }

    public RenderKind RenderKind
    {
        get => _renderKind;
        set => SetField(ref _renderKind, value);
    }

    public UndoPlan? UndoPlan
    {
        get => _undoPlan;
        set => SetField(ref _undoPlan, value);
    }

    public bool IsUndone
    {
        get => _isUndone;
        set => SetField(ref _isUndone, value);
    }

    public bool IsRunning => _exitCode is null;
    public bool Succeeded => _exitCode == 0;
    public bool Failed => _exitCode is not null and not 0;

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(name);
        return true;
    }
}
