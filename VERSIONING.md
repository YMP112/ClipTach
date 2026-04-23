# Versioning Policy

ClipTach uses Semantic Versioning:

- `MAJOR.MINOR.PATCH+BUILD`
- Example: `1.0.0+1`

## Rules

1. Increment `MAJOR` for breaking changes.
2. Increment `MINOR` for backward-compatible features.
3. Increment `PATCH` for backward-compatible fixes.
4. Increment `BUILD` for rebuild/repackaging without functional change.

## Release Checklist

1. Update `pubspec.yaml` version.
2. Move changes from `Unreleased` into a dated release section in `CHANGELOG.md`.
3. Run:
   - `flutter analyze`
   - `flutter test`
4. Commit with message: `Release vX.Y.Z`.
5. Create annotated tag: `vX.Y.Z`.
6. Push branch and tag.
7. Create GitHub release notes from the matching `CHANGELOG.md` section.
