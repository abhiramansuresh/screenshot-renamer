# Screenshot Naming Benchmark Phase 3

Date: 2026-06-05 09:17:13 IST

Git commit: `7d1950c`

Pass/fail count: 4/4 passed, 0 failed

## Runner Notes

Recorded with:

```sh
Tests/ScreenshotNamingBenchmark/run_benchmark.sh
```

Phase 3 adds `BrandingSuppressor` and demotes low-value branding/app/navigation words in OCR phrase scoring. There was no regression versus Phase 2.

## Results

| Case | Expected name | Generated name | Result |
| --- | --- | --- | --- |
| `Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png` | `ManualCurriculumPipelineInspector` | `ManualCurriculumPipelineInspector` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png` | `CatchUpOnSameDay` | `CatchUpOnSameDay` | Pass |
| `Tests/ScreenshotNamingBenchmark/Finder_Debug.png` | `ScreenRenamer_DebugBuild` | `ScreenRenamer_DebugBuild` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png` | `TypographySystem` | `TypographySystem` | Pass |
