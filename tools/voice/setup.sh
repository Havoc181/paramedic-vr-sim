#!/usr/bin/env bash
# Rebuilds the offline voice toolchain (about 3 minutes). Build-time only; nothing here ships in the app.
#  - espeak-ng (GPL-3.0) built from source: text -> pronunciation
#  - Kokoro-82M ONNX model + voices (Apache-2.0) via kokoro-onnx release assets
#  - needs python3 with numpy + onnxruntime, cmake, gcc, ffmpeg
set -e
T="${VOICE_TOOLS:-$HOME/tts}"; mkdir -p "$T"; cd "$T"
[ -d espeak-ng ] || git clone -q --depth 1 https://github.com/espeak-ng/espeak-ng.git
if [ ! -x espeak/bin/espeak-ng ]; then
  mkdir -p espeak-ng/build && cd espeak-ng/build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$T/espeak" -DUSE_MBROLA=OFF -DUSE_LIBSONIC=OFF -DUSE_LIBPCAUDIO=OFF -DUSE_ASYNC=OFF >/dev/null
  make -j8 >/dev/null && make install >/dev/null && cd "$T"
fi
[ -d kokoro-onnx ] || git clone -q --depth 1 https://github.com/thewh1teagle/kokoro-onnx.git
R=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
[ -f kokoro-v1.0.onnx ] || curl -sSL -o kokoro-v1.0.onnx $R/kokoro-v1.0.onnx
[ -f voices-v1.0.bin ] || curl -sSL -o voices-v1.0.bin $R/voices-v1.0.bin
# WORLD vocoder (modified BSD), built as a shared library for ageing.py
if [ ! -f world/libworld.so ]; then
  [ -d World ] || git clone -q --depth 1 https://github.com/mmorise/World.git
  mkdir -p world && g++ -O2 -shared -fPIC -IWorld/src World/src/*.cpp -o world/libworld.so
fi
echo "Voice tools ready in $T"
