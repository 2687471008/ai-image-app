import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: AppConfig
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                GenerateView()
                    .tag(0)
                
                HistoryView()
                    .tag(1)
                
                SettingsView()
                    .tag(2)
            }
            .ignoresSafeArea(.keyboard)
            
            // 自定义底部导航栏
            HStack(spacing: 0) {
                TabButton(
                    icon: "sparkle.magic",
                    title: "生成",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                TabButton(
                    icon: "photo.on.rectangle",
                    title: "历史",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                TabButton(
                    icon: "gearshape.fill",
                    title: "设置",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 30)
            )
            .padding(.horizontal, 30)
            .padding(.bottom, 8)
        }
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .symbolEffect(.bounce, value: isSelected)
                Text(title)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }
}
