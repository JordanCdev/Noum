// FirebaseBootstrap.swift
// Centralized Firebase setup: App Check, Core, and Remote Config defaults

import Foundation
import OSLog

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif
#if canImport(DeviceCheck)
import DeviceCheck
#endif
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

public enum FirebaseBootstrap {
    /// A process-local readiness edge for Test B only. Remote Config defaults
    /// are installed synchronously, but `fetchAndActivate` completes later.
    /// NoumApp observes this edge to retry Review assignment against the newly
    /// active snapshot without disturbing the route-frozen activation test.
    static let reviewRemoteConfigActivationDidComplete = Notification.Name(
        "noum.reviewRemoteConfigActivationDidComplete"
    )

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Noum",
        category: "FirebaseBootstrap"
    )

    /// Configure Firebase services as early as possible (e.g., in App.init())
    public static func configure() {
        #if canImport(FirebaseCore)
        guard hasConfigurationPlist else { return }
        #else
        return
        #endif

        // Unit-test hosts do not have an app keychain entitlement and should
        // not exchange App Check tokens or start optional network services.
        // Keep Firebase Core configured so tests that touch Firebase-backed
        // types still see a valid default app. UI automation launches the real
        // app separately with `UI_TESTING`, so it continues through production
        // bootstrap below.
        #if canImport(FirebaseCore)
        let process = ProcessInfo.processInfo
        let isUnitTestHost = process.environment["XCTestConfigurationFilePath"] != nil
            && !process.arguments.contains("UI_TESTING")
        if isUnitTestHost {
            _ = unitTestCoreReady
            return
        }
        #endif

        _ = runtimeServicesReady
    }

    /// Both the SwiftUI stored-property path and the UIKit delegate call
    /// `configure()`. A static-let initializer is process-wide and thread-safe,
    /// so App Check and Remote Config start exactly once without mutable flags.
    #if canImport(FirebaseCore)
    private static let unitTestCoreReady: Void = {
        FirebaseApp.configure()
    }()
    #endif

    private static let runtimeServicesReady: Void = {
        #if canImport(FirebaseAppCheck)
        #if DEBUG || targetEnvironment(simulator)
        // DeviceCheck/App Attest are not available in Simulator, including a
        // Release-configuration simulator build. Keep production attestation
        // on physical devices while making local verification use Firebase's
        // explicit debug-provider flow.
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(NoumAppCheckProviderFactory())
        #endif
        #endif

        #if canImport(FirebaseCore)
        // Do not use the default-app accessor as a readiness probe before
        // setup: Firebase logs I-COR000003 whenever it returns nil. This
        // process-wide initializer is the configuration guard, so configure
        // the default app exactly once and treat successful return as ready.
        FirebaseApp.configure()
        guard shouldStartOptionalServices(
            configurationPresent: true,
            configured: true
        ) else { return }
        #endif

        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        let defaults: [String: NSObject] = [
            "ai_stream_url": "" as NSString,
            ActivationExperimentContract.remoteConfigKey: "" as NSString,
            ReviewExperimentContract.remoteConfigKey: "" as NSString,
        ]
        rc.setDefaults(defaults)
        rc.fetchAndActivate { status, error in
            if let error = error {
                Self.log.error("Remote Config fetch failed: \(error.localizedDescription, privacy: .private)")
            } else {
                Self.log.info("Remote Config status: \(status.rawValue, privacy: .public)")
            }
            Self.signalReviewRemoteConfigActivationCompleted()
        }
        #endif
    }()

    /// Injecting a center keeps the signal directly verifiable without
    /// starting Firebase or network services in the unit-test host.
    static func signalReviewRemoteConfigActivationCompleted(
        using center: NotificationCenter = .default
    ) {
        center.post(name: reviewRemoteConfigActivationDidComplete, object: nil)
    }

    static var hasConfigurationPlist: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    static func shouldStartOptionalServices(configurationPresent: Bool, configured: Bool) -> Bool {
        configurationPresent && configured
    }
}

#if canImport(FirebaseAppCheck) && !DEBUG
/// App Attest is the production default on supported Apple hardware. Device
/// Check remains the compatibility fallback; neither path relies on a client
/// secret. The factory must be installed before `FirebaseApp.configure()`.
private final class NoumAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if targetEnvironment(simulator)
        return DeviceCheckProvider(app: app)
        #else
        #if canImport(DeviceCheck)
        if DCAppAttestService.shared.isSupported {
            return AppAttestProvider(app: app)
        }
        #endif
        return DeviceCheckProvider(app: app)
        #endif
    }
}
#endif
