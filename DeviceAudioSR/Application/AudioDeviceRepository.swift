//
//  AudioDeviceRepository.swift
//  DeviceAudioSR — Application
//
//  The boundary the use cases depend on. Implemented by Infrastructure
//  (CoreAudio); nothing here imports CoreAudio.
//

enum SetSampleRateOutcome {
    case applied(rate: Double)
    case setStatusFailed(status: Int32)
    case notSwitched(current: Double?)
}

enum SetDefaultOutputOutcome {
    case applied
    case setStatusFailed(status: Int32)
    case notSwitched(current: UInt32?)
}

protocol AudioDeviceRepository {
    /// All devices in system order, each with its live format snapshot.
    func allDevices() -> [AudioDevice]

    /// Re-read a device's live properties (after a property change).
    func device(withID id: UInt32) -> AudioDevice?

    /// The system default for the given scope.
    func defaultDevice(for scope: AudioScope) -> AudioDevice?

    /// Set the nominal sample rate and verify it took effect.
    func setNominalSampleRate(_ rate: Double, on device: AudioDevice) -> SetSampleRateOutcome

    func setDefaultOutput(_ device: AudioDevice) -> SetDefaultOutputOutcome
}
