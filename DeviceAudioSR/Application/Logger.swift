//
//  Logger.swift
//  DeviceAudioSR — Application
//
//  Debug step logging abstraction. Use cases depend on this protocol,
//  never on a concrete sink or global flag.
//

import Foundation

protocol Logger {
    func log(_ message: String)
}

struct NullLogger: Logger {
    func log(_ message: String) {}
}

/// Writes "debug: …" lines to stderr so stdout stays pure JSON.
struct StderrLogger: Logger {
    func log(_ message: String) {
        FileHandle.standardError.write("debug: \(message)\n".data(using: .utf8)!)
    }
}
