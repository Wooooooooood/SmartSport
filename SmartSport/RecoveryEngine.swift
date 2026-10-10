import Foundation

// MARK: - 趋势分析工具
struct TrendAnalyzer {

    static func slope(_ values: [Double]) -> Double {
        let n = values.count
        guard n >= 3 else { return 0 }
        let xs = (0..<n).map { Double($0) }
        let meanX = xs.reduce(0, +) / Double(n)
        let meanY = values.reduce(0, +) / Double(n)
        var num = 0.0
        var den = 0.0
        for i in 0..<n {
            num += (xs[i] - meanX) * (values[i] - meanY)
            den += (xs[i] - meanX) * (xs[i] - meanX)
        }
        return den == 0 ? 0 : num / den
    }

    static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    static func coefficientOfVariation(_ values: [Double]) -> Double {
        let avg = average(values)
        guard values.count >= 2, avg > 0 else { return 0 }
        let variance = values.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(values.count)
        return sqrt(variance) / avg * 100
    }
}

// MARK: - 生理周期
enum CyclePhase: String {
    case menstrual = "月经期"
    case follicular = "卵泡期"
    case ovulation = "排卵期"
    case luteal = "黄体期"
    case unknown = "未知"
}

struct CycleInfo {
    let cycleDay: Int
    let phase: CyclePhase
    let avgCycleLength: Int
}

struct CycleTracker {

    static func analyze(menstrualDays: Set<Date>) -> CycleInfo? {
        guard !menstrualDays.isEmpty else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let sorted = menstrualDays.sorted()

        var periodStarts: [Date] = []
        for day in sorted {
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { continue }
            if !menstrualDays.contains(prev) {
                periodStarts.append(day)
            }
        }
        guard let lastStart = periodStarts.last else { return nil }

        var avgLength = 28
        if periodStarts.count >= 2 {
            var gaps: [Int] = []
            for i in 1..<periodStarts.count {
                let gap = cal.dateComponents([.day], from: periodStarts[i - 1], to: periodStarts[i]).day ?? 0
                if gap >= 15 && gap <= 45 { gaps.append(gap) }
            }
            if !gaps.isEmpty { avgLength = gaps.reduce(0, +) / gaps.count }
        }

        let cycleDay = (cal.dateComponents([.day], from: lastStart, to: today).day ?? 0) + 1
        if cycleDay > 45 {
            return CycleInfo(cycleDay: cycleDay, phase: .unknown, avgCycleLength: avgLength)
        }

        let ovulationDay = avgLength - 14
        let phase: CyclePhase
        if cycleDay <= 5 {
            phase = .menstrual
        } else if cycleDay < ovulationDay - 2 {
            phase = .follicular
        } else if cycleDay <= ovulationDay + 1 {
            phase = .ovulation
        } else {
            phase = .luteal
        }
        return CycleInfo(cycleDay: cycleDay, phase: phase, avgCycleLength: avgLength)
    }
}

// MARK: - 评估结果
struct RecoveryResult {
    let totalScore: Int
    let hrvScore: Int
    let rhrScore: Int
    let baselineScore: Int
    let sleepLoadScore: Int
    let feelingScore: Int
    let todayHRV: Double
    let hrvBaseline: Double
    let todayRHR: Double
    let rhrBaseline: Double
    let spo2: Double
    let respiratoryRate: Double
    let sleepDebt: Double
    let rhrTrend: Double
    let consecutiveDays: Int
    let todayCalories: Double
    let todayExerciseMinutes: Double
    let calorieTarget: Double
    let bmi: Double
    let bmiCategory: String
    let cycleInfo: CycleInfo?
    let warnings: [String]
    let recommendation: String
}

// MARK: - 恢复评分引擎
struct RecoveryEngine {

    private let highIntensity = ["高强度间歇训练", "跑步", "力量训练", "跳绳", "球类运动", "滑雪", "划船机", "爬楼梯/踏步机"]
    private let mediumIntensity = ["跑步", "骑行", "游泳", "力量训练", "球类运动", "椭圆机", "划船机", "徒步", "舞蹈", "爬楼梯/踏步机", "多项目运动"]
    private let lowIntensity = ["快走/散步", "瑜伽/拉伸", "普拉提", "太极", "骑行", "游泳", "椭圆机", "徒步", "整理放松", "舞蹈"]
    private let highImpact = ["跑步", "高强度间歇训练", "跳绳", "球类运动", "滑雪", "爬楼梯/踏步机"]

