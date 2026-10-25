//
//  SetDefaultOutput.swift
//  DeviceAudioSR — Application
//

struct SetDefaultOutput {
    let repository: AudioDeviceRepository
    let logger: Logger

    struct Input {
        let deviceQuery: String
    }

    struct Result {
        let before: AudioDevice
        let after: AudioDevice
        let changed: Bool
    }

    func execute(_ input: Input) throws -> Result {
        let devices = repository.allDevices()
        let target: AudioDevice
        switch DeviceMatcher.resolve(query: input.deviceQuery, devices: devices) {
        case .found(let device):
            target = device
        case .ambiguous(let matches):
            var context = AppErrorContext()
            context.devices = matches
            throw AppError(id: .ambiguousDevice,
                           message: "'\(input.deviceQuery)' matches several devices, be more specific",
                           exitCode: .deviceNotFound, context: context)
        case .notFound:
            let suggestions = DeviceMatcher.suggestions(for: input.deviceQuery, devices: devices)
            var context = AppErrorContext()
            context.devices = devices
            context.suggestions = suggestions
            let hint = suggestions.isEmpty ? "" : " — did you mean \(suggestions.map { "'\($0)'" }.joined(separator: " or "))?"
            throw AppError(id: .deviceNotFound,
                           message: "device not found: \(input.deviceQuery)\(hint)",
                           exitCode: .deviceNotFound, context: context)
        }

        guard target.format(in: .output) != nil else {
            var context = AppErrorContext()
            context.device = target
            throw AppError(id: .coreAudioError,
                           message: "'\(target.name)' has no output stream",
                           exitCode: .coreAudioError, context: context)
        }

        guard let before = repository.defaultDevice(for: .output) else {
            throw AppError(id: .deviceNotFound,
                           message: "no default output device configured",
                           exitCode: .deviceNotFound)
        }
        guard before.id != target.id else {
            return Result(before: before, after: before, changed: false)
        }

        logger.log("setting default output: '\(target.name)' uid='\(target.uid)' id=\(target.id)")
        switch repository.setDefaultOutput(target) {
        case .applied:
            return Result(before: before,
                          after: repository.device(withID: target.id) ?? target,
                          changed: true)
        case .setStatusFailed(let status):
            var context = AppErrorContext()
            context.device = target
            context.osStatus = "0x" + String(UInt32(bitPattern: status), radix: 16)
            throw AppError(id: .coreAudioError,
                           message: "could not set '\(target.name)' as the default output device",
                           exitCode: .coreAudioError, context: context)
        case .notSwitched(let current):
            var context = AppErrorContext()
            context.device = target
            throw AppError(id: .coreAudioError,
                           message: "default output did not switch to '\(target.name)' (current id: \(current.map(String.init) ?? "?"))",
                           exitCode: .coreAudioError, context: context)
        }
    }
}
