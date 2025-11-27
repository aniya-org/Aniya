#!/bin/bash

echo "Cleaning Flutter build..."
flutter clean

echo "Getting dependencies..."
flutter pub get

echo "Rebuilding app..."
flutter run -d linux

