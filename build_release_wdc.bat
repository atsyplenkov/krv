@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
if not exist "android\app" (
  echo Сначала скопируйте этот набор в существующий Flutter-проект.
  if not defined WDC_NONINTERACTIVE pause
  exit /b 1
)
call flutter pub get
if errorlevel 1 goto :failed
call dart run flutter_launcher_icons
if errorlevel 1 goto :failed
call flutter build apk --release
if errorlevel 1 goto :failed
set "WDC_OUTPUT=wdc_v4_5_1.apk"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "%WDC_OUTPUT%" >nul
if errorlevel 1 goto :failed
echo.
echo APK создан: %WDC_OUTPUT%
if not defined WDC_NONINTERACTIVE pause
exit /b 0
:failed
echo.
echo Сборка остановлена из-за ошибки. Скопируйте сообщение об ошибке из этого окна.
if not defined WDC_NONINTERACTIVE pause
exit /b 1
