import Foundation
import MetricKit

// kalgram: what kalgram spent, from the reports iOS itself hands the app about once a day (MetricKit).
// They stay on this device: the last few, boiled down to a handful of numbers, in a file nothing sends anywhere.
public struct KalgramEnergyDay: Codable, Equatable {
    public var begin: Date
    public var end: Date
    public var appVersion: String
    // seconds
    public var foreground: Double
    public var background: Double
    public var backgroundAudio: Double
    public var cpu: Double
    public var gpu: Double
    // bytes
    public var wifiDown: Double
    public var wifiUp: Double
    public var cellularDown: Double
    public var cellularUp: Double
    public var diskWrites: Double
}

public final class KalgramEnergyReport: NSObject, MXMetricManagerSubscriber {
    public static let shared = KalgramEnergyReport()

    // About two weeks of daily reports
    private static let maxDays = 14

    private let lock = NSLock()
    private var storedDays: [KalgramEnergyDay]?
    private var started = false

    private static var fileURL: URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return directory.appendingPathComponent("kalgram-energy.json")
    }

    public func start() {
        precondition(Thread.isMainThread)
        guard !self.started else {
            return
        }
        self.started = true
        let manager = MXMetricManager.shared
        manager.add(self)
        let pastPayloads = manager.pastPayloads
        DispatchQueue.global(qos: .utility).async {
            self.didReceive(pastPayloads)
        }
    }

    // Newest first
    public var days: [KalgramEnergyDay] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.loadedDays()
    }

    public func didReceive(_ payloads: [MXMetricPayload]) {
        if payloads.isEmpty {
            return
        }
        let newDays = payloads.map(KalgramEnergyReport.day(from:))

        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        var days = self.loadedDays()
        for day in newDays where !days.contains(where: { $0.begin == day.begin }) {
            days.append(day)
        }
        days.sort(by: { $0.begin > $1.begin })
        if days.count > KalgramEnergyReport.maxDays {
            days.removeLast(days.count - KalgramEnergyReport.maxDays)
        }
        self.storedDays = days
        self.save(days)
    }

    // Called with the lock held
    private func loadedDays() -> [KalgramEnergyDay] {
        if let storedDays = self.storedDays {
            return storedDays
        }
        var days: [KalgramEnergyDay] = []
        if let url = KalgramEnergyReport.fileURL, let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode([KalgramEnergyDay].self, from: data) {
            days = decoded
        }
        self.storedDays = days
        return days
    }

    private func save(_ days: [KalgramEnergyDay]) {
        guard var url = KalgramEnergyReport.fileURL, let data = try? JSONEncoder().encode(days) else {
            return
        }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard (try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) != nil else {
            return
        }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private static func day(from payload: MXMetricPayload) -> KalgramEnergyDay {
        func seconds(_ value: Measurement<UnitDuration>?) -> Double {
            return value?.converted(to: .seconds).value ?? 0.0
        }
        func bytes(_ value: Measurement<UnitInformationStorage>?) -> Double {
            return value?.converted(to: .bytes).value ?? 0.0
        }
        let time = payload.applicationTimeMetrics
        let network = payload.networkTransferMetrics
        return KalgramEnergyDay(
            begin: payload.timeStampBegin,
            end: payload.timeStampEnd,
            appVersion: payload.latestApplicationVersion,
            foreground: seconds(time?.cumulativeForegroundTime),
            background: seconds(time?.cumulativeBackgroundTime),
            backgroundAudio: seconds(time?.cumulativeBackgroundAudioTime),
            cpu: seconds(payload.cpuMetrics?.cumulativeCPUTime),
            gpu: seconds(payload.gpuMetrics?.cumulativeGPUTime),
            wifiDown: bytes(network?.cumulativeWifiDownload),
            wifiUp: bytes(network?.cumulativeWifiUpload),
            cellularDown: bytes(network?.cumulativeCellularDownload),
            cellularUp: bytes(network?.cumulativeCellularUpload),
            diskWrites: bytes(payload.diskIOMetrics?.cumulativeLogicalWrites)
        )
    }
}

// kalgram Pro's text for one report, and the day before it to compare with
public func kalgramEnergyReportText(_ day: KalgramEnergyDay, previous: KalgramEnergyDay?) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "ru_RU")
    dateFormatter.dateFormat = "d MMM, HH:mm"

    func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours) ч \(minutes) мин"
        } else if minutes > 0 {
            return "\(minutes) мин \(total % 60) с"
        } else {
            return "\(total) с"
        }
    }
    func size(_ bytes: Double) -> String {
        let megabytes = bytes / 1_000_000.0
        if megabytes >= 10.0 {
            return "\(Int(megabytes.rounded())) МБ"
        } else {
            return String(format: "%.1f МБ", megabytes)
        }
    }
    // A share of the time on screen, the measure that is comparable between days
    func perScreenHour(_ seconds: Double, of day: KalgramEnergyDay) -> String {
        guard day.foreground >= 60.0 else {
            return ""
        }
        return " (\(duration(seconds / day.foreground * 3600.0)) на час экрана)"
    }

    var lines: [String] = []
    lines.append("\(dateFormatter.string(from: day.begin)) – \(dateFormatter.string(from: day.end)), версия \(day.appVersion)")
    var timeLine = "На экране \(duration(day.foreground)), в фоне \(duration(day.background))"
    if day.backgroundAudio >= 60.0 {
        timeLine += ", из них беззвучный звук \(duration(day.backgroundAudio))"
    }
    lines.append(timeLine)
    lines.append("Процессор: \(duration(day.cpu))\(perScreenHour(day.cpu, of: day))")
    lines.append("Видеочип: \(duration(day.gpu))\(perScreenHour(day.gpu, of: day))")
    lines.append("Wi‑Fi: ↓ \(size(day.wifiDown)) ↑ \(size(day.wifiUp)), сотовая: ↓ \(size(day.cellularDown)) ↑ \(size(day.cellularUp))")
    lines.append("Запись на диск: \(size(day.diskWrites))")

    if let previous, previous.foreground >= 60.0, day.foreground >= 60.0 {
        func change(_ current: Double, _ before: Double) -> String {
            let currentRate = current / day.foreground
            let beforeRate = before / previous.foreground
            guard beforeRate > 0.0 else {
                return "—"
            }
            let percent = Int(((currentRate / beforeRate - 1.0) * 100.0).rounded())
            return percent > 0 ? "+\(percent)%" : "\(percent)%"
        }
        lines.append("К прошлому отчёту, на час экрана: процессор \(change(day.cpu, previous.cpu)), видеочип \(change(day.gpu, previous.gpu))")
    }
    return lines.joined(separator: "\n")
}
