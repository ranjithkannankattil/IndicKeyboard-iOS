//  SpeedMeter.swift
//  Measures where typing time goes, shown in ⚙ → Speed check:
//  - Keyboard work: our own work for one key, from the finger lifting to the text being sent.
//  - App reply: from sending the text until the app reports it changed (iOS + the app).
//  - Suggestion bar: the time to fill the bar above the keys.
//  Only timings are kept (the last 200 of each); nothing you type is stored.

import QuartzCore

final class SpeedMeter {
    static let shared = SpeedMeter()

    private struct Series {
        var values: [Double] = []
        mutating func add(_ ms: Double) {
            values.append(ms)
            if values.count > 200 { values.removeFirst(values.count - 200) }
        }
        var summary: String {
            guard !values.isEmpty else { return "no data yet" }
            let sorted = values.sorted()
            let avg = values.reduce(0, +) / Double(values.count)
            let p90 = sorted[min(sorted.count - 1, Int(Double(sorted.count) * 0.9))]
            return String(format: "avg %.1f ms · 90%% under %.0f ms · max %.0f ms (%d)", avg, p90, sorted.last!, values.count)
        }
    }

    private var keyWork = Series()
    private var appReply = Series()
    private var suggestions = Series()
    private var sentAt: CFTimeInterval?

    static func now() -> CFTimeInterval { CACurrentMediaTime() }

    func keyHandled(since start: CFTimeInterval) {
        let t = Self.now()
        keyWork.add((t - start) * 1000)
        sentAt = t
    }

    func appReplied() {
        guard let s = sentAt else { return }
        sentAt = nil
        let ms = (Self.now() - s) * 1000
        if ms < 2000 { appReply.add(ms) }   // ignore pauses where nothing was waiting
    }

    func suggestionsFilled(since start: CFTimeInterval) {
        suggestions.add((Self.now() - start) * 1000)
    }

    var lines: [(String, String)] {
        [("Keyboard work per key", keyWork.summary),
         ("App reply after each key", appReply.summary),
         ("Suggestion bar", suggestions.summary)]
    }
}
