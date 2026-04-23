# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and the project follows Semantic Versioning.

## [Unreleased]

### Changed
- Improved auto-assist object selection with connected-components scoring and user hints.
- Auto-assist now avoids adding aggressive auto-erase strokes by default.
- Extraction now blocks invalid transitions when mask selection is empty or effectively full-image.

### Added
- Mask coverage utility to validate extract preconditions.
- Tests for auto-assist hint behavior and mask coverage edge cases.

## [1.0.0] - 2026-04-23

### Added
- First stable ClipTach release.
- PNG export flow with remembered export folder.
- Polygon keep workflow improvements and stable vertex rendering.
- Pixel-accurate object size controls in object edit mode.
- Save/load project support and recent projects list.
- Auto-assist baseline workflow for initial object marking.

[Unreleased]: https://github.com/YMP112/ClipTach/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/YMP112/ClipTach/releases/tag/v1.0.0
