//
//  Naufalp5App.swift
//  Naufalp5
//
//  Created by Naufal Adli on 21/04/25.
//

import SwiftUI
import GoogleMaps
@main
struct Naufalp5App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GMSServices.provideAPIKey("ISI_API_KEY_KAMU_DI SINI")
        return true
    }
}
