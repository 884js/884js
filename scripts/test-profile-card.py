import importlib.util
from datetime import date
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

SCRIPT = Path(__file__).with_name('generate-profile-card.py')
spec = importlib.util.spec_from_file_location('profile_card', SCRIPT)
card = importlib.util.module_from_spec(spec)
spec.loader.exec_module(card)


def source(values=('4518', '1657', '586'), labels=card.LABELS):
    root = ET.Element(f'{{{card.SVG}}}svg')
    ET.SubElement(root, f'{{{card.SVG}}}desc').text = 'private-repository-must-not-be-published'
    for label, value in zip(labels, values):
        ET.SubElement(root, f'{{{card.SVG}}}text').text = label
        ET.SubElement(root, f'{{{card.SVG}}}text').text = value
    return ET.tostring(root, encoding='unicode')


class ProfileCardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'source.svg'

    def test_plain_and_formatted_counts(self):
        for values in [('4518', '1657', '586'), ('4,518', '1,657', '586')]:
            self.path.write_text(source(values))
            self.assertEqual(card.read_counts(self.path), [4518, 1657, 586])

    def test_rejects_changed_labels_and_invalid_counts(self):
        for value in ['-1', '1.5', '1k', '1,23', '01', 'NaN', '1000000000']:
            with self.subTest(value=value):
                self.path.write_text(source((value, '1', '2')))
                with self.assertRaises(ValueError):
                    card.read_counts(self.path)
        self.path.write_text(source(labels=['Stars:', *card.LABELS[1:]]))
        with self.assertRaises(ValueError):
            card.read_counts(self.path)
        self.path.write_text(source().replace('</svg>', '<text>extra</text></svg>'))
        with self.assertRaises(ValueError):
            card.read_counts(self.path)

    def test_output_contains_only_profile_content(self):
        for mobile in [False, True]:
            with self.subTest(mobile=mobile):
                rendered = card.render_card([4518, 1657, 586], date(2026, 10, 18), mobile)
                root = ET.fromstring(rendered)
                texts = [''.join(node.itertext()) for node in root.iter(f'{{{card.SVG}}}text')]
                self.assertTrue({'4,518', '1,657', '586'} <= set(texts))
                self.assertIn('2026.10.18', rendered)
                for palette in card.PALETTES.values():
                    self.assertIn(palette['paper'], rendered)
                self.assertIn('@media (prefers-color-scheme: dark)', rendered)
                self.assertEqual(root.attrib['width'], '320' if mobile else '640')
                self.assertFalse({'script', 'image', 'foreignObject', 'a'} & {node.tag.split('}')[-1] for node in root.iter()})
                self.assertNotIn('private-repository', rendered)

    def test_large_counts_fit_the_mobile_columns(self):
        rendered = card.render_card([999999999] * 3, date(2026, 10, 18), True)
        root = ET.fromstring(rendered)
        values = [node for node in root.iter(f'{{{card.SVG}}}text') if node.text == '999,999,999']
        self.assertEqual(len(values), 3)
        self.assertTrue(all(11 <= float(node.attrib['font-size']) <= 16 for node in values))

    def test_cli_writes_all_variants_and_preserves_them_on_bad_input(self):
        self.path.write_text(source())
        output = Path(self.temp.name) / 'profile'
        command = [sys.executable, str(SCRIPT), str(self.path), '--output-dir', str(output)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        before = {path.name: path.read_bytes() for path in output.glob('*.svg')}
        self.assertEqual(set(before), {'card.svg', 'card-mobile.svg'})
        self.assertNotIn(b'private-repository', b''.join(before.values()))
        self.path.write_text('<svg>invalid source</svg>')
        self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertEqual(before, {path.name: path.read_bytes() for path in output.glob('*.svg')})


if __name__ == '__main__':
    unittest.main()