    func evaluate(hrvHistory: [Date: Double],
                  rhrHistory: [Date: Double],
                  sleepHistory: [Date: Double],
                  oxygenHistory: [Date: Double],
                  respiratoryHistory: [Date: Double],
                  energyHistory: [Date: Double],
                  menstrualDays: Set<Date>,
                  todayCalories: Double,
                  todayExerciseMinutes: Double,
                  profile: UserProfile) -> RecoveryResult {

        var warnings: [String] = []

        let hrvValues = hrvHistory.sorted(by: { $0.key < $1.key }).map { $0.value }
        let rhrValues = rhrHistory.sorted(by: { $0.key < $1.key }).map { $0.value }
        let sleepValues = sleepHistory.sorted(by: { $0.key < $1.key }).map { $0.value }
        let spo2 = oxygenHistory.sorted(by: { $0.key < $1.key }).last?.value ?? 0
        let rr = respiratoryHistory.sorted(by: { $0.key < $1.key }).last?.value ?? 0

        let cycleInfo = profile.isFemale ? CycleTracker.analyze(menstrualDays: menstrualDays) : nil
        let isLuteal = cycleInfo?.phase == .luteal

        let preferred = UserDefaults.standard.stringArray(forKey: "preferredExercises") ?? []
        let goal = UserDefaults.standard.string(forKey: "trainingGoal") ?? "health"
        let feeling = todayFeeling()

        // ---------- 1. HRV 评分 ----------
        var hrvScore = 55.0
        var rawHRVBaseline = 0.0
        let todayHRV = hrvValues.last ?? 0
        if hrvValues.count >= 3 {
            rawHRVBaseline = TrendAnalyzer.average(Array(hrvValues.dropLast().suffix(30)))
            var effectiveBaseline = rawHRVBaseline
            if isLuteal { effectiveBaseline *= 0.92 }
            if effectiveBaseline > 0 {
                let ratio = todayHRV / effectiveBaseline
                let scoreVsBaseline = clamp((ratio - 0.75) / 0.35 * 100, 0, 100)
                let last7 = Array(hrvValues.suffix(7))
                let avg7 = TrendAnalyzer.average(last7)
                let slope7 = TrendAnalyzer.slope(last7)
                let trendScore = avg7 > 0 ? clamp(50 + slope7 / avg7 * 500, 0, 100) : 50
                let cv = TrendAnalyzer.coefficientOfVariation(last7)
                let stabilityScore = clamp((25 - cv) / 20 * 100, 0, 100)
                hrvScore = scoreVsBaseline * 0.40 + trendScore * 0.35 + stabilityScore * 0.25
            }
        } else {
            warnings.append("HRV历史数据不足，该项评分仅供参考")
        }

        // ---------- 2. 静息心率评分 ----------
        var rhrScore = 55.0
        var rawRHRBaseline = 0.0
        let todayRHR = rhrValues.last ?? 0
        let rhrSlope = TrendAnalyzer.slope(Array(rhrValues.suffix(7)))
        if rhrValues.count >= 3 {
            rawRHRBaseline = TrendAnalyzer.average(Array(rhrValues.dropLast().suffix(30)))
            var effectiveBaseline = rawRHRBaseline
            if isLuteal { effectiveBaseline += 2 }
            if effectiveBaseline > 0 {
                let diff = todayRHR - effectiveBaseline
                rhrScore = clamp(85 - diff * 8, 0, 100)
            }
        } else {
            warnings.append("静息心率历史数据不足，该项评分仅供参考")
        }

        // ---------- 3. 基础指标评分 ----------
        var spo2Score = -1.0
        if spo2 > 0 {
            switch spo2 {
            case 97...: spo2Score = 100
            case 95..<97: spo2Score = 90
            case 93..<95: spo2Score = 75
            case 90..<93: spo2Score = 55
            default: spo2Score = 20
            }
        }
        var rrScore = -1.0
        if rr > 0 {
            if rr >= 12 && rr <= 20 {
                rrScore = 100
            } else {
                let distance = rr < 12 ? 12 - rr : rr - 20
                rrScore = clamp(100 - distance * 12, 0, 100)
            }
        }
        let baselineScore: Double
        if spo2Score >= 0 && rrScore >= 0 {
            baselineScore = spo2Score * 0.5 + rrScore * 0.5
        } else if spo2Score >= 0 {
            baselineScore = spo2Score
        } else if rrScore >= 0 {
            baselineScore = rrScore
        } else {
            baselineScore = 60
        }

        // ---------- 4. 睡眠与负荷评分 ----------
        let lastSleep = sleepValues.last ?? 0
        let sleepScore = clamp(lastSleep / 7.5 * 100, 0, 100)
        let sleepDebt = sleepValues.suffix(7).reduce(0.0) { $0 + max(0, 7.5 - $1) }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var consecutive = 0
        var cursor = cal.date(byAdding: .day, value: -1, to: today)!
        while let energy = energyHistory[cursor], energy > 200 {
            consecutive += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        let loadScore = clamp(100.0 - Double(max(0, consecutive - 3)) * 15.0, 20, 100)
        let sleepLoadScore = sleepScore * 0.6 + loadScore * 0.4

        // ---------- 客观加权总分 ----------
        var total = hrvScore * 0.30 + rhrScore * 0.25 + baselineScore * 0.15 + sleepLoadScore * 0.30

        // ---------- 主观感受（占10%，与数据互相印证）----------
        let objectiveTotal = total
        if feeling > 0 {
            total = total * 0.9 + Double(feeling) * 0.1
            if feeling <= 30 && objectiveTotal >= 70 {
                warnings.append("数据显示恢复良好，但你感觉疲劳——相信身体的感受，建议降一档强度")
            } else if feeling >= 90 && objectiveTotal < 55 {
                warnings.append("你感觉状态不错，但数据显示身体未恢复，建议谨慎训练")
            }
        }

        // ---------- 修正项 ----------
        if sleepDebt >= 10 {
            total -= 12
            warnings.append("近7天睡眠负债 \(String(format: "%.1f", sleepDebt)) 小时，身体在透支")
        } else if sleepDebt >= 5 {
            total -= 6
            warnings.append("近7天睡眠负债 \(String(format: "%.1f", sleepDebt)) 小时，注意补觉")
        }

        if rhrSlope > 1.5 {
            total -= 8
            warnings.append("静息心率持续上升，可能有疲劳积累或生病前兆")
        } else if rhrSlope > 0.8 {
            total -= 4
            warnings.append("静息心率有上升趋势，注意休息")
        }

        if consecutive >= 6 {
            total -= 10
            warnings.append("已连续运动 \(consecutive) 天，建议安排休息日")
        }

        if lastSleep > 0 && lastSleep < 4 {
            total = min(total, 45)
            warnings.append("昨晚睡眠不足4小时，今天必须休息")
        }

        // ---------- 红线一票否决 ----------
        if spo2 > 0 && spo2 < 90 {
            total = min(total, 40)
            warnings.append("血氧低于90%，请停止运动，必要时就医")
        }
        if rr >= 24 {
            total = min(total, 60)
            warnings.append("呼吸频率偏高，身体可能处于应激状态")
        }
        if hrvValues.count >= 3 && rhrValues.count >= 3 && rawHRVBaseline > 0 && rawRHRBaseline > 0 {
            let hrvCrash = todayHRV < rawHRVBaseline * 0.75
            let rhrSpike = todayRHR > rawRHRBaseline + 7
            if hrvCrash && rhrSpike {
                total = min(total, 45)
                warnings.append("HRV大幅下降且静息心率明显升高，身体未恢复，强制休息")
            }
        }

        // ---------- 女性周期修正 ----------
        var cycleRec: String? = nil
        if let cycle = cycleInfo {
            if cycle.phase == .menstrual && cycle.cycleDay <= 3 {
                total = min(total, 70)
                cycleRec = "经期第 \(cycle.cycleDay) 天：建议散步、温和拉伸或阴瑜伽，避免高强度训练"
            } else if cycle.phase == .ovulation {
                total += 5
            }
        }

        // ---------- 身体成分修正 ----------
        var needLowImpact = false
        if profile.bmi >= 28 {
            needLowImpact = true
            warnings.append("BMI \(String(format: "%.1f", profile.bmi))（\(profile.bmiCategory)），优先低冲击运动保护关节")
        }
        if profile.isBodyFatHigh {
            needLowImpact = true
            warnings.append("体脂率偏高，建议以中低强度有氧为主")
        }
        if profile.isBoneLow {
            warnings.append("骨盐量偏低，注意补钙并安排适量力量训练")
        }
        if profile.isMuscleLow {
            warnings.append("肌肉量偏低，恢复期可安排适量力量训练")
        }

        // ---------- 今日已运动修正 ----------
        let doneToday = todayExerciseMinutes >= 45
        if doneToday {
            total = min(total, 74)
        }

        total = clamp(total, 0, 100)
        let totalInt = Int(total.rounded())

        // ---------- 最终推荐 ----------
        let recommendation: String
        if let cycleRec = cycleRec {
            recommendation = cycleRec
        } else if doneToday {
            recommendation = "今天已完成 \(Int(todayExerciseMinutes)) 分钟运动，训练量够了，建议休息、拉伸或轻松散步"
        } else {
            recommendation = buildRecommendation(score: totalInt, preferred: preferred, needLowImpact: needLowImpact, goal: goal)
        }

        return RecoveryResult(
            totalScore: totalInt,
            hrvScore: Int(hrvScore.rounded()),
            rhrScore: Int(rhrScore.rounded()),
            baselineScore: Int(baselineScore.rounded()),
            sleepLoadScore: Int(sleepLoadScore.rounded()),
            feelingScore: feeling,
            todayHRV: todayHRV,
            hrvBaseline: rawHRVBaseline,
            todayRHR: todayRHR,
            rhrBaseline: rawRHRBaseline,
            spo2: spo2,
            respiratoryRate: rr,
            sleepDebt: sleepDebt,
            rhrTrend: rhrSlope,
            consecutiveDays: consecutive,
            todayCalories: todayCalories,
            todayExerciseMinutes: todayExerciseMinutes,
            calorieTarget: profile.calorieTarget,
            bmi: profile.bmi,
            bmiCategory: profile.bmiCategory,
            cycleInfo: cycleInfo,
            warnings: warnings,
            recommendation: recommendation
        )
    }

    // MARK: - 读取今日主观感受（0=未填写）
    private func todayFeeling() -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return UserDefaults.standard.integer(forKey: "feeling_" + f.string(from: Date()))
    }

