@echo off
echo Removing SAS jobs service from the system...
bin\SasJobs.WindowsService.exe --uninstall
pause