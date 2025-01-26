//
//  MLCChatApp.swift
//  MLCChat
//
//  Created by Tianqi Chen on 4/26/23.
//

import SwiftUI

@main
struct MLCChatApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var chatStorage = ChatStorage()

    init() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().tableFooterView = UIView()
    }

    var body: some Scene {
        WindowGroup {
            LandingPage()
                .environmentObject(appState)
                .environmentObject(chatStorage)
                .environmentObject(appState.chatState)
                .task {
                    appState.loadAppConfigAndModels()
                }
        }
    }
}
