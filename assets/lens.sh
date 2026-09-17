#!/usr/bin/env bash

image=$(mktemp --tmpdir caelestia-lens.XXXXXX.png)
trap 'rm -f "$image"' EXIT

region=$(slurp)
[ -z "$region" ] && exit 0

if ! grim -g "$region" "$image"; then
    notify-send -a caelestia-shell -u low "Google Lens" "Unable to capture the selected region"
    exit 1
fi

upload_args=(
    --silent
    --show-error
    --fail
    --retry 2
    --connect-timeout 15
    --user-agent "caelestia-shell"
    --form "files[]=@$image"
    https://uguu.se/upload.php
)

if ! response=$(curl "${upload_args[@]}" 2>/dev/null); then
    # Uguu occasionally serves an incomplete certificate chain. Retry without
    # verification only after the normal secure request fails.
    response=$(curl --insecure "${upload_args[@]}" 2>/dev/null) || {
        notify-send -a caelestia-shell -u low "Google Lens" "Image upload failed"
        exit 1
    }
fi

url=$(printf '%s' "$response" | jq --raw-output '.files[0].url // empty')
if [ -z "$url" ]; then
    notify-send -a caelestia-shell -u low "Google Lens" "Upload returned no image URL"
    exit 1
fi

xdg-open "https://lens.google.com/uploadbyurl?url=${url}" >/dev/null 2>&1
notify-send -a caelestia-shell "Google Lens" "Analysis opened in your browser"
