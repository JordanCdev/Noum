// FirebaseBootstrap.swift
// Centralized Firebase setup: App Check, Core, Auth (anonymous), Remote Config defaults

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif

public enum FirebaseBootstrap {
    /// Configure Firebase services as early as possible (e.g., in App.init())
    public static func configure() {
        #if canImport(FirebaseCore)
        guard hasConfigurationPlist else { return }
        #else
        return
        #endif

        #if canImport(FirebaseAppCheck)
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #endif
        #endif

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        guard shouldStartOptionalServices(
            configurationPresent: true,
            configured: FirebaseApp.app() != nil
        ) else { return }
        #endif

        #if canImport(FirebaseAuth)
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error = error {
                    print("[FirebaseBootstrap] Anonymous sign-in error: \(error)")
                } else if let uid = result?.user.uid {
                    print("[FirebaseBootstrap] Signed in anonymously as \(uid)")
                }
            }
        }
        #endif

        #if canImport(FirebaseRemoteConfig)
        let rc = RemoteConfig.remoteConfig()
        let defaults: [String: NSObject] = [
            "ai_model": "gemini-2.5-flash" as NSString,
            "ai_system_prompt": "You are a helpful NPC coach. Keep replies concise." as NSString,
            "ai_stream_url": "" as NSString
        ]
        rc.setDefaults(defaults)
        rc.fetchAndActivate { status, error in
            if let error = error {
                print("[FirebaseBootstrap] Remote Config fetch error: \(error)")
            } else {
                print("[FirebaseBootstrap] Remote Config status: \(status.rawValue)")
            }
        }
        #endif
    }

    static var hasConfigurationPlist: Bool {
        Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    static func shouldStartOptionalServices(configurationPresent: Bool, configured: Bool) -> Bool {
        configurationPresent && configured
    }
}
