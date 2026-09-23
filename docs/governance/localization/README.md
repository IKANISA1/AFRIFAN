# Localization source dispositions

These tracked registries make the Flutter literal and dynamic-copy inventories
reproducible in CI. They classify exact current-source boundaries; they do not
approve live CMS wording, translations, screenshots, or store listings.

- `flutter-copy-dispositions.json` records exact literals that are internal
  diagnostics, localized navigation fallbacks, or runtime values rather than
  untranslated supporter copy.
- `dynamic-copy-dispositions.json` governs proper names, source-authored
  editorial content, controlled enum/status mappings, and the runtime-copy
  locale channel with fail-closed expected match counts.

Any source change that adds, removes, or changes a candidate must update the
relevant registry through code and localization review. English editorial
approval remains an accountable external gate.
