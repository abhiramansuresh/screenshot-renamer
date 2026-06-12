#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MODULE_CACHE="${ROOT_DIR}/.derivedData/ModuleCache.noindex"

mkdir -p "${MODULE_CACHE}"

{
  cat "${ROOT_DIR}/Screen Renamer/Models/AppContext.swift"
  cat "${ROOT_DIR}/Screen Renamer/Models/OCRToken.swift"
  cat "${ROOT_DIR}/Screen Renamer/Services/WindowMetadataProvider.swift"
  cat "${ROOT_DIR}/Screen Renamer/Services/NoiseFilter.swift"
  cat "${ROOT_DIR}/Screen Renamer/Services/BrandingSuppressor.swift"
  cat "${ROOT_DIR}/Screen Renamer/Services/TextScorer.swift"
  cat "${ROOT_DIR}/Screen Renamer/Services/FilenameGenerator.swift"
  cat "${SCRIPT_DIR}/BenchmarkCases.swift"
  cat "${SCRIPT_DIR}/BenchmarkCLI.swift"
} | swift \
  -D BENCHMARK_STANDALONE \
  -module-cache-path "${MODULE_CACHE}" \
  - "$@"
