#!/usr/bin/env python3
"""Turn the existing private-activity totals into the 884js profile card."""

import argparse
from datetime import datetime, timedelta, timezone
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
SVG = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG)
LABELS = ['Total Commits (last year):', 'Total PRs:', 'Total PRs Reviewed:']
STACK = [
    ('Web', 'TypeScript / React / Next.js'),
    ('モバイル', 'React Native / Expo'),
    ('バックエンド', 'Go / Hono / Ruby on Rails'),
    ('インフラ', 'Cloudflare / AWS'),
]
PALETTES = {
    'light': {'paper': '#faf8ff', 'ink': '#302447', 'muted': '#716182', 'panel': '#eae2fa'},
    'dark': {'paper': '#261f34', 'ink': '#f3edff', 'muted': '#c4b5d9', 'panel': '#3c3051'},
}


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
    width, height = (320, 588) if mobile else (640, 530)
    main_height = 412 if mobile else 350
    root = ET.Element(f'{{{SVG}}}svg', {
        'width': str(width), 'height': str(height), 'viewBox': f'0 0 {width} {height}',
        'role': 'img', 'aria-labelledby': 'title description',
        'font-family': 'Arial, "Hiragino Kaku Gothic ProN", "Yu Gothic", Meiryo, sans-serif',
        'fill': colors['ink'],
    })

    def element(tag, attributes=None, parent=root):
        return ET.SubElement(parent, f'{{{SVG}}}{tag}', {key: str(value) for key, value in (attributes or {}).items()})

    element('title', {'id': 'title'}).text = '884js / 林 悠暉'
    element('desc', {'id': 'description'}).text = (
        '技術スタック: ' + '、'.join(f'{name}: {value}' for name, value in STACK)
        + f'。公開・非公開の活動: コミット（過去1年）{counts[0]:,}、'
        + f'PR（累計）{counts[1]:,}、レビュー（過去1年）{counts[2]:,}。'
        + f'{updated_at:%Y年%m月%d日}時点。'
    )
    # GitHub rewrites theme-based picture sources, so theme adaptation stays in the SVG.
    light = ';'.join(f'--{name}:{color}' for name, color in PALETTES['light'].items())
    dark = ';'.join(f'--{name}:{color}' for name, color in PALETTES['dark'].items())
    element('style').text = f':root {{{light}}} @media (prefers-color-scheme: dark) {{:root {{{dark}}}}}'
    clip = element('clipPath', {'id': 'card'}, element('defs'))
    element('rect', {'width': width, 'height': height, 'rx': 16}, clip)
    body = element('g', {'clip-path': 'url(#card)'})

    def rect(x, y, w, h, color):
        element('rect', {'x': x, 'y': y, 'width': w, 'height': h, 'fill': color}, body)

    def text(x, y, value, size=14, color=None, **attributes):
        element('text', {'x': x, 'y': y, 'font-size': size, 'fill': color or colors['ink'], **attributes}, body).text = value

    rect(0, 0, width, height, colors['paper'])
    rect(0, 0, width if mobile else 269, 140 if mobile else main_height, '#d4c3ff')
    name_x, name_y = (156, 44) if mobile else (24, 44)
    text(name_x, name_y, '林 悠暉', 16 if mobile else 18, '#2e2148', **{'letter-spacing': '2px'})
    text(name_x, name_y + 23, 'Yuki Hayashi', 13 if mobile else 12, '#2e2148')
    text(name_x if mobile else 24, 109 if mobile else 318, 'アプリ・ツール一覧', 12, '#2e2148', **{'text-decoration': 'underline'})

    # Outlines keep the selected Silkscreen lettering independent of installed fonts.
    wordmark = ET.parse(ROOT / 'templates/profile/wordmark.svg').getroot().find(f'{{{SVG}}}path')
    logo_x, logo_y, logo_scale = (24, 31, .75) if mobile else (30, 141, 1)
    element('path', {'d': wordmark.attrib['d'], 'fill': '#2e2148',
                     'transform': f'translate({logo_x} {logo_y}) scale({logo_scale})'}, body)

    stack_x, stack_y, stack_gap = (24, 177, 60) if mobile else (297, 72, 70)
    for index, (name, value) in enumerate(STACK):
        y = stack_y + stack_gap * index
        text(stack_x, y, name, 14 if mobile else 12, colors['muted'])
        text(stack_x, y + 24, value, 15 if mobile else 14)

    rect(0, main_height, width, 130 if mobile else 134, colors['panel'])
    metric_names = [('コミット', '過去1年'), ('PR', '累計'), ('レビュー', '過去1年')]
    for index, (count, (name, period)) in enumerate(zip(counts, metric_names)):
        value = f'{count:,}'
        x = (18 + index * 98) if mobile else (26 + index * 205)
        y = main_height + (47 if mobile else 53)
        available = 86 if mobile else 175
        size = min(30 if mobile else 33, available / (len(value) * .62))
        text(x, y, value, f'{size:.2f}')
        text(x, y + 29, name, 13 if mobile else 12)
        text(x, y + 48, period, 12 if mobile else 11, colors['muted'])
    text(22 if mobile else 26, height - 19,
         f'公開・非公開の集計 / {updated_at:%Y.%m.%d} 時点', 12 if mobile else 11, colors['muted'])
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
