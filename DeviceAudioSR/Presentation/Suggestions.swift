//
//  Suggestions.swift
//  DeviceAudioSR — Presentation
//
//  "Did you mean" suggestions for mistyped flags. Device suggestions
//  live in the domain (DeviceMatcher).
//

let knownFlags = ["--device", "--output", "--list", "--input", "--verbose", "--version", "--help"]

/// Close matches for a mistyped flag, e.g. "-devce" → "--device".
func suggestFlags(for arg: String) -> [String] {
    let target = arg.hasPrefix("--") ? String(arg.dropFirst(2))
               : arg.hasPrefix("-") ? String(arg.dropFirst(1))
               : arg
    guard !target.isEmpty else { return [] }
    let threshold = max(1, target.count / 3)
    return knownFlags.filter { DeviceMatcher.editDistance(target, String($0.dropFirst(2))) <= threshold }
}
