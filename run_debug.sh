#!/bin/bash

# Run Flutter in debug (Linux)
if [ ! -f "pubspec.yaml" ]; then
  echo "Run this from the project root"
  exit 1
fi

flutter pub get
flutter run -d linux
