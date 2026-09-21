#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
build_dir="$project_dir/build"
app_dir="$build_dir/Codex Pulse.app"
macos_dir="$app_dir/Contents/MacOS"
resources_dir="$app_dir/Contents/Resources"

mkdir -p "$macos_dir" "$resources_dir"

/usr/bin/swiftc \
  -parse-as-library \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -o "$macos_dir/CodexPulse" \
  "$project_dir"/Sources/CodexPulse/*.swift

cp "$project_dir/App/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir"/Sources/CodexPulse/Resources/*.png "$resources_dir/"
codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
