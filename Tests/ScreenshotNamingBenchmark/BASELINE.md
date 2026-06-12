# Screenshot Naming Benchmark Baseline

Date: 2026-06-05 08:32:34 IST

Git commit: `7d1950c`

Pass/fail count: 0/4 passed, 4 failed

## Runner Notes

`Tests/ScreenshotNamingBenchmark/run_benchmark.sh` now runs the benchmark directly from source without relying on Xcode's hosted XCTest runner.

The original `xcodebuild -project "Screen Renamer.xcodeproj" -scheme "Screen Renamer" -destination "platform=macOS" -derivedDataPath .derivedData test` attempt built the app and test bundle, but the hosted XCTest run failed in this sandbox because Xcode could not reach `testmanagerd.control`.

## Results

| Case | Expected name | Generated name | Result |
| --- | --- | --- | --- |
| `Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png` | `ManualCurriculumPipelineInspector` | `Chrome_Brainmo` | Fail |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png` | `CatchUpOnSameDay` | `Figma_Brainmo` | Fail |
| `Tests/ScreenshotNamingBenchmark/Finder_Debug.png` | `ScreenRenamer_DebugBuild` | `Finder_Debug` | Fail |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png` | `TypographySystem` | `Figma_Brainmo_UI_Kit` | Fail |
