import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

public protocol AudioCapturing {
    func start()
    func stop()
}

public final class AudioCapture: AudioCapturing {
    public private(set) var isCapturing = false
    public var onFrame: ((AudioFrame) -> Void)?
    public var onError: ((Error) -> Void)?

#if canImport(AVFoundation)
    private let engine: AVAudioEngine
#endif

    public init() {
#if canImport(AVFoundation)
        engine = AVAudioEngine()
#endif
    }

    public func start() {
        guard !isCapturing else {
            return
        }

#if canImport(AVFoundation)
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handle(buffer: buffer)
        }

        do {
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
        } else {
            return
        }

        emitFrame(.init(samples: samples, sampleRate: buffer.format.sampleRate, channels: 1))
    }
#endif
}
