//
//  SampleRate.swift
//  DeviceAudioSR — Domain
//

import Foundation

enum SampleRate {
    static let minPlausible = 8_000.0
    static let maxPlausible = 768_000.0

    static func isPlausible(_ rate: Double) -> Bool {
        rate >= minPlausible && rate <= maxPlausible
    }

    /// Parse "48000", "48,000", "48 000", "48k", "44.1k", "48,000Hz 2ch 32-bit"…
    /// Only the first whitespace-separated token is considered.
    static func parse(from raw: String) -> Double? {
        var token = raw.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? raw
        token = token.lowercased()
            .replacingOccurrences(of: "hz", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        let multiplier: Double = token.hasSuffix("k") ? 1000 : 1
        var body = token.hasSuffix("k") ? String(token.dropLast()) : token
        if body.hasSuffix(".0") { body = String(body.dropLast(2)) }
        if body.isEmpty { return nil }

        // Comma may be a thousands separator ("48,000") or a decimal comma ("44,1").
        if body.contains(",") {
            for candidate in [body.replacingOccurrences(of: ",", with: ""),
                              body.replacingOccurrences(of: ",", with: ".")] {
                if let parsed = Double(candidate) {
                    let scaled = parsed * multiplier
                    // "48,0" with a k-suffix is nonsense; only accept decimal comma
                    // when the result stays in a plausible audio range.
                    if isPlausible(scaled) { return scaled }
                }
            }
            return nil
        }
        guard let parsed = Double(body) else { return nil }
        return parsed * multiplier
    }

    /// 48000 -> "48,000"; 44100 -> "44,100"; 44.1 -> "44.1"
    static func display(_ rate: Double) -> String {
        let rounded = rate.rounded()
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.maximumFractionDigits = rounded == rate ? 0 : 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: rounded == rate ? rounded : rate)) ?? String(rate)
    }
}
