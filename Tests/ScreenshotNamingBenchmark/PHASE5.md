# Screenshot Naming Benchmark Phase 5

Date: 2026-06-12 07:18:22 IST

Git commit: `7d1950c`

Pass/fail count: 7/7 passed, 0 failed

## Runner Notes

Recorded with:

```sh
Tests/ScreenshotNamingBenchmark/run_benchmark.sh
```

Phase 5 tightens metadata cleanup and observability:

- Repeated metadata phrases are collapsed before naming.
- Known project/document extensions such as `.xcodeproj` are removed.
- Xcode project screenshots now produce `ScreenRenamer` instead of
  `ScreenRenamerScreenRenamerXcodeproj`.
- Processing logs top OCR candidate summaries for non-chat apps and redacts
  OCR candidate text for privacy-sensitive chat apps.

## Results

| Case | Expected name | Generated name | Result |
| --- | --- | --- | --- |
| `Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png` | `ManualCurriculumPipelineInspector` | `ManualCurriculumPipelineInspector` | Pass |
| `Tests/ScreenshotNamingBenchmark/Chrome_GitHub_Document.png` | `ConflictResolution_TestDriveCrawl_Rule3_GitHub` | `ConflictResolution_TestDriveCrawl_Rule3_GitHub` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png` | `CatchUpOnSameDay` | `CatchUpOnSameDay` | Pass |
| `Tests/ScreenshotNamingBenchmark/Finder_Debug.png` | `ScreenRenamer_DebugBuild` | `ScreenRenamer_DebugBuild` | Pass |
| `Tests/ScreenshotNamingBenchmark/Xcode_Screen_Renamer_Project.png` | `ScreenRenamer` | `ScreenRenamer` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png` | `TypographySystem` | `TypographySystem` | Pass |
| `Tests/ScreenshotNamingBenchmark/VLC_In_The_Grey.png` | `InTheGrey20261080pWebripX26510bitAAC51YTSBZMp4` | `InTheGrey20261080pWebripX26510bitAAC51YTSBZMp4` | Pass |
