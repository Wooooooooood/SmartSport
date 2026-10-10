import SwiftUI

struct TodayView: View {

    @State private var result: RecoveryResult?
    @State private var loadFailed = false
    @State private var showQuickUpdate = false
    @AppStorage("userGender") private var gender = "male"

    private var isFemale: Bool { gender == "female" }
    private var profile: UserProfile { UserProfile() }
    private let accent = Color(red: 0, green: 0.83, blue: 0.67)

    var body: some View {
        Group {
            if let result = result {
                mainContent(result)
            } else if loadFailed {
                failureContent
            } else {
                loadingContent
            }
        }
        .onAppear {
            if result == nil { loadData() }
        }
        .sheet(isPresented: $showQuickUpdate, onDismiss: {
            refresh()
        }) {
            QuickUpdateSheet()
        }
    }

    private func refresh() {
        result = nil
        loadFailed = false
        loadData()
    }

    private var loadingContent: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在读取健康数据…")
                .foregroundColor(.secondary)
        }
    }

    private var failureContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            Text("健康数据读取失败")
                .font(.title3)
                .fontWeight(.semibold)
            Text("请检查是否已允许本 App 访问健康数据\n（设置 → 健康 → 数据访问与设备）")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(action: refresh) {
                Text("重新加载")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(accent)
                    .cornerRadius(20)
            }
        }
        .padding()
    }

    private func mainContent(_ r: RecoveryResult) -> some View {
        ScrollView {
            VStack(spacing: 16) {

                HStack {
                    Text("今日恢复报告")
                        .font(.headline)
                    Spacer()
                    Button(action: refresh) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新数据")
                        }
                        .font(.subheadline)
                        .foregroundColor(accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accent.opacity(0.15))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if profile.needsWeeklyUpdate {
                    Button(action: { showQuickUpdate = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text(profile.lastUpdated == nil ? "还没有身体数据，点这里填写" : "身体数据已 \(profile.daysSinceUpdate) 天未更新，点这里快速更新")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }

                scoreRing(r)
                recommendationCard(r)

                if let cycle = r.cycleInfo {
                    cycleCard(cycle)
                }

                HStack(spacing: 10) {
                    TodayStatBox(title: "今日已消耗", value: "\(Int(r.todayCalories))", unit: "千卡")
                    TodayStatBox(title: "今日已活动", value: "\(Int(r.todayExerciseMinutes))", unit: "分钟")
                    TodayStatBox(title: "目标完成", value: "\(targetPercent(r))", unit: "%")
                }
                .padding(.horizontal)

                detailPanel(r)

                if !r.warnings.isEmpty {
                    warningsPanel(r)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            refresh()
        }
    }

    private func targetPercent(_ r: RecoveryResult) -> Int {
        guard r.calorieTarget > 0 else { return 0 }
        return Int(r.todayCalories / r.calorieTarget * 100)
    }

    private func scoreRing(_ r: RecoveryResult) -> some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 14)
            Circle()
                .trim(from: 0, to: Double(r.totalScore) / 100)
                .stroke(scoreColor(r.totalScore), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(r.totalScore)")
                    .font(.system(size: 48, weight: .bold))
                Text("恢复评分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .padding(.vertical, 8)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 85 { return accent }
        if score >= 70 { return .green }
        if score >= 55 { return .orange }
        return .red
    }

    private func recommendationCard(_ r: RecoveryResult) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.run")
                .foregroundColor(accent)
            Text(r.recommendation)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(accent.opacity(0.12))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func cycleCard(_ cycle: CycleInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "moonphase.first.quarter")
                .foregroundColor(.pink)
            VStack(alignment: .leading, spacing: 4) {
                Text("生理周期：第 \(cycle.cycleDay) 天 · \(cycle.phase.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(cycleAdvice(cycle))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color.pink.opacity(0.12))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func cycleAdvice(_ cycle: CycleInfo) -> String {
        switch cycle.phase {
        case .menstrual: return "经期注意保暖休息，平均周期 \(cycle.avgCycleLength) 天"
        case .follicular: return "卵泡期状态回升，适合安排训练，平均周期 \(cycle.avgCycleLength) 天"
        case .ovulation: return "排卵期状态最佳，可以进行高质量训练"
        case .luteal: return "黄体期评分标准已自动放宽，注意情绪波动"
        case .unknown: return "已超过平均周期长度，如月经推迟请注意身体状况"
        }
    }

    private func detailPanel(_ r: RecoveryResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("评分明细")
                .font(.headline)
            InfoLine(title: "HRV 评分（权重30%）", value: "\(r.hrvScore) 分")
            InfoLine(title: "静息心率评分（权重25%）", value: "\(r.rhrScore) 分")
            InfoLine(title: "睡眠与负荷评分（权重30%）", value: "\(r.sleepLoadScore) 分")
            InfoLine(title: "基础指标评分（权重15%）", value: "\(r.baselineScore) 分")
            Divider()
            InfoLine(title: "今日 HRV", value: r.todayHRV > 0 ? String(format: "%.0f ms（基线 %.0f）", r.todayHRV, r.hrvBaseline) : "无数据")
            InfoLine(title: "今日静息心率", value: r.todayRHR > 0 ? String(format: "%.0f 次/分（基线 %.0f）", r.todayRHR, r.rhrBaseline) : "无数据")
            InfoLine(title: "血氧", value: r.spo2 > 0 ? String(format: "%.0f%%", r.spo2) : "无数据")
            InfoLine(title: "呼吸频率", value: r.respiratoryRate > 0 ? String(format: "%.1f 次/分", r.respiratoryRate) : "无数据")
            InfoLine(title: "近7天睡眠负债", value: String(format: "%.1f 小时", r.sleepDebt))
            InfoLine(title: "静息心率7天趋势", value: String(format: "%+.2f 次/天", r.rhrTrend))
            InfoLine(title: "连续运动", value: "\(r.consecutiveDays) 天")
            InfoLine(title: "BMI", value: r.bmi > 0 ? String(format: "%.1f（%@）", r.bmi, r.bmiCategory) : "未填写")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func warningsPanel(_ r: RecoveryResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("注意事项")
                .font(.headline)
            ForEach(r.warnings, id: \.self) { warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func loadData() {
        let hk = HealthKitManager.shared
        hk.requestAuthorization(isFemale: isFemale) { ok in
            guard ok else {
                DispatchQueue.main.async { loadFailed = true }
                return
            }

            var hrvHistory: [Date: Double] = [:]
            var rhrHistory: [Date: Double] = [:]
            var sleepHistory: [Date: Double] = [:]
            var oxygenHistory: [Date: Double] = [:]
            var respiratoryHistory: [Date: Double] = [:]
            var energyHistory: [Date: Double] = [:]
            var menstrualDays: Set<Date> = []
            var todayCalories = 0.0
            var todayMinutes = 0.0

            let group = DispatchGroup()

            group.enter()
            hk.fetchHRVHistory(days: 30) { data in hrvHistory = data; group.leave() }

            group.enter()
            hk.fetchRHRHistory(days: 30) { data in rhrHistory = data; group.leave() }

            group.enter()
            hk.fetchSleepHistory(days: 7) { data in sleepHistory = data; group.leave() }

            group.enter()
            hk.fetchOxygenHistory(days: 7) { data in oxygenHistory = data; group.leave() }

            group.enter()
            hk.fetchRespiratoryHistory(days: 7) { data in respiratoryHistory = data; group.leave() }

            group.enter()
            hk.fetchEnergyHistory(days: 14) { data in energyHistory = data; group.leave() }

            group.enter()
            hk.fetchTodayEnergy { value in todayCalories = value; group.leave() }

            group.enter()
            hk.fetchTodayExerciseMinutes { value in todayMinutes = value; group.leave() }

            if isFemale {
                group.enter()
                hk.fetchMenstrualDays { days in menstrualDays = days; group.leave() }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                if result == nil && !loadFailed {
                    loadFailed = true
                }
            }

            group.notify(queue: .main) {
                result = RecoveryEngine().evaluate(
                    hrvHistory: hrvHistory,
                    rhrHistory: rhrHistory,
                    sleepHistory: sleepHistory,
                    oxygenHistory: oxygenHistory,
                    respiratoryHistory: respiratoryHistory,
                    energyHistory: energyHistory,
                    menstrualDays: menstrualDays,
                    todayCalories: todayCalories,
                    todayExerciseMinutes: todayMinutes,
                    profile: UserProfile()
                )
            }
        }
    }
}

// MARK: - 今日数据小卡片
struct TodayStatBox: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 明细行
struct InfoLine: View {
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
        .font(.subheadline)
    }
}

// MARK: - 快速更新身体数据弹窗
struct QuickUpdateSheet: View {

    @Environment(\.dismiss) private var dismiss
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var muscle = ""
    @State private var bone = ""

    private let accent = Color(red: 0, green: 0.83, blue: 0.67)

    var body: some View {
        NavigationView {
            VStack(spacing: 14) {
                Text("更新本周身体数据")
                    .font(.headline)
                    .padding(.top, 20)

                inputRow(title: "体重", unit: "kg", text: $weight)
                inputRow(title: "体脂率", unit: "%", text: $bodyFat)
                inputRow(title: "肌肉量", unit: "kg", text: $muscle)
                inputRow(title: "骨盐量", unit: "kg", text: $bone)

                Button(action: save) {
                    Text("保存")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 6)

                Spacer()
            }
            .onAppear {
                let p = UserProfile()
                if p.weight > 0 { weight = String(format: "%.1f", p.weight) }
                if p.bodyFat > 0 { bodyFat = String(format: "%.1f", p.bodyFat) }
                if p.muscle > 0 { muscle = String(format: "%.1f", p.muscle) }
                if p.bone > 0 { bone = String(format: "%.2f", p.bone) }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func inputRow(title: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("输入数值", text: text)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            Text(unit)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func save() {
        let d = UserDefaults.standard
        if let v = Double(weight) { d.set(v, forKey: "profileWeight") }
        if let v = Double(bodyFat) { d.set(v, forKey: "profileBodyFat") }
        if let v = Double(muscle) { d.set(v, forKey: "profileMuscle") }
        if let v = Double(bone) { d.set(v, forKey: "profileBone") }
        UserProfile.saveSnapshot()
        dismiss()
    }
}
