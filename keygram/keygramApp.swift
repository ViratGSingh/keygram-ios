//
//  keygramApp.swift
//  keygram
//
//  Created by Virat Singh on 03/05/26.
//

import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct keygramApp: App {
    init() {
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        #if canImport(GoogleSignIn) && canImport(FirebaseCore)
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Firebase is configured by now; reflect any persisted session.
                    AuthManager.shared.refreshFromFirebase()
                }
                #if canImport(GoogleSignIn)
                .onOpenURL { url in
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
                #endif
        }
    }
}
