//  EngineTests.swift
//  Run with ⌘U. Checks the Swift engines against golden.json, which was produced
//  by the reference implementation in tools/engine_prototype.py.

import XCTest

final class EngineTests: XCTestCase {
    private func golden() throws -> [String: [[String: Any]]] {
        let url = try XCTUnwrap(ResourceLocator.url("golden", subdirectory: nil), "golden.json missing from test bundle")
        let obj = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return try XCTUnwrap(obj as? [String: [[String: Any]]])
    }

    func testCatalogLoads() {
        XCTAssertFalse(LayoutCatalog.all.isEmpty)
        XCTAssertNotNil(LayoutCatalog.info("ml-swanalekha"))
        for l in LayoutCatalog.all {
            switch l.kind {
            case .transliteration: XCTAssertNoThrow(try EngineLoader.engine(file: l.file ?? ""), l.id)
            case .direct: XCTAssertNoThrow(try LayoutCatalog.directLayout(file: l.file ?? ""), l.id)
            case .english: break
            }
        }
    }

    func testSwanalekhaMatchesReference() throws {
        let e = try EngineLoader.engine(file: "ml-swanalekha")
        for c in try golden()["swanalekha"] ?? [] {
            let keys = c["keys"] as! String
            XCTAssertEqual(e.output(for: keys), c["output"] as? String, "output for \(keys)")
            let variants = e.candidates(for: keys).map(\.text)
            XCTAssertEqual(variants, c["variants"] as? [String], "variants for \(keys)")
        }
    }

    func testMozhiMatchesReference() throws {
        let e = try EngineLoader.engine(file: "ml-transliteration")
        for c in try golden()["ml-transliteration"] ?? [] {
            let keys = c["keys"] as! String
            XCTAssertEqual(e.output(for: keys), c["output"] as? String, "output for \(keys)")
        }
    }

    func testIncrementalCacheGivesSameResult() throws {
        let e = try EngineLoader.engine(file: "ml-transliteration")
        let word = "thiruvananthapuram"
        var last = ""
        for i in 1...word.count { last = e.output(for: String(word.prefix(i))) }
        _ = e.output(for: "xyz")                     // disturb the cache
        XCTAssertEqual(e.output(for: word), last)
    }

    func testJSReplacementConversion() {
        XCTAssertEqual(JQueryIMEEngine.icuTemplate(fromJS: "$1്ര"), "$1്ര")
        XCTAssertEqual(JQueryIMEEngine.icuTemplate(fromJS: "a$$b"), "a\\$b")
        XCTAssertEqual(JQueryIMEEngine.icuTemplate(fromJS: "\\"), "\\\\")
    }

    func testDirectLayoutShape() throws {
        let d = try LayoutCatalog.directLayout(file: "ml-lalitha")
        XCTAssertEqual(d.rows.map(\.count), [10, 9, 7])
        XCTAssertTrue(d.hasShift)
        XCTAssertEqual(d.rows[0].first?.label, "ഐ")
    }
}
