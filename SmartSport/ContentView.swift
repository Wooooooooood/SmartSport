import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var selectedTab = 0
    
    var body: some View {
        if hasOnboarded {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem {
                        Image(systemName: "chart.bar.fill")
                        Text("今日")
                    }
                    .tag(0)
                
                DataView()
                    .tabItem {
                        Image(systemName: "heart.text.square.fill")
                        Text("数据")
                    }
                    .tag(1)
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                        Text("设置")
                    }
                    .tag(2)
            }
            .accentColor(Color(red: 0, green: 0.83, blue: 0.67))
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
