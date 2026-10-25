//
//  ListDevices.swift
//  DeviceAudioSR — Application
//

struct ListDevices {
    let repository: AudioDeviceRepository

    func execute() throws -> [AudioDevice] {
        let devices = repository.allDevices()
        guard !devices.isEmpty else {
            throw AppError(id: .coreAudioError,
                           message: "no audio devices found",
                           exitCode: .coreAudioError)
        }
        return devices
    }
}
