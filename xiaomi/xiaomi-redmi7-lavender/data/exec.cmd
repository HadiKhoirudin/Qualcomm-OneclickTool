@echo off
cls
set datetime=%DATE:~10,4%%DATE:~4,2%%DATE:~7,2%%TIME:~0,2%%TIME:~3,2%
set datetime=%datetime: =0%
set backup=%~dp0-%datetime%
set basedir=%~dp0
set emmcdl=%~dp0emmcdl.exe
set Loader=%~dp0loader.elf
set MemoryName=%1
set reboot=%~dp0boot.xml
set repl=%~dp0repl.cmd
set SelectedOperation=%2

%emmcdl% -l | findstr "COM" >Port.txt
for /F "tokens=5 delims=() " %%a in (Port.txt) do (set USBComPort=%%a)
del /F /Q Port.txt >nul 2>&1

IF (%USBComPort%) == () (GOTO :err_process) ELSE (GOTO :process)


:err_process
echo.
echo. Error!
echo. QCUSB Port EDL Not Detected...
exit

:err_relockbl
echo.
echo. Error!
echo. Can't Relock Bootloader 
echo. Backup file not found...
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
    %emmcdl% -p %USBComPort% -f %Loader% -d persist -o %backup%-persist.img -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -b persist persist.img -memoryname %MemoryName% >nul

:: Erase USERDATA
    %emmcdl% -p %USBComPort% -f %Loader% -e userdata -memoryname %MemoryName% >nul

:: Done
echo. Done! Device Reset Factory...
echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
)

IF "%SelectedOperation%" == "-reset_frp" (
:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -d persist -o %backup%-persist.img -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -b persist persist.img -memoryname %MemoryName% >nul

:: Done
echo. Done! FRP Erased...
echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
)

IF "%SelectedOperation%" == "-reset_safe" (
:: Get Partition Info
    %emmcdl% -p %USBComPort% -f %Loader% -gpt -memoryname %MemoryName% >partition.xml

:: Erase FRP
    %emmcdl% -p %USBComPort% -f %Loader% -e frp -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -d persist -o %backup%-persist.img -memoryname %MemoryName% >nul
    %emmcdl% -p %USBComPort% -f %Loader% -b persist persist.img -memoryname %MemoryName% >nul

::: Partition Misc
    for /F "Tokens=2 skip=1 delims=SECTOR_SIZE_IN_BYTES= " %%e in ('findstr /I "SECTOR_SIZE_IN_BYTES" partition.xml') do (type misc.xml | %repl% "(SECTOR_SIZE_IN_BYTES=\q).*?(\q.*>)" $1%%e$2 xi >tmp.xml)
    for /F "Tokens=7 " %%f in ('findstr /I "misc" partition.xml') do (type tmp.xml | %repl% "(start_sector=\q).*?(\q.*>)" "$1%%f$2" xi >patch.xml)
        %emmcdl% -p %USBComPort% -f %Loader% -d misc -o %backup%-misc.img -memoryname %MemoryName% >nul
        %emmcdl% -p %USBComPort% -f %Loader% -x patch.xml -memoryname %MemoryName% >nul
del /F /Q partition.xml >nul 2>&1
del /F /Q tmp.xml >nul 2>&1
del /F /Q patch.xml >nul 2>&1
:: Done
echo. Done! Reset With Safe...
echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
)

IF "%SelectedOperation%" == "-unlock_bl" (
if exist %basedir%abl.bin (
echo. >nul
) else (
%emmcdl% -p %USBComPort% -f %Loader% -d abl -o abl.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -d keymaster -o keymaster.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -d pmic -o pmic.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -d xbl -o xbl.bin -memoryname %MemoryName% >nul
)
%emmcdl% -p %USBComPort% -f %Loader% -b abl ubl-abl.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b keymaster ubl-keymaster.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b pmic ubl-pmic.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b xbl ubl-xbl.bin -memoryname %MemoryName% >nul
:: Done
echo.
echo.
echo. Done! 
echo. Please Go To Fastboot Mode
echo. With Vol - and Power button
echo. Display Will Black Screen
echo. Run Unlock.exe Refresh and Unlock
echo. Then Flash Fasboot Firmware...
echo.
echo.
)

IF "%SelectedOperation%" == "-relock_bl" (
if exist %basedir%abl.bin (
%emmcdl% -p %USBComPort% -f %Loader% -b abl abl.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b keymaster keymaster.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b pmic pmic.bin -memoryname %MemoryName% >nul
%emmcdl% -p %USBComPort% -f %Loader% -b xbl xbl.bin -memoryname %MemoryName% >nul
) else (
goto err_relockbl
)
:: Done
echo. Done! Bootloader Relocked...
echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
)

IF "%SelectedOperation%" == "-reboot" (
echo. Rebooting Device...
echo.
%emmcdl% -p %USBComPort% -f %Loader% -x %reboot% -memoryname %MemoryName% >nul
)

exit
