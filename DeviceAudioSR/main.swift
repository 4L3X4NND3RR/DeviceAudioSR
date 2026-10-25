//
//  main.swift
//  DeviceAudioSR — composition root
//
//  CLI to change (and inspect) the nominal sample rate of a CoreAudio device.
//
//  Usage:
//    DeviceAudioSR <rate> [-d <name|uid>] [-i] [--verbose]
//    DeviceAudioSR --list
//    DeviceAudioSR --help | --version
//
//  Results are JSON: success on stdout, errors (and debug logs) on stderr.
//
//  Layers:
//    Domain/          entities, pure logic (no CoreAudio, no I/O)
//    Application/     use cases + repository protocol
//    Infrastructure/  CoreAudio implementation of the repository
//    Presentation/    argv parsing, help, JSON rendering
//

import Foundation

let cliOptions = parseArguments(Array(CommandLine.arguments.dropFirst()))

let logger: Logger = cliOptions.verbose ? StderrLogger() : NullLogger()
let repository = CoreAudioDeviceRepository(logger: logger)

if cliOptions.wantList {
    do {
        present(devices: try ListDevices(repository: repository).execute())
    } catch let error as AppError {
        present(error: error)
    }
    exit(ExitCode.success.rawValue)
}

guard !cliOptions.isEmptyRun else {
    printUsage()
    exit(ExitCode.usageError.rawValue)
}

let setSampleRate = SetSampleRate(repository: repository, logger: logger)
let input = SetSampleRate.Input(rawRate: cliOptions.rateArg,
                                deviceQuery: cliOptions.deviceQuery,
                                preferInput: cliOptions.preferInput)
do {
    present(result: try setSampleRate.execute(input))
} catch let error as AppError {
    present(error: error)
}
exit(ExitCode.success.rawValue)
