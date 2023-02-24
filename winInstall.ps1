@echo off

echo Installing Flutter...
call flutter\bin\flutter.bat precache
echo Flutter installation complete.

echo Installing Dart...
call dart\bin\dart.exe --version >NUL 2>NUL || (
  echo Dart not found, installing...
  call flutter\bin\flutter.bat --no-color pub global activate dart_sdk_manager --source path --no-executables
  call dart-sdk-manager.bat
  echo Dart installation complete.
)

echo Environment setup complete.
