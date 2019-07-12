using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

static class SiraLime {
	static void Main() {
        string title = "";
		using (Process node = new Process()) {
			node.StartInfo.FileName = "bin\\node.exe";
    		node.StartInfo.Arguments = "-e require('./src/node_modules/coffeescript/register.js');require('./src/main.coffee')";
    		node.StartInfo.UseShellExecute = false;
            if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows) && AttachConsole(-1)) 
                {title = Console.Title; Console.Title = ".[SiraLime]."; Console.WriteLine("");}
            else node.StartInfo.CreateNoWindow = true;
    		node.Start();
    		node.WaitForExit();
		}
        Console.Title = title;
	}

    // P/Invoke declarations
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AttachConsole(int dwProcessId);
}