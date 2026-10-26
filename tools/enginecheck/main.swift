// Command-line check of the shared engines against Tests/golden.json.
// Build: swiftc -O Shared/Engine/*.swift tools/enginecheck/main.swift -o build/enginecheck
import Foundation

let url = ResourceLocator.url("golden", subdirectory: nil)!
let gold = try! JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: [[String: Any]]]
var fails = 0, checks = 0

let sw = try! EngineLoader.engine(file: "ml-swanalekha")
for c in gold["swanalekha"]! {
    let k = c["keys"] as! String
    checks += 2
    if sw.output(for: k) != c["output"] as! String { fails += 1; print("FAIL sw output", k, sw.output(for: k)) }
    let v = sw.candidates(for: k).map(\.text)
    if v != c["variants"] as! [String] { fails += 1; print("FAIL sw variants", k, v) }
}
let mz = try! EngineLoader.engine(file: "ml-transliteration")
for c in gold["ml-transliteration"]! {
    let k = c["keys"] as! String
    checks += 1
    if mz.output(for: k) != c["output"] as! String { fails += 1; print("FAIL mozhi", k, mz.output(for: k), "expected", c["output"]!) }
}
for l in LayoutCatalog.all where l.kind == .direct {
    checks += 1
    do { _ = try LayoutCatalog.directLayout(file: l.file!) } catch { fails += 1; print("FAIL layout", l.id, error) }
}
print("layouts:", LayoutCatalog.all.map(\.id).joined(separator: ", "))
print("sample:", sw.output(for: "malayaaLam "), mz.output(for: "malayaaLam"), sw.candidates(for: "njaan").map(\.text).prefix(3))
print("\(checks) checks, \(fails) failures")
exit(fails == 0 ? 0 : 1)
