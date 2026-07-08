using System.Diagnostics;

namespace FriendlyTerminal.App.Models;

public sealed record RunningProcess(int Pid, string Command, int Port, string FriendlyName, bool IsWebServer)
{
    public string Id => $"{Pid}:{Port}";
}

/// <summary>
/// Lists processes listening on TCP ports (netstat -ano) with friendly names,
/// mirroring the macOS lsof-based ProcessMonitor. Refresh/kill are synchronous
/// worker calls the panel invokes off the UI thread.
/// </summary>
public static class ProcessMonitor
{
    public static List<RunningProcess> Load()
    {
        string output;
        try
        {
            using var p = Process.Start(new ProcessStartInfo
            {
                FileName = "netstat.exe",
                Arguments = "-ano -p TCP",
                UseShellExecute = false,
                RedirectStandardOutput = true,
                CreateNoWindow = true,
            });
            if (p is null) return new List<RunningProcess>();
            output = p.StandardOutput.ReadToEnd();
            p.WaitForExit(10_000);
        }
        catch
        {
            return new List<RunningProcess>();
        }
        return Parse(output);
    }

    internal static List<RunningProcess> Parse(string netstatOutput)
    {
        var result = new List<RunningProcess>();
        var seen = new HashSet<string>();

        foreach (var line in netstatOutput.Split('\n'))
        {
            var parts = line.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            // TCP  0.0.0.0:3000  0.0.0.0:0  LISTENING  1234
            if (parts.Length < 5 || parts[0] != "TCP" || parts[3] != "LISTENING") continue;
            if (!int.TryParse(parts[4], out var pid) || pid <= 0) continue;

            var local = parts[1];
            var colon = local.LastIndexOf(':');
            if (colon < 0 || !int.TryParse(local[(colon + 1)..], out var port) || port <= 0) continue;

            string command;
            try { command = Process.GetProcessById(pid).ProcessName; }
            catch { command = "?"; }

            var entry = new RunningProcess(pid, command, port, FriendlyName(command, port), IsWebPort(port));
            if (!seen.Add(entry.Id)) continue;
            result.Add(entry);
        }

        return result.OrderBy(e => e.Port).ToList();
    }

    public static bool Kill(int pid)
    {
        try
        {
            Process.GetProcessById(pid).Kill(entireProcessTree: true);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static string FriendlyName(string command, int port) => port switch
    {
        3000 => command.Equals("node", StringComparison.OrdinalIgnoreCase) ? "Node.js" : "Dev server",
        3306 => "MySQL",
        >= 3001 and <= 3999 => "Dev server",
        4200 => "Angular",
        4321 => "Astro",
        5000 => command.StartsWith("python", StringComparison.OrdinalIgnoreCase) ? "Flask" : "Dev server",
        5173 => "Vite",
        5432 => "PostgreSQL",
        6379 => "Redis",
        8000 => "Dev server",
        8080 => "Web server",
        8888 => "Jupyter",
        9000 => "Dev server",
        27017 => "MongoDB",
        _ => command.ToLowerInvariant() switch
        {
            "node" => "Node.js",
            "python" or "python3" => "Python",
            "ruby" => "Ruby",
            "java" => "Java",
            "go" => "Go",
            _ => command,
        },
    };

    private static bool IsWebPort(int port)
    {
        int[] webPorts = { 3000, 3001, 3002, 3003, 4200, 4321, 5000, 5173, 8000, 8080, 8081, 8888, 9000 };
        return webPorts.Contains(port)
            || (port >= 1024 && port < 10000 && port != 5432 && port != 6379 && port != 3306);
    }
}
