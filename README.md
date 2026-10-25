# DeviceAudioSR

A macOS command-line tool to change (and inspect) the nominal sample rate of
any CoreAudio audio device. Results are emitted as machine-readable JSON.
The installed executable is `deviceaudiosr` (lower-case, Homebrew-friendly).

```console
$ deviceaudiosr 48000 -d "MacBook Pro Speakers"
{
  "ok" : true,
  "device" : { "name" : "MacBook Pro Speakers", "uid" : "BuiltInSpeakerDevice" },
  "scope" : "output",
  "requestedRate" : 48000,
  "changed" : true,
  "before" : { "sampleRate" : 44100, "channels" : 2, "bits" : 32, "format" : "44,100Hz 2ch 32-bit" },
  "after"  : { "sampleRate" : 48000, "channels" : 2, "bits" : 32, "format" : "48,000Hz 2ch 32-bit" }
}
```

## Install (Homebrew)

```console
$ brew install 4L3X4NND3RR/tap/deviceaudiosr
```

Requires macOS 15.6 or newer. The tap ships prebuilt bottles for Apple
Silicon; on Intel, install with `--build-from-source` (needs Xcode 16+).

## CLI contract (stable — do not break casually)

| Invocation | Effect |
|---|---|
| `deviceaudiosr <rate> [-d <name\|uid\|id>] [-i]` | Set nominal sample rate |
| `deviceaudiosr --output <name\|uid\|id>` | Set the system default output device |
| `deviceaudiosr --list` | All devices: uid, per-scope format, supported rates |
| `deviceaudiosr --help` / `--version` | Help / version, plain text, exit 0 |

- **Rate syntax:** `48000`, `48,000`, `48 000`, `48k`, `44.1k`, or a full spec
  string like `"48,000Hz 2ch 32-bit"` (only the rate is applied; `ch`/`bit`
  tokens are accepted and ignored because they are not settable properties).
- **Device resolution (`-d`, `--output`):** case-insensitive exact UID match,
  then exact name, then numeric CoreAudio device ID, then name substring.
  Ambiguity and misses fail with candidates and
  edit-distance suggestions. No `-d` = default output device (default input
  with `-i`).
- **Streams:** success JSON → `stdout`; error JSON and `-v` debug lines →
  `stderr`. `--help`/`--version` are the only plain-text stdout output.
  No ANSI colors anywhere so `| jq` always works.
- **`--`:** stops option parsing; `-d` accepts flag-looking values unless
  they are exact known flags.
- **Precedence:** `--help` beats everything (even malformed flags), then
  `--version`. Invoked with no arguments: help to stdout, exit 1.

### Error JSON

```json
{
  "ok": false,
  "error": "rate_not_supported",
  "message": "'MacBook Pro Speakers' does not support 192,000Hz",
  "code": 3,
  "device": { "name": "…", "uid": "…" },
  "rates": [44100, 48000, 88200, 96000]
}
```

Stable `error` ids: `usage_error`, `device_not_found`, `ambiguous_device`,
`rate_not_supported`, `core_audio_error`. Optional context keys depending on
the failure: `device`, `devices`, `rates`, `osStatus` (hex string),
`suggestions`, `received`.

### Exit codes

| Code | Meaning |
|---|---|
| 0 | success |
| 1 | usage error |
| 2 | device not found or ambiguous |
| 3 | rate not supported / out of range |
| 4 | CoreAudio failure (set rejected or rate did not apply) |

## Building

The package ships both an Xcode project and a `Package.swift` over the same
sources, so use whichever you prefer. Both target macOS 15.6+
(`.macOS("15.6")` in the manifest, matching the Xcode target). The SPM build
uses `swift-tools-version: 6.0` (Swift 6 language mode); the Xcode target is
still Swift 5 — the code compiles warning-free in both.

### Swift Package Manager

```console
$ swift run deviceaudiosr --list                    # debug
$ swift run -c release deviceaudiosr 48000          # release
# built binary: .build/debug/deviceaudiosr | .build/release/deviceaudiosr
```

### Xcode

Requires Xcode on macOS (deployment target 15.6, Swift 5).

```console
$ xcodebuild -project DeviceAudioSR.xcodeproj -scheme DeviceAudioSR -configuration Debug build
# binary lands in:
#   ~/Library/Developer/Xcode/DerivedData/DeviceAudioSR-*/Build/Products/Debug/deviceaudiosr
```

### Bare swiftc (no manifest)

```console
$ xcrun swiftc -O -o deviceaudiosr \
    DeviceAudioSR/main.swift DeviceAudioSR/{Domain,Application,Infrastructure,Presentation}/*.swift
```

`swift DeviceAudioSR/main.swift` does **not** work: interpreter mode compiles
only that one file, so all cross-file symbols (`parseArguments`, …) are out of
scope. Pass every file (swiftc) or point at a manifest (`swift run`).

