# Slides to video

This folder holds a Quarto revealjs slide deck that showcases ggindex and a
script that turns the deck into a short MP4 video.

## Files

| File | Purpose |
|------|---------|
| `ggindex-showcase.qmd` | The deck. Each example slide runs R code and shows its plot. |
| `theme.scss` | Colors, fonts and the plot/code column widths. |
| `plot-first.html` | Small script that shows the plot first and the code second. |
| `logo.svg`, `header.png` | ggindex hex logo and Discindo logo. |
| `make-video.sh` | Renders the deck and builds the video. |

Not in repo: a music file (ogg or mp3) can be passed to `make-video.sh` to add background music to the video.

## Requirements

- Quarto, R, and the R packages ggplot2, ggindex and sf
- Chromium (headless, for printing the deck to PDF)
- `pdftoppm` (from poppler)
- ffmpeg and ffprobe
- awk

## Usage

```bash
# 4 s per step, no music
./make-video.sh   
# 5 s per step
./make-video.sh 5                  
# with music              
./make-video.sh 4 music.ogg        
# music from 1:29.25
./make-video.sh 4 music.ogg 1:29.25       
```

See more at [The ggindex video showcase](https://discindo.org/posts/2026-11-16-ggindex-video-showcase/).