//
//  Help.swift
//  DeviceAudioSR — Presentation
//

let cliVersion = "1.0.0"

func printUsage() {
    print("""
    deviceaudiosr \(cliVersion)

    Change the nominal sample rate of a macOS audio device (CoreAudio).

    USAGE
      deviceaudiosr <rate> [-d <name|uid>] [-i]
      deviceaudiosr --list
      deviceaudiosr --help | --version

    EXAMPLES
      deviceaudiosr 48000
      deviceaudiosr "48,000Hz 2ch 32-bit" -d "MacBook Pro Speakers"
      deviceaudiosr 96k -d BuiltInHeadphoneOutputDevice
      deviceaudiosr --list | jq .

    OPTIONS
      <rate>            Sample rate: 48000, 48,000, 44.1k, or "48,000Hz 2ch 32-bit"
                        (only the rate is applied; trailing ch/bit tokens are ignored)
      -d, --device      Device name or UID (case-insensitive exact match, then
                        substring). Defaults to the current default output device
                        (default input with -i).
      -i, --input       Target the input scope of the device.
      -l, --list        List all devices: uid, current format, supported rates.
      -v, --verbose     Log execution steps to stderr (or set DEBUG=1).
      -V, --version     Print version and exit.
      -h, --help        Show this help and exit.
      --                Stop option parsing (lets values start with "-").

    OUTPUT
      Results are JSON: success on stdout, errors on stderr.
      Errors carry: ok=false, error (stable id), message, code, plus context
      such as device, devices, rates, osStatus, suggestions.
      Error ids: usage_error, device_not_found, ambiguous_device,
      rate_not_supported, core_audio_error.

    EXIT CODES
      0  success
      1  usage error
      2  device not found or ambiguous
      3  rate not supported or out of range
      4  CoreAudio failure
    """)
}
