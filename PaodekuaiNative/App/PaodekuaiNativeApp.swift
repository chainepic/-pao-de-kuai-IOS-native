import SwiftUI

@main
struct PaodekuaiNativeApp: App {
    @StateObject private var store = GameStore()

    private let screenshotPage = ScreenshotLaunchConfiguration.page

    init() {
        ScreenshotLaunchConfiguration.apply()
    }

    var body: some Scene {
        WindowGroup {
            if !store.showWelcomeScreen {
                GameView()
                    .environmentObject(store)
                    .onAppear {
                        if screenshotPage == .game || screenshotPage == .rules {
                            store.showWelcomeScreen = false
                        }
                        store.bootstrap()
                    }
            } else {
                WelcomeView()
                    .environmentObject(store)
                    .onAppear {
                        if screenshotPage == .game || screenshotPage == .rules {
                            store.showWelcomeScreen = false
                        }
                    }
            }
        }
    }
}

private enum ScreenshotPage: String {
    case welcome
    case game
    case rules
}

private enum ScreenshotLaunchConfiguration {
    static var page: ScreenshotPage? {
        value(after: "-screenshot_page").flatMap(ScreenshotPage.init(rawValue:))
    }

    static func apply() {
        if let language = value(after: "-screenshot_language"),
           AppLanguage(rawValue: language) != nil {
            UserDefaults.standard.set(language, forKey: AppLanguage.storageKey)
        }
    }

    private static func value(after key: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}