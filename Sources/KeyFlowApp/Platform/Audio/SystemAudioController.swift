import AudioToolbox
import CoreAudio
import Foundation

enum SystemAudioError: LocalizedError {
    case defaultDeviceUnavailable(OSStatus)
    case volumeUnavailable
    case muteUnavailable
    case operationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .defaultDeviceUnavailable(status):
            "The default audio output device is unavailable (\(status))."
        case .volumeUnavailable:
            "The current output device does not expose a controllable master volume."
        case .muteUnavailable:
            "The current output device does not expose a mute control."
        case let .operationFailed(status):
            "The audio operation failed with status \(status)."
        }
    }
}

@MainActor
enum SystemAudioController {
    private struct ContinuousSession {
        let device: AudioObjectID
        var volume: Float32
        var isMuted: Bool?
        var lastAdjustment: ContinuousClock.Instant
    }

    private static let sessionTimeout: Duration = .milliseconds(250)
    private static var continuousSession: ContinuousSession?

    @discardableResult
    static func increaseVolume() throws -> Float32 {
        try adjustVolume(up: true, stepCount: 1, stepPercentage: 2)
    }

    @discardableResult
    static func decreaseVolume() throws -> Float32 {
        try adjustVolume(up: false, stepCount: 1, stepPercentage: 2)
    }

    static func adjustVolume(up: Bool, stepCount: Int, stepPercentage: Int) throws -> Float32 {
        guard stepCount > 0 else { return continuousSession?.volume ?? 0 }
        let now = ContinuousClock.now
        var session: ContinuousSession
        if let cached = continuousSession,
            now - cached.lastAdjustment <= sessionTimeout
        {
            session = cached
        } else {
            let device = try defaultOutputDevice()
            try validateVolumeControl(on: device)
            session = ContinuousSession(
                device: device,
                volume: try currentVolume(on: device),
                isMuted: try currentMuteState(on: device),
                lastAdjustment: now
            )
        }

        let percentage = Float32(min(max(stepPercentage, 1), 10)) / 100
        let signedStep = (up ? percentage : -percentage) * Float32(stepCount)
        let adjustedVolume = min(1, max(0, session.volume + signedStep))
        if adjustedVolume != session.volume {
            try setVolume(adjustedVolume, on: session.device)
            session.volume = adjustedVolume
        }
        if up, session.isMuted == true {
            try setMuted(false, on: session.device)
            session.isMuted = false
        }
        session.lastAdjustment = now
        continuousSession = session
        return session.volume
    }

    static func toggleMute() throws -> (isMuted: Bool, volume: Float32) {
        continuousSession = nil
        let device = try defaultOutputDevice()
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { throw SystemAudioError.muteUnavailable }

        var isSettable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &isSettable) == noErr, isSettable.boolValue else {
            throw SystemAudioError.muteUnavailable
        }

        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
        muted = muted == 0 ? 1 : 0
        status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &muted)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
        return (muted != 0, try currentVolume(on: device))
    }

    private static func validateVolumeControl(on device: AudioObjectID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { throw SystemAudioError.volumeUnavailable }

        var isSettable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(device, &address, &isSettable) == noErr, isSettable.boolValue else {
            throw SystemAudioError.volumeUnavailable
        }
    }

    private static func setVolume(_ requestedVolume: Float32, on device: AudioObjectID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume = requestedVolume
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &volume)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
    }

    private static func currentVolume(on device: AudioObjectID) throws -> Float32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { throw SystemAudioError.volumeUnavailable }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
        return volume
    }

    private static func currentMuteState(on device: AudioObjectID) throws -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
        return muted != 0
    }

    private static func setMuted(_ muted: Bool, on device: AudioObjectID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
    }

    private static func defaultOutputDevice() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard status == noErr, device != kAudioObjectUnknown else {
            throw SystemAudioError.defaultDeviceUnavailable(status)
        }
        return device
    }
}
