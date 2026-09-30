@echo off

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\copobras.local\SYSVOL\copobras.local\scripts\extensoes\lista_extensoes_json.ps1" >> C:\Temp\PowerShellLog.txt 2>&1
