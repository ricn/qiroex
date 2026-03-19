# Changelog

All notable changes to Qiroex are documented in this file.

## [1.0.0] - 2026-03-19

First stable release.

### Added

- Decoder-backed conformance tests using a real QR decoder.
- Public doctests across the main API and payload helpers.
- Published reference-vector tests for BCH encoding, Version 5-Q interleaving, and exact final matrix output.
- Renderer capability documentation for SVG, PNG, and terminal output.

### Changed

- Standardized the public option surface on `:level` and `:quiet_zone`.
- Unknown options now fail fast with typo suggestions instead of being silently ignored.
- PNG rendering now rejects SVG-only options such as `:logo` and `:background_image` with explicit guidance.
- Hex package metadata now includes the changelog, docs link, and README example assets.

### Fixed

- Corrected top-left format-information bit placement to match the QR specification.
- Tightened SVG color validation to supported syntaxes and named colors.
- Removed ExDoc warnings and aligned generated docs with the published API.

### Upgrade Notes

- Replace `:ec_level` with `:level`.
- Replace `:margin` with `:quiet_zone`.
- If you passed unknown or misspelled options before, they now return validation errors.