    // MARK: - 按分数档位 + 偏好 + 训练目标生成推荐
    private func buildRecommendation(score: Int, preferred: [String], needLowImpact: Bool, goal: String) -> String {
        switch score {
        case 85...:
            let options = orderByGoal(pick(from: highIntensity, preferred: preferred, needLowImpact: needLowImpact), goal: goal)
            if options.isEmpty { return "状态极佳！适合高强度训练，45-60分钟" }
            return "状态极佳！推荐：\(options.joined(separator: "、"))" + goalSuffix(goal: goal, tier: 0)
        case 70..<85:
            let options = orderByGoal(pick(from: mediumIntensity, preferred: preferred, needLowImpact: needLowImpact), goal: goal)
            if options.isEmpty { return "状态良好，适合中等强度运动，45-60分钟" }
            return "状态良好！推荐：\(options.joined(separator: "、"))" + goalSuffix(goal: goal, tier: 1)
        case 55..<70:
            let options = orderByGoal(pick(from: lowIntensity, preferred: preferred, needLowImpact: needLowImpact), goal: goal)
            if options.isEmpty { return "恢复一般，建议低强度有氧，30分钟左右" }
            return "恢复一般，推荐：\(options.joined(separator: "、"))" + goalSuffix(goal: goal, tier: 2)
        case 40..<55:
            return "身体较疲劳，只做轻度活动：散步、温和拉伸，早点休息"
        default:
            return "身体需要恢复，今天完全休息，保证睡眠和营养"
        }
    }

