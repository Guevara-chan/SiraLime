@echo off
set exe=..\SiraLime.exe
if exist %exe% ( del %exe% )
%windir%/Microsoft.NET/Framework/v4.0.30319/csc.exe /nologo /win32icon:../res/siralim.ico /out:%exe% boot.cs