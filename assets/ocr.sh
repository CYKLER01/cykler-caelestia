#!/usr/bin/env bash

region=$(slurp)
[ -z "$region" ] && exit 0

text=$(grim -g "$region" - | tesseract stdin stdout -l eng 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')

if [ -n "$text" ]; then
    printf '%s' "$text" | wl-copy
    notify-send -a caelestia-shell "OCR" "Text copied to clipboard"
else
    notify-send -a caelestia-shell -u low "OCR" "No text detected"
fi
