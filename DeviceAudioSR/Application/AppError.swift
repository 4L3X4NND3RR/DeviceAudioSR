//
//  AppError.swift
//  DeviceAudioSR — Application
//
//  Typed failures with stable machine-readable ids and process exit codes.
//

enum ExitCode: Int32 {
    case success = 0
    case usageError = 1
    case deviceNotFound = 2
    case rateNotSupported = 3
    case coreAudioError = 4
}

/// Stable machine-readable error identifiers (in `error` field of the JSON).
enum ErrorID: String {
    case usageError = "usage_error"
    case deviceNotFound = "device_not_found"
    case ambiguousDevice = "ambiguous_device"
    case rateNotSupported = "rate_not_supported"
    case coreAudioError = "core_audio_error"
}

/// Extra context rendered into the error JSON (device, devices, rates,
/// osStatus, suggestions, received).
struct AppErrorContext {
    var device: AudioDevice?
    var devices: [AudioDevice]?
    var rates: [Double]?
    var suggestions: [String]?
    var osStatus: String?
    var received: String?
}

struct AppError: Error {
    let id: ErrorID
    let message: String
    let exitCode: ExitCode
    var context = AppErrorContext()
}
