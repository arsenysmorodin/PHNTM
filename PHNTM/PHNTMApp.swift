//
//  PHNTMApp.swift
//  PHNTM
//
//  Created by Arseny Smorodin on 20.10.2026.
//

import SwiftUI

@main
struct PHNTMApp: App {

    @StateObject private var appStatus = AppStatusStore()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appStatus)
        }

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(appStatus)
        } label: {
            Image(systemName: appStatus.status.symbolName)
                .accessibilityLabel(appStatus.status.title)
                .help(appStatus.status.title)
        }
        .menuBarExtraStyle(.menu)
    }
}
