# Graph Report - .  (2026-07-12)

## Corpus Check
- 66 files · ~430,141 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 543 nodes · 1265 edges · 22 communities (21 shown, 1 thin omitted)
- Extraction: 94% EXTRACTED · 6% INFERRED · 0% AMBIGUOUS · INFERRED: 72 edges (avg confidence: 0.82)
- Token cost: 90,925 input · 0 output

## Community Hubs (Navigation)
- App Lifecycle & Startup
- Filename Generation Logic
- Context Tracking & Browser Detection
- Screenshot Watching & File System
- Context Matching
- Cross-Service Core Imports
- Noise & Branding Filtering
- App Entry & Menu Bar UI
- Naming Template Model
- OCR Token Recognition
- App Folder Organization
- Context Tracking Rationale
- OCR & Filtering Rationale
- Launch-at-Login Management
- Debug Logging
- Filename Cleanup Rule Chain
- MVP Vision & Benchmarking
- Naming & Organization Rationale
- Window Metadata Priority
- Benchmark Phase 5 Metadata Cleanup
- MVP Requirements & Stack
- Benchmark Runner Script

## God Nodes (most connected - your core abstractions)
1. `FilenameGenerator` - 60 edges
2. `AppContext` - 51 edges
3. `ContextTracker` - 48 edges
4. `AppController` - 46 edges
5. `ScreenshotWatcher` - 32 edges
6. `OCRNamingTests` - 23 edges
7. `Foundation` - 22 edges
8. `NamingField` - 17 edges
9. `OCRToken` - 16 edges
10. `OCRResult` - 16 edges

## Surprising Connections (you probably didn't know these)
- `Filename Decision Order (metadata before OCR)` --semantically_similar_to--> `Full Filename Decision Order (6 steps)`  [INFERRED] [semantically similar]
  README.md → screen_renamer_mvp_spec.md
- `ContextTracker` --semantically_similar_to--> `Context Tracker (spec)`  [INFERRED] [semantically similar]
  README.md → screen_renamer_mvp_spec.md
- `FilenameGenerator` --semantically_similar_to--> `Filename Renamer (spec)`  [INFERRED] [semantically similar]
  README.md → screen_renamer_mvp_spec.md
- `Screenshot Naming Benchmark` --semantically_similar_to--> `BenchmarkCase struct`  [INFERRED] [semantically similar]
  README.md → screen_renamer_mvp_spec.md
- `Screenshot Naming Benchmark Phase 2 Report` --semantically_similar_to--> `Phase 1 Benchmark Cases`  [INFERRED] [semantically similar]
  Tests/ScreenshotNamingBenchmark/PHASE2.md → screen_renamer_mvp_spec.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Screenshot Naming Pipeline (8 runtime components)** — readme_contexttracker, readme_screenshotwatcher, readme_contextmatcher, readme_screenshotprocessor, readme_ocrprocessor, readme_textscorer, readme_filenamegenerator, readme_screenshotorganizer [EXTRACTED 1.00]
- **Filename Cleanup Rules 1-9 Pipeline** — spec_rule1_strip_urls, spec_rule2_strip_domain_tokens, spec_rule3_remove_app_suffix, spec_rule4_search_query_collapse, spec_rule5_word_truncation_casing, spec_rule6_illegal_chars, spec_rule7_normalize_separators, spec_rule8_low_quality_fallback, spec_rule9_length_limit [EXTRACTED 1.00]
- **Benchmark Phase Progression (Baseline through Phase 5)** — tests_screenshotnamingbenchmark_baseline_benchmark_report, tests_screenshotnamingbenchmark_phase2_benchmark_report, tests_screenshotnamingbenchmark_phase3_benchmark_report, tests_screenshotnamingbenchmark_phase4_benchmark_report, tests_screenshotnamingbenchmark_phase5_benchmark_report [EXTRACTED 1.00]

## Communities (22 total, 1 thin omitted)

### Community 0 - "App Lifecycle & Startup"
Cohesion: 0.06
Nodes (21): Notification, NSApplication, NSApplicationDelegate, NSObject, NSPanel, NumberFormatter, ObservableObject, AppController (+13 more)

### Community 1 - "Filename Generation Logic"
Cohesion: 0.12
Nodes (8): FilenameGenerator, Bool, DateFormatter, Float, Int, Set, String, URL

### Community 2 - "Context Tracking & Browser Detection"
Cohesion: 0.12
Nodes (13): NSObjectProtocol, NSRunningApplication, pid_t, ContextSignature, ContextTracker, AXUIElement, Bool, CFString (+5 more)

### Community 3 - "Screenshot Watching & File System"
Cohesion: 0.11
Nodes (20): CInt, DispatchSourceFileSystemObject, escaping, MainActor, DirectoryWatcher, URL, Array, ScreenshotCaptureTime (+12 more)

### Community 4 - "Context Matching"
Cohesion: 0.12
Nodes (17): Equatable, AppContext, Bool, Date, Set, String, ContextMatcher, Date (+9 more)

### Community 5 - "Cross-Service Core Imports"
Cohesion: 0.08
Nodes (17): CoreGraphics, Darwin, Foundation, ImageIO, ScreenshotLocationResolver, Any, URL, ScreenRenamer (+9 more)

### Community 6 - "Noise & Branding Filtering"
Cohesion: 0.11
Nodes (17): Double, BrandingSuppressor, Bool, Set, String, NoiseFilter, Bool, Set (+9 more)

### Community 7 - "App Entry & Menu Bar UI"
Cohesion: 0.11
Nodes (16): App, AppKit, ApplicationServices, Scene, NSImage, ScreenRenamerApp, String, View (+8 more)

### Community 8 - "Naming Template Model"
Cohesion: 0.09
Nodes (23): Binding, CaseIterable, Codable, Hashable, Identifiable, NamingField, app, date (+15 more)

