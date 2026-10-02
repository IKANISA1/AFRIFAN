#!/usr/bin/env python3
"""Negative source-contract proofs for dynamic golden filename resolution."""

import json
import struct
import tempfile
import unittest
from pathlib import Path

from golden_test_references import Source, find_reference


PROFILE_SOURCE = """
void main() {
  for (final profile in _profiles) {
    testWidgets('golden ${profile.id}', (tester) async {
      _setGoldenSurface(tester, profile.size);
      ColorTokens.setBrightness(profile.brightness);
      await expectGoldenOrClubAssertions(tester, find.byType(HomeScreen),
        'goldens/home_${profile.id}.png');
    });
  }
}
const _profiles = <({String id, Size size, Brightness brightness})>[
  (id: 'compact_dark_320x760', size: Size(320, 760), brightness: Brightness.dark),
  (id: 'tablet_light_834x1194', size: Size(834, 1194), brightness: Brightness.light),
];
"""


class GoldenReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.test_root = self.root / 'packages/features/feat_home/test'
        self.test_root.mkdir(parents=True)
        self.source = self.test_root / 'home_states_test.dart'
        self.source.write_text(PROFILE_SOURCE)

    def baseline(self, name='home_compact_dark_320x760.png', width=320, height=760, theme='dark'):
        path = self.test_root / 'goldens' / name
        path.parent.mkdir(exist_ok=True)
        # The resolver reads the PNG signature and IHDR dimensions only.
        path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR' + struct.pack('>II', width, height))
        return {'path': str(path.relative_to(self.root)),
                'viewport': {'width': width, 'height': height}, 'theme': theme}

    def resolves(self, baseline):
        return find_reference(self.root, baseline, {}) is not None

    def test_actual_declared_home_profile_template_resolves(self):
        self.assertTrue(self.resolves(self.baseline()))
        self.assertTrue(self.resolves(self.baseline('home_tablet_light_834x1194.png', 834, 1194, 'light')))

    def test_dangling_case_cannot_use_an_unrelated_literal_id(self):
        self.source.write_text(PROFILE_SOURCE + "\nconst unused = (id: 'removed_dark_320x760', size: Size(320, 760), brightness: Brightness.dark);")
        self.assertFalse(self.resolves(self.baseline('home_removed_dark_320x760.png')))

    def test_wrong_case_id_and_case_are_rejected(self):
        self.assertFalse(self.resolves(self.baseline('home_compact_light_320x760.png')))
        self.assertFalse(self.resolves(self.baseline('home_Compact_dark_320x760.png')))

    def test_same_filename_with_wrong_declared_case_viewport_is_rejected(self):
        self.source.write_text(PROFILE_SOURCE.replace('size: Size(320, 760)', 'size: Size(390, 844)'))
        self.assertFalse(self.resolves(self.baseline()))

    def test_viewport_and_theme_cannot_be_mixed_between_profiles(self):
        self.assertFalse(self.resolves(self.baseline(width=834, height=1194)))
        self.assertFalse(self.resolves(self.baseline(theme='light')))

    def test_other_test_file_cannot_supply_missing_case(self):
        self.source.write_text(PROFILE_SOURCE.replace('compact_dark_320x760', 'other_dark_320x760'))
        (self.test_root / 'unrelated_test.dart').write_text("const id = 'compact_dark_320x760'; const viewport = '320x760'; const theme = 'dark'; matchesGoldenFile('goldens/unrelated.png');")
        self.assertFalse(self.resolves(self.baseline()))

    def test_comments_and_unused_non_test_source_are_not_references(self):
        self.source.write_text("// matchesGoldenFile('goldens/home_compact_dark_320x760.png');\n")
        (self.test_root / 'helper.dart').write_text(PROFILE_SOURCE)
        self.assertFalse(self.resolves(self.baseline()))

    def test_wrong_template_prefix_is_rejected(self):
        self.source.write_text(PROFILE_SOURCE.replace('goldens/home_', 'goldens/wrong_'))
        self.assertFalse(self.resolves(self.baseline()))

    def test_adjacent_templates_bind_enum_and_component_cases(self):
        self.source.write_text("""
enum _State { hover, focused, pressed }
class _Spec { String get fileKey => componentKey.replaceAll('|', '_'); }
void main() {
  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    for (final spec in _specs) {
      for (final state in _State.values) {
        matchesGoldenFile('goldens/${spec.fileKey}_${state.name}_'
          '${brightness.name}.png');
      }
    }
  }
}
final _specs = [_Spec(componentKey: 'app_shell|bottom_nav')];
""")
        self.assertTrue(self.resolves(self.baseline('app_shell_bottom_nav_focused_dark.png')))
        self.assertFalse(self.resolves(self.baseline('app_shell_bottom_nav_unknown_dark.png')))
        self.assertFalse(self.resolves(self.baseline('wrong_component_focused_dark.png')))

    def test_real_home_source_resolves_actual_manifest_profile(self):
        repo = Path(__file__).resolve().parents[2]
        manifest = json.loads((repo / 'docs/governance/golden-baselines.json').read_text())
        baseline = next(b for b in manifest['baselines'] if b['path'].endswith('/home_compact_dark_320x760.png'))
        self.assertIsNotNone(find_reference(repo, baseline, {}))


if __name__ == '__main__':
    unittest.main()
