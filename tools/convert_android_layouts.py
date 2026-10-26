#!/usr/bin/env python3
"""Converts Indic Keyboard (Android) direct key layouts to the JSON format used by the iOS keyboard.
Usage: convert_android_layouts.py <Indic-Keyboard/java/res/xml> <out_dir>"""
import json, re, sys, os
import xml.etree.ElementTree as ET

NS = '{http://schemas.android.com/apk/res-auto}'
SHIFT_ELEMENTS = ('alphabetManualShifted', 'alphabetShiftLocked', 'alphabetShiftLockShifted')

LAYOUTS = {  # id: (rows file, name, description)
    'ml-lalitha':        ('rows_malayalam',               'മലയാളം', 'Malayalam (Lalitha)'),
    'ml-compact':        ('rows_malayalam_compact',       'മലയാളം Compact', 'Malayalam compact'),
    'ml-inscript':       ('rows_malayalam_inscript',      'ഇൻസ്ക്രിപ്റ്റ്', 'Malayalam InScript'),
    'ml-poorna-inscript':('rows_malayalam_poorna_inscript','പൂർണ്ണ ഇൻസ്ക്രിപ്റ്റ്', 'Malayalam Poorna InScript'),
    'ml-mobile-inscript':('rows_malayalam_mobile_inscript','മൊബൈൽ ഇൻസ്ക്രിപ്റ്റ്', 'Malayalam Mobile InScript'),
}

def unescape(s):
    return re.sub(r'\\(.)', r'\1', s)

def split_more(s):
    if not s: return []
    parts = re.split(r'(?<!\\),', s)
    out = []
    for p in parts:
        p = p.strip()
        if not p or p.startswith('!'):
            continue  # layout directives like !fixedColumnOrder!4 or unresolved !text/ refs
        out.append(unescape(p))
    return out

def resolve_spec(spec):
    m = re.match(r'!text/keyspec_symbols_(\d)$', spec or '')
    if m: return m.group(1)
    if spec and spec.startswith('!'): return None
    return unescape(spec) if spec else None

def key_from(el):
    g = lambda a: el.get(NS + a)
    spec = resolve_spec(g('keySpec'))
    if spec is None: return None
    label, output = spec, spec
    if '|' in spec and len(spec) > 1:
        label, output = spec.split('|', 1)
    more = split_more(g('moreKeys')) + split_more(g('additionalMoreKeys'))
    k = {'label': label, 'output': output}
    if more: k['more'] = more
    hint = g('keyHintLabel')
    if hint: k['hint'] = unescape(hint)
    return k

def parse_rowkeys(path):
    normal, shifted = [], []
    root = ET.parse(path).getroot()
    def walk(node, mode):
        for ch in node:
            tag = ch.tag
            if tag == 'Key':
                k = key_from(ch)
                if k:
                    if mode in ('both', 'normal'): normal.append(k)
                    if mode in ('both', 'shifted'): shifted.append(k)
            elif tag == 'switch':
                cases = list(ch)
                handled_shift = handled_normal = False
                for c in cases:
                    el = c.get(NS + 'keyboardLayoutSetElement') or ''
                    if c.tag == 'case' and el:
                        is_shift = any(s in el.split('|') for s in SHIFT_ELEMENTS)
                        if is_shift and not handled_shift:
                            walk(c, 'shifted' if mode != 'normal' else 'none'); handled_shift = True
                        elif not is_shift and not handled_normal:
                            walk(c, 'normal' if mode != 'shifted' else 'none'); handled_normal = True
                    elif c.tag == 'default':
                        if not handled_shift and not handled_normal: walk(c, mode)
                        elif not handled_shift: walk(c, 'shifted' if mode != 'normal' else 'none')
                        elif not handled_normal: walk(c, 'normal' if mode != 'shifted' else 'none')
            else:
                walk(ch, mode)
    walk(root, 'both')
    return normal, shifted

def parse_rows(xmldir, rowsfile):
    root = ET.parse(os.path.join(xmldir, rowsfile + '.xml')).getroot()
    rows = []
    for row in root.iter('Row'):
        # skip the optional number row (inside <case numberRowEnabled>)
        incs = [i.get(NS + 'keyboardLayout') for i in row.iter('include')]
        incs = [i.split('/')[-1] for i in incs if i]
        if any(i == 'rowkeys_symbols1' for i in incs):
            continue
        styles = [k.get(NS + 'keyStyle') for k in row.iter('Key')]
        rows.append({'include': incs[0] if incs else None, 'shift': 'shiftKeyStyle' in styles,
                     'delete': 'deleteKeyStyle' in styles})
    return rows

def main(xmldir, outdir):
    for lid, (rowsfile, name, desc) in LAYOUTS.items():
        rows = parse_rows(xmldir, rowsfile)
        normal_rows, shifted_rows, flags = [], [], []
        for r in rows:
            n, s = parse_rowkeys(os.path.join(xmldir, r['include'] + '.xml'))
            normal_rows.append(n); shifted_rows.append(s if s else n)
            flags.append({'shift': r['shift'], 'delete': r['delete']})
        has_shift = any(f['shift'] for f in flags) or any(a != b for a, b in zip(normal_rows, shifted_rows))
        out = {'engine': 'direct', 'id': lid, 'name': name, 'description': desc,
               'author': 'Jishnu Mohan, SMC, ICFOSS (Indic Keyboard)', 'license': 'Apache-2.0',
               'hasShift': has_shift, 'rowFlags': flags, 'rows': normal_rows, 'shiftedRows': shifted_rows}
        with open(os.path.join(outdir, lid + '.json'), 'w') as f:
            json.dump(out, f, ensure_ascii=False, indent=1)
        print(lid, [len(r) for r in normal_rows], [len(r) for r in shifted_rows], flags)

if __name__ == '__main__':
    main(*sys.argv[1:3])
