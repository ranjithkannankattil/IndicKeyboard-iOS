//  LayoutCatalog.swift
//  The list of layouts (catalog.json) and the direct-key layout data (Layouts/*.json).

import Foundation

public enum LayoutKind: String {
    case english, transliteration, direct
}

public struct LayoutInfo: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let short: String
    public let kind: LayoutKind
    public let file: String?
}

/// A key on a direct (non-transliterating) layout, converted from the Android XML.
public struct DirectKey: Equatable {
    public let label: String
    public let output: String
    public let hint: String?
    public let more: [String]
}

public struct DirectLayout {
    public struct RowFlags { public let shift: Bool; public let delete: Bool }
    public let id: String
    public let hasShift: Bool
    public let rows: [[DirectKey]]
    public let shiftedRows: [[DirectKey]]
    public let rowFlags: [RowFlags]
}

public enum LayoutCatalog {
    public static let all: [LayoutInfo] = load().layouts
    public static let defaultEnabled: [String] = load().defaults

    public static func info(_ id: String) -> LayoutInfo? { all.first { $0.id == id } }

    private static var loaded: (layouts: [LayoutInfo], defaults: [String])?

    private static func load() -> (layouts: [LayoutInfo], defaults: [String]) {
        if let l = loaded { return l }
        var layouts: [LayoutInfo] = []
        var defaults: [String] = ["en"]
        if let j = try? ResourceLocator.json("catalog", subdirectory: nil) {
            for e in (j["layouts"] as? [[String: Any]]) ?? [] {
                guard let id = e["id"] as? String,
                      let kind = LayoutKind(rawValue: e["kind"] as? String ?? "") else { continue }
                layouts.append(LayoutInfo(id: id,
                                          name: e["name"] as? String ?? id,
                                          subtitle: e["subtitle"] as? String ?? "",
                                          short: e["short"] as? String ?? String(id.prefix(2)).uppercased(),
                                          kind: kind,
                                          file: e["file"] as? String))
            }
            defaults = (j["defaultEnabled"] as? [String]) ?? defaults
        }
        if layouts.isEmpty {
            layouts = [LayoutInfo(id: "en", name: "English", subtitle: "QWERTY", short: "EN", kind: .english, file: nil)]
        }
        loaded = (layouts, defaults)
        return (layouts, defaults)
    }

    private static var directCache: [String: DirectLayout] = [:]

    public static func directLayout(file: String) throws -> DirectLayout {
        if let d = directCache[file] { return d }
        let j = try ResourceLocator.json(file, subdirectory: "Layouts")
        func keys(_ value: Any?) -> [[DirectKey]] {
            ((value as? [[[String: Any]]]) ?? []).map { row in
                row.compactMap { k -> DirectKey? in
                    guard let label = k["label"] as? String else { return nil }
                    return DirectKey(label: label,
                                     output: k["output"] as? String ?? label,
                                     hint: k["hint"] as? String,
                                     more: k["more"] as? [String] ?? [])
                }
            }
        }
        let rows = keys(j["rows"])
        var shifted = keys(j["shiftedRows"])
        if shifted.count != rows.count { shifted = rows }
        let flags = ((j["rowFlags"] as? [[String: Bool]]) ?? []).map {
            DirectLayout.RowFlags(shift: $0["shift"] ?? false, delete: $0["delete"] ?? false)
        }
        let layout = DirectLayout(id: j["id"] as? String ?? file,
                                  hasShift: j["hasShift"] as? Bool ?? false,
                                  rows: rows, shiftedRows: shifted,
                                  rowFlags: flags.count == rows.count ? flags
                                    : rows.indices.map { DirectLayout.RowFlags(shift: false, delete: $0 == rows.count - 1) })
        directCache[file] = layout
        return layout
    }
}
