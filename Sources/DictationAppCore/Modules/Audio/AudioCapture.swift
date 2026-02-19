import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(AudioToolbox)
import AudioToolbox
#endif
#if canImport(CoreAudio)
import CoreAudio
#endif

public protocol AudioCapturing {
    func start()
    func stop()
}

public enum AudioCaptureError: Error, Equatable, Sendable {
    case inputDeviceNotFound(String)
    case inputDeviceSelectionUnsupported
    case audioUnitUnavailable
    case failedToSetInputDevice(Int32)
    case failedToEnumerateInputDevices(Int32)
}

public final class AudioCapture: AudioCapturing {
    public private(set) var isCapturing = false
    public var onFrame: ((AudioFrame) -> Void)?
    public var onError: ((Error) -> Void)?
    private let preferredInputDevice: String?

#if canImport(AVFoundation)
    private let engine: AVAudioEngine
#endif

    public init(preferredInputDevice: String? = nil) {
        let normalized = preferredInputDevice?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.preferredInputDevice = normalized?.isEmpty == true ? nil : normalized
#if canImport(AVFoundation)
        engine = AVAudioEngine()
#endif
    }

    public static func availableInputDevices() throws -> [AudioInputDevice] {
#if canImport(CoreAudio)
        return try CoreAudioInputDeviceCatalog.publicDevices()
#else
        return []
#endif
    }

    public func start() {
        guard !isCapturing else {
            return
        }

#if canImport(AVFoundation)
        do {
            let inputNode = engine.inputNode
            do {
                try configurePreferredInputDeviceIfNeeded(inputNode: inputNode)
            } catch AudioCaptureError.inputDeviceNotFound(let identifier) {
                // Fall back to system default input if a configured device disappeared.
                onError?(AudioCaptureError.inputDeviceNotFound(identifier))
            }

            var tapFormat = inputNode.inputFormat(forBus: 0)
            if tapFormat.channelCount == 0 {
                tapFormat = inputNode.outputFormat(forBus: 0)
            }
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
                self?.handle(buffer: buffer)
            }

            try engine.start()
            isCapturing = true
        } catch {
            onError?(error)
            isCapturing = false
        }
#else
        isCapturing = true
#endif
    }

    public func stop() {
#if canImport(AVFoundation)
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
#endif
        isCapturing = false
    }

    public func emitFrame(_ frame: AudioFrame) {
        onFrame?(frame)
    }

#if canImport(AVFoundation)
    private func configurePreferredInputDeviceIfNeeded(inputNode: AVAudioInputNode) throws {
        guard let preferredInputDevice else {
            return
        }

#if canImport(CoreAudio) && canImport(AudioToolbox)
        let entries = try CoreAudioInputDeviceCatalog.entries()
        let publicDevices = entries.map(\.device)
        guard let selectedDevice = try AudioInputDeviceSelector.resolve(
            preferredInputDevice: preferredInputDevice,
            availableDevices: publicDevices
        ) else {
            return
        }

        guard let selectedEntry = entries.first(where: { $0.device.id == selectedDevice.id }) else {
            throw AudioCaptureError.inputDeviceNotFound(preferredInputDevice)
        }

        guard let audioUnit = inputNode.audioUnit else {
            throw AudioCaptureError.audioUnitUnavailable
        }

        var deviceID = selectedEntry.deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw AudioCaptureError.failedToSetInputDevice(status)
        }
#else
        throw AudioCaptureError.inputDeviceSelectionUnsupported
#endif
    }

    private func handle(buffer: AVAudioPCMBuffer) {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return
        }

        let channels = Int(buffer.format.channelCount)
        guard channels > 0 else {
            return
        }

        var samples: [Float] = []
        samples.reserveCapacity(frameLength)
        if let floatData = buffer.floatChannelData {
            for frameIndex in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += floatData[channel][frameIndex]
                }
                samples.append(sum / Float(channels))
            }
        } else if let int16Data = buffer.int16ChannelData {
            for frameIndex in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += Float(int16Data[channel][frameIndex]) / Float(Int16.max)
                }
                samples.append(sum / Float(channels))
            }
        } else if let int32Data = buffer.int32ChannelData {
            for frameIndex in 0..<frameLength {
                var sum: Float = 0
                for channel in 0..<channels {
                    sum += Float(int32Data[channel][frameIndex]) / Float(Int32.max)
                }
                samples.append(sum / Float(channels))
            }
        } else {
            return
        }

        emitFrame(.init(samples: samples, sampleRate: buffer.format.sampleRate, channels: 1))
    }

#endif
}
