# Third-party components

combegone.app bundles these programs, built from source by `scripts/build-deps.sh`.
Full license texts are in `Resources/Licenses/` and in the app under **combegone → About combegone**.

| Component | Version | License | Source |
|---|---|---|---|
| Comskip | 0.83.001 (commit a140b6a) | GPL-2.0 | https://github.com/erikkaashoek/Comskip |
| FFmpeg (ffmpeg, ffprobe, libav*) | 6.1.2, `--enable-gpl` | GPL-2.0-or-later | https://ffmpeg.org/releases/ffmpeg-6.1.2.tar.xz |
| Argtable | 2.13 | LGPL-2.0-or-later | https://argtable.sourceforge.io |

Only macOS system libraries (libSystem, libz, libbz2, libiconv, Apple frameworks) are linked dynamically.
