import SwiftUI
import HealthKit
import Charts

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - 按天的折线图卡片（近7天/近30天/体重体脂用）

struct TrendChartCard: View {
    let title: String
    let points: [ChartPoint]
    let color: Color
    let unit: String
    var maxLabels: Int = 6
    var emptyText: String = "暂无数据，请佩戴 Apple Watch 并授权后重试"
    var showPointValues: Bool = false

    @State private var selected: ChartPoint? = nil

    private static let bubbleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("点图表查看每天")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if points.isEmpty {
                HStack {
                    Spacer()
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(height: 120)
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(x: .value("日期", p.date), y: .value(unit, p.value))
                            .foregroundStyle(color)
                        if showPointValues {
                            PointMark(x: .value("日期", p.date), y: .value(unit, p.value))
                                .foregroundStyle(color)
                                .annotation(position: .top, spacing: 4) {
                                    Text(p.value, format: .number.precision(.fractionLength(1)))
                                        .font(.caption2)
                                        .foregroundColor(color)
                                }
                        } else {
                            PointMark(x: .value("日期", p.date), y: .value(unit, p.value))
                                .foregroundStyle(color)
                        }
                    }
                    if let sel = selected {
                        RuleMark(x: .value("选中", sel.date))
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .top, spacing: 4,
                                        overflowResolution: .init(x: .fit, y: .disabled)) {
                                HStack(spacing: 6) {
                                    Text(sel.date, formatter: Self.bubbleFormatter)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(String(format: "%.1f%@", sel.value, unit))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                            }
                        PointMark(x: .value("选中", sel.date), y: .value("值", sel.value))
                            .foregroundStyle(color)
                            .symbolSize(120)
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    AxisMarks(values: xTicks) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                    }
                }
                .chartYScale(domain: yDomain)
                .frame(height: 180)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { v in
                                        let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let hit = points.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        selected = hit
                                        if let hit = hit {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                if selected?.id == hit.id { selected = nil }
                                            }
                                        }
                                    }
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let dates = points.map { $0.date }
        guard let minD = dates.min(), let maxD = dates.max() else {
            let today = cal.startOfDay(for: Date())
            return today...cal.date(byAdding: .day, value: 1, to: today)!
        }
        let start = cal.date(byAdding: .hour, value: -12, to: cal.startOfDay(for: minD))!
        let end = cal.date(byAdding: .hour, value: 36, to: cal.startOfDay(for: maxD))!
        return start...end
    }

    private var xTicks: [Date] {
        let cal = Calendar.current
        let days = points.map { cal.startOfDay(for: $0.date) }.sorted()
        guard let first = days.first, let last = days.last else { return [] }
        let totalDays = (cal.dateComponents([.day], from: first, to: last).day ?? 0) + 1
        let step = max(1, Int(ceil(Double(totalDays) / Double(maxLabels))))
        var ticks: [Date] = []
        var d = first
        while d <= last {
            ticks.append(d)
            guard let next = cal.date(byAdding: .day, value: step, to: d) else { break }
            d = next
        }
        if let lastTick = ticks.last, lastTick != last {
            ticks.append(last)
        }
        return ticks
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { $0.value }
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        let pad = max((maxV - minV) * 0.3, 1.0)
        return (minV - pad)...(maxV + pad)
    }
}

// MARK: - 今日 24 小时图表卡片（心率曲线 / HRV散点 / 血氧散点用）

struct TodayChartCard: View {
    let title: String
    let points: [ChartPoint]
    let color: Color
    let unit: String
    var connectLine: Bool = false
    var emptyText: String = "今日暂无数据，请佩戴 Apple Watch"

