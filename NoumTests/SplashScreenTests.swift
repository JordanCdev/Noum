import Foundation
import Testing
@testable import Noum

@Suite("Splash launch policy")
struct SplashLaunchPolicyTests {
    @Test("Normal launches present the splash")
    func normalLaunchPresents() {
        #expect(SplashLaunchPolicy.shouldPresent(arguments: []))
    }

    @Test("Existing UI automation bypass remains immediate")
    func uiTestingSkips() {
        #expect(
            !SplashLaunchPolicy.shouldPresent(
                arguments: [SplashLaunchPolicy.uiTestingArgument]
            )
        )
    }

    @Test("Focused splash automation can opt back in")
    func splashUITestOptsIn() {
        #expect(
            SplashLaunchPolicy.shouldPresent(
                arguments: [
                    SplashLaunchPolicy.uiTestingArgument,
                    SplashLaunchPolicy.uiTestingOptInArgument,
                ]
            )
        )
    }
}

@Suite("Splash motion contract")
struct SplashTimelineTests {
    @Test("Milestones are ordered and launch remains bounded")
    func orderedBoundedTimeline() {
        #expect(SplashTimeline.orderedMilestones == SplashTimeline.orderedMilestones.sorted())
        #expect(SplashTimeline.completion == 5.25)
        #expect(SplashTimeline.completion <= 5.50)
        #expect(SplashTimeline.reducedMotionCompletion < SplashTimeline.completion)
        #expect(SplashTimeline.pairTransition >= 0.50)
        #expect(SplashTimeline.takeoverTransition >= 1.00)
        #expect(SplashTimeline.wordmarkTransition >= 0.60)
        #expect(SplashTimeline.homeTransition >= 0.35)
    }

    @Test("The camera enters the conversation and Reduce Motion stays still")
    func motionAllowances() {
        #expect(SplashTimeline.cameraScale(reduceMotion: false) == 5.20)
        #expect(SplashTimeline.cameraScale(reduceMotion: true) == 1)
        #expect(SplashTimeline.mouthTransition <= 0.22)
        #expect(SplashTimeline.conversationFocus.x < 0.5)
        #expect(SplashTimeline.conversationFocus.y < 0.5)
    }

    @Test("Native launch screen stays white in every appearance")
    func launchScreenUsesFixedWhiteAsset() throws {
        let launchScreen = try #require(
            Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen")
                as? [String: Any]
        )

        #expect(launchScreen["UIColorName"] as? String == "LaunchBackground")
    }

    @Test("Bundled Lottie mirrors the authored timeline")
    func lottieAssetContract() throws {
        let url = try #require(
            Bundle.main.url(
                forResource: "noum-splash-conversation",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: url)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let layers = try #require(object["layers"] as? [[String: Any]])
        let assets = try #require(object["assets"] as? [[String: Any]])
        let names = Set(layers.compactMap { $0["nm"] as? String })

        #expect(object["fr"] as? Int == 60)
        #expect(object["op"] as? Int == 315)
        #expect(assets.isEmpty)
        #expect(names.contains("background.white"))
        #expect(names.contains("takeover.conversation-gradient"))
        #expect(names.contains("bubble.orange"))
        #expect(names.contains("bubble.yellow"))
        #expect(names.contains("wordmark.noum"))

        let bubbleLayers = layers.filter { layer in
            guard let name = layer["nm"] as? String else { return false }
            return name == "bubble.orange" || name == "bubble.yellow"
        }

        #expect(bubbleLayers.count == 2)
        #expect(bubbleLayers.allSatisfy { containsShapeType("sh", in: $0) })
        #expect(bubbleLayers.allSatisfy { containsShapeType("gf", in: $0) })
        #expect(bubbleLayers.allSatisfy { !containsShapeType("rc", in: $0) })
        #expect(bubbleLayers.allSatisfy { layerHasAnimatedTransformProperty("p", in: $0) })
        #expect(bubbleLayers.allSatisfy { layerHasAnimatedTransformProperty("s", in: $0) })

        let blendedField = try #require(
            layers.first { $0["nm"] as? String == "takeover.conversation-gradient" }
        )
        #expect(containsShapeType("gf", in: blendedField))

        let orangeLayer = try #require(
            bubbleLayers.first { $0["nm"] as? String == "bubble.orange" }
        )
        #expect(containsAnimatedShape(named: "Rear speaking mouth", in: orangeLayer))

        let yellowLayer = try #require(
            bubbleLayers.first { $0["nm"] as? String == "bubble.yellow" }
        )
        #expect(containsName("Front app-icon shadow", in: yellowLayer))
        #expect(containsAnimatedShape(named: "Speaking mouth silhouette", in: yellowLayer))

        let wordmark = try #require(
            layers.first { $0["nm"] as? String == "wordmark.noum" }
        )
        let text = try #require(wordmark["t"] as? [String: Any])
        let document = try #require(text["d"] as? [String: Any])
        let keyframes = try #require(document["k"] as? [[String: Any]])
        let firstKeyframe = try #require(keyframes.first)
        let style = try #require(firstKeyframe["s"] as? [String: Any])
        #expect(style["t"] as? String == "noum")
        #expect(style["f"] as? String == "Figtree-ExtraBold")
        #expect(style["s"] as? Int == 120)
        #expect(layerHasAnimatedTransformProperty("s", in: wordmark))
    }

    private func containsShapeType(_ type: String, in value: Any) -> Bool {
        if let object = value as? [String: Any] {
            if object["ty"] as? String == type {
                return true
            }
            return object.values.contains { containsShapeType(type, in: $0) }
        }

        if let array = value as? [Any] {
            return array.contains { containsShapeType(type, in: $0) }
        }

        return false
    }

    private func containsName(_ name: String, in value: Any) -> Bool {
        if let object = value as? [String: Any] {
            if object["nm"] as? String == name {
                return true
            }
            return object.values.contains { containsName(name, in: $0) }
        }

        if let array = value as? [Any] {
            return array.contains { containsName(name, in: $0) }
        }

        return false
    }

    private func containsAnimatedShape(named name: String, in value: Any) -> Bool {
        if let object = value as? [String: Any] {
            if object["nm"] as? String == name,
               let keyframes = object["ks"] as? [String: Any],
               keyframes["a"] as? Int == 1 {
                return true
            }
            return object.values.contains { containsAnimatedShape(named: name, in: $0) }
        }

        if let array = value as? [Any] {
            return array.contains { containsAnimatedShape(named: name, in: $0) }
        }

        return false
    }

    private func layerHasAnimatedTransformProperty(
        _ property: String,
        in layer: [String: Any]
    ) -> Bool {
        guard let transform = layer["ks"] as? [String: Any],
              let value = transform[property] as? [String: Any] else {
            return false
        }
        return value["a"] as? Int == 1
    }
}
