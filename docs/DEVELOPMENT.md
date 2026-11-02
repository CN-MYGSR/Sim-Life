# Development and verification

The development branch is `zugsj666`. Use native Git CLI only; never force push or push to `main`.

## Portable Godot

Validated on Windows x64 with **4.7.2.stable.official.ed1daf0bf**. Official download:
https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_win64.exe.zip

On this development host the editor lives outside the checkout at
`F:\codex\tools\godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe`.
Set `SIM_LIFE_GODOT` to another official installation if needed; no system PATH changes are required.

```powershell
./tools/godot.ps1 --version
./tools/godot.ps1 --headless --editor --import --quit
./tools/godot.ps1 --headless --scene res://tests/benchmark.tscn -- --output=res://.artifacts/headless.json
./tools/godot.ps1 --windowed --resolution 1280x720 --disable-vsync --scene res://tests/benchmark.tscn -- --output=res://.artifacts/rendered.json
```

Benchmarks warm up 120 frames and measure 600 frames with Godot `Performance` monitors.
Headless runs measure CPU/physics and memory only; their draw calls and frame times are **not** GPU performance measurements.
Compare runs using the same seed, renderer, resolution, camera, hardware and frame limiter.
The initial checkout is missing the ignored `assets/kit`, `assets/chars` and `assets/animals` packs;
its missing visuals make it unsuitable as a visual-quality performance baseline.

2026-11-02: clean clone and `--headless --editor --import --quit` passed on the required engine.
The initial runtime reported 41 missing-resource errors; follow-up work restores visible alternatives.
