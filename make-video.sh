#!/usr/bin/env bash
# Render the deck and turn it into an MP4, one frame per slide step
# (each fragment is its own step). Needs quarto, chromium, pdftoppm, ffmpeg.
#
# Usage: ./make-video.sh [seconds per step] [music file] [music start]
#
# Seconds per step default to 4. The optional music file can be any format
# ffmpeg reads (ogg, mp3, wav, ...). It loops with a 1 s crossfade if
# shorter than the video, is cut to the video length, and fades in and out.
# The music start, in seconds or as mm:ss, skips the beginning of the track.
set -euo pipefail
cd "$(dirname "$0")"

secs="${1:-4}"
music="${2:-}"
music_start="${3:-0}"
if [[ -n "$music" ]]; then music="$(realpath "$music")"; fi
deck="ggindex-showcase"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

quarto render "$deck.qmd"

chromium --headless --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=10000 \
  --print-to-pdf="$tmp/deck.pdf" \
  "file://$PWD/$deck.html?print-pdf&pdfSeparateFragments=true" 2>/dev/null

pdftoppm -png -scale-to-x 1920 -scale-to-y 1080 "$tmp/deck.pdf" "$tmp/frame"

# Each step is a still image shown for $secs seconds, blended into the
# next with a crossfade. The video fades in from and out to white.
xf=0.5
calc() { awk "BEGIN { print $1 }"; }
frames=("$tmp"/frame-*.png)
n=${#frames[@]}
inputs=()
filter=""
for i in "${!frames[@]}"; do
  inputs+=(-loop 1 -framerate 30 -t "$(calc "$secs + $xf")" -i "${frames[$i]}")
  filter+="[$i:v]format=yuv420p,setsar=1[v$i];"
done
prev="v0"
for ((i = 1; i < n; i++)); do
  filter+="[$prev][v$i]xfade=transition=fade:duration=$xf:offset=$(calc "$i * $secs")[x$i];"
  prev="x$i"
done
total=$(calc "$n * $secs + $xf")
filter+="[$prev]fade=t=in:st=0:d=0.8:color=white,"
filter+="fade=t=out:st=$(calc "$total - 1"):d=1:color=white[out]"

audio=()
if [[ -n "$music" ]]; then
  start=$(awk -F: '{ s = 0; for (i = 1; i <= NF; i++) s = s * 60 + $i; print s }' <<<"$music_start")
  # Repeat the track often enough to cover the video, joining the copies
  # with a 1 s crossfade so the restart is smooth.
  axf=1
  len=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$music")
  copies=$(awk -v n="$(calc "$start + $total")" -v l="$len" -v x="$axf" \
    'BEGIN { c = 1; while (c * l - (c - 1) * x < n) c++; print c }')
  inputs+=(-i "$music")
  if ((copies > 1)); then
    filter+=";[$n:a]asplit=$copies"
    for ((i = 0; i < copies; i++)); do filter+="[m$i]"; done
    prev="m0"
    for ((i = 1; i < copies; i++)); do
      filter+=";[$prev][m$i]acrossfade=d=$axf[mx$i]"
      prev="mx$i"
    done
    filter+=";[$prev]"
  else
    filter+=";[$n:a]"
  fi
  filter+="atrim=start=$start:end=$(calc "$start + $total"),asetpts=PTS-STARTPTS,"
  filter+="afade=t=in:d=1,afade=t=out:st=$(calc "$total - 2"):d=2[aout]"
  audio=(-map "[aout]" -c:a aac -b:a 192k)
fi

ffmpeg -y -loglevel error "${inputs[@]}" \
  -filter_complex "$filter" -map "[out]" "${audio[@]}" \
  -r 30 -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart \
  "$deck.mp4"

echo "Wrote $PWD/$deck.mp4"
