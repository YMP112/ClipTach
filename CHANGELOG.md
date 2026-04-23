# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning.

## [Unreleased]

## [1.1.0] - 2026-04-23

### Added
- Connected-components based auto-assist scoring with keep/erase user hints.
- Mask coverage validation before extraction, including empty/full-selection guards.
- Tests for auto-assist hint routing and mask-coverage edge cases.
- Full Hebrew UI localization coverage for editor and export flow labels.

### Changed
- Auto-assist fill density was increased to reduce holey masks.
- Auto-assist no longer adds aggressive auto-erase strokes by default.
- Export and in-editor strings now consistently use localization keys.

## [1.0.0] - 2026-04-23

### Added
- First stable ClipTach release.
- PNG export flow with remembered export folder.
- Polygon keep workflow improvements and stable vertex rendering.
- Pixel-accurate object size controls in object edit mode.
- Save/load project support and recent projects list.
- Auto-assist baseline workflow for initial object marking.

[Unreleased]: https://github.com/YMP112/ClipTach/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/YMP112/ClipTach/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/YMP112/ClipTach/releases/tag/v1.0.0
