#!/usr/bin/env python3
"""Builds Shared/Resources/emoji.json (iOS-style categories) from unicode-emoji-json.

Usage:
    npm pack unicode-emoji-json@0.8.0 && tar xzf unicode-emoji-json-0.8.0.tgz
    python3 tools/make_emoji.py package/data-by-group.json Shared/Resources/emoji.json
"""
import json, os, sys

CATEGORIES = [  # (name shown in the keyboard, SF Symbol, source groups)
    ("Smileys & People", "face.smiling", ["Smileys & Emotion", "People & Body"]),
    ("Animals & Nature", "pawprint", ["Animals & Nature"]),
    ("Food & Drink", "fork.knife", ["Food & Drink"]),
    ("Activity", "figure.run", ["Activities"]),
    ("Travel & Places", "car", ["Travel & Places"]),
    ("Objects", "lightbulb", ["Objects"]),
    ("Symbols", "number", ["Symbols"]),
    ("Flags", "flag", ["Flags"]),
]


def main(src, dest):
    groups = {g["name"]: g["emojis"] for g in json.load(open(src, encoding="utf-8"))}
    cats = [{"name": n, "symbol": s, "emoji": [e["emoji"] for g in gs for e in groups[g]]}
            for n, s, gs in CATEGORIES]
    with open(dest, "w", encoding="utf-8") as f:
        json.dump({"source": "unicode-emoji-json 0.8.0 (Unicode emoji data, MIT)", "categories": cats},
                  f, ensure_ascii=False, separators=(",", ":"))
    print("emoji.json:", sum(len(c["emoji"]) for c in cats), "emoji,", os.path.getsize(dest), "bytes")


if __name__ == "__main__":
    main(*sys.argv[1:3])
