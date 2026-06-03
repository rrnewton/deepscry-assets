# deepscry-assets

Design source assets for **DeepScry** (the `mtg-forge-rs` web frontend at
deepscry.net).

This repo holds the *large, raw design masters* and their **transparent
masters**, so they never bloat the main `mtg-forge-rs` code repo. The small,
web-optimized derivatives that the site serves are pulled into
`mtg-forge-rs/web/` at deploy/validate time by
`mtg-forge-rs/scripts/sync-web-assets.sh` — they are **not** committed into the
app repo (`*.png`/`*.webp`/`*.ico` are gitignored there on purpose). The web
build then content-addresses (CAS-hashes) the derivatives at build time, so the
served filenames are immutable hashes (see `mtg-k935c`).

## Two assets

| Asset      | What                                   | Background removal |
|------------|----------------------------------------|--------------------|
| **logo**   | full DeepScry wordmark/illustration; the hero banner | **rembg** (U²-Net ML matting) |
| **emblem** | compact mark; favicon + app icons (≤256px) | **luminance key** (ImageMagick) |

Two techniques because the sources differ:

- The **logo**'s eye-glow and fire bleed into its dark background, so a
  flood-fill / chroma key either leaves a lit halo or punches holes in the
  subject — only ML matting cuts it cleanly.
- The **emblem** source ships with a *baked light-grey checkerboard* standing in
  for transparency, so a simple luminance key recovers a clean alpha channel
  without ML.

## Layout

```
logos/
  deepscry_logo_raw.png      raw opaque source master (1254², dark bg)
  deepscry_logo.png          rembg ML-matted transparent master
  deepscry_logo_512.webp     web derivative (512px, transparent)
  deepscry_logo_256.webp     web derivative (256px, transparent)
emblem/
  emblem_raw.png             raw source (baked checkerboard bg)
  emblem.png                 luma-keyed transparent master
  emblem_{16,32,48,64,128,180,192,256,512}.png   icon PNG sizes
  emblem_{64,128,256,512}.webp                    accent WebP sizes
  favicon.ico                multi-res (16/32/48) favicon
scripts/
  make-web-derivatives.sh    regenerates BOTH masters + all derivatives
```

## Regenerating

```sh
scripts/make-web-derivatives.sh        # rembg the logo, luma-key the emblem
```

The script resolves `rembg` from `$REMBG`, then any `rembg` on `PATH`, then
bootstraps an isolated venv under `scripts/.venv` (gitignored; the U²-Net model
downloads to `~/.u2net/` on first run). The emblem path needs only ImageMagick
`convert`.

After regenerating, run `mtg-forge-rs/scripts/sync-web-assets.sh` to refresh the
gitignored web copies; nothing here gets committed into `mtg-forge-rs`.

## Inactive-submodule policy

This repo is wired into `mtg-forge-rs` as a **submodule that is NOT checked out
by default** (`update = none` in `.gitmodules`) — normal clones, agent
worktrees, CI, and deploys never pay for the masters. `sync-web-assets.sh` does
an explicit on-demand `git submodule update --init --checkout assets`. The
mtg-forge-rs harness (`scripts/validate.sh`, `multiagent_workspace/scripts/
new_worktree.sh`) treats an uninitialised `update = none` submodule as **clean**,
not dirty.

- **Masters here, derivatives synced into the app, never committed there.**
- New design masters go under a descriptive subdirectory here, with a regen
  step in `scripts/` if they have a web derivative.
