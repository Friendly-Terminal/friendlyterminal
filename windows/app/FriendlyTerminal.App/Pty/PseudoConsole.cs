using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace FriendlyTerminal.App.Pty;

internal sealed class PseudoConsole : IDisposable
{
    public IntPtr Handle { get; }
    private bool _disposed;

    private PseudoConsole(IntPtr handle) => Handle = handle;

    public static PseudoConsole Create(SafeFileHandle input, SafeFileHandle output, int width, int height)
    {
        var size = new COORD { X = (short)width, Y = (short)height };
        int hr = CreatePseudoConsole(size, input, output, 0, out var handle);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        return new PseudoConsole(handle);
    }

    public void Resize(int width, int height) =>
        ResizePseudoConsole(Handle, new COORD { X = (short)width, Y = (short)height });

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        ClosePseudoConsole(Handle);
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct COORD { public short X; public short Y; }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int CreatePseudoConsole(COORD size, SafeFileHandle hInput, SafeFileHandle hOutput, uint dwFlags, out IntPtr phPC);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int ResizePseudoConsole(IntPtr hPC, COORD size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int ClosePseudoConsole(IntPtr hPC);
}
