//
//  JSONPresenter.swift
//  DeviceAudioSR — Presentation
//
//  Renders use-case results and errors as JSON: success on stdout,
//  errors on stderr. The key shapes here are the CLI's public contract.
//

import Foundation

func writeJSON(_ object: Any, to output: FileHandle = .standardOutput) {
    let data = (try? JSONSerialization.data(withJSONObject: object,
                                            options: [.prettyPrinted, .sortedKeys])) ?? Data()
    output.write(data)
    output.write(Data([0x0A]))
}

// MARK: - Success

func present(devices: [AudioDevice]) {
    writeJSON(["devices": devices.map(deviceJSON)])
}

func present(result: SetSampleRate.Result) {
    let rate = result.requestedRate
    writeJSON([
        "ok": true,
        "device": deviceSummary(result.device),
        "scope": result.scope.displayName,
        "requestedRate": NSNumber(value: rate.rounded() == rate ? rate.rounded() : rate),
        "changed": result.changed,
        "before": formatJSON(result.before).map { $0 as Any } ?? NSNull(),
        "after": formatJSON(result.after).map { $0 as Any } ?? NSNull(),
    ])
}

func deviceSummary(_ device: AudioDevice) -> [String: Any] {
    ["name": device.name, "uid": device.uid]
}

func formatJSON(_ format: StreamFormat?) -> [String: Any]? {
    guard let format else { return nil }
    return [
        "sampleRate": format.sampleRate
            .map { NSNumber(value: $0.rounded() == $0 ? $0.rounded() : $0) } ?? NSNull(),
        "channels": format.channels.map { NSNumber(value: $0) } ?? NSNull(),
        "bits": format.bits.map { NSNumber(value: $0) } ?? NSNull(),
        "format": format.displayString,
    ]
}

func deviceJSON(_ device: AudioDevice) -> [String: Any] {
    var json: [String: Any] = [
        "name": device.name,
        "uid": device.uid,
        "defaultOutput": device.isDefaultOutput,
        "defaultInput": device.isDefaultInput,
        "rates": device.distinctSupportedRates,
    ]
    json["output"] = formatJSON(device.format(in: .output)).map { $0 as Any } ?? NSNull()
    json["input"] = formatJSON(device.format(in: .input)).map { $0 as Any } ?? NSNull()
    return json
}

// MARK: - Errors

func present(error: AppError) -> Never {
    var json: [String: Any] = [
        "ok": false,
        "error": error.id.rawValue,
        "message": error.message,
        "code": error.exitCode.rawValue,
    ]
    let context = error.context
    if let device = context.device { json["device"] = deviceSummary(device) }
    if let devices = context.devices { json["devices"] = devices.map(deviceSummary) }
    if let rates = context.rates { json["rates"] = rates }
    if let suggestions = context.suggestions { json["suggestions"] = suggestions }
    if let osStatus = context.osStatus { json["osStatus"] = osStatus }
    if let received = context.received { json["received"] = received }
    writeJSON(json, to: .standardError)
    exit(error.exitCode.rawValue)
}
