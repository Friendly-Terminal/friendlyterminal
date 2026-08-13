using FriendlyTerminal.Core.Undo;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class RmInterceptorTests
{
    private const string Cwd = "/Users/test/project";

    [Fact]
    public void Recognizes_safe_rm_of_existing_targets()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        var targets = new RmInterceptor(fs).SafeTargets("rm -rf build", Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Rejects_empty_quoted_target_instead_of_trashing_cwd()
    {
        var fs = new FakeFileSystem().AddDir(Cwd);
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm \"\"", Cwd));
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -rf ''", Cwd));
    }

    [Fact]
    public void Rejects_globs_and_metacharacters()
    {
        var fs = new FakeFileSystem();
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm *.txt", Cwd));
    }

    [Fact]
    public void Rejects_missing_targets()
    {
        var fs = new FakeFileSystem();
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm gone.txt", Cwd));
    }

    [Fact]
    public void Rejects_unknown_flags()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/a.txt");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -z a.txt", Cwd));
    }

    [Theory]
    [InlineData("Remove-Item -Recurse -Force build")]
    [InlineData("del -r build")]
    [InlineData("rd -r build")]
    [InlineData("ri -r build")]
    [InlineData("erase -r build")]
    [InlineData("rmdir -r build")]
    [InlineData("Rm -rf build")]
    [InlineData("REMOVE-ITEM -Recurse build")]
    [InlineData("rm -re -fo build")]
    public void Recognizes_powershell_deletion_forms(string command)
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        var targets = new RmInterceptor(fs).SafeTargets(command, Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Recognizes_quoted_path_with_spaces()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/my build");
        var targets = new RmInterceptor(fs).SafeTargets("Remove-Item -Recurse \"my build\"", Cwd);
        Assert.Equal(new[] { "/Users/test/project/my build" }, targets);
    }

    [Fact]
    public void Resolves_windows_absolute_target()
    {
        var fs = new FakeFileSystem().AddDir("C:\\proj\\build");
        var targets = new RmInterceptor(fs).SafeTargets("Remove-Item -Recurse C:\\proj\\build", "C:\\proj");
        Assert.Equal(new[] { "C:\\proj\\build" }, targets);
    }

    [Fact]
    public void Rejects_powershell_switch_that_is_not_recurse_or_force()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/a.txt");
        Assert.Null(new RmInterceptor(fs).SafeTargets("Remove-Item -WhatIf a.txt", Cwd));
    }

    [Fact]
    public void Rejects_unbalanced_quotes()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm \"build", Cwd));
    }

    [Theory]
    [InlineData("rm -rf .")]
    [InlineData("rm -rf ..")]
    [InlineData("rm -rf ../project")]
    [InlineData("rm -rf ./..")]
    [InlineData("rm -rf /Users/test/project")]
    [InlineData("rm -rf /Users/test")]
    public void Rejects_cwd_and_ancestors_including_dot_dot_forms(string command)
    {
        var fs = new FakeFileSystem()
            .AddDir("/Users/test")
            .AddDir("/Users/test/project")
            .AddDir("/Users/test/project/build");
        Assert.Null(new RmInterceptor(fs).SafeTargets(command, Cwd));
    }

    [Theory]
    [InlineData("rm -rf ./build")]
    [InlineData("rm -rf ././build")]
    [InlineData("rm -rf sub/../build")]
    public void Normalizes_dot_segments_and_still_intercepts(string command)
    {
        var fs = new FakeFileSystem()
            .AddDir("/Users/test/project/sub")
            .AddDir("/Users/test/project/build");
        var targets = new RmInterceptor(fs).SafeTargets(command, Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Declines_directory_target_without_recursive_flag()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/build");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm build", Cwd));
        Assert.Null(new RmInterceptor(fs).SafeTargets("del build", Cwd));
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -f build", Cwd));
    }

    [Fact]
    public void Accepts_empty_directory_with_dash_d()
    {
        var fs = new FakeFileSystem().AddDir("/Users/test/project/empty");
        var targets = new RmInterceptor(fs).SafeTargets("rm -d empty", Cwd);
        Assert.Equal(new[] { "/Users/test/project/empty" }, targets);
    }

    [Fact]
    public void Declines_non_empty_directory_with_dash_d_only()
    {
        var fs = new FakeFileSystem()
            .AddDir("/Users/test/project/build")
            .AddFile("/Users/test/project/build/a.txt");
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -d build", Cwd));
        Assert.Null(new RmInterceptor(fs).SafeTargets("rm -fd build", Cwd));
    }

    [Fact]
    public void Accepts_non_empty_directory_when_recursive_flag_is_present()
    {
        var fs = new FakeFileSystem()
            .AddDir("/Users/test/project/build")
            .AddFile("/Users/test/project/build/a.txt");
        var targets = new RmInterceptor(fs).SafeTargets("rm -rd build", Cwd);
        Assert.Equal(new[] { "/Users/test/project/build" }, targets);
    }

    [Fact]
    public void Accepts_file_target_without_flags()
    {
        var fs = new FakeFileSystem().AddFile("/Users/test/project/a.txt");
        var targets = new RmInterceptor(fs).SafeTargets("rm a.txt", Cwd);
        Assert.Equal(new[] { "/Users/test/project/a.txt" }, targets);
    }
}
