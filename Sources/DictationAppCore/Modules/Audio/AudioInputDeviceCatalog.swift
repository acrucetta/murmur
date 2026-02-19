import Foundation

#if canImport(CoreAudio)
import CoreAudio
#endif

public struct AudioInputDevice: Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool

    public init(id: String, name: String, isDefault: Bool) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
    }
}

enum AudioInputDeviceSelector {
    static func resolve(
        preferredInputDevice: String?,
        availableDevices: [AudioInputDevice]
    ) throws -> AudioInputDevice? {
        guard let preferredInputDevice else {
            return nil
        }

        let normalized = preferredInputDevice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        if let byID = availableDevices.first(where: { $0.id == normalized }) {
            return byID
        }

        if let byName = availableDevices.first(where: {
            $0.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) {
            return byName
        }

        throw AudioCaptureError.inputDeviceNotFound(normalized)
    }
}

#if canImport(CoreAudio)
struct CoreAudioInputDeviceCatalog {
    struct Entry {
        let deviceID: AudioDeviceID
        let device: AudioInputDevice
    }

    static func publicDevices() throws -> [AudioInputDevice] {
        try entries().map(\.device)
    }

    static func entries() throws -> [Entry] {
        let defaultInputDeviceID = try defaultInputDeviceID()
        let inputDeviceIDs = try allInputDeviceIDs()
        var items: [Entry] = []
        items.reserveCapacity(inputDeviceIDs.count)

        for deviceID in inputDeviceIDs {
            let name = readStringProperty(
                deviceID: deviceID,
                selector: kAudioObjectPropertyName,
                scope: kAudioObjectPropertyScopeGlobal
            )
            let uid = readStringProperty(
                deviceID: deviceID,
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            )

            guard let name, let uid else {
                continue
            }

            items.append(
                .init(
                    deviceID: deviceID,
                    device: .init(
                        id: uid,
                        name: name,
                        isDefault: deviceID == defaultInputDeviceID
                    )
                )
            )
        }

        return items.sorted {
            $0.device.name.localizedCaseInsensitiveCompare($1.device.name) == .orderedAscending
        }
    }

    private static func allInputDeviceIDs() throws -> [AudioDeviceID] {
        let allDevices = try allDeviceIDs()
        return allDevices.filter(hasInputStreams(deviceID:))
    }

    private static func allDeviceIDs() throws -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else {
            throw AudioCaptureError.failedToEnumerateInputDevices(status)
        }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else {
            throw AudioCaptureError.failedToEnumerateInputDevices(status)
        }

        return deviceIDs
    }

    private static func defaultInputDeviceID() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr else {
            throw AudioCaptureError.failedToEnumerateInputDevices(status)
        }
        return deviceID
    }

    private static func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private static func readStringProperty(
        deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var unmanagedValue: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &unmanagedValue
        )
        guard status == noErr, let unmanagedValue else {
            return nil
        }
        return unmanagedValue.takeUnretainedValue() as String
    }
}
#endif
