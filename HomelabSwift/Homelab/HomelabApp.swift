import SwiftUI
#if canImport(UIKit)
import UIKit

/// Lets OpenList player force landscape / portrait while open.
final class HomelabAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        MainActor.assumeIsolated {
            OpenListOrientationLock.mask
        }
    }
}
#endif

@main
struct HomelabApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(HomelabAppDelegate.self) private var appDelegate
    #endif
    @State private var servicesStore = ServicesStore()
    @State private var settingsStore = SettingsStore()
    @State private var localizer = Localizer()
    @State private var isUnlocked = false
    @State private var needsSetup = false
    @Environment(\.scenePhase) private var scenePhase

    private var colorScheme: ColorScheme? {
        switch settingsStore.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if needsSetup {
                    PinSetupView {
                        needsSetup = false
                        isUnlocked = true
                    }
                } else if settingsStore.isPinSet && !isUnlocked {
                    LockScreenView {
                        isUnlocked = true
                    }
                } else if !servicesStore.isReady {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                    }
                } else {
                    ContentView()
                }
            }
            .environment(servicesStore)
            .environment(settingsStore)
            .environment(localizer)
            .preferredColorScheme(colorScheme)
            .task {
                // Force LogStore init so homelab-debug.log exists for agent pull
                // (simctl / My Mac Designed for iPad host mirror).
                _ = LogStore.shared
                let paths = LogStore.shared.logFilePathsDescription()
                AppLogger.shared.info(
                    "App launched isiOSAppOnMac=\(ProcessInfo.processInfo.isiOSAppOnMac) logs:\n\(paths)",
                    source: "App"
                )
                settingsStore.syncAppIconWithSystem()
                localizer.language = settingsStore.language
                needsSetup = !settingsStore.hasCompletedOnboarding
                if needsSetup {
                    isUnlocked = false
                }
                await servicesStore.initialize()
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    servicesStore.stopPeriodicHealthChecks()
                    if settingsStore.isPinSet {
                        settingsStore.lastBackgroundDate = Date()
                    }
                case .active:
                    servicesStore.startPeriodicHealthChecks()
                    Task { await servicesStore.checkAllReachability() }
                    if settingsStore.isPinSet {
                        if let bg = settingsStore.lastBackgroundDate {
                            let elapsed = Date().timeIntervalSince(bg)
                            if elapsed > 60 {
                                isUnlocked = false
                            }
                        } else if !isUnlocked {
                            // First launch or killed: stay locked
                            isUnlocked = false
                        }
                        settingsStore.lastBackgroundDate = nil
                    }
                default:
                    break
                }
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 430, height: 932)
    }
}
