import Foundation

// MARK: - 单次测量记录
struct MeasurementRecord: Codable {
    let date: Date
    let weight: Double
    let bodyFat: Double
    let muscle: Double
    let bone: Double
    let bmi: Double
}

// MARK: - 用户档案
struct UserProfile {

    var height: Double { UserDefaults.standard.double(forKey: "profileHeight") }      // cm
    var weight: Double { UserDefaults.standard.double(forKey: "profileWeight") }      // kg
    var age: Int { UserDefaults.standard.integer(forKey: "profileAge") }
    var bodyFat: Double { UserDefaults.standard.double(forKey: "profileBodyFat") }    // %
    var muscle: Double { UserDefaults.standard.double(forKey: "profileMuscle") }      // kg
    var bone: Double { UserDefaults.standard.double(forKey: "profileBone") }          // kg
    var gender: String { UserDefaults.standard.string(forKey: "userGender") ?? "male" }
    var isFemale: Bool { gender == "female" }

    private var storedBMR: Double { UserDefaults.standard.double(forKey: "profileBMR") }

    // MARK: 更新时间与每周提醒
    var lastUpdated: Date? { UserDefaults.standard.object(forKey: "profileLastUpdated") as? Date }

    var daysSinceUpdate: Int {
        guard let last = lastUpdated else { return 999 }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 999
    }

    var needsWeeklyUpdate: Bool { daysSinceUpdate >= 7 }

    // MARK: BMI
    var bmi: Double {
        guard height > 0, weight > 0 else { return 0 }
        let h = height / 100.0
        return weight / (h * h)
    }

    var bmiCategory: String {
        switch bmi {
        case ..<0.1: return "未填写"
        case ..<18.5: return "偏瘦"
        case ..<24: return "正常"
        case ..<28: return "超重"
        default: return "肥胖"
        }
    }

    // MARK: 基础代谢（优先手动填写，否则 Mifflin-St Jeor 公式估算）
    var bmr: Double {
        if storedBMR > 0 { return storedBMR }
        guard height > 0, weight > 0, age > 0 else { return 0 }
        let base = 10 * weight + 6.25 * height - 5 * Double(age)
        return isFemale ? base - 161 : base + 5
    }

    // MARK: 每日运动消耗目标
    var calorieTarget: Double {
        guard bmr > 0 else { return 300 }
        return bmr * 0.25
    }

    // MARK: 体脂率
    var bodyFatStatus: String {
        guard bodyFat > 0 else { return "未填写" }
        let low = isFemale ? 18.0 : 10.0
        let high = isFemale ? 28.0 : 20.0
        if bodyFat < low { return "偏低" }
        if bodyFat > high { return "偏高" }
        return "正常"
    }

    var isBodyFatHigh: Bool { bodyFatStatus == "偏高" }

    // MARK: 肌肉量
    var muscleRate: Double {
        guard weight > 0, muscle > 0 else { return 0 }
        return muscle / weight * 100
    }

    var isMuscleLow: Bool {
        guard muscleRate > 0 else { return false }
        return isFemale ? muscleRate < 28 : muscleRate < 32
    }

    // MARK: 骨盐量
    var expectedBoneMass: Double {
        guard weight > 0 else { return 0 }
        if isFemale {
            if weight < 45 { return 1.8 }
            if weight < 60 { return 2.2 }
            return 2.5
        } else {
            if weight < 60 { return 2.5 }
            if weight < 75 { return 2.9 }
            return 3.2
        }
    }

    var isBoneLow: Bool {
        guard bone > 0, expectedBoneMass > 0 else { return false }
        return bone < expectedBoneMass
    }

    // MARK: - 保存快照（带时间戳，同一天只留一条，最多52条）
    static func saveSnapshot() {
        let p = UserProfile()
        guard p.weight > 0 else { return }
        UserDefaults.standard.set(Date(), forKey: "profileLastUpdated")

        var records = history
        let cal = Calendar.current
        records.removeAll { cal.isDate($0.date, inSameDayAs: Date()) }
        records.append(MeasurementRecord(date: Date(), weight: p.weight, bodyFat: p.bodyFat,
                                         muscle: p.muscle, bone: p.bone, bmi: p.bmi))
        if records.count > 52 { records = Array(records.suffix(52)) }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "measurementHistory")
        }
    }

    static var history: [MeasurementRecord] {
        guard let data = UserDefaults.standard.data(forKey: "measurementHistory"),
              let records = try? JSONDecoder().decode([MeasurementRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.date < $1.date }
    }
}
