import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    // MARK: - 授权

    func requestAuthorization(isFemale: Bool, completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        var readTypes: Set<HKObjectType> = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate),
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.respiratoryRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType()
        ]
        if isFemale {
            readTypes.insert(HKCategoryType(.menstrualFlow))
        }
        print("➡️ 开始请求健康授权")
        healthStore.requestAuthorization(toShare: [], read: readTypes) { ok, error in
            print("✅ 授权请求返回: ok = \(ok), error = \(String(describing: error))")
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - 今日逐条数据（24小时，用于日内图表）

    /// 今日心率，单位 次/分（每几分钟一条，数据密集）
    func fetchTodayHeartRate(completion: @escaping ([(Date, Double)]) -> Void) {
        fetchTodaySamples(.heartRate,
                          unit: HKUnit.count().unitDivided(by: .minute()),
                          completion: completion)
    }

    /// 今日 HRV 逐条记录，单位毫秒 ms（主要在夜间测量，较稀疏）
    func fetchTodayHRVSamples(completion: @escaping ([(Date, Double)]) -> Void) {
        fetchTodaySamples(.heartRateVariabilitySDNN,
                          unit: HKUnit.secondUnit(with: .milli),
                          completion: completion)
    }

    /// 今日血氧逐条记录，单位 %（主要在夜间自动测量，较稀疏）
    func fetchTodayOxygenSamples(completion: @escaping ([(Date, Double)]) -> Void) {
        fetchTodaySamples(.oxygenSaturation,
                          unit: .percent(), scale: 100,
                          completion: completion)
    }

    /// 通用：今日某指标的逐条原始记录，按时间升序
    private func fetchTodaySamples(_ identifier: HKQuantityTypeIdentifier,
                                   unit: HKUnit, scale: Double = 1,
                                   completion: @escaping ([(Date, Double)]) -> Void) {
        let type = HKQuantityType(identifier)
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let pairs = (samples as? [HKQuantitySample] ?? []).map {
                ($0.startDate, $0.quantity.doubleValue(for: unit) * scale)
            }
            completion(pairs)
        }
        healthStore.execute(query)
    }

    // MARK: - 历史数据（对外接口，返回 [日期: 数值]，days 都有默认值，可省略）

    /// HRV 心率变异性，单位毫秒 ms
    func fetchHRVHistory(days: Int = 30, completion: @escaping ([Date: Double]) -> Void) {
        fetchDailyAverage(HKQuantityType(.heartRateVariabilitySDNN),
                          unit: HKUnit.secondUnit(with: .milli),
                          days: days) { pairs in
            completion(Self.toDict(pairs))
        }
    }

    /// 静息心率，单位 次/分
    func fetchRestingHRHistory(days: Int = 30, completion: @escaping ([Date: Double]) -> Void) {
        fetchDailyAverage(HKQuantityType(.restingHeartRate),
                          unit: HKUnit.count().unitDivided(by: .minute()),
                          days: days) { pairs in
            completion(Self.toDict(pairs))
        }
    }

    /// 兼容旧写法：静息心率历史
    func fetchRHRHistory(days: Int = 30, completion: @escaping ([Date: Double]) -> Void) {
        fetchRestingHRHistory(days: days, completion: completion)
    }

    /// 血氧，单位 %
    func fetchOxygenHistory(days: Int = 10, completion: @escaping ([Date: Double]) -> Void) {
        fetchDailyAverage(HKQuantityType(.oxygenSaturation),
                          unit: .percent(),
                          days: days, scale: 100) { pairs in
            completion(Self.toDict(pairs))
        }
    }

    /// 呼吸频率，单位 次/分
    func fetchRespiratoryHistory(days: Int = 10, completion: @escaping ([Date: Double]) -> Void) {
        fetchDailyAverage(HKQuantityType(.respiratoryRate),
                          unit: HKUnit.count().unitDivided(by: .minute()),
                          days: days) { pairs in
            completion(Self.toDict(pairs))
        }
    }

    /// 活动能量，单位 千卡 kcal（每日总和）
    func fetchEnergyHistory(days: Int = 14, completion: @escaping ([Date: Double]) -> Void) {
        fetchDailySum(HKQuantityType(.activeEnergyBurned),
                      unit: .kilocalorie(),
                      days: days) { pairs in
            completion(Self.toDict(pairs))
        }
    }

    /// 睡眠时长，单位小时（归属到醒来的那一天）
    func fetchSleepHistory(days: Int = 10, completion: @escaping ([Date: Double]) -> Void) {
        let type = HKCategoryType(.sleepAnalysis)
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            completion([:])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let cal = Calendar.current
            // 1=旧版睡着, 3=核心睡眠, 4=深睡, 5=快速眼动；排除 0=在床 和 2=清醒
            let asleepValues: Set<Int> = [1, 3, 4, 5]
            var dict: [Date: Double] = [:]
            for s in (samples as? [HKCategorySample] ?? []) where asleepValues.contains(s.value) {
                let wakeDay = cal.startOfDay(for: s.endDate)
                dict[wakeDay, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
            }
            completion(dict)
        }
        healthStore.execute(query)
    }

    /// 经期日期集合
    func fetchMenstrualDays(days: Int = 180, completion: @escaping (Set<Date>) -> Void) {
        let type = HKCategoryType(.menstrualFlow)
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let cal = Calendar.current
            var daysSet = Set<Date>()
            for s in (samples as? [HKCategorySample] ?? []) {
                // 5 = 「无月经」记录，不算经期
                if s.value == 5 { continue }
                daysSet.insert(cal.startOfDay(for: s.startDate))
            }
            completion(daysSet)
        }
        healthStore.execute(query)
    }

    // MARK: - 今日数据

    /// 今日已消耗千卡
    func fetchTodayEnergy(completion: @escaping (Double) -> Void) {
        fetchTodaySum(HKQuantityType(.activeEnergyBurned), unit: .kilocalorie(), completion: completion)
    }

    /// 今日已活动分钟数
    func fetchTodayExerciseMinutes(completion: @escaping (Double) -> Void) {
        fetchTodaySum(HKQuantityType(.appleExerciseTime), unit: .minute(), completion: completion)
    }

    // MARK: - 体能训练记录（读取 Apple Watch 的运动项目）

    /// 返回按使用频率排序的运动项目名称列表
    func fetchUsedWorkoutTypes(days: Int = 365, completion: @escaping ([String]) -> Void) {
        guard let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
            let workouts = (samples as? [HKWorkout]) ?? []
            print("ℹ️ 体能训练原始记录数：\(workouts.count)")
            var counts: [String: Int] = [:]
            for w in workouts {
                if let name = self.workoutName(w.workoutActivityType) {
                    counts[name, default: 0] += 1
                }
            }
            let sorted = counts.sorted { $0.value > $1.value }.map { $0.key }
            print("✅ 读到运动记录：\(sorted)")
            completion(sorted)
        }
        healthStore.execute(query)
    }

    /// 把手表的运动类型映射成 App 里统一的中文名；不认识的类型返回 nil（忽略）
    private func workoutName(_ type: HKWorkoutActivityType) -> String? {
        switch type {
        case .running:
            return "跑步"
        case .swimming:
            return "游泳"
        case .cycling:
            return "骑行"
        case .walking:
            return "快走/散步"
        case .hiking:
            return "徒步"
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return "力量训练"
        case .highIntensityIntervalTraining:
            return "高强度间歇训练"
        case .yoga, .flexibility:
            return "瑜伽/拉伸"
        case .pilates:
            return "普拉提"
        case .cardioDance, .socialDance:
            return "舞蹈"
        case .taiChi:
            return "太极"
        case .tableTennis, .badminton, .tennis, .basketball, .soccer, .volleyball, .golf:
            return "球类运动"
        case .rowing:
            return "划船机"
        case .elliptical:
            return "椭圆机"
        case .stairClimbing, .stepTraining:
            return "爬楼梯/踏步机"
        case .snowboarding, .downhillSkiing, .crossCountrySkiing:
            return "滑雪"
        case .cooldown:
            return "整理放松"
        default:
            return nil
        }
    }

    // MARK: - 内部工具

    private static func toDict(_ pairs: [(Date, Double)]) -> [Date: Double] {
        var dict: [Date: Double] = [:]
        for (d, v) in pairs { dict[d] = v }
        return dict
    }

    /// 按天统计平均值
    private func fetchDailyAverage(_ type: HKQuantityType, unit: HKUnit, days: Int,
                                   scale: Double = 1,
                                   completion: @escaping ([(Date, Double)]) -> Void) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        var interval = DateComponents()
        interval.day = 1
        let query = HKStatisticsCollectionQuery(quantityType: type,
                                                quantitySamplePredicate: predicate,
                                                options: .discreteAverage,
                                                anchorDate: end,
                                                intervalComponents: interval)
        query.initialResultsHandler = { _, results, _ in
            var pairs: [(Date, Double)] = []
            results?.enumerateStatistics(from: start, to: end) { stats, _ in
                if let v = stats.averageQuantity()?.doubleValue(for: unit) {
                    pairs.append((stats.startDate, v * scale))
                }
            }
            completion(pairs)
        }
        healthStore.execute(query)
    }

    /// 按天统计总和
    private func fetchDailySum(_ type: HKQuantityType, unit: HKUnit, days: Int,
                               completion: @escaping ([(Date, Double)]) -> Void) {
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else {
            completion([])
            return
        }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        var interval = DateComponents()
        interval.day = 1
        let query = HKStatisticsCollectionQuery(quantityType: type,
                                                quantitySamplePredicate: predicate,
                                                options: .cumulativeSum,
                                                anchorDate: end,
                                                intervalComponents: interval)
        query.initialResultsHandler = { _, results, _ in
            var pairs: [(Date, Double)] = []
            results?.enumerateStatistics(from: start, to: end) { stats, _ in
                if let v = stats.sumQuantity()?.doubleValue(for: unit) {
                    pairs.append((stats.startDate, v))
                }
            }
            completion(pairs)
        }
        healthStore.execute(query)
    }

    /// 今日总和（从当天 0 点到现在）
    private func fetchTodaySum(_ type: HKQuantityType, unit: HKUnit,
                               completion: @escaping (Double) -> Void) {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let query = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
            completion(stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        healthStore.execute(query)
    }
}
