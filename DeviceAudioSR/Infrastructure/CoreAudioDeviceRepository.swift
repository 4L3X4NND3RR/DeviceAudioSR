//
//  CoreAudioDeviceRepository.swift
//  DeviceAudioSR — Infrastructure
//
//  Maps CoreAudio property values into domain entities and implements
//  the repository protocol the use cases depend on.
//

import Foundation
import CoreAudio

struct CoreAudioDeviceRepository: AudioDeviceRepository {
    let logger: Logger

    func allDevices() -> [AudioDevice] {
        CoreAudioClient.allDeviceIDs().map(snapshot)
    }

    func device(withID id: UInt32) -> AudioDevice? {
        guard CoreAudioClient.allDeviceIDs().contains(id) else { return nil }
        return snapshot(id)
    }

    func defaultDevice(for scope: AudioScope) -> AudioDevice? {
        let id = scope == .input
            ? CoreAudioClient.defaultInputDeviceID()
            : CoreAudioClient.defaultOutputDeviceID()
        guard let id else { return nil }
        return snapshot(id)
    }

    func setNominalSampleRate(_ rate: Double, on device: AudioDevice) -> SetSampleRateOutcome {
        let status = CoreAudioClient.setNominalSampleRate(deviceID: device.id, rate: rate)
        logger.log("AudioObjectSetPropertyData status: \(status)")
        guard status == noErr else {
            return .setStatusFailed(status: status)
        }

        // Verify — some hardware applies the new rate asynchronously
        for attempt in 0..<10 {
            if let current = CoreAudioClient.nominalSampleRate(device.id) {
                logger.log("verify attempt \(attempt + 1): current rate \(current)")
                if abs(current - rate) < 0.5 {
                    return .applied(rate: current)
                }
            }
            if attempt < 9 { usleep(50_000) }
        }
        return .notSwitched(current: CoreAudioClient.nominalSampleRate(device.id))
    }

    func setDefaultOutput(_ device: AudioDevice) -> SetDefaultOutputOutcome {
        let status = CoreAudioClient.setDefaultOutputDeviceID(device.id)
        logger.log("AudioObjectSetPropertyData default output status: \(status)")
        guard status == noErr else { return .setStatusFailed(status: status) }

        for attempt in 0..<10 {
            let current = CoreAudioClient.defaultOutputDeviceID()
            logger.log("default output verify attempt \(attempt + 1): current id \(current.map(String.init) ?? "?")")
            if current == device.id { return .applied }
            if attempt < 9 { usleep(50_000) }
        }
        return .notSwitched(current: CoreAudioClient.defaultOutputDeviceID())
    }

    /// Build a domain snapshot of the device's live properties.
    private func snapshot(_ id: AudioDeviceID) -> AudioDevice {
        var formats: [AudioScope: StreamFormat] = [:]
        for scope in [AudioScope.output, .input] {
            let caScope = scope.coreAudioScope
            guard CoreAudioClient.firstStreamID(device: id, scope: caScope) != nil else { continue }
            formats[scope] = StreamFormat(
                sampleRate: CoreAudioClient.nominalSampleRate(id),
                channels: CoreAudioClient.channelCount(device: id, scope: caScope),
                bits: CoreAudioClient.bitDepth(device: id, scope: caScope)
            )
        }
        return AudioDevice(
            id: id,
            name: CoreAudioClient.copyStringProperty(objectID: id,
                                                     address: CoreAudioClient.addr(kAudioObjectPropertyName)) ?? "(unnamed)",
            uid: CoreAudioClient.copyStringProperty(objectID: id,
                                                    address: CoreAudioClient.addr(kAudioDevicePropertyDeviceUID)) ?? "",
            isDefaultOutput: id == CoreAudioClient.defaultOutputDeviceID(),
            isDefaultInput: id == CoreAudioClient.defaultInputDeviceID(),
            nominalSampleRate: CoreAudioClient.nominalSampleRate(id),
            supportedRateRanges: CoreAudioClient.availableRateRanges(id),
            formats: formats
        )
    }
}
