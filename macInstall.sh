#!/bin/bash

echo Installing Flutter...
./flutter/bin/flutter precache
echo Flutter installation complete.

echo Installing Dart...
./dart/bin/dart --version >/dev/null 2>&1 || (
  echo Dart not found, installing...
  ./flutter/bin/flutter --no-color pub global activate dart_sdk_manager --source path --no-executables
  ./dart-sdk-manager
  echo Dart installation complete.
)

echo Environment setup complete.
