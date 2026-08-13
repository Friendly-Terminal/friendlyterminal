using FriendlyTerminal.Core.Agents;
using Xunit;

namespace FriendlyTerminal.Core.Tests;

public class AgentRegistryTests
{
    [Theory]
    [InlineData("claude", "claude")]
    [InlineData("codex", "codex")]
    [InlineData("gemini", "gemini")]
    [InlineData("qwen", "qwen")]
    [InlineData("zcode", "zcode")]
    [InlineData("zai", "zcode")]
    public void Match_recognizes_each_tool_basename(string command, string expectedId)
    {
        Assert.Equal(expectedId, AgentRegistry.Match(command)?.Id);
    }

    [Theory]
    [InlineData("& \"C:\\Users\\me\\AppData\\Roaming\\npm\\claude.cmd\"", "claude")]
    [InlineData("/usr/local/bin/codex", "codex")]
    [InlineData("C:\\tools\\gemini.exe --resume", "gemini")]
    [InlineData("& 'C:\\Users\\John Smith\\AppData\\Roaming\\npm\\claude.cmd'", "claude")]
    [InlineData("& \"C:\\Program Files\\Codex\\codex.exe\" --resume", "codex")]
    [InlineData("'/Users/x/My Tools/claude' --continue", "claude")]
    public void Match_recognizes_path_prefixed_basename(string command, string expectedId)
    {
        Assert.Equal(expectedId, AgentRegistry.Match(command)?.Id);
    }

    [Theory]
    [InlineData("echo hi | claude", "claude")]
    [InlineData("sudo claude", "claude")]
    [InlineData("command codex", "codex")]
    [InlineData("time gemini", "gemini")]
    [InlineData("FOO=bar claude", "claude")]
    [InlineData("env QWEN_KEY=1 qwen", "qwen")]
    public void Match_skips_pipe_wrappers_and_env_assignments(string command, string expectedId)
    {
        Assert.Equal(expectedId, AgentRegistry.Match(command)?.Id);
    }

    [Theory]
    [InlineData("")]
    [InlineData("ls -la")]
    [InlineData("vim notes.txt")]
    [InlineData("git commit")]
    [InlineData("npm install claude")]
    public void Match_returns_null_for_unknown_commands(string command)
    {
        Assert.Null(AgentRegistry.Match(command));
    }

    [Fact]
    public void DangerFlags_are_matched_case_sensitively_against_the_command()
    {
        var claude = AgentRegistry.Claude;
        Assert.Contains("--dangerously-skip-permissions", claude.DangerFlags);

        var codex = AgentRegistry.Codex;
        Assert.Contains("--yolo", codex.DangerFlags);
        Assert.Empty(AgentRegistry.Zcode.DangerFlags);
    }
}
