//
//  ContentView.swift
//  WorkSurvivalGuide
//
//  主 TabView，带登录检查
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some View {
        Group {
            if authManager.isLoggedIn {
                TabView {
                    TaskListView()
                        .tabItem {
                            Label("任务", systemImage: "list.bullet")
                        }
                    
                    Text("状态")
                        .tabItem {
                            Label("状态", systemImage: "person.fill")
                        }
                    
                    Text("档案")
                        .tabItem {
                            Label("档案", systemImage: "folder.fill")
                        }
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            authManager.checkLoginStatus()
        }
    }
}

