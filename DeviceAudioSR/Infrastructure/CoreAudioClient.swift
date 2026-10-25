//
//  CoreAudioClient.swift
//  DeviceAudioSR — Infrastructure
//
//  Low-level CoreAudio property access. All `AudioObjectGetPropertyData`
//  / `SetPropertyData` calls and raw struct parsing live here.
//

import Foundation
import CoreAudio

extension AudioScope {
    var coreAudioScope: AudioObjectPropertyScope {
        self == .input ? kAudioObjectPropertyScopeInput : kAudioObjectPropertyScopeOutput
    }
}

enum CoreAudioClient {
    static func addr(_ selector: AudioObjectPropertySelector,
                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                     element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    /// Fixed-size typed getter.
    static func getProperty<T>(objectID: AudioObjectID, address a: AudioObjectPropertyAddress) -> T? {
        var address = a
        var storage = Data(count: MemoryLayout<T>.size)
        guard !storage.isEmpty else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        let status: OSStatus = storage.withUnsafeMutableBytes { raw in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, raw.baseAddress!)
        }
        guard status == noErr, Int(size) == MemoryLayout<T>.size else { return nil }
        return storage.withUnsafeBytes { $0.loadUnaligned(as: T.self) }
    }

    /// Variable-sized getter (arrays, strings, structs with trailing buffers).
    static func getPropertyData(objectID: AudioObjectID, address a: AudioObjectPropertyAddress) -> Data? {
        var address = a
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size) == noErr, size > 0 else {
            return nil
        }
        var buffer = Data(count: Int(size))
        let status: OSStatus = buffer.withUnsafeMutableBytes { raw in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, raw.baseAddress!)
        }
        guard status == noErr else { return nil }
        if Int(size) < buffer.count { buffer.removeSubrange(Int(size)..<buffer.count) }
        return buffer
    }

    /// Read a CFString-valued property (CoreAudio returns it at +1).
    static func copyStringProperty(objectID: AudioObjectID,
                                   address a: AudioObjectPropertyAddress) -> String? {
        guard let data = getPropertyData(objectID: objectID, address: a),
              data.count >= MemoryLayout<UInt32>.stride else { return nil }
        let str = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> String in
            // The buffer contains a CFStringRef; load the pointer it stores.
            let pointer = raw.loadUnaligned(as: UnsafeRawPointer.self)
            return Unmanaged<CFString>.fromOpaque(pointer).takeRetainedValue() as String
        }
        return str.isEmpty ? nil : str
    }

    @discardableResult
    static func setNominalSampleRate(deviceID: AudioDeviceID, rate: Double) -> OSStatus {
        var address = addr(kAudioDevicePropertyNominalSampleRate)
        var value = rate
        return withUnsafeMutablePointer(to: &value) { ptr in
            AudioObjectSetPropertyData(deviceID, &address, 0, nil,
                                       UInt32(MemoryLayout<Float64>.size), ptr)
        }
    }

    static func allDeviceIDs() -> [AudioDeviceID] {
        guard let data = getPropertyData(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            address: addr(kAudioHardwarePropertyDevices)
        ) else { return [] }
        return data.withUnsafeBytes { raw -> [AudioDeviceID] in
            Array(raw.bindMemory(to: AudioDeviceID.self))
        }
    }

    static func defaultOutputDeviceID() -> AudioDeviceID? {
        getProperty(objectID: AudioObjectID(kAudioObjectSystemObject),
                    address: addr(kAudioHardwarePropertyDefaultOutputDevice))
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        getProperty(objectID: AudioObjectID(kAudioObjectSystemObject),
                    address: addr(kAudioHardwarePropertyDefaultInputDevice))
    }

    /// Total channels reported by the device's stream configuration for a scope.
    static func channelCount(device id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int? {
        guard let data = getPropertyData(
            objectID: id,
            address: addr(kAudioDevicePropertyStreamConfiguration, scope: scope)
        ) else { return nil }

        return data.withUnsafeBytes { raw -> Int? in
            guard raw.count >= MemoryLayout<UInt32>.stride else { return nil }
            // C aligns the trailing AudioBuffer array to AudioBuffer's alignment (8),
            // so mBuffers starts after padding, not right after the UInt32 count.
            let header = max(MemoryLayout<UInt32>.stride, MemoryLayout<AudioBuffer>.alignment)
            let bufferStride = MemoryLayout<AudioBuffer>.stride
            let count = raw.loadUnaligned(as: UInt32.self)
            var total = 0
            for i in 0..<Int(count) {
                let offset = header + i * bufferStride
                guard offset + MemoryLayout<UInt32>.stride <= raw.count else { break }
                // Read only mNumberChannels (first field), unaligned-safe.
                total += Int(raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
            }
            return total
        }
    }

    /// ID of the first stream listed for the given scope.
    static func firstStreamID(device id: AudioDeviceID, scope: AudioObjectPropertyScope) -> AudioObjectID? {
        guard let data = getPropertyData(objectID: id,
                                         address: addr(kAudioDevicePropertyStreams, scope: scope)) else {
            return nil
        }
        return data.withUnsafeBytes { raw -> AudioObjectID? in
            let ids = raw.bindMemory(to: AudioObjectID.self)
            return ids.isEmpty ? nil : ids[0]
        }
    }

    static func streamFormatBits(objectID: AudioObjectID, selector: AudioObjectPropertySelector,
                                 scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> Int? {
        guard let data = getPropertyData(objectID: objectID,
                                         address: addr(selector, scope: scope)),
              data.count >= MemoryLayout<AudioStreamBasicDescription>.size else { return nil }
        let bits = Int(data.withUnsafeBytes { $0.loadUnaligned(as: AudioStreamBasicDescription.self).mBitsPerChannel })
        return bits > 0 ? bits : nil
    }

    /// Bit depth from the physical (hardware) format, falling back to the virtual
    /// stream format, then to the device stream format.
    static func bitDepth(device id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int? {
        if let stream = firstStreamID(device: id, scope: scope) {
            if let bits = streamFormatBits(objectID: stream, selector: kAudioStreamPropertyPhysicalFormat) {
                return bits
            }
            if let bits = streamFormatBits(objectID: stream, selector: kAudioStreamPropertyVirtualFormat) {
                return bits
            }
        }
        return streamFormatBits(objectID: id, selector: kAudioDevicePropertyStreamFormat, scope: scope)
    }

    static func nominalSampleRate(_ id: AudioDeviceID) -> Double? {
        getProperty(objectID: id, address: addr(kAudioDevicePropertyNominalSampleRate))
    }

    /// Supported nominal sample rates as ranges.
    static func availableRateRanges(_ id: AudioDeviceID) -> [ClosedRange<Double>] {
        guard let data = getPropertyData(objectID: id,
                                         address: addr(kAudioDevicePropertyAvailableNominalSampleRates)) else {
            return []
        }
        guard data.count >= MemoryLayout<AudioValueRange>.stride else { return [] }
        return data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [ClosedRange<Double>] in
            raw.bindMemory(to: AudioValueRange.self).map {
                ClosedRange(uncheckedBounds: (lower: min($0.mMinimum, $0.mMaximum),
                                              upper: max($0.mMinimum, $0.mMaximum)))
            }
        }
    }
}
