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

## Stability pass (2026-11-02)

`./tools/test.ps1` passed: editor import, 32 regression checks and the existing
weapon-qualification UI tests (`QUIZ_DEMO_DONE fail=0`). The runner treats engine
script/resource errors as failures even when Godot returns exit code zero.

Covered fixes: missing building/character packs now have visible animated replacements;
negative purchases and invalid upgrade/paint inputs are rejected; fines charge money;
rent lasts seven inclusive days and expired jobs stop; multi-day clock advancement works;
career changes cancel incompatible missions; invalid/overlapping furniture never charges;
refunding is idempotent; vehicle upgrades retain node/location and paint leaves glass intact;
enter/exit restores collision and camera, and tablet close releases the driver UI lock;
pause freezes the simulation; arrest follows the real fleeing target and killing a target
does not pay for an arrest; patrol completion records visited points and pays only once.
Business is limited to a valid rented shop/career/proximity; customers expire after 30 seconds.

Run `./tools/test.ps1` for automated verification. Local logs are under `.artifacts/`.
The development host has an AMD FirePro W2100 with 2 GiB VRAM. Forward+ initialization
works; the Windows session has no working WASAPI output, so audio listening remains unverified.

## Persistence and batching pass

The suite now passes 42 regression checks plus the existing quiz tests. It exercises
save roundtrip, atomic replacement, backup recovery after corruption, rejecting non-finite
and invalid upgrades, and leaving current state intact when neither save is readable.
Saves use `user://saves/city.save` with a `.bak` recovery copy. The pause menu exposes
save/load and save-and-quit; a 60-second autosave and window-close save are enabled in
normal play. Tests pass `--no-save` and use an isolated `.artifacts/regression.save`.
Positions, furniture, careers, rent, money, mission waypoints, weapons and magazines persist.
Reloading/equipping a weapon no longer refills its magazine.

Static interior boxes are grouped by material into per-building MultiMeshes after layout
and path pruning. Furniture collision shapes and existing facade batching remain in place.
The four-block-per-side scene now has about 3,000 nodes instead of about 6,100 with the
fallback visuals. Raw runs are kept locally; renderer-specific comparisons still require
an identical camera, seed, viewport and warmup. No FPS gain is claimed from node count alone.
