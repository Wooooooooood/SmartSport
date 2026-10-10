import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("userGender") private var userGender = ""
    @State private var selected = ""
    
    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.1).ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                Text("👋").font(.system(size: 60))
                Text("欢迎使用\n恢复教练")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("为了让评分和推荐更准确\n请先选择你的生理性别")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    GenderCard(emoji: "👨", title: "男性", subtitle: "标准评分模型", isSelected: selected == "male") {
                        selected = "male"
                    }
                    GenderCard(emoji: "👩", title: "女性", subtitle: "含经期周期追踪", isSelected: selected == "female") {
                        selected = "female"
                    }
                }
                .padding(.horizontal, 30)
                
                if selected == "female" {
                    Text("将额外读取经期数据，评分会随生理周期智能调整")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0, green: 0.83, blue: 0.67))
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                Button {
                    userGender = selected
                    hasOnboarded = true
                } label: {
                    Text("开始使用")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(selected.isEmpty ? .gray : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selected.isEmpty ? Color.white.opacity(0.1) : Color(red: 0, green: 0.83, blue: 0.67))
                        .cornerRadius(14)
                }
                .disabled(selected.isEmpty)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

struct GenderCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(emoji).font(.system(size: 40))
                Text(title).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(isSelected ? Color(red: 0, green: 0.83, blue: 0.67).opacity(0.15) : Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(red: 0, green: 0.83, blue: 0.67) : Color.clear, lineWidth: 2)
            )
            .cornerRadius(16)
        }
    }
}

#Preview {
    OnboardingView()
}