    @State private var selected: ChartPoint? = nil

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("点图表查看")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if points.isEmpty {
                HStack {
                    Spacer()
                    Text(emptyText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(height: 120)
            } else {
                Chart {
                    ForEach(points) { p in
                        if connectLine {
                            LineMark(x: .value("时间", p.date), y: .value(unit, p.value))
                                .foregroundStyle(color)
                        } else {
                            PointMark(x: .value("时间", p.date), y: .value(unit, p.value))
                                .foregroundStyle(color)
                                .symbolSize(50)
                        }
                    }
                    if let sel = selected {
                        RuleMark(x: .value("选中", sel.date))
                            .foregroundStyle(Color.gray.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                            .annotation(position: .top, spacing: 4,
                                        overflowResolution: .init(x: .fit, y: .disabled)) {
                                HStack(spacing: 6) {
                                    Text(sel.date, formatter: Self.timeFormatter)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Text(String(format: "%.1f%@", sel.value, unit))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(color)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.systemBackground))
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                            }
                        PointMark(x: .value("选中", sel.date), y: .value("值", sel.value))
                            .foregroundStyle(color)
                            .symbolSize(120)
                    }
                }
                .chartXScale(domain: xDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                    }
                }
                .chartYScale(domain: yDomain)
                .frame(height: 160)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { v in
                                        let x = v.location.x - geo[proxy.plotAreaFrame].origin.x
                                        guard let date: Date = proxy.value(atX: x) else { return }
                                        let hit = points.min(by: {
                                            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                        })
                                        selected = hit
                                        if let hit = hit {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                if selected?.id == hit.id { selected = nil }
                                            }
                                        }
                                    }
                            )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var xDomain: ClosedRange<Date> {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return start...end
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map { $0.value }
        guard let minV = values.min(), let maxV = values.max() else { return 0...1 }
        let pad = max((maxV - minV) * 0.3, 1.0)
        return (minV - pad)...(maxV + pad)
    }
}

// MARK: - 数据页

struct DataView: View {
    @AppStorage("userGender") private var gender = "male"

