#!/bin/bash
# Regenerates all layout data from the upstream sources.
# Usage: tools/build_data.sh <dir containing swanalekha/, Indic-Keyboard/, jquery.ime/>
set -euo pipefail
SRC="$1"
cd "$(dirname "$0")/.."
python3 - "$SRC/swanalekha/js/src/rules.json" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
out = {"engine": "swanalekha", "id": "ml-swanalekha", "name": "സ്വനലേഖ",
       "description": "Swanalekha Malayalam phonetic transliteration", "author": "Santhosh Thottingal",
       "license": "MIT", "maxPatternLength": 5, "rules": r}
json.dump(out, open('Shared/Resources/Schemes/ml-swanalekha.json', 'w'), ensure_ascii=False, indent=0)
print('ml-swanalekha', len(r), 'rules')
PY
node tools/convert_jqueryime.js "$SRC/jquery.ime/rules/ml/ml-transliteration.js" Shared/Resources/Schemes/ml-transliteration.json
python3 tools/convert_android_layouts.py "$SRC/Indic-Keyboard/java/res/xml" Shared/Resources/Layouts
python3 - <<'PY'
import sys, json; sys.path.insert(0, 'tools')
from engine_prototype import Swanalekha, JQueryIME
s = Swanalekha(); m = JQueryIME('ml-transliteration')
words = ['malayaaLam','malayaaLam ','kEraLam','swanalekha','nanni','amma','kaRuppu','enthaa','sukhamaaNO','ente','naaTT','avan~','pakshi','aaNu','kshamikkuka','njaan','ngaL','mm','ka2','ka3','thaangal','dhanyavaadam','namaskaaram ','kRshNan~','sreeraam','vidyaalayam','prakR^thi','L~','r~','yaathra','chhaaya','zh','vazhi','thiruvananthapuram','kozhikkOd','aRivu','~','a_i','123','hello']
gold = {'swanalekha': [{'keys': w, 'output': s.output(w), 'variants': [v[0] for v in s.variants(w)]} for w in words],
        'ml-transliteration': [{'keys': w, 'output': m.output(w)} for w in words]}
json.dump(gold, open('Tests/golden.json', 'w'), ensure_ascii=False, indent=1)
print('golden.json', len(words), 'words; njaan ->', s.output('njaan'), [v[0] for v in s.variants('njaan')])
PY
mkdir -p LICENSES
cp "$SRC/Indic-Keyboard/LICENSE" LICENSES/Indic-Keyboard-Apache-2.0.txt
cp "$SRC/swanalekha/LICENSE" LICENSES/Swanalekha-MIT.txt
cp "$SRC/jquery.ime/GPL-LICENSE" LICENSES/jquery.ime-rules-GPL.txt
cp "$SRC/jquery.ime/MIT-LICENSE" LICENSES/jquery.ime-MIT.txt
echo done
