import Testing
@testable import DictationAppCore

struct AudioInputDeviceSelectorTests {
    @Test
    func resolveReturnsNilWhenNoPreferenceProvided() throws {
        let devices = [
            AudioInputDevice(id: "uid-default", name: "MacBook Pro Microphone", isDefault: true)
        ]

        let resolved = try AudioInputDeviceSelector.resolve(
            preferredInputDevice: nil,
            availableDevices: devices
        )

        #expect(resolved == nil)
    }

    @Test
    func resolveMatchesByUIDFirst() throws {
        let devices = [
            AudioInputDevice(id: "uid-default", name: "MacBook Pro Microphone", isDefault: true),
            AudioInputDevice(id: "uid-headset", name: "USB Headset", isDefault: false)
        ]

        let resolved = try AudioInputDeviceSelector.resolve(
            preferredInputDevice: "uid-headset",
            availableDevices: devices
        )

        #expect(resolved?.id == "uid-headset")
    }

    @Test
    func resolveMatchesByCaseInsensitiveName() throws {
        let devices = [
            AudioInputDevice(id: "uid-default", name: "MacBook Pro Microphone", isDefault: true),
            AudioInputDevice(id: "uid-headset", name: "USB Headset", isDefault: false)
        ]

        let resolved = try AudioInputDeviceSelector.resolve(
            preferredInputDevice: "usb headset",
            availableDevices: devices
        )

        #expect(resolved?.id == "uid-headset")
    }

    @Test
    func resolveThrowsWhenDeviceIsUnknown() {
        let devices = [
            AudioInputDevice(id: "uid-default", name: "MacBook Pro Microphone", isDefault: true)
        ]

        #expect(throws: AudioCaptureError.inputDeviceNotFound("missing")) {
            try AudioInputDeviceSelector.resolve(
                preferredInputDevice: "missing",
                availableDevices: devices
            )
        }
    }
}
