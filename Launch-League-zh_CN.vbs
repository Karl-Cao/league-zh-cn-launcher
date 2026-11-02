Option Explicit

Dim shell, files, folder, powershell, launcher, command, result
Set shell = CreateObject("WScript.Shell")
Set files = CreateObject("Scripting.FileSystemObject")

folder = files.GetParentFolderName(WScript.ScriptFullName)
powershell = files.BuildPath(shell.ExpandEnvironmentStrings("%SystemRoot%"), "System32\WindowsPowerShell\v1.0\powershell.exe")
launcher = files.BuildPath(folder, "League-zh_CN-Launcher.ps1")
command = """" & powershell & """ -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & launcher & """"

If WScript.Arguments.Count > 0 Then
    If LCase(WScript.Arguments(0)) = "/validate" Then
        result = shell.Run(command & " -NoLaunch", 0, True)
        WScript.Quit result
    End If
End If

shell.Run command, 0, False