    @State private var loaded = false
    @State private var isRefreshing = false
    // 今日 24 小时数据
    @State private var todayHeartRate: [ChartPoint] = []
    @State private var todayHRV: [ChartPoint] = []
    @State private var todayOxygen: [ChartPoint] = []
    // 趋势数据
    @State private var scoreTrend: [ChartPoint] = []
    @State private var sleepTrend: [ChartPoint] = []
    @State private var hrvTrend: [ChartPoint] = []
    @State private var rhrTrend: [ChartPoint] = []
    @State private var weightTrend: [ChartPoint] = []
    @State private var bodyFatTrend: [ChartPoint] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !loaded {
                        ProgressView("正在读取健康数据…")
                            .padding(.top, 60)
                    } else {
                        // 今日 24 小时
                        TodayChartCard(title: "今日心率", points: todayHeartRate,
                                       color: .red, unit: "bpm", connectLine: true,
                                       emptyText: "今日暂无心率数据，请佩戴 Apple Watch")
                        TodayChartCard(title: "今日HRV（主要在夜间测量）", points: todayHRV,
                                       color: .pink, unit: "ms",
                                       emptyText: "今日暂无HRV数据，夜间佩戴手表睡觉后会有记录")
                        TodayChartCard(title: "今日血氧（主要在夜间测量）", points: todayOxygen,
                                       color: .blue, unit: "%",
                                       emptyText: "今日暂无血氧数据，夜间佩戴手表睡觉后会有记录")
                        // 趋势
                        TrendChartCard(title: "近7天恢复评分", points: scoreTrend,
                                       color: .green, unit: "分", maxLabels: 7)
                        TrendChartCard(title: "近7天睡眠时长", points: sleepTrend,
                                       color: .indigo, unit: "小时", maxLabels: 7)
                        TrendChartCard(title: "近30天HRV", points: hrvTrend,
                                       color: .pink, unit: "ms", maxLabels: 6)
                        TrendChartCard(title: "近30天静息心率", points: rhrTrend,
                                       color: .red, unit: "bpm", maxLabels: 6)
                        TrendChartCard(title: "体重变化（kg）", points: weightTrend,
                                       color: .orange, unit: "kg", maxLabels: 5,
                                       emptyText: "暂无记录，在「设置」页填写后点「保存并更新计算」",
                                       showPointValues: true)
                        TrendChartCard(title: "体脂率变化（%）", points: bodyFatTrend,
                                       color: .purple, unit: "%", maxLabels: 5,
                                       emptyText: "暂无记录，在「设置」页填写后点「保存并更新计算」",
                                       showPointValues: true)
                    }
                }
                .padding()
            }
            .navigationTitle("数据")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button {
                            refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            if !loaded { loadData() }
        }
    }

    // MARK: - 手动刷新

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        loadData()
    }

    // MARK: - 工具

    /// 同一天只保留最后一条记录；日期统一对齐到当天0点，保证点在刻度正中间
    private func dedupeByDay(_ points: [ChartPoint]) -> [ChartPoint] {
        let cal = Calendar.current
        var byDay: [Date: ChartPoint] = [:]
        for p in points {
            let day = cal.startOfDay(for: p.date)
            byDay[day] = ChartPoint(date: day, value: p.value)
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - 数据加载

    private func loadData() {
        let isFemale = (gender == "female")

        HealthKitManager.shared.requestAuthorization(isFemale: isFemale) { ok in
            guard ok else {
                DispatchQueue.main.async {
                    self.loaded = true
                    self.isRefreshing = false
                }
                return
            }

            let group = DispatchGroup()
            var hrv: [Date: Double] = [:]
            var rhr: [Date: Double] = [:]
            var sleep: [Date: Double] = [:]
            var oxygen: [Date: Double] = [:]
            var respiratory: [Date: Double] = [:]
            var energy: [Date: Double] = [:]
            var menstrual: Set<Date> = []
            var todayHR: [(Date, Double)] = []
            var todayHRVRaw: [(Date, Double)] = []
            var todayO2: [(Date, Double)] = []

            // 今日 24 小时逐条数据
            group.enter()
            HealthKitManager.shared.fetchTodayHeartRate { r in todayHR = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchTodayHRVSamples { r in todayHRVRaw = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchTodayOxygenSamples { r in todayO2 = r; group.leave() }
            // 历史趋势数据
            group.enter()
            HealthKitManager.shared.fetchHRVHistory(days: 30) { r in hrv = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchRestingHRHistory(days: 30) { r in rhr = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchSleepHistory(days: 10) { r in sleep = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchOxygenHistory(days: 10) { r in oxygen = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchRespiratoryHistory(days: 10) { r in respiratory = r; group.leave() }
            group.enter()
            HealthKitManager.shared.fetchEnergyHistory(days: 14) { r in energy = r; group.leave() }
            if isFemale {
                group.enter()
                HealthKitManager.shared.fetchMenstrualDays(days: 180) { r in menstrual = r; group.leave() }
            }

            group.notify(queue: .main) {
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())
                let profile = UserProfile()
                let engine = RecoveryEngine()

                // 今日 24 小时
                self.todayHeartRate = todayHR.map { ChartPoint(date: $0.0, value: $0.1) }
                self.todayHRV = todayHRVRaw.map { ChartPoint(date: $0.0, value: $0.1) }
                self.todayOxygen = todayO2.map { ChartPoint(date: $0.0, value: $0.1) }

                // 近7天评分回放
                var scores: [ChartPoint] = []
                for offset in (0..<7).reversed() {
                    guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                    let h = hrv.filter { $0.key <= day }
                    let r = rhr.filter { $0.key <= day }
                    let s = sleep.filter { $0.key <= day }
                    let o = oxygen.filter { $0.key <= day }
                    let rr = respiratory.filter { $0.key <= day }
                    let e = energy.filter { $0.key <= day }
                    let m = menstrual.filter { $0 <= day }
                    guard h[day] != nil || r[day] != nil else { continue }
                    let result = engine.evaluate(
                        hrvHistory: h, rhrHistory: r, sleepHistory: s,
                        oxygenHistory: o, respiratoryHistory: rr,
                        energyHistory: e, menstrualDays: Set(m),
                        todayCalories: e[day] ?? 0,
                        todayExerciseMinutes: 0,
                        profile: profile
                    )
                    scores.append(ChartPoint(date: day, value: Double(result.totalScore)))
                }
                self.scoreTrend = scores

                let weekAgo = cal.date(byAdding: .day, value: -6, to: today)!
                let monthAgo = cal.date(byAdding: .day, value: -29, to: today)!

                self.sleepTrend = sleep.filter { $0.key >= weekAgo }
                    .map { ChartPoint(date: $0.key, value: min($0.value, 16)) }
                    .sorted { $0.date < $1.date }
                self.hrvTrend = hrv.filter { $0.key >= monthAgo }
                    .map { ChartPoint(date: $0.key, value: $0.value) }
                    .sorted { $0.date < $1.date }
                self.rhrTrend = rhr.filter { $0.key >= monthAgo }
                    .map { ChartPoint(date: $0.key, value: $0.value) }
                    .sorted { $0.date < $1.date }

                // 体重 / 体脂：过滤掉日期损坏的记录，同一天去重，日期对齐当天0点
                let lowerBound = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
                let upperBound = cal.date(byAdding: .day, value: 1, to: today)!
                let validHistory = UserProfile.history.filter { record in
                    record.date >= lowerBound && record.date <= upperBound
                }

                let weightPoints = validHistory.filter { $0.weight > 0 }
                    .map { ChartPoint(date: $0.date, value: $0.weight) }
                let fatPoints = validHistory.filter { $0.bodyFat > 0 }
                    .map { ChartPoint(date: $0.date, value: $0.bodyFat) }
                self.weightTrend = self.dedupeByDay(weightPoints)
                self.bodyFatTrend = self.dedupeByDay(fatPoints)

                self.loaded = true
                self.isRefreshing = false
            }
        }
    }
}