    // 先按用户偏好过滤，再按低冲击需求过滤
    private func pick(from candidates: [String], preferred: [String], needLowImpact: Bool) -> [String] {
        var options = candidates
        if !preferred.isEmpty {
            let filtered = options.filter { preferred.contains($0) }
            if !filtered.isEmpty { options = filtered }
        }
        if needLowImpact {
            let filtered = options.filter { !highImpact.contains($0) }
            if !filtered.isEmpty { options = filtered }
        }
        return options
    }

    // 按训练目标给项目排序
    private func orderByGoal(_ options: [String], goal: String) -> [String] {
        let order: [String]
        switch goal {
        case "lose":
            order = ["跑步", "游泳", "骑行", "椭圆机", "划船机", "爬楼梯/踏步机", "跳绳", "高强度间歇训练", "快走/散步", "徒步", "舞蹈", "球类运动", "滑雪", "力量训练", "瑜伽/拉伸", "普拉提", "太极", "整理放松"]
        case "muscle":
            order = ["力量训练", "高强度间歇训练", "划船机", "球类运动", "跑步", "骑行", "游泳", "椭圆机", "爬楼梯/踏步机", "快走/散步", "徒步", "滑雪", "舞蹈", "跳绳", "瑜伽/拉伸", "普拉提", "太极", "整理放松"]
        default:
            return options
        }
        return options.sorted { a, b in
            (order.firstIndex(of: a) ?? 99) < (order.firstIndex(of: b) ?? 99)
        }
    }

    // 按训练目标给时长建议
    private func goalSuffix(goal: String, tier: Int) -> String {
        switch goal {
        case "lose":
            switch tier {
            case 0: return "，45-60分钟，以有氧为主，燃脂效率更高"
            case 1: return "，45-60分钟，保持燃脂心率区间"
            default: return "，30-40分钟，动起来就有消耗"
            }
        case "muscle":
            switch tier {
            case 0: return "，力量为主50-60分钟，可加10分钟有氧收尾"
            case 1: return "，力量40-50分钟 + 轻松有氧15分钟"
            default: return "，轻量恢复性训练即可，给肌肉修复时间"
            }
        default:
            switch tier {
            case 2: return "，30分钟左右"
            default: return "，45-60分钟"
            }
        }
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
