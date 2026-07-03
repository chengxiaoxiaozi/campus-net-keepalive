Option Explicit

Dim shell, fso, scriptDir, ps, target, cmd

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
target = fso.BuildPath(scriptDir, "campus_keepalive.ps1")

cmd = """" & ps & """ -NoProfile -ExecutionPolicy Bypass -File """ & target & """"

shell.Run cmd, 0, False