The executable must **stay unsandboxed** — CoreAudio device mutation
needs a non-sandboxed process. The Xcode template default is fine; do not add
the App Sandbox entitlement.

## Architecture

Clean architecture, four layers. The dependency rule points inward only:
`Presentation → Application → Domain` and `Infrastructure → Application`.

```
DeviceAudioSR/
  main.swift                          composition root (wiring only)
  Domain/                             pure entities; NO CoreAudio import
    AudioDevice.swift                 AudioDevice, AudioScope, StreamFormat
    SampleRate.swift                  parse / plausibility / display format
    DeviceMatcher.swift               resolve query, fuzzy suggestions
  Application/                        use cases; depends on a protocol
    AudioDeviceRepository.swift       the CoreAudio boundary
    ListDevices.swift
    SetSampleRate.swift               resolve → validate → apply → verify
    AppError.swift                    ErrorID, ExitCode, typed context
    Logger.swift                      protocol + Stderr/Null impls
  Infrastructure/                     every AudioObject* call lives here
    CoreAudioClient.swift             low-level property access
    CoreAudioDeviceRepository.swift   snapshots, set + async verify loop
  Presentation/                       terminal edge
    ArgumentParser.swift              argv rules, precedence
    Suggestions.swift                 mistyped-flag hints
    Help.swift                        cliVersion + help text
    JSONPresenter.swift               JSON rendering, process exit
```

Key seams:

- **Use cases never call `exit()`** or print. They return typed results or
  throw `AppError(id:message:exitCode:context:)`. Only `JSONPresenter` turns
  those into streams and process exit.
- **`AudioDeviceRepository`** is the port. `SetSampleRate` would run unchanged
  against a fake repository — there is no CoreAudio in Domain or Application,
  device ids are `UInt32`, scopes are `AudioScope.output/.input`, rate ranges
  are `[ClosedRange<Double>]`.
- **Logging** goes through an injected `Logger`. The repo logs CoreAudio
  status and verify attempts; use cases log resolution steps. `stdout` is
  never touched by logging.
- Single target, so the dependency rule is convention, not compiler-enforced.
  If it must become hard, split the four folders into local SwiftPM targets
  with explicit dependencies.

## CoreAudio gotchas (learned the hard way)

These are the traps that caused crashes or wrong output during development;
preserve the workarounds in `Infrastructure/CoreAudioClient.swift`:

1. **CFString properties are returned at +1 and the buffer *contains a
   pointer*.** Load the pointer out of the `Data` first, then
   `Unmanaged<CFString>.fromOpaque(pointer).takeRetainedValue()`. Passing the
   buffer's own base address to `fromOpaque` crashes in `objc_msgSend`.
2. **`AudioBufferList` buffers start at byte offset 8, not 4.** The trailing
   `AudioBuffer` array is aligned to `AudioBuffer.alignment` (8 on arm64), so
   there is 4 bytes of padding after `mNumberBuffers`. Reading at offset 4
   yields `0ch`. Also: buffers are misaligned for Swift's `load(as:)` — use
   `loadUnaligned` and read only `mNumberChannels`.
3. **Rate changes apply asynchronously on some hardware.** After
   `AudioObjectSetPropertyData` succeeds, re-read
   `kAudioDevicePropertyNominalSampleRate` in a retry loop (10 × 50 ms)
   before declaring success.
4. **Validate against `kAudioDevicePropertyAvailableNominalSampleRates` first.**
   Otherwise an unsupported rate silently returns an OSStatus error with no
   way to show the user what *is* supported.
5. **Device UIDs are not always UUIDs** (`BuiltInSpeakerDevice`,
   `MSLoopbackDriverDevice_UID`), which is why `-d` accepts arbitrary strings
   and `--list` exists.

## Verifying changes

The CLI contract above is regression-tested manually with a golden-diff
workflow: build a binary from `HEAD`, build one from your branch, then run
both through the same command matrix (all rate syntaxes, device resolution
paths, every error class, `--`/help/version precedence, verbose streams) and
diff **stdout, stderr, and exit codes** byte-for-byte. Useful matrix:
`--help`, `--version`, `-zz --help`, `--list`, no args, `48000`, `44.1k`,
`"48,000Hz 2ch 32-bit"`, `48,000`, `-- 44.1k`, `-d` by name/uid,
`-i`, `192000`, `banana`, `10`, bad `-d`, typo `-d`, `zzzz`, `-devce`,
`-d --list`, `-v 44.1k`.

When testing against real hardware, remember to restore the device rates
(`48000` and `48000 -i`) when done.

## Conventions

- One type or function group per file, named after its layer job.
- Comments explain *why* (hardware quirks, +1 ownership), not *what*.
- New flags: extend `CLIOptions` + `parseArguments` in Presentation only;
  new commands: add a use case in Application, keep `main.swift` wiring-only.
- Version: `cliVersion` in `Presentation/Help.swift` (the pbxproj has no
  `MARKETING_VERSION` set; if you add one, wire it in and remove the literal).
