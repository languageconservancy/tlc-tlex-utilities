@echo off
mkdir norm
mkdir trim
for %%a in (*.wav) do (
  sox --norm=-3 "%%a" "norm\%%~na.wav"
  ffmpeg -i "norm\%%~na.wav" -af silenceremove=start_periods=1:start_silence=0.3:start_threshold=-42dB,areverse,silenceremove=start_periods=1:start_silence=0.3:start_threshold=-42dB,areverse "trim\%%~na.mp3"
)
