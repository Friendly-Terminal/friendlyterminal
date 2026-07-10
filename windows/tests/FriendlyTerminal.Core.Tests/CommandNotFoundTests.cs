using FriendlyTerminal.Core.Help;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class CommandNotFoundTests
{
    [Fact]
    public void Extracts_term_from_powershell_error()
    {
        var output = "gti: The term 'gti' is not recognized as a name of a cmdlet, function, "
                     + "script file, or executable program.";
        Assert.Equal("gti", CommandNotFound.ExtractMissingTerm(output));
    }

    [Fact]
    public void Extracts_term_from_windows_powershell_error()
    {
        var output = "The term 'pyhton' is not recognized as the name of a cmdlet, function, "
                     + "script file, or operable program.";
        Assert.Equal("pyhton", CommandNotFound.ExtractMissingTerm(output));
    }

    [Fact]
    public void Extracts_term_from_cmd_style_error()
    {
        var output = "'nodee' is not recognized as an internal or external command,\noperable program or batch file.";
        Assert.Equal("nodee", CommandNotFound.ExtractMissingTerm(output));
    }

    [Fact]
    public void Unrelated_error_yields_no_term()
    {
        Assert.Null(CommandNotFound.ExtractMissingTerm("fatal: not a git repository"));
    }

    [Fact]
    public void Transposition_typo_is_corrected()
    {
        Assert.Equal("git status", CommandNotFound.SuggestCorrection("gti status", "gti"));
    }

    [Fact]
    public void Typo_in_longer_command_keeps_the_arguments()
    {
        Assert.Equal("python app.py", CommandNotFound.SuggestCorrection("pyhton app.py", "pyhton"));
    }

    [Fact]
    public void Cmdlet_typo_is_corrected()
    {
        Assert.Equal("Get-ChildItem", CommandNotFound.SuggestCorrection("Get-Chilitem", "Get-Chilitem"));
    }

    [Fact]
    public void Nothing_close_yields_no_suggestion()
    {
        Assert.Null(CommandNotFound.SuggestCorrection("frobnicate --all", "frobnicate"));
    }

    [Fact]
    public void Existing_command_yields_no_suggestion()
    {
        // The command exists, so the failure is not a typo we can fix.
        Assert.Null(CommandNotFound.SuggestCorrection("git status", "git"));
    }

    [Fact]
    public void Single_letter_term_yields_no_suggestion()
    {
        Assert.Null(CommandNotFound.SuggestCorrection("x", "x"));
    }
}
