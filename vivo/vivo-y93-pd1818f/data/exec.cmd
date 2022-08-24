@echo off
cls
set MemoryName=%1
set SelectedOperation=%2
set emmcdl=%~dp2emmcdl.exe
set Loader=%~dp2loader.elf
set reboot=%~dp2boot.xml
set repl=%~dp2repl.cmd

%emmcdl% -l | findstr "COM" >Port.txt
for /F "tokens=5 delims=() " %%a in (Port.txt) do (set USBComPort=%%a)
del /F /Q Port.txt >nul 2>&1

IF (%USBComPort%) == () (GOTO :process) ELSE (GOTO :err_process)


:err_process
echo.
echo. Error!
echo. QCUSB Port EDL Not Detected...
echo.
echo.
echo.
echo.
echo.
echo.
echo.
exit

:process
echo.
echo.
echo.
echo. Connecting To Device...[OK]

:: Get Device Info
:: %emmcdl% -p %USBComPort% -info >info.log
for /F "Tokens=2 " %%x in ('findstr /I "SerialNumber" info.log') do (set MSM_ID=%%x)
set MSM_ID=%MSM_ID:~2,8%
echo. MSM ID   : %MSM_ID%

for /F "Tokens=2 " %%y in ('findstr /I "MSM_HW_ID" info.log') do (set MSM_HW=%%y0000000000000000)
set MSM_HW=%MSM_HW:~2,16%
echo. MSM HW : %MSM_HW%

for /F "Tokens=2 delims=2 " %%z in ('findstr /I "OEM_PK_HASH" info.log') do (set OEM_PK=%%z)
set OEM_PK=%OEM_PK:~2,16%
echo. OEM PK  : %OEM_PK%

echo.
echo. Configuring Firehose...[OK]

IF "%SelectedOperation%" == "-reset_imei" (

:: Done
echo. Done! IMEI Reset...
)

IF "%SelectedOperation%" == "-reset_factory" (

:: Done
echo. Done! Device Reset Factory...
)

IF "%SelectedOperation%" == "-reset_frp" (

:: Done
echo. Done! FRP Erased...
)

IF "%SelectedOperation%" == "-reset_safe" (
:: Get Partition Info
    %emmcdl% -p %USBComPort% -f %Loader% -gpt -memoryname %MemoryName% >partition.xml

:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul

::: Partition Misc
    for /F "Tokens=2 skip=1 delims=SECTOR_SIZE_IN_BYTES= " %%t in ('findstr /I "SECTOR_SIZE_IN_BYTES" partition.xml') do (type patch.xml | %repl% "(SECTOR_SIZE_IN_BYTES=\q).*?(\q.*>)" $1%%t$2 xi >tmp.xml)
    for /F "Tokens=7 " %%u in ('findstr /I "misc" partition.xml') do (type tmp.xml | %repl% "(start_sector=\q).*?(\q.*>)" "$1%%u$2" xi >misc.xml)
        %emmcdl% -p %USBComPort% -f %Loader% -x misc.xml -memoryname %MemoryName% >nul
:: Done
echo. Done! Reset With Safe...
)

IF "%SelectedOperation%" == "-unlock_bl" (

:: Done
echo. Done! Bootloader Unlocked...
)

IF "%SelectedOperation%" == "-relock_bl" (

:: Done
echo. Done! Bootloader Relocked...
)

echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
exit
