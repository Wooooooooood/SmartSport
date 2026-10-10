import SwiftUI

struct SettingsView: View {

    @AppStorage("userGender") private var gender = "male"
    @State private var height = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var bmr = ""
    @State private var muscle = ""
    @State private var bone = ""
    @State private var preferredExercises: Set<String> = []
    @State private var detectedExercises: [String] = []
    @State private var trainingGoal = "health"
    @State private var showSaveAlert = false
    @State private var savedProfile = UserProfile()

    private let accent = Color(red: 0, green: 0.83, blue: 0.67)
    private let exerciseOptions = ["跑步", "游泳", "骑行", "快走/散步", "徒步", "力量训练", "高强度间歇训练", "瑜伽/拉伸", "普拉提", "舞蹈", "太极", "球类运动", "划船机", "椭圆机", "爬楼梯/踏步机", "滑雪", "跳绳", "整理放松"]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 18) {

                    statusCard

                    SettingSection(title: "性别") {
                        HStack(spacing: 12) {
                            GenderButton(title: "男生", icon: "figure.stand", isSelected: gender == "male") {
                                gender = "male"
                            }
                            GenderButton(title: "女生", icon: "figure.stand.dress", isSelected: gender == "female") {
                                gender = "female"
                            }
                        }
                    }

                    SettingSection(title: "训练目标") {
                        HStack(spacing: 10) {
                            goalButton(title: "减脂", value: "lose", icon: "flame.fill")
                            goalButton(title: "增肌", value: "muscle", icon: "dumbbell.fill")
                            goalButton(title: "保持健康", value: "health", icon: "heart.fill")
                        }
                        Text(goalDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    SettingSection(title: "运动偏好（多选，推荐从这里挑）") {
                        if !detectedExercises.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "applewatch")
                                    .foregroundColor(accent)
                                Text("已从手表读取到你练过：\(detectedExercises.joined(separator: "、"))，已自动勾选")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(exerciseOptions, id: \.self) { item in
                                Button(action: { toggleExercise(item) }) {
                                    Text(item)
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(preferredExercises.contains(item) ? accent.opacity(0.2) : Color(.systemGray6))
                                        .foregroundColor(preferredExercises.contains(item) ? accent : .primary)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(preferredExercises.contains(item) ? accent : Color.clear, lineWidth: 1.5)
                                        )
                                }
                            }
                        }
                        if preferredExercises.isEmpty {
                            Text("不选择则按默认项目推荐")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    SettingSection(title: "长期数据（不常变化）") {
                        NumberInputRow(title: "身高", text: $height, unit: "cm")
                        Divider()
                        NumberInputRow(title: "年龄", text: $age, unit: "岁")
                    }

                    SettingSection(title: "每周数据（建议每周更新）") {
                        NumberInputRow(title: "体重", text: $weight, unit: "kg")
                        Divider()
                        NumberInputRow(title: "体脂率", text: $bodyFat, unit: "%")
                        Divider()
                        NumberInputRow(title: "肌肉量", text: $muscle, unit: "kg")
                        Divider()
                        NumberInputRow(title: "骨盐量", text: $bone, unit: "kg")
                        Divider()
                        NumberInputRow(title: "基础代谢率", text: $bmr, unit: "千卡（选填）")
                    }

                    SettingSection(title: "自动计算") {
                        InfoRow(title: "BMI", value: savedProfile.bmi > 0 ? String(format: "%.1f（%@）", savedProfile.bmi, savedProfile.bmiCategory) : "保存后自动计算")
                        Divider()
                        InfoRow(title: "基础代谢率", value: savedProfile.bmr > 0 ? "\(Int(savedProfile.bmr)) 千卡/天" : "保存后自动估算")
                        Divider()
                        InfoRow(title: "每日运动消耗目标", value: "\(Int(savedProfile.calorieTarget)) 千卡")
                        Divider()
                        InfoRow(title: "体脂率状态", value: savedProfile.bodyFatStatus)
                    }

                    Button(action: save) {
                        Text("保存并更新计算")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(accent)
                            .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("设置")
            .onAppear {
                loadValues()
                autoDetectExercises()
            }
            .alert("保存成功", isPresented: $showSaveAlert) {
                Button("好的", role: .cancel) { }
            } message: {
                Text("数据已保存，回到「今日」页点「刷新数据」即可用新数据重新计算")
            }
        }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: savedProfile.needsWeeklyUpdate ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(savedProfile.needsWeeklyUpdate ? .red : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(savedProfile.needsWeeklyUpdate ? "需要更新身体数据" : "身体数据是最新的")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(statusSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var statusSubtitle: String {
        if savedProfile.lastUpdated == nil { return "还没有保存过数据，请填写后点下方保存" }
        let days = savedProfile.daysSinceUpdate
        if days == 0 { return "今天已更新" }
        return "上次更新：\(days) 天前（建议每 7 天更新一次）"
    }

    private var goalDescription: String {
        switch trainingGoal {
        case "lose": return "推荐会优先安排有氧项目，时长偏长，保持燃脂心率"
        case "muscle": return "推荐会优先安排力量训练，有氧作为辅助"
        default: return "有氧和力量均衡推荐"
        }
    }

    private func goalButton(title: String, value: String, icon: String) -> some View {
        Button(action: { trainingGoal = value }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(trainingGoal == value ? accent.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(trainingGoal == value ? accent : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(trainingGoal == value ? accent : Color.clear, lineWidth: 1.5)
            )
        }
    }

    private func toggleExercise(_ item: String) {
        if preferredExercises.contains(item) {
            preferredExercises.remove(item)
        } else {
            preferredExercises.insert(item)
        }
    }

    // 先请求授权，再从手表读取近一年练过的项目并自动勾选
    private func autoDetectExercises() {
        HealthKitManager.shared.requestAuthorization(isFemale: gender == "female") { ok in
            guard ok else {
                print("❌ 设置页授权失败")
                return
            }
            HealthKitManager.shared.fetchUsedWorkoutTypes(days: 365) { types in
                DispatchQueue.main.async {
                    detectedExercises = types
                    if !types.isEmpty {
                        preferredExercises.formUnion(types)
                    }
                }
            }
        }
    }

    private func loadValues() {
        let p = UserProfile()
        if p.height > 0 { height = String(format: "%.0f", p.height) }
        if p.age > 0 { age = "\(p.age)" }
        if p.weight > 0 { weight = String(format: "%.1f", p.weight) }
        if p.bodyFat > 0 { bodyFat = String(format: "%.1f", p.bodyFat) }
        let storedBMR = UserDefaults.standard.double(forKey: "profileBMR")
        if storedBMR > 0 { bmr = String(format: "%.0f", storedBMR) }
        if p.muscle > 0 { muscle = String(format: "%.1f", p.muscle) }
        if p.bone > 0 { bone = String(format: "%.2f", p.bone) }
        preferredExercises = Set(UserDefaults.standard.stringArray(forKey: "preferredExercises") ?? [])
        trainingGoal = UserDefaults.standard.string(forKey: "trainingGoal") ?? "health"
        savedProfile = p
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(Double(height) ?? 0, forKey: "profileHeight")
        d.set(Int(age) ?? 0, forKey: "profileAge")
        d.set(Double(weight) ?? 0, forKey: "profileWeight")
        d.set(Double(bodyFat) ?? 0, forKey: "profileBodyFat")
        d.set(Double(bmr) ?? 0, forKey: "profileBMR")
        d.set(Double(muscle) ?? 0, forKey: "profileMuscle")
        d.set(Double(bone) ?? 0, forKey: "profileBone")
        d.set(Array(preferredExercises), forKey: "preferredExercises")
        d.set(trainingGoal, forKey: "trainingGoal")
        UserProfile.saveSnapshot()
        savedProfile = UserProfile()
        showSaveAlert = true
    }
}

// MARK: - 分组容器
struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            VStack(spacing: 10) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - 数字输入行
struct NumberInputRow: View {
    let title: String
    @Binding var text: String
    let unit: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("未填写", text: $text)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 性别按钮
struct GenderButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    private let accent = Color(red: 0, green: 0.83, blue: 0.67)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? accent.opacity(0.15) : Color(.systemGray6))
            .foregroundColor(isSelected ? accent : .primary)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accent : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - 信息行
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
