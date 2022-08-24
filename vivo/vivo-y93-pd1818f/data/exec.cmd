@echo off
cls
set datetime=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%%TIME:~0,2%%TIME:~3,2%
set datetime=%datetime: =0%
set backup=%~dp2-%datetime%
set emmcdl=%~dp2emmcdl.exe
set Loader=%~dp2loader.elf
set MemoryName=%1
set reboot=%~dp2boot.xml
set repl=%~dp2repl.cmd
set SelectedOperation=%2

%emmcdl% -l | findstr "COM" >Port.txt
for /F "tokens=5 delims=() " %%a in (Port.txt) do (set USBComPort=%%a)
del /F /Q Port.txt >nul 2>&1

IF (%USBComPort%) == () (GOTO :err_process) ELSE (GOTO :process)


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
%emmcdl% -p %USBComPort% -info >info.log
for /F "Tokens=2 " %%b in ('findstr /I "SerialNumber" info.log') do (set MSM_ID=%%b)
set MSM_ID=%MSM_ID:~2,8%
echo. MSM ID   : %MSM_ID%

for /F "Tokens=2 " %%c in ('findstr /I "MSM_HW_ID" info.log') do (set MSM_HW=%%c0000000000000000)
set MSM_HW=%MSM_HW:~2,16%
echo. MSM HW : %MSM_HW%

for /F "Tokens=2 delims=2 " %%d in ('findstr /I "OEM_PK_HASH" info.log') do (set OEM_PK=%%d)
set OEM_PK=%OEM_PK:~2,16%
echo. OEM PK  : %OEM_PK%
del /F /Q info.log >nul 2>&1

echo.
echo. Configuring Firehose...[OK]

IF "%SelectedOperation%" == "-reset_imei" (
    %emmcdl% -p %USBComPort% -f %Loader% -d fsg -o %backup%-fsg.bin -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -d modemst1 -o %backup%-modemst1.bin -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -d modemst2 -o %backup%-modemst2.bin -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -e fsg -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -e modemst1 -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -e modemst2 -memoryname %MemoryName% >nul
:: Done
echo. Done! IMEI Reset...
)

IF "%SelectedOperation%" == "-reset_factory" (
:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul

:: Erase USERDATA
    %emmcdl% -p %USBComPort% -f %Loader% -e userdata -memoryname %MemoryName% >nul

:: Done
echo. Done! Device Reset Factory...
)

IF "%SelectedOperation%" == "-reset_frp" (
:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul

:: Done
echo. Done! FRP Erased...
)

IF "%SelectedOperation%" == "-reset_safe" (
:: Get Partition Info
    %emmcdl% -p %USBComPort% -f %Loader% -gpt -memoryname %MemoryName% >partition.xml

:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul

::: Partition Misc
    for /F "Tokens=2 skip=1 delims=SECTOR_SIZE_IN_BYTES= " %%e in ('findstr /I "SECTOR_SIZE_IN_BYTES" partition.xml') do (type misc.xml | %repl% "(SECTOR_SIZE_IN_BYTES=\q).*?(\q.*>)" $1%%e$2 xi >tmp.xml)
    for /F "Tokens=7 " %%f in ('findstr /I "misc" partition.xml') do (type tmp.xml | %repl% "(start_sector=\q).*?(\q.*>)" "$1%%f$2" xi >patch.xml)
        %emmcdl% -p %USBComPort% -f %Loader% -x patch.xml -memoryname %MemoryName% >nul
del /F /Q partition.xml >nul 2>&1
del /F /Q tmp.xml >nul 2>&1
del /F /Q patch.xml >nul 2>&1
:: Done
echo. Done! Reset With Safe...
)

IF "%SelectedOperation%" == "-unlock_bl" (
:: Get Partition Info
    %emmcdl% -p %USBComPort% -f %Loader% -gpt -memoryname %MemoryName% >partition.xml
::: Partition Devinfo
    for /F "Tokens=2 skip=1 delims=SECTOR_SIZE_IN_BYTES= " %%g in ('findstr /I "SECTOR_SIZE_IN_BYTES" partition.xml') do (type ubl_patch.xml | %repl% "(SECTOR_SIZE_IN_BYTES=\q).*?(\q.*>)" $1%%g$2 xi >tmp.xml)
    for /F "Tokens=7 " %%h in ('findstr /I "devinfo" partition.xml') do (type tmp.xml | %repl% "(start_sector=\q).*?(\q.*>)" "$1%%h$2" xi >patch.xml)
        %emmcdl% -p %USBComPort% -f %Loader% -d devinfo -o %backup%-devinfo.bin -memoryname %MemoryName% >nul
        %emmcdl% -p %USBComPort% -f %Loader% -x patch.xml -memoryname %MemoryName% >nul
del /F /Q partition.xml >nul 2>&1
del /F /Q tmp.xml >nul 2>&1
del /F /Q patch.xml >nul 2>&1
:: Done
echo. Done! Bootloader Unlocked...
)

IF "%SelectedOperation%" == "-relock_bl" (
:: Get Partition Info
    %emmcdl% -p %USBComPort% -f %Loader% -gpt -memoryname %MemoryName% >partition.xml
::: Partition Devinfo
    for /F "Tokens=2 skip=1 delims=SECTOR_SIZE_IN_BYTES= " %%i in ('findstr /I "SECTOR_SIZE_IN_BYTES" partition.xml') do (type rbl_patch.xml | %repl% "(SECTOR_SIZE_IN_BYTES=\q).*?(\q.*>)" $1%%i$2 xi >tmp.xml)
    for /F "Tokens=7 " %%j in ('findstr /I "devinfo" partition.xml') do (type tmp.xml | %repl% "(start_sector=\q).*?(\q.*>)" "$1%%j$2" xi >patch.xml)
        %emmcdl% -p %USBComPort% -f %Loader% -x patch.xml -memoryname %MemoryName% >nul
del /F /Q partition.xml >nul 2>&1
del /F /Q tmp.xml >nul 2>&1
del /F /Q patch.xml >nul 2>&1
:: Done
echo. Done! Bootloader Relocked...
)

echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
exit
