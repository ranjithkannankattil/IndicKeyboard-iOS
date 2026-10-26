// Converts jquery.ime rule files (rules/<lang>/<id>.js) to the JSON format used by the iOS keyboard.
// Usage: node convert_jqueryime.js <rule.js> <out.json>
const fs = require('fs');
const vm = require('vm');
const [src, out] = process.argv.slice(2);
let im = null;
const jQuery = { ime: { register: (x) => { im = x; } } };
vm.runInNewContext(fs.readFileSync(src, 'utf8'), { jQuery, $: jQuery });
if (!im) throw new Error('no input method registered in ' + src);
const conv = (pats) => (pats || []).map((p) => {
  if (typeof p.slice(-1)[0] === 'function') throw new Error('function replacement unsupported');
  return p.length === 3 ? { input: p[0], context: p[1], replacement: p[2] } : { input: p[0], replacement: p[1] };
});
if (typeof im.patterns === 'function') throw new Error('function-based rules unsupported: ' + im.id);
const json = {
  engine: 'jqueryime', id: im.id, name: im.name, description: im.description || '',
  author: im.author || '', license: im.license || '', version: im.version || '',
  contextLength: im.contextLength || 0, maxKeyLength: im.maxKeyLength || 1,
  patterns: conv(im.patterns), patternsAltGr: conv(im.patterns_x),
};
fs.writeFileSync(out, JSON.stringify(json, null, 1));
console.log(im.id, json.patterns.length, 'patterns', json.patternsAltGr.length, 'altgr', 'license', json.license);
