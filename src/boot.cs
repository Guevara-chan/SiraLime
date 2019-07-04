using System;
using System.Diagnostics;

static class SiraLime {
	static void Main() {
		using (Process node = new Process()) {
			node.StartInfo.FileName = "bin\\node.exe";
    		node.StartInfo.Arguments = "-e require('./src/node_modules/coffeescript/register.js');require('./src/main.coffee')";
    		node.StartInfo.UseShellExecute = false;
    		//node.StartInfo.CreateNoWindow = true; 
    		node.Start();
    		node.WaitForExit();
		}
	}
}