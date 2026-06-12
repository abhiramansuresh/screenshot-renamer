# Screenshot Naming Benchmark Phase 2

Date: 2026-06-05 09:06:39 IST

Git commit: `7d1950c`

Pass/fail count: 4/4 passed, 0 failed

## Runner Notes

Recorded with:

```sh
Tests/ScreenshotNamingBenchmark/run_benchmark.sh
```

Phase 2 adds `WindowMetadataProvider` and inserts window metadata before OCR in the filename decision order. Benchmark fixtures now include the window title or document name metadata expected from the active window.

## Results

| Case | Expected name | Generated name | Result |
| --- | --- | --- | --- |
| `Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png` | `ManualCurriculumPipelineInspector` | `ManualCurriculumPipelineInspector` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png` | `CatchUpOnSameDay` | `CatchUpOnSameDay` | Pass |
| `Tests/ScreenshotNamingBenchmark/Finder_Debug.png` | `ScreenRenamer_DebugBuild` | `ScreenRenamer_DebugBuild` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png` | `TypographySystem` | `TypographySystem` | Pass |
