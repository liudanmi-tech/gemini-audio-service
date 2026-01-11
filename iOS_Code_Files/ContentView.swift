import SwiftUI

struct ContentView: View {
    var body: some View {
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
    }
}


