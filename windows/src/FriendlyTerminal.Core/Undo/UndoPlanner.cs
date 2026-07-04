using FriendlyTerminal.Core.Platform;

namespace FriendlyTerminal.Core.Undo;

public sealed class UndoPlanner
{
    private const string UnsafeChars = "'\"*?[]{}|&;<>$`";

    private readonly IFileSystem _fs;
    private readonly IShellQuoter _quoter;

    public UndoPlanner(IFileSystem fs, IShellQuoter quoter)
    {
        _fs = fs;
        _quoter = quoter;
    }

    public UndoPlan? Plan(string command, string cwd, bool allowPreState = true)
    {
        var trimmed = command.Trim();
        if (trimmed.Length == 0) return null;
        if (trimmed.IndexOfAny(UnsafeChars.ToCharArray()) >= 0) return null;

        var parts = trimmed.Split(' ', '\t').Where(p => p.Length > 0).ToArray();
        if (parts.Length == 0) return null;
        var cmd = parts[0];
        var args = parts.Skip(1).ToArray();
        var operands = args.Where(a => !a.StartsWith('-')).ToArray();

        string Resolve(string p) => PathUtil.Resolve(p, cwd, _fs.HomeDirectory);
        string Q(string s) => _quoter.Quote(s);
        UndoPlan One(string label, UndoAction action) => new(label, new[] { action });

        switch (cmd)
        {
            case "cd":
                return One($"Undo: go back to “{PathUtil.LastComponent(cwd)}”",
                    new UndoAction.Shell($"cd {Q(cwd)}"));

            case "mkdir":
                if (operands.Length == 0) return null;
                var made = Resolve(operands[^1]);
                return One($"Undo: delete folder “{PathUtil.LastComponent(made)}”",
                    new UndoAction.Trash(made));

            case "touch":
            {
                if (!allowPreState) return null;
                var created = operands.Select(Resolve).Where(p => !_fs.Exists(p)).ToArray();
                if (created.Length == 0) return null;
                var label = created.Length == 1
                    ? $"Undo: delete “{PathUtil.LastComponent(created[0])}”"
                    : $"Undo: delete {created.Length} new files";
                return new UndoPlan(label, created.Select(p => (UndoAction)new UndoAction.Trash(p)).ToArray());
            }

            case "cp":
            {
                if (!allowPreState || operands.Length < 2) return null;
                var src = operands[0];
                var dest = Resolve(operands[^1]);
                string made2;
                if (_fs.Exists(dest) && _fs.IsDirectory(dest))
                {
                    made2 = PathUtil.Combine(dest, PathUtil.LastComponent(src));
                    if (_fs.Exists(made2)) return null;
                }
                else if (!_fs.Exists(dest))
                {
                    made2 = dest;
                }
                else return null;
                return One($"Undo: delete the copy “{PathUtil.LastComponent(made2)}”",
                    new UndoAction.Trash(made2));
            }

            case "mv":
            {
                if (!allowPreState || operands.Length != 2) return null;
                var src = Resolve(operands[0]);
                var dest = Resolve(operands[1]);
                var movedInto = _fs.Exists(dest) && _fs.IsDirectory(dest);
                var finalDest = movedInto ? PathUtil.Combine(dest, PathUtil.LastComponent(src)) : dest;
                if (movedInto && _fs.Exists(finalDest)) return null;
                return One($"Undo: move “{PathUtil.LastComponent(src)}” back",
                    new UndoAction.Shell($"mv {Q(finalDest)} {Q(src)}"));
            }

            case "git":
            {
                if (args.Length == 0) return null;
                switch (args[0])
                {
                    case "add":
                        var rest = string.Join(' ', args.Skip(1));
                        if (rest.Length == 0) return null;
                        return One("Undo: unstage", new UndoAction.Shell($"git restore --staged {rest}"));
                    case "commit":
                        return One("Undo: undo last commit (keep the changes)",
                            new UndoAction.Shell("git reset --soft HEAD~1"));
                    case "checkout":
                    case "switch":
                        var branchOps = args.Skip(1).Where(a => !a.StartsWith('-')).ToArray();
                        if (branchOps.Length != 1) return null;
                        return One("Undo: switch back to the previous branch",
                            new UndoAction.Shell("git checkout -"));
                    default:
                        return null;
                }
            }

            case "export":
            {
                if (args.Length == 0) return null;
                var eq = args[0].IndexOf('=');
                if (eq <= 0) return null;
                var name = args[0][..eq];
                return One($"Undo: unset {name}", new UndoAction.Shell($"Remove-Item Env:\\{name}"));
            }

            case "zip":
                if (operands.Length == 0) return null;
                var archive = Resolve(operands[0]);
                return One($"Undo: delete “{PathUtil.LastComponent(archive)}”",
                    new UndoAction.Trash(archive));

            case "tar":
            {
                if (args.Length == 0 || !args[0].StartsWith('-') ||
                    !args[0].Contains('c') || !args[0].Contains('f')) return null;
                var tarArchive = args.Skip(1).FirstOrDefault(a => !a.StartsWith('-'));
                if (tarArchive == null) return null;
                var url = Resolve(tarArchive);
                return One($"Undo: delete “{PathUtil.LastComponent(url)}”",
                    new UndoAction.Trash(url));
            }

            case "curl":
            {
                var oIdx = Array.IndexOf(args, "-o");
                if (oIdx >= 0 && oIdx + 1 < args.Length)
                {
                    var url = Resolve(args[oIdx + 1]);
                    return One($"Undo: delete “{PathUtil.LastComponent(url)}”",
                        new UndoAction.Trash(url));
                }
                if (args.Contains("-O") && operands.Length > 0)
                {
                    var name = PathUtil.LastComponent(operands[^1]);
                    if (name.Length == 0) return null;
                    var url = Resolve(name);
                    return One($"Undo: delete “{name}”", new UndoAction.Trash(url));
                }
                return null;
            }

            case "winget":
            {
                if (args.Length == 0 || args[0] != "install") return null;
                var pkgs = args.Skip(1).Where(a => !a.StartsWith('-')).ToArray();
                if (pkgs.Length == 0) return null;
                return One($"Undo: uninstall {string.Join(", ", pkgs)}",
                    new UndoAction.Shell($"winget uninstall {string.Join(' ', pkgs)}"));
            }

            default:
                return null;
        }
    }
}
