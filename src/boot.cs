using System;
using System.Drawing;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;

static class SiraLime {
	[DllImport("user32.dll", EntryPoint = "SetWindowPos")]
    public static extern IntPtr SetWinPos(IntPtr hWnd, int hWndInsertAfter, int x, int Y, int cx, int cy, uint wFlags);

	static void Main() {
		Console.WindowWidth = 95;
		Console.WindowHeight = 60; // 68
		Console.Title = ".[SiraLime].";
		Console.Write("...Now loading...\r");
		//Console.WindowHeight = 68;
		CenterConsole();
		using (Process node = new Process()) {
			node.StartInfo.FileName = "bin\\node.exe";
    		node.StartInfo.Arguments = "-e require('./src/node_modules/coffeescript/register.js');require('./src/main.coffee')";
    		node.StartInfo.UseShellExecute = false;
    		node.Start();
    		node.WaitForExit();
		}
	}

	public static void CenterConsole() {
        IntPtr hWin = GetConsoleWindow();
        RECT rc;
        GetWindowRect(hWin, out rc);
        Screen scr = Screen.FromPoint(new Point(rc.left, rc.top));
        int x = scr.WorkingArea.Left + (scr.WorkingArea.Width - (rc.right - rc.left)) / 2;
        int y = scr.WorkingArea.Top + (scr.WorkingArea.Height - (rc.bottom - rc.top)) / 2;
        MoveWindow(hWin, x, y, rc.right - rc.left, rc.bottom - rc.top, false);
    }

    // P/Invoke declarations
    private struct RECT { public int left, top, right, bottom; }
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT rc);
    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool MoveWindow(IntPtr hWnd, int x, int y, int w, int h, bool repaint);
}