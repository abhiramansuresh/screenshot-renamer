# Screenshot Naming Benchmark Phase 4

Date: 2026-06-05 11:54:06 IST

Git commit: `7d1950c`

Pass/fail count: 6/6 passed, 0 failed

## Runner Notes

Recorded with:

```sh
Tests/ScreenshotNamingBenchmark/run_benchmark.sh
```

Phase 4 moves window and document metadata into the timestamp-matched capture
context used by `ScreenshotProcessor`. This prevents a later app switch from
overriding the correct screenshot context. The benchmark now includes a VLC
movie-title regression case based on the switched-name debug log.

This phase also adds OCR document filename extraction. Filename-looking OCR
tokens with `.md`, `.docx`, `.pdf`, `.pptx`, `.xlsx`, `.swift`, or `.fig` are
promoted above generic OCR phrases, while privacy-sensitive chat apps skip OCR
text naming entirely.

## Results

| Case | Expected name | Generated name | Result |
| --- | --- | --- | --- |
| `Tests/ScreenshotNamingBenchmark/Chrome_BrainMo.png` | `ManualCurriculumPipelineInspector` | `ManualCurriculumPipelineInspector` | Pass |
| `Tests/ScreenshotNamingBenchmark/Chrome_GitHub_Document.png` | `ConflictResolution_TestDriveCrawl_Rule3_GitHub` | `ConflictResolution_TestDriveCrawl_Rule3_GitHub` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo.png` | `CatchUpOnSameDay` | `CatchUpOnSameDay` | Pass |
| `Tests/ScreenshotNamingBenchmark/Finder_Debug.png` | `ScreenRenamer_DebugBuild` | `ScreenRenamer_DebugBuild` | Pass |
| `Tests/ScreenshotNamingBenchmark/Figma_BrainMo_UI_Kit.png` | `TypographySystem` | `TypographySystem` | Pass |
| `Tests/ScreenshotNamingBenchmark/VLC_In_The_Grey.png` | `InTheGrey20261080pWebripX26510bitAAC51YTSBZMp4` | `InTheGrey20261080pWebripX26510bitAAC51YTSBZMp4` | Pass |
