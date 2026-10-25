//
//  DeviceMatcher.swift
//  DeviceAudioSR — Domain
//
//  Pure name/UID matching and fuzzy suggestions. No I/O.
//

enum DeviceMatch {
    case found(AudioDevice)
    case ambiguous([AudioDevice])
    case notFound
}

enum DeviceMatcher {
    /// Resolve a device by name or UID: case-insensitive exact match first,
    /// then case-insensitive name substring match.
    static func resolve(query: String, devices: [AudioDevice]) -> DeviceMatch {
        let lowered = query.lowercased()

        let exactUID = devices.filter { !$0.uid.isEmpty && $0.uid.lowercased() == lowered }
        if exactUID.count == 1 { return .found(exactUID[0]) }
        if exactUID.count > 1 { return .ambiguous(exactUID) }

        let exactName = devices.filter { $0.name.lowercased() == lowered }
        if exactName.count == 1 { return .found(exactName[0]) }
        if exactName.count > 1 { return .ambiguous(exactName) }

        if let id = UInt32(query), let device = devices.first(where: { $0.id == id }) {
            return .found(device)
        }

        let partial = devices.filter { $0.name.lowercased().contains(lowered) }
        if partial.count == 1 { return .found(partial[0]) }
        if partial.count > 1 { return .ambiguous(partial) }
        return .notFound
    }

    /// Close matches for a mistyped device name or UID.
    static func suggestions(for query: String, devices: [AudioDevice]) -> [String] {
        let lowered = query.lowercased()
        let threshold = max(1, lowered.count / 3)
        return devices.compactMap { device in
            if editDistance(lowered, device.name.lowercased()) <= threshold { return device.name }
            if editDistance(lowered, device.uid.lowercased()) <= threshold { return device.name }
            return nil
        }
    }

    /// Simple Levenshtein edit distance.
    static func editDistance(_ a: some StringProtocol, _ b: some StringProtocol) -> Int {
        let s = Array(a), t = Array(b)
        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)
        for i in 1...s.count {
            current[0] = i
            for j in 1...t.count {
                current[j] = min(previous[j] + 1,                 // deletion
                                 current[j - 1] + 1,              // insertion
                                 previous[j - 1] + (s[i - 1] == t[j - 1] ? 0 : 1)) // substitution
            }
            swap(&previous, &current)
        }
        return previous[t.count]
    }
}
