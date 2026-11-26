# combegone

Made by CEADD (Chad L).

Removes commercials from TV recordings on your Mac. Drop a recording on the window, get back a copy without the ads.

Uses [Comskip](https://github.com/erikkaashoek/Comskip) to find the commercial breaks and [FFmpeg](https://ffmpeg.org) to cut them out, both built into the app. Nothing else to install.

## Using it

1. Download `combegone.zip` from [Releases](https://github.com/ceadd/combegone/releases/latest), unzip it, and drag **combegone** to Applications.
2. **First launch only:** right-click combegone → **Open** → **Open**. (The app isn't signed with a paid Apple developer certificate, so macOS asks once.)
   On newer macOS, if there's no Open button: System Settings → Privacy & Security → scroll down → **Open Anyway**.
3. Drop recordings on the window (or click **Choose Files…**).

The cleaned copy is saved next to the original as `Name (no ads).ext`. The original is never changed.
Cuts are done without re-encoding — fast and lossless, but edges land on the nearest keyframe (can be ~1 second off).

**Tuning detection:** if you have a `~/.comskip.ini`, combegone uses it instead of its built-in settings.

Requires an Apple Silicon Mac with macOS 14 (Sonoma) or later.

## Building from source

Needs Xcode, plus `autoconf`, `automake`, `libtool` and `pkg-config` (e.g. from Homebrew — only for building; the app doesn't use them).

```bash
make        # builds ffmpeg/comskip (first time ~10–20 min), then build/combegone.app and build/combegone.zip
make test   # unit tests
```

## License

GPL-2.0-or-later. See `LICENSE` and `THIRD_PARTY.md`.
