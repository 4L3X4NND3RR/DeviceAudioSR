//
//  AudioDevice.swift
//  DeviceAudioSR — Domain
//
//  Core entities. No CoreAudio imports: the domain knows nothing about
//  how device data is obtained.
//

import Foundation

enum AudioScope: Hashable {
    case output
    case input

    var displayName: String { self == .input ? "input" : "output" }
}

/// Current audio format reported for one scope of a device.
struct StreamFormat {
    let sampleRate: Double?
    let channels: Int?
    let bits: Int?

    /// "48,000Hz 2ch 32-bit"
    var displayString: String {
        let rate = sampleRate.map(SampleRate.display) ?? "?"
        let ch = channels.map(String.init) ?? "?"
        let b = bits.map(String.init) ?? "?"
        return "\(rate)Hz \(ch)ch \(b)-bit"
    }
}

struct AudioDevice {
    let id: UInt32
    let name: String
    let uid: String
    let isDefaultOutput: Bool
    let isDefaultInput: Bool
    let nominalSampleRate: Double?
    let supportedRateRanges: [ClosedRange<Double>]
    /// Present per scope only when the device has a stream there.
    let formats: [AudioScope: StreamFormat]

    func format(in scope: AudioScope) -> StreamFormat? { formats[scope] }

    /// Output scope unless explicitly preferred otherwise or the device is
    /// an input-only default.
    func targetScope(preferInput: Bool) -> AudioScope {
        if preferInput || (!isDefaultOutput && isDefaultInput) { return .input }
        return .output
    }

    /// Whether the rate fits one of the device's reported ranges.
    /// No reported ranges: trust CoreAudio to reject invalid values.
    func supports(rate: Double) -> Bool {
        guard !supportedRateRanges.isEmpty else { return true }
        return supportedRateRanges.contains {
            rate >= $0.lowerBound - 0.01 && rate <= $0.upperBound + 0.01
        }
    }

    /// Sorted, deduplicated supported rates. Continuous ranges contribute
    /// their endpoints.
    var distinctSupportedRates: [Double] {
        let endpoints = supportedRateRanges.flatMap { [$0.lowerBound.rounded(), $0.upperBound.rounded()] }
        return Array(Set(endpoints)).sorted()
    }
}
