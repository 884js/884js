#!/usr/bin/env python3
"""Turn the existing private-activity totals into the 884js profile card."""

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SVG = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG)
LABELS = ['Total Commits (last year):', 'Total PRs:', 'Total PRs Reviewed:']
STACK = [
    ('Web', ['TypeScript / React / Next.js']),
    ('モバイル', ['React Native / Expo']),
    ('バックエンド', ['NestJS / Express / Hono', 'Go / Ruby on Rails']),
    ('インフラ', ['Cloudflare / AWS']),
]
PIXEL_FONT = json.loads((ROOT / 'templates/profile/pixel-glyphs.json').read_text(encoding='utf-8'))
PALETTES = {
    'light': {'paper': '#f5f0e7', 'ink': '#25231f', 'muted': '#645d54', 'panel': '#e6dfd2'},
    'dark': {'paper': '#22211e', 'ink': '#f1eadd', 'muted': '#bab1a2', 'panel': '#33302b'},
}


def text_width(value, size):
    try:
        return sum(PIXEL_FONT['glyphs'][char]['advance'] for char in value) * size / PIXEL_FONT['units_per_em']
    except KeyError as error:
        raise ValueError(f'Missing pixel glyph: {error.args[0]}') from error


def read_counts(path):
    data = path.read_bytes()
    if len(data) > 131072 or b'<!DOCTYPE' in data or b'<!ENTITY' in data:
        raise ValueError('Unexpected activity source.')
    root = ET.fromstring(data)
    texts = [''.join(node.itertext()).strip() for node in root.iter(f'{{{SVG}}}text')]
    if root.tag != f'{{{SVG}}}svg' or len(texts) != 6 or texts[::2] != LABELS:
        raise ValueError('Activity source must contain only commits, PRs, and reviews.')
    values = texts[1::2]
    if not all(re.fullmatch(r'(0|[1-9]\d{0,8}|[1-9]\d{0,2}(?:,\d{3}){1,2})', value, re.ASCII) for value in values):
        raise ValueError('Invalid activity counts.')
    return [int(value.replace(',', '')) for value in values]


