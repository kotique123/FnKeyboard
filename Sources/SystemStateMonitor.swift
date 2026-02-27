import Foundation
import CoreAudio
import AudioToolbox
import IOKit
import IOKit.hidsystem

/// Polls the system for current brightness and volume levels.
///
/// Updates every second on a background timer, publishing values on the main thread.
/// Used by `FunctionKeyView` to show mini state indicators on relevant keys.
///
/// - Brightness: read via `IODisplayGetFloatParameter` (IOKit display services).
/// - Volume:     read via `CoreAudio` hardware service property.
/// - Muted:      read via `CoreAudio` mute property.
final class SystemStateMonitor: ObservableObject {

    /// Display brightness, 0.0–1.0.  `nil` if unavailable.
    @Published private(set) var brightness: Float? = nil

    /// Output volume, 0.0–1.0.  `nil` if unavailable.
    @Published private(set) var volume: Float? = nil

    /// Whether the system output is muted.
    @Published private(set) var isMuted: Bool = false

    private var timer: Timer?

    init() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Polling

    private func poll() {
        let b = readBrightness()
        let v = readVolume()
        let m = readMuted()
        DispatchQueue.main.async { [weak self] in
            self?.brightness = b
            self?.volume = v
            self?.isMuted = m
        }
    }

    // MARK: - Brightness (IOKit Display Services)

    private func readBrightness() -> Float? {
        var service: io_object_t = 0
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect"),
            &iterator
        )
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var brightness: Float = 0
        let kr = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        return kr == KERN_SUCCESS ? brightness : nil
    }

    // MARK: - Volume & Mute (CoreAudio)

    private func defaultOutputDevice() -> AudioDeviceID {
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func readVolume() -> Float? {
        let device = defaultOutputDevice()
        guard device != kAudioObjectUnknown else { return nil }

        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    private func readMuted() -> Bool {
        let device = defaultOutputDevice()
        guard device != kAudioObjectUnknown else { return false }

        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &muted)
        return status == noErr && muted != 0
    }
}
