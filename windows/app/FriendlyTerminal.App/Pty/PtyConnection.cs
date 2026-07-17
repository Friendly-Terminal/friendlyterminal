using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace FriendlyTerminal.App.Pty;

internal sealed class PtyConnection : IDisposable
{
    private readonly string _command;
    private readonly int _width;
    private readonly int _height;

    private PseudoConsole? _console;
    private SafeFileHandle? _inputWrite;
    private SafeFileHandle? _outputRead;
    private FileStream? _writer;
    private Thread? _reader;
    private IntPtr _processHandle;
    private volatile bool _running;
    private volatile bool _disposed;

    public event Action<byte[]>? OutputReceived;

    /// <summary>Raised on the reader thread when the shell process ends on its own
    /// (not when the connection is disposed).</summary>
    public event Action? Exited;

    public PtyConnection(string command, int width, int height)
    {
        _command = command;
        _width = width;
        _height = height;
    }

    public void Start()
    {
        CreatePipe(out var inputRead, out var inputWrite);
        SafeFileHandle? outputRead = null;
        SafeFileHandle? outputWrite = null;
        try
        {
            CreatePipe(out outputRead, out outputWrite);

            _console = PseudoConsole.Create(inputRead, outputWrite, _width, _height);

            // PseudoConsole duplicated the handles; keep the parent ends, close the child ends.
            _inputWrite = inputWrite;
            _outputRead = outputRead;
            // Drop the local refs so the finally (failure-only cleanup) leaves them alive
            // for the running reader/writer on the success path.
            inputWrite = null;
            outputRead = null;

            StartProcess(_console.Handle, _command);

            _writer = new FileStream(_inputWrite, FileAccess.Write);
            _running = true;
            _reader = new Thread(ReadLoop) { IsBackground = true };
            _reader.Start();
        }
        catch
        {
            // Reclaim whatever was created so handles never leak on a partial start.
            Dispose();
            throw;
        }
        finally
        {
            // The child ends are never needed past PseudoConsole.Create.
            inputRead.Dispose();
            outputWrite?.Dispose();
            // Parent ends transferred to fields on success; on failure the catch path owns them.
            inputWrite?.Dispose();
            outputRead?.Dispose();
        }
    }

    public void WriteInput(string text)
    {
        var writer = _writer;
        if (writer is null || _disposed || !_running) return;
        try
        {
            var bytes = Encoding.UTF8.GetBytes(text);
            writer.Write(bytes, 0, bytes.Length);
            writer.Flush();
        }
        // The shell can close its input pipe (e.g. after `exit`) before the UI stops
        // sending; a broken pipe here is expected, not a crash.
        catch (IOException) { }
        catch (ObjectDisposedException) { }
    }

    public void Resize(int width, int height)
    {
        if (_disposed) return;
        try { _console?.Resize(width, height); }
        catch (ObjectDisposedException) { }
    }

    private void ReadLoop()
    {
        using var stream = new FileStream(_outputRead!, FileAccess.Read);
        var buffer = new byte[4096];
        while (_running)
        {
            int read;
            try { read = stream.Read(buffer, 0, buffer.Length); }
            catch { break; }
            if (read <= 0) break;
            var chunk = new byte[read];
            Array.Copy(buffer, chunk, read);
            OutputReceived?.Invoke(chunk);
        }
        if (_running)
            Exited?.Invoke();
    }

    private static void CreatePipe(out SafeFileHandle read, out SafeFileHandle write)
    {
        if (!NativeMethods.CreatePipe(out read, out write, IntPtr.Zero, 0))
            throw new InvalidOperationException("CreatePipe failed");
    }

    private void StartProcess(IntPtr console, string command)
    {
        var attrSize = IntPtr.Zero;
        NativeMethods.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attrSize);
        var attrList = Marshal.AllocHGlobal(attrSize);
        try
        {
            if (!NativeMethods.InitializeProcThreadAttributeList(attrList, 1, 0, ref attrSize))
                throw new InvalidOperationException("InitializeProcThreadAttributeList failed");

            try
            {
                if (!NativeMethods.UpdateProcThreadAttribute(attrList, 0,
                        (IntPtr)NativeMethods.PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                        console, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
                    throw new InvalidOperationException("UpdateProcThreadAttribute failed");

                var startup = new NativeMethods.STARTUPINFOEX();
                startup.StartupInfo.cb = Marshal.SizeOf<NativeMethods.STARTUPINFOEX>();
                startup.lpAttributeList = attrList;

                if (!NativeMethods.CreateProcess(null, command, IntPtr.Zero, IntPtr.Zero, false,
                        NativeMethods.EXTENDED_STARTUPINFO_PRESENT, IntPtr.Zero, null,
                        ref startup, out var proc))
                    throw new InvalidOperationException("CreateProcess failed");

                NativeMethods.CloseHandle(proc.hThread);
                // Retain the process handle so Dispose can wait for the child to exit
                // (otherwise powershell.exe can outlive the window).
                _processHandle = proc.hProcess;
            }
            finally
            {
                NativeMethods.DeleteProcThreadAttributeList(attrList);
            }
        }
        finally
        {
            Marshal.FreeHGlobal(attrList);
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _running = false;
        _writer?.Dispose();
        _outputRead?.Dispose();
        _inputWrite?.Dispose();
        _console?.Dispose(); // tearing down the pseudoconsole signals the child to exit

        var handle = _processHandle;
        _processHandle = IntPtr.Zero;
        if (handle != IntPtr.Zero)
        {
            // Reap the child off the UI thread: waiting inline froze the window for up to
            // 2s per pane. The console is already gone, so the child is exiting anyway;
            // the background wait just releases its handle without leaking the process.
            new Thread(() =>
            {
                NativeMethods.WaitForSingleObject(handle, 2000);
                NativeMethods.CloseHandle(handle);
            }) { IsBackground = true }.Start();
        }
    }
}
