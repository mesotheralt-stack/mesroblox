#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="$PWD/.tools"
mkdir -p "$TOOLS"
fetch_tool() {
  local url="$1" archive="$2" executable="$3"
  if [[ ! -x "$TOOLS/$executable" ]]; then
    curl --fail --location --retry 2 "$url" --output "$TOOLS/$archive"
    unzip -o "$TOOLS/$archive" -d "$TOOLS"
    rm "$TOOLS/$archive"
    chmod +x "$TOOLS/$executable"
  fi
}
fetch_tool 'https://github.com/rojo-rbx/rojo/releases/download/v7.5.1/rojo-7.5.1-linux-x86_64.zip' rojo.zip rojo
fetch_tool 'https://github.com/luau-lang/luau/releases/download/0.744/luau-ubuntu.zip' luau.zip luau
chmod +x "$TOOLS"/luau*
"$TOOLS/rojo" --version
python3 scripts/test.py --luau-dir "$TOOLS"
mkdir -p build
"$TOOLS/rojo" build default.project.json -o build/BrainrotBloom.rbxlx
cp build/BrainrotBloom.rbxlx BrainrotBloom.rbxlx
