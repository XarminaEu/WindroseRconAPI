@echo off
REM Build windrose_rcon.dll for WindroseRCON
REM Requires Visual Studio 2022 Build Tools or full VS with C++ workload.

cmake -S "%~dp0" -B "%~dp0build" -A x64
if %errorlevel% neq 0 exit /b %errorlevel%

cmake --build "%~dp0build" --config Release
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo Build complete. Output: %~dp0..\WindroseRCON\Scripts\windrose_rcon.dll
pause
