//
//  ArgumentParser.swift
//  DeviceAudioSR — Presentation
//

import Foundation

struct CLIOptions {
    var rateArg: String?
    var deviceQuery: String?
    var wantList = false
    var preferInput = false
    var verbose = false

    var isEmptyRun: Bool {
        rateArg == nil && deviceQuery == nil && !wantList && !preferInput
    }
}

func parseArguments(_ arguments: [String]) -> CLIOptions {
    // --help (and --version) take precedence over everything, including
    // malformed flags, and print to stdout with exit 0.
    if arguments.contains("-h") || arguments.contains("--help") {
        printUsage()
        exit(ExitCode.success.rawValue)
    }
    if arguments.contains("-V") || arguments.contains("--version") {
        print("DeviceAudioSR \(cliVersion)")
        exit(ExitCode.success.rawValue)
    }

    var options = CLIOptions()
    if arguments.contains("-v") || arguments.contains("--verbose")
        || ProcessInfo.processInfo.environment["DEBUG"] != nil {
        options.verbose = true
    }

    var iterator = arguments.makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--":
            // everything after "--" is positional
            while let rest = iterator.next() {
                if options.rateArg == nil { options.rateArg = rest }
            }
        case "-l", "--list":
            options.wantList = true
        case "-i", "--input":
            options.preferInput = true
        case "-v", "--verbose":
            options.verbose = true
        case "-d", "--device":
            guard let value = iterator.next(), !knownFlags.contains(value) else {
                present(error: AppError(id: .usageError,
                                        message: "missing value for \(arg)",
                                        exitCode: .usageError))
            }
            options.deviceQuery = value
        default:
            if arg.hasPrefix("-"), arg != "-" {
                let suggestions = suggestFlags(for: arg)
                let hint = suggestions.isEmpty ? "" : " — did you mean \(suggestions.joined(separator: " or "))?"
                present(error: AppError(id: .usageError,
                                       message: "unknown option: \(arg)\(hint)",
                                       exitCode: .usageError,
                                       context: { var c = AppErrorContext(); c.suggestions = suggestions; return c }()))
            }
            // first positional = rate; extra tokens ("2ch", "32-bit") are ignored
            if options.rateArg == nil { options.rateArg = arg }
        }
    }
    return options
}