### Community 9 - "OCR Token Recognition"
Cohesion: 0.13
Nodes (16): OCRResult, OCRToken, CGRect, CGSize, Float, String, OCRProcessor, Any (+8 more)

### Community 10 - "App Folder Organization"
Cohesion: 0.31
Nodes (8): FileManager, AppFolderIdentity, ScreenshotOrganizer, Bool, Int, Set, String, URL

### Community 11 - "Context Tracking Rationale"
Cohesion: 0.15
Nodes (17): ContextMatcher, ContextTracker, Debug Log (~/Library/Application Support/Screen Renamer/debug.log), Menu Bar App UI, Rolling App/Window Context Buffer, ScreenshotWatcher, NSWorkspace Activation Burst Capture (~50ms/~150ms), AppContext struct (+9 more)

### Community 12 - "OCR & Filtering Rationale"
Cohesion: 0.21
Nodes (13): BrandingSuppressor, NoiseFilter, OCRProcessor, Privacy-Sensitive Chat App OCR Exclusion, ScreenshotProcessor, Branding Suppression (stopword list), OCR Processor and Text Scoring (spec), Deterministic OCR Scoring Heuristics (+5 more)

### Community 13 - "Launch-at-Login Management"
Cohesion: 0.23
Nodes (7): LocalizedError, LoginItemError, unknownStatus, LoginItemManager, Bool, String, ServiceManagement

### Community 14 - "Debug Logging"
Cohesion: 0.26
Nodes (4): ScreenshotDebugLogger, ISO8601DateFormatter, String, URL

### Community 15 - "Filename Cleanup Rule Chain"
Cohesion: 0.17
Nodes (12): Known Acronym Casing List (API, JSON, UI, PDF, etc.), Collision Handling (incrementing suffix), Filename Cleanup Rules (8-step pipeline), Rule 1 - Strip Raw URLs, Rule 2 - Strip Domain Tokens for Browsers, Rule 3 - Remove App Suffix Noise, Rule 4 - Detect and Collapse Search Queries, Rule 5 - Word Truncation and Title Casing (+4 more)

### Community 16 - "MVP Vision & Benchmarking"
Cohesion: 0.18
Nodes (11): Git commit 7d1950c (feat(logic): adds apple native OCR to make it smarter), Local-First Privacy Principle, run_benchmark.sh, Screen Renamer (Project), Screenshot Naming Benchmark, ScreenshotNamingBenchmarkTests, Core UX Principles (deterministic, local-first, reliable over clever), MVP Scope (Included / Explicitly Not Included) (+3 more)

### Community 17 - "Naming & Organization Rationale"
Cohesion: 0.33
Nodes (7): Quiet App Folder Auto-Organization (5-screenshot threshold), Filename Decision Order (metadata before OCR), FilenameGenerator, ScreenshotOrganizer, TextScorer, App Folder Auto-Organization (spec), appFolderThreshold = 5 (code-level constant)

### Community 18 - "Window Metadata Priority"
Cohesion: 0.29
Nodes (7): Known Browser Domain Display Names, Context Fallback Format [App]_[PageName], Full Filename Decision Order (6 steps), OCR Document Name Extraction (.md .docx .pdf .pptx .xlsx .swift .fig), Window Metadata Priority Rationale (deterministic, more precise than OCR), Window Metadata Provider (spec), WindowMetadata struct

### Community 19 - "Benchmark Phase 5 Metadata Cleanup"
Cohesion: 0.47
Nodes (6): BenchmarkCase struct, Filename Renamer (spec), Metadata Cleanup (extension stripping, phrase collapsing), OCR Candidate Debug Logging (ocr_candidates / ocr_candidates_redacted), Phase 1 Benchmark Cases, Screenshot Naming Benchmark Phase 5 Report

### Community 20 - "MVP Requirements & Stack"
Cohesion: 0.40
Nodes (5): First Launch Experience (Accessibility permission prompt), Menu Bar App (spec section), Performance Requirements (500ms sampling, 10s buffer), Recommended Stack (SwiftUI, AppKit, Accessibility APIs), Success Criteria (80%+ more useful filenames)

## Knowledge Gaps
- **35 isolated node(s):** `accessibility`, `launchAtStartup`, `app`, `windowTitle`, `tabName` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppContext` connect `Context Matching` to `Filename Generation Logic`, `Context Tracking & Browser Detection`, `Screenshot Watching & File System`, `Cross-Service Core Imports`, `Noise & Branding Filtering`, `Naming Template Model`, `OCR Token Recognition`?**
  _High betweenness centrality (0.183) - this node is a cross-community bridge._
- **Why does `AppController` connect `App Lifecycle & Startup` to `Context Tracking & Browser Detection`, `Screenshot Watching & File System`, `App Entry & Menu Bar UI`, `Naming Template Model`, `Debug Logging`?**
  _High betweenness centrality (0.163) - this node is a cross-community bridge._
- **Why does `ContextTracker` connect `Context Tracking & Browser Detection` to `App Lifecycle & Startup`, `Screenshot Watching & File System`, `Context Matching`?**
  _High betweenness centrality (0.158) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `FilenameGenerator` (e.g. with `OCRNamingTests` and `.generatedName()`) actually correct?**
  _`FilenameGenerator` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 4 inferred relationships involving `AppContext` (e.g. with `.pruneBuffer()` and `.stop()`) actually correct?**
  _`AppContext` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `AppController` (e.g. with `ContextTracker` and `ScreenshotWatcher`) actually correct?**
  _`AppController` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `accessibility`, `launchAtStartup`, `app` to the rest of the system?**
  _35 weakly-connected nodes found - possible documentation gaps or missing edges._