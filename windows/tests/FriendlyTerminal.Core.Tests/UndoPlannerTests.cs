using FriendlyTerminal.Core.Platform;
using FriendlyTerminal.Core.Undo;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class UndoPlannerTests
{
    private const string Cwd = "/Users/test/project";

    private static UndoPlanner Planner(FakeFileSystem? fs = null) =>
        new(fs ?? new FakeFileSystem(), new PowerShellQuoter());

    [Fact]
    public void Cd_goes_back_to_previous_directory()
    {
        var plan = Planner().Plan("cd /tmp", Cwd);
        var action = Assert.IsType<UndoAction.Shell>(Assert.Single(plan!.Actions));
        Assert.Equal("cd '/Users/test/project'", action.Command);
        Assert.Contains("project", plan.Label);
    }

    [Fact]
    public void Mkdir_trashes_created_folder()
    {
        var plan = Planner().Plan("mkdir build", Cwd);
        var action = Assert.IsType<UndoAction.Trash>(Assert.Single(plan!.Actions));
        Assert.Equal("/Users/test/project/build", action.Path);
    }

    [Fact]
    public void Git_commit_soft_resets()
    {
        var plan = Planner().Plan("git commit -m hello", Cwd);
        var action = Assert.IsType<UndoAction.Shell>(Assert.Single(plan!.Actions));
        Assert.Equal("git reset --soft HEAD~1", action.Command);
    }

    [Fact]
    public void Winget_install_uninstalls()
    {
        var plan = Planner().Plan("winget install wget", Cwd);
        var action = Assert.IsType<UndoAction.Shell>(Assert.Single(plan!.Actions));
        Assert.Equal("winget uninstall wget", action.Command);
    }

    [Fact]
    public void Export_removes_env_var()
    {
        var plan = Planner().Plan("export FOO=bar", Cwd);
        var action = Assert.IsType<UndoAction.Shell>(Assert.Single(plan!.Actions));
        Assert.Equal("Remove-Item Env:\\FOO", action.Command);
    }

    [Fact]
    public void Touch_only_undoes_files_it_creates()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/existing.txt");
        Assert.Null(Planner(fs).Plan("touch existing.txt", Cwd));

        var plan = Planner(fs).Plan("touch fresh.txt", Cwd);
        var action = Assert.IsType<UndoAction.Trash>(Assert.Single(plan!.Actions));
        Assert.Equal("/Users/test/project/fresh.txt", action.Path);
    }

    [Fact]
    public void Touch_needs_pre_state()
    {
        Assert.Null(Planner().Plan("touch fresh.txt", Cwd, allowPreState: false));
    }

    [Fact]
    public void Unsafe_commands_are_rejected()
    {
        Assert.Null(Planner().Plan("echo $HOME", Cwd));
        Assert.Null(Planner().Plan("mkdir a && mkdir b", Cwd));
    }

    [Fact]
    public void Read_only_commands_have_no_plan()
    {
        Assert.Null(Planner().Plan("ls -la", Cwd));
        Assert.Null(Planner().Plan("git status", Cwd));
    }

    [Fact]
    public void Mkdir_force_over_existing_folder_offers_no_destructive_undo()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        Assert.Null(Planner(fs).Plan("mkdir -Force build", Cwd));
    }

    [Fact]
    public void Mkdir_without_pre_state_offers_no_undo()
    {
        Assert.Null(Planner().Plan("mkdir build", Cwd, allowPreState: false));
    }

    [Fact]
    public void Zip_over_existing_archive_offers_no_destructive_undo()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/out.zip");
        Assert.Null(Planner(fs).Plan("zip out.zip build", Cwd));

        var plan = Planner().Plan("zip fresh.zip build", Cwd);
        var action = Assert.IsType<UndoAction.Trash>(Assert.Single(plan!.Actions));
        Assert.Equal("/Users/test/project/fresh.zip", action.Path);
    }

    [Fact]
    public void Curl_over_existing_output_offers_no_destructive_undo()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/data.json");
        Assert.Null(Planner(fs).Plan("curl -o data.json http://x", Cwd));
    }

    [Fact]
    public void Mv_over_existing_file_offers_no_undo()
    {
        var fs = new FakeFileSystem()
            .AddFile("/Users/test/project/src.txt")
            .AddFile("/Users/test/project/dest.txt");
        Assert.Null(Planner(fs).Plan("mv src.txt dest.txt", Cwd));
    }

    [Fact]
    public void Archive_and_download_undo_need_pre_state()
    {
        Assert.Null(Planner().Plan("zip out.zip build", Cwd, allowPreState: false));
        Assert.Null(Planner().Plan("tar -cf out.tar build", Cwd, allowPreState: false));
        Assert.Null(Planner().Plan("curl -o data.json http://x", Cwd, allowPreState: false));
    }
}
