#!/usr/bin/env bash
# Regenerate the transparent masters + web derivatives for both DeepScry assets.
#
# Two distinct assets, two distinct background-removal techniques:
#
#   logos/   the full DeepScry wordmark/illustration.
#            raw (opaque dark bg) --rembg ML matting--> transparent master --resize--> WebP
#            The eye-glow / fire bleed into the dark background, so a flood-fill
#            or chroma key leaves a lit halo or punches holes — only U^2-Net ML
#            matting cuts it cleanly.
#
#   emblem/  the compact mark used for the favicon + app icons.
#            raw (baked checkerboard "transparency" bg) --luma key--> transparent
#            master --resize--> PNG/WebP sizes + multi-res favicon.ico
#            The emblem source ships with a painted light-grey checkerboard
#            standing in for transparency; a luminance key recovers a clean
#            alpha channel without ML.
#
# Deterministic given the same sources (+ the U^2-Net model for the logo).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(dirname "$here")"

logo_raw="$root/logos/deepscry_logo_raw.png"      # raw opaque source
logo_master="$root/logos/deepscry_logo.png"       # ML-matted, transparent
emblem_raw="$root/emblem/emblem_raw.png"          # raw, baked checkerboard bg
emblem_master="$root/emblem/emblem.png"           # luma-keyed, transparent

command -v convert >/dev/null || { echo "ImageMagick 'convert' required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# rembg resolution. Prefer an existing rembg ($REMBG or one already on PATH);
# otherwise bootstrap an isolated venv under scripts/.venv (gitignored).
# (ensurepip is broken on some distros, so bootstrap pip via get-pip; an
# isolated venv also avoids the numpy ABI clash of --break-system-packages.)
# ---------------------------------------------------------------------------
venv="$here/.venv"
REMBG="${REMBG:-}"
if [ -z "$REMBG" ]; then
  if command -v rembg >/dev/null; then
    REMBG="$(command -v rembg)"
  else
    if [ ! -x "$venv/bin/rembg" ]; then
      echo "Bootstrapping rembg venv at $venv ..."
      python3 -m venv --without-pip "$venv"
      curl -fsSL https://bootstrap.pypa.io/get-pip.py | "$venv/bin/python" - --quiet
      "$venv/bin/pip" install --quiet "rembg[cli]" onnxruntime pillow
    fi
    REMBG="$venv/bin/rembg"
  fi
fi

# ===========================================================================
# 1. LOGO — ML background removal -> transparent master -> WebP derivatives.
# ===========================================================================
echo "→ logo: rembg ML matte ($REMBG)"
"$REMBG" i "$logo_raw" "$logo_master"
for px in 256 512; do
  convert "$logo_master" -resize ${px}x${px} -strip -quality 90 \
    "$root/logos/deepscry_logo_${px}.webp"
done

# ===========================================================================
# 2. EMBLEM — luminance key -> transparent master -> PNG/WebP sizes + favicon.
#    The baked checkerboard is near-white; level 89%,95% + negate turns the
#    luma into an alpha mask (CopyOpacity), dropping the background.
# ===========================================================================
echo "→ emblem: luma key"
convert "$emblem_raw" \
  \( +clone -alpha off -colorspace gray -level 89%,95% -negate \) \
  -alpha off -compose CopyOpacity -composite "$emblem_master"

for px in 16 32 48 64 128 180 192 256 512; do
  convert "$emblem_master" -resize ${px}x${px} -strip "$root/emblem/emblem_${px}.png"
done
for px in 64 128 256 512; do
  convert "$emblem_master" -resize ${px}x${px} -strip -quality 90 \
    "$root/emblem/emblem_${px}.webp"
done
# Multi-resolution favicon (16/32/48 packed into one .ico).
convert "$root/emblem/emblem_16.png" "$root/emblem/emblem_32.png" \
  "$root/emblem/emblem_48.png" "$root/emblem/favicon.ico"

echo
echo "Regenerated logo + emblem masters and derivatives."
echo "Web copies are pulled into mtg-forge-rs/web/ at deploy/validate time by"
echo "mtg-forge-rs/scripts/sync-web-assets.sh — the app then content-addresses"
echo "(CAS-hashes) them at build time (see mtg-k935c). Nothing here is committed"
echo "into mtg-forge-rs; only this submodule's gitlink is."
