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
protocol AudioControlling: AnyObject {
    func adjustVolume(up: Bool, stepCount: Int, stepPercentage: Int) throws -> Float32
    func toggleMute() throws -> (isMuted: Bool, volume: Float32)
}

@MainActor
protocol CoreAudioAccessing: AnyObject {
    func defaultOutputDevice() throws -> AudioObjectID
    func validateVolumeControl(on device: AudioObjectID) throws
    func setVolume(_ volume: Float32, on device: AudioObjectID) throws
    func currentVolume(on device: AudioObjectID) throws -> Float32
    func currentMuteState(on device: AudioObjectID) throws -> Bool?
    func setMuted(_ muted: Bool, on device: AudioObjectID) throws
}

@MainActor
final class SystemAudioController: AudioControlling {
    private struct ContinuousSession {
        let device: AudioObjectID
        var volume: Float32
        var isMuted: Bool?
        var lastAdjustment: ContinuousClock.Instant
    }

    private let hardware: any CoreAudioAccessing
    private let sessionTimeout: Duration
    private let now: () -> ContinuousClock.Instant
    private var continuousSession: ContinuousSession?

    init(
        hardware: any CoreAudioAccessing = SystemCoreAudioAccess(),
        sessionTimeout: Duration = .milliseconds(250),
        now: @escaping () -> ContinuousClock.Instant = { .now }
    ) {
        self.hardware = hardware
        self.sessionTimeout = max(.zero, sessionTimeout)
        self.now = now
    }

    func adjustVolume(up: Bool, stepCount: Int, stepPercentage: Int) throws -> Float32 {
        let performance = KeyFlowPerformance.begin("AdjustVolume", using: KeyFlowPerformance.audio)
        defer { performance.end() }
        guard stepCount > 0 else { return continuousSession?.volume ?? 0 }
        let instant = now()
        var session: ContinuousSession
        if let cached = continuousSession,
            instant - cached.lastAdjustment <= sessionTimeout
        {
            session = cached
        } else {
            let device = try hardware.defaultOutputDevice()
            try hardware.validateVolumeControl(on: device)
            session = ContinuousSession(
                device: device,
                volume: try hardware.currentVolume(on: device),
                isMuted: try hardware.currentMuteState(on: device),
                lastAdjustment: instant
            )
        }

        let percentage = Float32(min(max(stepPercentage, 1), 10)) / 100
        let signedStep = (up ? percentage : -percentage) * Float32(stepCount)
        let adjustedVolume = min(1, max(0, session.volume + signedStep))
        if adjustedVolume != session.volume {
            try hardware.setVolume(adjustedVolume, on: session.device)
            session.volume = adjustedVolume
        }
        if up, session.isMuted == true {
            try hardware.setMuted(false, on: session.device)
            session.isMuted = false
        }
        session.lastAdjustment = instant
        continuousSession = session
        return session.volume
    }

    func toggleMute() throws -> (isMuted: Bool, volume: Float32) {
        let performance = KeyFlowPerformance.begin("ToggleMute", using: KeyFlowPerformance.audio)
        defer { performance.end() }
        continuousSession = nil
        let device = try hardware.defaultOutputDevice()
        guard let isMuted = try hardware.currentMuteState(on: device) else {
            throw SystemAudioError.muteUnavailable
        }
        let updatedState = !isMuted
        try hardware.setMuted(updatedState, on: device)
        return (updatedState, try hardware.currentVolume(on: device))
    }
}

@MainActor
final class SystemCoreAudioAccess: CoreAudioAccessing {
    func validateVolumeControl(on device: AudioObjectID) throws {
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

    func setVolume(_ requestedVolume: Float32, on device: AudioObjectID) throws {
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

    func currentVolume(on device: AudioObjectID) throws -> Float32 {
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

    func currentMuteState(on device: AudioObjectID) throws -> Bool? {
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

    func setMuted(_ muted: Bool, on device: AudioObjectID) throws {
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
        var value: UInt32 = muted ? 1 : 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(device, &address, 0, nil, size, &value)
        guard status == noErr else { throw SystemAudioError.operationFailed(status) }
    }

    func defaultOutputDevice() throws -> AudioObjectID {
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
