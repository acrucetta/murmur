import Testing
@testable import DictationAppCore

#if canImport(AppKit)
import AppKit
#endif

struct FeedbackSoundAssetTests {
    @Test
    func feedbackSoundResourcesExistInBundle() {
        for asset in FeedbackSoundAsset.allCases {
            #expect(asset.resourceURL != nil)
        }
    }

    #if canImport(AppKit)
    @Test
    @MainActor
    func feedbackSoundResourcesLoadAsNSSound() {
        for asset in FeedbackSoundAsset.allCases {
            guard let url = asset.resourceURL else {
                Issue.record("missing URL for \(asset.rawValue)")
                continue
            }
            #expect(NSSound(contentsOf: url, byReference: true) != nil)
        }
    }
    #endif
}
