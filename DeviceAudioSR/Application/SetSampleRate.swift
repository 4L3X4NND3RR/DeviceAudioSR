//
//  SetSampleRate.swift
//  DeviceAudioSR — Application
//
//  Resolve device → validate rate → apply → verify. Returns a typed
//  result; all failures surface as AppError. Never calls exit() or
//  touches stdout/stderr directly (only through Logger).
//

struct SetSampleRate {
    let repository: AudioDeviceRepository
    let logger: Logger

    struct Input {
        var rawRate: String?
        var deviceQuery: String?
        var preferInput = false
    }

    struct Result {
        let device: AudioDevice
        let scope: AudioScope
        let requestedRate: Double
        let changed: Bool
        let before: StreamFormat?
        let after: StreamFormat?
    }

    func execute(_ input: Input) throws -> Result {
        guard let rawRate = input.rawRate else {
            throw AppError(id: .usageError,
                           message: "missing <rate> argument (use --list to see devices)",
                           exitCode: .usageError)
        }
        guard let rate = SampleRate.parse(from: rawRate) else {
            var context = AppErrorContext()
            context.received = rawRate
            throw AppError(id: .usageError,
                           message: "could not parse sample rate from: \(rawRate)",
                           exitCode: .usageError, context: context)
        }
        guard SampleRate.isPlausible(rate) else {
            throw AppError(id: .rateNotSupported,
                           message: "sample rate out of plausible range: \(SampleRate.display(rate))Hz",
                           exitCode: .rateNotSupported)
        }

        let target = try resolveTarget(input)

        let currentScope = target.targetScope(preferInput: input.preferInput)
        logger.log("target: '\(target.name)' uid='\(target.uid)' id=\(target.id) scope=\(currentScope.displayName)")
        logger.log("requested rate: \(SampleRate.display(rate))Hz (from '\(rawRate)')")
        logger.log("supported rates: \(target.distinctSupportedRates.map(SampleRate.display).joined(separator: ", "))")

        guard target.supports(rate: rate) else {
            var context = AppErrorContext()
            context.device = target
            context.rates = target.distinctSupportedRates
            throw AppError(id: .rateNotSupported,
                           message: "'\(target.name)' does not support \(SampleRate.display(rate))Hz",
                           exitCode: .rateNotSupported, context: context)
        }

        let before = target.format(in: currentScope)
        let beforeRate = target.nominalSampleRate

        logger.log("setting kAudioDevicePropertyNominalSampleRate = \(rate)")
        let outcome = repository.setNominalSampleRate(rate, on: target)

        switch outcome {
        case .setStatusFailed(let status):
            var context = AppErrorContext()
            context.device = target
            context.osStatus = "0x" + String(UInt32(bitPattern: status), radix: 16)
            throw AppError(id: .coreAudioError,
                           message: "could not set \(SampleRate.display(rate))Hz on '\(target.name)'",
                           exitCode: .coreAudioError, context: context)
        case .notSwitched(let current):
            var context = AppErrorContext()
            context.device = target
            throw AppError(id: .coreAudioError,
                           message: "property set but '\(target.name)' did not switch to "
                               + "\(SampleRate.display(rate))Hz (current: \(current.map(SampleRate.display) ?? "?")Hz)",
                           exitCode: .coreAudioError, context: context)
        case .applied(let applied):
            let refreshed = repository.device(withID: target.id) ?? target
            let changed = beforeRate.map { abs($0 - applied) >= 0.5 } ?? true
            return Result(device: refreshed,
                          scope: currentScope,
                          requestedRate: rate,
                          changed: changed,
                          before: before,
                          after: refreshed.format(in: currentScope))
        }
    }

    private func resolveTarget(_ input: Input) throws -> AudioDevice {
        if let query = input.deviceQuery {
            let devices = repository.allDevices()
            switch DeviceMatcher.resolve(query: query, devices: devices) {
            case .found(let device):
                return device
            case .ambiguous(let matches):
                var context = AppErrorContext()
                context.devices = matches
                throw AppError(id: .ambiguousDevice,
                               message: "'\(query)' matches several devices, be more specific",
                               exitCode: .deviceNotFound, context: context)
            case .notFound:
                let suggestions = DeviceMatcher.suggestions(for: query, devices: devices)
                let hint = suggestions.isEmpty
                    ? ""
                    : " — did you mean \(suggestions.map { "'\($0)'" }.joined(separator: " or "))?"
                logger.log("device '\(query)' not found; suggestions: \(suggestions)")
                var context = AppErrorContext()
                context.devices = devices
                context.suggestions = suggestions
                throw AppError(id: .deviceNotFound,
                               message: "device not found: \(query)\(hint)",
                               exitCode: .deviceNotFound, context: context)
            }
        } else if let device = repository.defaultDevice(for: input.preferInput ? .input : .output) {
            return device
        } else {
            throw AppError(id: .deviceNotFound,
                           message: "no default \(input.preferInput ? "input" : "output") device configured",
                           exitCode: .deviceNotFound)
        }
    }
}
