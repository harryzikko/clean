import SwiftUI

@main
struct CleanSpaceApp: App {
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label("Tổng quan", systemImage: "sparkles")
                    }
                
                SwipeCleanView(viewModel: dashboardViewModel)
                    .tabItem {
                        Label("Vuốt dọn", systemImage: "hand.draw.fill")
                    }
                
                NavigationStack {
                    VideoCompressorView()
                }
                .tabItem {
                    Label("Nén video", systemImage: "arrow.down.right.and.arrow.up.left")
                }
                
                SecretVaultView()
                    .tabItem {
                        Label("Kho bảo mật", systemImage: "lock.shield.fill")
                    }
                
                NavigationStack {
                    PaywallView()
                }
                .tabItem {
                    Label("PRO", systemImage: "crown.fill")
                }
            }
            .tint(.blue)
            .environmentObject(subscriptionManager)
        }
    }
}
