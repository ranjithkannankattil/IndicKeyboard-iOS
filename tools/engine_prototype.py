"""Reference implementation of the two engines. The Swift code mirrors this exactly."""
import json, re, sys, os
D = os.path.join(os.path.dirname(__file__), '..', 'Shared', 'Resources', 'Schemes')

class Swanalekha:
    def __init__(self):
        j = json.load(open(os.path.join(D, 'ml-swanalekha.json')))
        self.rules, self.maxlen = j['rules'], j['maxPatternLength']
    def segments(self, keys):
        segs = []  # list of [pattern, output]
        for c in keys:
            if segs:
                p = segs[-1][0] + c
                if len(p) <= self.maxlen and p in self.rules:
                    segs[-1] = [p, self.rules[p]]; continue
            segs.append([c, self.rules.get(c, c)])
        return segs
    def output(self, keys):
        return ''.join(o for _, o in self.segments(keys))
    def variants(self, keys):
        """Alternatives for the last segment: pattern, pattern2, pattern3... -> new key strings."""
        segs = self.segments(keys)
        if not segs: return []
        p = segs[-1][0]
        base = p.rstrip('0123456789') if len(p) > 1 and p[-1].isdigit() and p.rstrip('0123456789') in self.rules else p
        prefix = keys[:len(keys) - len(p)]
        cands, seen = [], set()
        for i in [None, 2, 3, 4, 5, 6, 7, 8, 9]:
            pat = base if i is None else base + str(i)
            if pat in self.rules and len(pat) <= self.maxlen:
                out = self.output(prefix + pat)
                if out not in seen:
                    seen.add(out); cands.append((out, prefix + pat))
            elif i is not None and i > 2:
                break
        return cands

def js_repl_to_python(r):
    # JS replacement: $1..$9, $&, $$ ; everything else literal
    out, i = '', 0
    while i < len(r):
        c = r[i]
        if c == '$' and i + 1 < len(r):
            n = r[i+1]
            if n.isdigit(): out += '\\g<' + n + '>'; i += 2; continue
            if n == '&': out += '\\g<0>'; i += 2; continue
            if n == '$': out += '$'; i += 2; continue
        out += c.replace('\\', '\\\\'); i += 1
    return out

class JQueryIME:
    def __init__(self, name):
        j = json.load(open(os.path.join(D, name + '.json')))
        self.ctxlen, self.maxkey = j['contextLength'], j['maxKeyLength']
        self.pats = [(re.compile(p['input'] + '$'), re.compile(p['context'] + '$') if 'context' in p else None,
                      js_repl_to_python(p['replacement'])) for p in j['patterns']]
    def transliterate(self, inp, ctx):
        for rx, cx, rep in self.pats:
            if rx.search(inp):
                if cx is None or cx.search(ctx):
                    return rx.sub(rep, inp, count=1), False
        return inp, True
    def output(self, keys):
        text, ctx = '', ''
        for c in keys:
            start = max(0, len(text) - self.maxkey)
            inp = text[start:] + c
            out, noop = self.transliterate(inp, ctx)
            ctx = (ctx + c)[-self.ctxlen:] if self.ctxlen else ''
            text = text[:start] + out  # noop: out == inp, i.e. key appended as-is
        return text

if __name__ == '__main__':
    s = Swanalekha(); m = JQueryIME('ml-transliteration')
    words = sys.argv[1:] or ['malayaaLam', 'kEraLam', 'njaan', 'ka2']
    for w in words:
        print(f'{w:14} sw: {s.output(w):14} mozhi: {m.output(w):14} variants: {[v[0] for v in s.variants(w)]}')
