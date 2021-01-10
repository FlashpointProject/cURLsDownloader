@ECHO off
REM External tools used: Wget for Windows, Bulk Rename Command
REM Wget binary downloaded from: https://eternallybored.org/misc/wget/
REM Bulk Rename Command official site: bulkrenameutility.co.uk

SETLOCAL EnableDelayedExpansion
SET "INPUT=%~1"
:START

REM cURLsDownloader Settings - you're free to change these!
SET "WGET_OPTIONS=-x -nc --no-check-certificate -t 3 -e robots=off --compression=auto --referer=URL --append-output=..\Logs\wget.log"
SET "GRAB_OPTIONS=--page-requisites"
SET "MIR_OPTIONS=-r -l inf -np"
SET /A AUTOCLOSE_SECS=-1

CALL :PRETTY
REM %~dp0 is the full path to the batch file, including the trailing backslash.
PUSHD "%~dp0"
IF NOT EXIST App (
	POPD
	ENDLOCAL
	ECHO Error: Application files not found!
	ECHO Press any key to exit...
	PAUSE>NUL
	EXIT /B 1
)
IF NOT EXIST Logs (MKDIR Logs)
SET "TMPFILE=%~dp0Logs\test.tmp"
IF NOT DEFINED INPUT (SET /P INPUT="Enter a filename or URL: ")
REM Autofill URLs.txt for the input if nothing is entered
IF NOT DEFINED INPUT (
	SET "FILE=%~dp0URLs.txt"
	GOTO MAIN
)

REM Check if a URL was entered
IF "!INPUT:~0,5!"=="http:" (
	CALL :addURL
	GOTO MAIN
)
IF "!INPUT:~0,6!"=="https:" (
	CALL :addURL
	GOTO MAIN
)
IF "!INPUT:~0,4!"=="ftp:" (
	CALL :addURL
	GOTO MAIN
)

REM Check if the input is just a filename or a whole path. If it is a path it will contain a backslash.
REM So we count the number of backslashes in the string with FIND /C. 
REM The count is written to a temporary file and read from there into the TEST variable.
SET "CHAR=\"
ECHO "!INPUT!" | %WINDIR%\System32\find.exe /C "%CHAR%" > "%TMPFILE%"
SET /P TEST=<"%TMPFILE%"
DEL "%TMPFILE%"
IF %TEST%==0 (
	SET "FILE=%~dp0!INPUT!"
) ELSE (
	SET "FILE=!INPUT!"
)

:MAIN
	CALL :PRETTY
	REM Check if the file exists
	IF NOT EXIST "!FILE!" (GOTO ERR)
	REM Check if the file is readable by the TYPE function
	TYPE "%FILE%">NUL
	IF NOT %ERRORLEVEL%==0 (GOTO ERR)
	ECHO Fetching files...
	REM NEWFILE is a log of all the valid URLs passed to Wget.
	SET "NEWFILE=%~dp0Logs\URLs.txt"
	IF EXIST "%NEWFILE%" (DEL "%NEWFILE%")
	IF EXIST Logs\wget.log (DEL Logs\wget.log)
	IF NOT EXIST Downloads (MKDIR Downloads)

	CD Downloads
	REM Read from the input file. Set the delimiters to the double-quote character " and space.
	REM This means that quotes can't be used to enclose the FOR command itself
	REM So all special chars have to be escaped with ^ instead.
	REM Give the 1st token to the 1st variable and the 2nd token to the 2nd variable,
	REM and validate the 2nd variable.
	REM Validate the 1st variable if validation of the 2nd is unsuccessful.
	FOR /F tokens^=1^-2^ delims^=^"^  %%i in ('type "%FILE%"') do (
		SET "URL=%%j"
		CALL :validateURL
		IF NOT !ERRORLEVEL!==0 (
			SET "URL=%%i"
			CALL :validateURL
		)
	)
	CD ..
	SET "INPUT="

	REM Check if any URLs were actually fetched
	SET /A NUMLINES=0
	FOR /F %%i in ('type "%NEWFILE%"') do (SET /A NUMLINES=!NUMLINES!+1)
	IF %NUMLINES%==0 (
		CALL :PRETTY
		GOTO ERR
	)

	CALL :checkFiles
	CALL :PRETTY
	IF NOT %AUTOCLOSE_SECS%==-1 (GOTO AUTOCLOSE)
	REM Have to double-escape the ! symbol since it indicates delayed-expanded variables
	REM The 1st ^ escapes the 2nd, and the 3rd escapes the !, so we get: ^!
	REM Then in the 2nd expansion phase, the remaining ^ escapes the !, so the ! gets displayed.
	ECHO Finished^^^! Press Enter to view your files,
	SET /P INPUT="Or type another filename or URL: "
	IF DEFINED INPUT (GOTO START)
	START explorer "%~dp0Downloads"
	GOTO EXIT
:AUTOCLOSE
	ECHO Finished^^^!
	TIMEOUT %AUTOCLOSE_SECS%
:EXIT
	ENDLOCAL
	CLS
EXIT /B