def render_card(counts, updated_at, mobile=False):
    colors = {name: f'var(--{name})' for name in PALETTES['light']}
    width, height = (320, 638) if mobile else (640, 530)
    main_height = 448 if mobile else 350
    root = ET.Element(f'{{{SVG}}}svg', {
        'width': str(width), 'height': str(height), 'viewBox': f'0 0 {width} {height}',
        'role': 'img', 'aria-labelledby': 'title description',
        'fill': colors['ink'],
    })

    def element(tag, attributes=None, parent=root):
        return ET.SubElement(parent, f'{{{SVG}}}{tag}', {key: str(value) for key, value in (attributes or {}).items()})

    element('title', {'id': 'title'}).text = '884js / 林 悠暉'
    element('desc', {'id': 'description'}).text = (
        '技術スタック: ' + '、'.join(f'{name}: {" / ".join(lines)}' for name, lines in STACK)
        + f'。公開・非公開の活動: コミット（過去1年）{counts[0]:,}、'
        + f'PR（累計）{counts[1]:,}、レビュー（過去1年）{counts[2]:,}。'
        + f'{updated_at:%Y年%m月%d日}時点。'
    )
    # GitHub rewrites theme-based picture sources, so theme adaptation stays in the SVG.
    light = ';'.join(f'--{name}:{color}' for name, color in PALETTES['light'].items())
    dark = ';'.join(f'--{name}:{color}' for name, color in PALETTES['dark'].items())
    element('style').text = f':root {{{light}}} @media (prefers-color-scheme: dark) {{:root {{{dark}}}}}'
    definitions = element('defs')
    clip = element('clipPath', {'id': 'card'}, definitions)
    element('rect', {'width': width, 'height': height, 'rx': 16}, clip)
    body = element('g', {'clip-path': 'url(#card)'})

    def rect(x, y, w, h, color):
        element('rect', {'x': x, 'y': y, 'width': w, 'height': h, 'fill': color}, body)

    used_glyphs = set()

    def text(x, y, value, size=16, color=None, underline=False):
        measured = text_width(value, size)
        if x + measured > width - 16:
            raise ValueError(f'Profile text exceeds the card width: {value}')
        scale = size / PIXEL_FONT['units_per_em']
        group = element('g', {'role': 'img', 'aria-label': value, 'font-size': f'{size:.2f}',
                              'fill': color or colors['ink'], 'transform': f'translate({x} {y}) scale({scale})'}, body)
        advance = 0
        for char in value:
            glyph = PIXEL_FONT['glyphs'][char]
            if glyph['path']:
                glyph_id = f'glyph-{ord(char)}'
                if char not in used_glyphs:
                    element('path', {'id': glyph_id, 'd': glyph['path']}, definitions)
                    used_glyphs.add(char)
                element('use', {'href': f'#{glyph_id}', 'x': advance}, group)
            advance += glyph['advance']
        if underline:
            element('rect', {'x': 0, 'y': 3, 'width': advance, 'height': 1}, group)

    rect(0, 0, width, height, colors['paper'])
    rect(0, 0, width if mobile else 269, 140 if mobile else main_height, '#20201e')
    name_x, name_y = (156, 44) if mobile else (24, 44)
    text(name_x, name_y, '林 悠暉', 20, '#ff7957')
    text(name_x, name_y + 23, 'Yuki Hayashi', 14, '#ff7957')
    text(name_x if mobile else 24, 109 if mobile else 318, 'アプリ・ツール一覧', 14, '#ff7957', underline=True)

    # Outlines keep the selected Silkscreen lettering independent of installed fonts.
    wordmark = ET.parse(ROOT / 'templates/profile/wordmark.svg').getroot().find(f'{{{SVG}}}path')
    logo_x, logo_y, logo_scale = (24, 31, .75) if mobile else (30, 141, 1)
    element('path', {'d': wordmark.attrib['d'], 'fill': '#ff7957',
                     'transform': f'translate({logo_x} {logo_y}) scale({logo_scale})'}, body)

    stack_x, y = (24, 177) if mobile else (297, 66)
    for name, lines in STACK:
        text(stack_x, y, name, 16 if mobile else 14, colors['muted'])
        for index, value in enumerate(lines):
            text(stack_x, y + 24 * (index + 1), value)
        y += 42 + 24 * len(lines)

    rect(0, main_height, width, 130 if mobile else 134, colors['panel'])
    metric_names = [('コミット', '過去1年'), ('PR', '累計'), ('レビュー', '過去1年')]
    for index, (count, (name, period)) in enumerate(zip(counts, metric_names)):
        value = f'{count:,}'
        x = (18 + index * 98) if mobile else (26 + index * 205)
        y = main_height + (47 if mobile else 53)
        available = 86 if mobile else 175
        size = min(32 if mobile else 36, available / text_width(value, 1))
        text(x, y, value, size)
        text(x, y + 29, name, 14)
        text(x, y + 48, period, 14, colors['muted'])
    if mobile:
        text(22, height - 36, '公開・非公開の集計', 14, colors['muted'])
        text(22, height - 16, f'{updated_at:%Y.%m.%d} 時点', 14, colors['muted'])
    else:
        text(26, height - 19, f'公開・非公開の集計 / {updated_at:%Y.%m.%d} 時点', 14, colors['muted'])
    ET.indent(root, space='  ')
    return ET.tostring(root, encoding='unicode') + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output-dir', type=Path, default=ROOT / 'profile')
    args = parser.parse_args()
    counts = read_counts(args.source)
    updated_at = datetime.now(timezone(timedelta(hours=9))).date()
    cards = {
        f'card{"-mobile" if mobile else ""}.svg': render_card(counts, updated_at, mobile)
        for mobile in [False, True]
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name, content in cards.items():
        (args.output_dir / name).write_text(content, encoding='utf-8')
    print('Generated desktop and mobile profile cards from validated activity totals.')


if __name__ == '__main__':
    main()
