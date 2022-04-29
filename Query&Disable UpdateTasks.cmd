@ECHO OFF

FSUTIL DIRTY query %SystemDrive% >NUL || (
    PowerShell "Start-Process cmd.exe '/C CHDIR /D %CD% & "%0"' -Verb RunAs"
    EXIT
)

SCHTASKS /Query /TN "Adobe Acrobat Update Task" 2>NUL
SCHTASKS /Query /TN "CCleaner Update" 2>NUL
SCHTASKS /Query /TN MEGA\ 2>NUL
ECHO;
ECHO;
PAUSE
ECHO;
ECHO;

SET $disable=0

SCHTASKS /Query /Fo CSV /TN "Adobe Acrobat Update Task" 2>NUL | FINDSTR "Ready Running" >NUL && (
    SCHTASKS /Change /TN "Adobe Acrobat Update Task" /DISABLE & SET $disable=1
)
SCHTASKS /Query /Fo CSV /TN "CCleaner Update" 2>NUL | FINDSTR "Ready Running" >NUL && (
    SCHTASKS /Change /TN "CCleaner Update" /DISABLE & SET $disable=1
)
FOR /F "tokens=1 delims=," %%I IN ('SCHTASKS /Query /Fo CSV /TN MEGA\ 2^>NUL ^| FINDSTR "Ready Running"') DO (
    SCHTASKS /Change /TN %%I /DISABLE & SET $disable=1
)

IF %$disable%==1 (
    ECHO;
    ECHO;
    PAUSE
)
