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
    public void Mkdir_trashes_every_new_folder()
    {
        var plan = Planner().Plan("mkdir a b", Cwd);
        Assert.Equal("Undo: delete 2 new folders", plan!.Label);
        Assert.Equal(
            new[] { "/Users/test/project/a", "/Users/test/project/b" },
            plan.Actions.Select(a => Assert.IsType<UndoAction.Trash>(a).Path));
    }

    [Fact]
    public void Mkdir_only_trashes_folders_it_creates()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/a");
        var plan = Planner(fs).Plan("mkdir a b", Cwd);
        var action = Assert.IsType<UndoAction.Trash>(Assert.Single(plan!.Actions));
        Assert.Equal("/Users/test/project/b", action.Path);
        Assert.Contains("b", plan.Label);
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

    [Fact]
    public void Mkdir_p_over_existing_folder_offers_no_undo()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        Assert.Null(Planner(fs).Plan("mkdir -p build", Cwd));
    }

    [Fact]
    public void Tar_over_existing_archive_offers_no_destructive_undo()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/out.tar");
        Assert.Null(Planner(fs).Plan("tar -cf out.tar build", Cwd));
    }

    [Fact]
    public void Git_add_paths_unstages_them()
    {
        var plan = Planner().Plan("git add file.txt", Cwd);
        var action = Assert.IsType<UndoAction.Shell>(Assert.Single(plan!.Actions));
        Assert.Equal("git restore --staged file.txt", action.Command);
    }

    [Theory]
    [InlineData("git add -A")]
    [InlineData("git add -u")]
    [InlineData("git add --all")]
    [InlineData("git add -n")]
    [InlineData("git add -p")]
    public void Git_add_with_flags_offers_no_undo(string command)
    {
        Assert.Null(Planner().Plan(command, Cwd));
    }

    [Fact]
    public void Git_add_mixing_flags_and_paths_offers_no_undo()
    {
        Assert.Null(Planner().Plan("git add -f secret.txt", Cwd));
    }

    [Fact]
    public void Cp_only_plans_for_exactly_two_operands()
    {
        var fs = new FakeFileSystem()
            .AddFile("/Users/test/project/a.txt")
            .AddFile("/Users/test/project/b.txt")
            .AddDir("/Users/test/project/dest");
        Assert.Null(Planner(fs).Plan("cp a.txt b.txt dest", Cwd));

        var plan = Planner(fs).Plan("cp a.txt dest", Cwd);
        var action = Assert.IsType<UndoAction.Trash>(Assert.Single(plan!.Actions));
        Assert.Equal("/Users/test/project/dest/a.txt", action.Path);
    }
}
