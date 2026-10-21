//
//  PHNTMApp.swift
//  PHNTM
//
//  Created by Arseny Smorodin on 20.10.2026.
//

import SwiftUI

@main
struct PHNTMApp: App {

    @StateObject private var appStatus: AppStatusStore
    @StateObject private var appController: AppController

    init() {
        let appStatus = AppStatusStore()
        _appStatus = StateObject(wrappedValue: appStatus)
        _appController = StateObject(
            wrappedValue: AppController(appStatus: appStatus)
        )
    }

    var body: some Scene {
        Window("PHNTM", id: "main") {
            ContentView()
                .environmentObject(appController)
        }
        .defaultSize(width: 608, height: 660)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarStatusView()
                .environmentObject(appStatus)
                .environmentObject(appController)
        } label: {
            Image(systemName: appStatus.status.symbolName)
                .accessibilityLabel(appStatus.status.title)
                .help(appStatus.status.title)
        }
        .menuBarExtraStyle(.menu)
    }
}
