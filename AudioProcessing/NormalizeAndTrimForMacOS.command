#!/bin/bash
#chmod a+x NormalizeAndTrimForMacOS.command


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd "$SCRIPT_DIR"

mkdir norm
mkdir trim

#i=1;
for file in *.wav; do
  filename=${file%.*};
#  x=$((i/50+1));
#  mkdir "./trim/$x";
  sox "$file" "norm/$file" norm -3;
  ffmpeg -i "norm/$file" -af silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse,silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse "trim/$filename.mp3"
#  ((i++));
done

for file in *.mp3; do
  filename=${file%.*};
#  x=$((i/50+1));
#  mkdir "./trim/$x";
  sox "$file" "norm/$file" norm -3;
  ffmpeg -i "norm/$file" -af silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse,silenceremove=start_periods=1:start_silence=0.1:start_threshold=-42dB,areverse "trim/$filename.mp3"
#  ((i++));
done