:addURL
	CALL :PRETTY
	ECHO Choose an action for this URL:
	ECHO.
	ECHO 1) Grab page or file
	ECHO 2) Mirror website
	ECHO If you are not sure what to choose, just press Enter.
	ECHO.
	SET ACTION=1
	SET /P ACTION="Enter your choice: "
	IF /I "%ACTION:~0,1%"=="m" (SET "WGET_OPTIONS=%WGET_OPTIONS% %MIR_OPTIONS%")
	IF "%ACTION%"=="2" (SET "WGET_OPTIONS=%WGET_OPTIONS% %MIR_OPTIONS%")
	SET "WGET_OPTIONS=%WGET_OPTIONS% %GRAB_OPTIONS%"
	SET "FILE=%~dp0Logs\Input.txt"
	ECHO !INPUT!>"%FILE%"
EXIT /B

:validateURL
	REM Remove escape characters added by Chrome's "copy as cURL" button
	SET "URL=!URL:^=!"
	REM Some extra checks for compatibility with the output from the Firefox console.
	REM Quotes around the SET commands so a trailing space isn't added.
	IF /I "!URL:~0,3!"=="GET" (SET "URL=!URL:~3!" & GOTO validateURL)
	IF /I "!URL:~0,4!"=="POST" (SET "URL=!URL:~4!" & GOTO validateURL)
	IF /I "!URL:~0,3!"=="XHR" (SET "URL=!URL:~3!" & GOTO validateURL)
	IF NOT "!URL:~0,4!"=="http" (
		IF NOT "!URL:~0,4!"=="ftp:" (EXIT /B 1)
	)
	REM Set referer to current URL
	SET "WGET_OPT=%WGET_OPTIONS:URL=!URL!%"
	REM Write logs and grab URL
	ECHO !URL!>>"%NEWFILE%"
	ECHO %~dp0App\wget !WGET_OPT! "!URL!">>"%~dp0Logs\wget.log"
	"%~dp0App\wget" !WGET_OPT! "!URL!"
EXIT /B %ERRORLEVEL%

:checkFiles
	IF NOT EXIST Downloads (EXIT /B)
	CD Downloads
	REM Check if any filenames have the "@" symbol in the filename.
	REM This happens when Wget fetches URLs with parameters. 
	REM All the "@" symbols must be removed to work correctly in Flashpoint.
	DIR /A-D /B /S | %WINDIR%\System32\find.exe /C "@" > "%TMPFILE%"
	SET /P ERCOUNT=<"%TMPFILE%"
	DEL "%TMPFILE%"
	CD ..
	IF NOT %ERCOUNT%==0 (
		CALL :RENP
	)
IF NOT EXIST "Downloads\web.archive.org\web" (EXIT /B)

:WAYBACKMERGE
	CALL :PRETTY
	ECHO Move files from web.archive.org to their original domains?
	ECHO.
	ECHO 1) Yes
	ECHO 2) No
	ECHO If you are not sure what to choose, just press Enter.
	ECHO.
	SET MCHOICE=1
	SET /P MCHOICE="Enter your choice: "
	IF /I "%MCHOICE:~0,1%"=="n" (EXIT /B)
	IF "%MCHOICE%"=="2" (EXIT /B)
	CALL :PRETTY
	ECHO Working...
	CD "Downloads\web.archive.org\web"
	FOR /D %%i IN (*) DO (
		CD %%i
		FOR /D %%j IN (*) DO (
			%WINDIR%\System32\Robocopy.exe %%j ..\..\..\ /S /MOVE >> "%~dp0Logs\robocopy.log"
		)
		CD ..
	)
	CD ..\..\..
	RMDIR /S /Q "Downloads\web.archive.org\web"
EXIT /B

:RENP
	CALL :PRETTY
	ECHO %ERCOUNT% broken filename^(s^) detected. Please choose an action:
	ECHO.
	ECHO 1) Rename
	ECHO 2) Back up and rename
	ECHO 3) No action
	ECHO If you are not sure what to choose, just press Enter.
	ECHO.
	SET REN=2
	SET /P REN="Enter your choice: "
	IF /I "%REN:~0,1%"=="n" (EXIT /B)
	IF "%REN%"=="3" (EXIT /B)
	CALL :PRETTY
	ECHO Working...
	IF /I "%REN:~0,1%"=="r" (GOTO REN)
	IF "%REN%"=="1" (GOTO REN)

	%WINDIR%\System32\Robocopy.exe Downloads Downloads-backup /S > Logs\robocopy.log
	:REN
	REM Use Bulk Rename Command with a regular expression rule to remove the "@" symbol and everything after it from each filename.
	App\BRC32 /DIR:Downloads /IGNOREFILEX /NOFOLDERS /NODUP /RECURSIVE /REGEXP:^(.*)(\@(.*)):\1 /EXECUTE > Logs\bulkrename.log
EXIT /B

:ERR
	SET "INPUT="
	ECHO Error: Cannot read file.
	ECHO.
	ECHO Press Enter to check the Downloads folder for errors,
	SET /P INPUT="Or type another filename or URL: "
	IF DEFINED INPUT (GOTO START)
	CALL :checkFiles
	CALL :PRETTY
	ECHO Finished checking files.
	ECHO Press Enter to exit,
	SET /P INPUT="Or type another filename or URL: "
	IF DEFINED INPUT (GOTO START)
EXIT /B

:PRETTY
	CLS & ECHO.
	ECHO -------------------------   cURLsDownloader by nosamu   ---   version 5.6   ---   2021-01-10   ------------------------- 
	ECHO.
EXIT /B