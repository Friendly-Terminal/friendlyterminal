using FriendlyTerminal.Core.Output;
using FriendlyTerminal.Core.Platform;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class DetectorTests
{
    private static readonly PowerShellQuoter Quoter = new();

    [Fact]
    public void LsListing_renders_directory_contents_as_chips()
    {
        var fs = new FakeFileSystem()
            .AddDir("C:/proj/src")
            .AddFile("C:/proj/readme.md")
            .AddFile("C:/proj/.hidden");
        var detector = new LsListingDetector(fs, Quoter);

        var kind = detector.Detect("whatever", "ls", "C:/proj");

        var list = Assert.IsType<RenderKind.CommandList>(kind);
        Assert.Equal(["src", "readme.md"], list.Items.Select(i => i.Label));
        Assert.Equal("cd 'src'", list.Items[0].FollowUp);
        Assert.Equal("Invoke-Item 'readme.md'", list.Items[1].FollowUp);
    }

    [Fact]
    public void LsListing_includes_hidden_with_force_flag()
    {
        var fs = new FakeFileSystem().AddFile("C:/proj/.hidden").AddFile("C:/proj/a.txt");
        var detector = new LsListingDetector(fs, Quoter);

        var kind = detector.Detect("x", "Get-ChildItem -Force", "C:/proj");

        var list = Assert.IsType<RenderKind.CommandList>(kind);
        Assert.Contains(list.Items, i => i.Label == ".hidden");
    }

    [Fact]
    public void LsListing_ignores_other_directories_and_recurse()
    {
        var fs = new FakeFileSystem().AddFile("C:/proj/a.txt");
        var detector = new LsListingDetector(fs, Quoter);

        Assert.Null(detector.Detect("x", "ls somewhere", "C:/proj"));
        Assert.Null(detector.Detect("x", "gci -Recurse", "C:/proj"));
    }

    [Fact]
    public void GitLogOneline_builds_git_show_chips()
    {
        var detector = new GitLogOnelineDetector();
        var output = "6696bba Add feature\ne168c2b Fix undo\n";

        var kind = detector.Detect(output, "git log --oneline", "C:/proj");

        var list = Assert.IsType<RenderKind.CommandList>(kind);
        Assert.Equal(2, list.Items.Count);
        Assert.Equal("git show 6696bba", list.Items[0].FollowUp);
    }

    [Fact]
    public void GitTag_builds_checkout_chips()
    {
        var detector = new GitTagDetector(Quoter);
        var kind = detector.Detect("v1.0\nv1.1\n", "git tag", "C:/proj");

        var list = Assert.IsType<RenderKind.CommandList>(kind);
        Assert.Equal("git checkout 'v1.0'", list.Items[0].FollowUp);
    }

    [Fact]
    public void History_parses_powershell_get_history_table()
    {
        var detector = new HistoryDetector();
        var output = "  Id CommandLine\n  -- -----------\n   1 git status\n   2 ls\n";

        var kind = detector.Detect(output, "history", "C:/proj");

        var list = Assert.IsType<RenderKind.CommandList>(kind);
        Assert.Equal(["git status", "ls"], list.Items.Select(i => i.Label));
        Assert.Equal("git status", list.Items[0].FollowUp);
    }

    [Fact]
    public void CatImage_detects_existing_image_target()
    {
        var fs = new FakeFileSystem().AddFile("C:/proj/pic.png");
        var detector = new CatImageDetector(fs);

        var kind = detector.Detect("garbage", "cat pic.png", "C:/proj");

        Assert.Equal("pic.png", System.IO.Path.GetFileName(Assert.IsType<RenderKind.ImageFile>(kind).Path));
        Assert.Null(detector.Detect("x", "cat notes.txt", "C:/proj"));
    }

    [Fact]
    public void ImagePath_detects_rooted_image_output()
    {
        var fs = new FakeFileSystem().AddFile("C:\\shots\\out.png");
        var detector = new ImagePathDetector(fs);

        var kind = detector.Detect("saved to:\nC:\\shots\\out.png\n", "some-tool", "C:/proj");

        Assert.Equal("C:\\shots\\out.png", Assert.IsType<RenderKind.ImageFile>(kind).Path);
    }

    [Fact]
    public void Json_detects_multiline_json()
    {
        var detector = new JsonDetector();
        Assert.IsType<RenderKind.JsonTree>(detector.Detect("{\n  \"a\": 1\n}", "x", "C:/"));
        Assert.Null(detector.Detect("{ not json", "x", "C:/"));
        Assert.Null(detector.Detect("{\"a\":1}", "x", "C:/")); // single line stays text
    }

    [Fact]
    public void Csv_detects_consistent_comma_rows()
    {
        var detector = new CsvDetector();
        var kind = detector.Detect("a,b,c\n1,2,3\n4,5,6\n", "x", "C:/");

        var csv = Assert.IsType<RenderKind.CsvTable>(kind);
        Assert.Equal(3, csv.Rows.Count);
        Assert.Equal(["a", "b", "c"], csv.Rows[0]);
    }

    [Fact]
    public void Table_detects_column_aligned_output()
    {
        var detector = new TableDetector();
        var output =
            "NAME      STATUS    AGE\n" +
            "web       Running   2d\n" +
            "db        Running   5d\n";

        var kind = detector.Detect(output, "kubectl get pods", "C:/");

        var table = Assert.IsType<RenderKind.Table>(kind);
        Assert.Equal(3, table.Rows.Count);
        Assert.Equal(["NAME", "STATUS", "AGE"], table.Rows[0]);
    }

    [Fact]
    public void Pipeline_prefers_command_list_over_generic_table()
    {
        var fs = new FakeFileSystem().AddDir("C:/proj/src").AddFile("C:/proj/a.txt");
        var pipeline = new OutputRenderingPipeline(fs, Quoter);

        var kind = pipeline.Process("col col col\ncol col col\ncol col col", "ls", "C:/proj");

        Assert.IsType<RenderKind.CommandList>(kind);
    }
}
