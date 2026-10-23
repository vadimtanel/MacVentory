import Foundation
import MacventoryCore

@main
struct Verify {
    static func main() async throws {
        let started = ContinuousClock.now
        var configuration = ScanConfiguration()
        configuration.showSystem = CommandLine.arguments.contains("--system")
        let snapshot = await InventoryService().scan(configuration: configuration, previous: nil, measureSizes: CommandLine.arguments.contains("--sizes")) { event in
            if case .report(let report) = event { FileHandle.standardError.write(Data("\(report.source.title): \(report.state.title) \(report.count)\n".utf8)) }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        if let index = CommandLine.arguments.firstIndex(of: "--output"), CommandLine.arguments.indices.contains(index + 1) {
            try encoder.encode(snapshot).write(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]), options: .atomic)
        }
        print("Inventory: \(snapshot.items.count) records in \(started.duration(to: .now))")
        for report in snapshot.reports { print("\(report.source.title): \(report.state.title), \(report.count) discoveries — \(report.message)") }
        let ids = snapshot.items.map(\.id)
        guard ids.count == Set(ids).count else { throw ScanError.malformed("Duplicate installation identities") }
        for item in snapshot.items {
            if let installed = item.installedAt, item.evidence["installedAt"]?.confidence != .verified { throw ScanError.malformed("Unverified installation timestamp for \(item.name): \(installed)") }
        }
        print("Identity and installation-date evidence checks passed.")
        if CommandLine.arguments.contains("--benchmark"), let sample = snapshot.items.first {
            // Synthetic copies are used only for a repeatable UI-scale performance probe, never persisted as inventory.
            let dataset = (0..<1000).map { index in var item = sample; item.id = "benchmark:\(index)"; item.name = "Example \(index)"; return item }
            var filter = InventoryFilter(); filter.search = "Example"; filter.showSystem = true
            let clock = ContinuousClock()
            var durations: [Double] = []
            for _ in 0..<25 {
                let start = clock.now
                let result = InventorySort.sorted(dataset.filter { filter.matches($0, configuration: configuration) })
                guard result.count == 1000 else { throw ScanError.malformed("Benchmark filtering unexpectedly dropped rows") }
                let duration = start.duration(to: clock.now).components
                durations.append(Double(duration.seconds) * 1000 + Double(duration.attoseconds) / 1e15)
            }
            print("Synthetic 1000-row cached filter + name sort, 25 runs: mean \(durations.reduce(0, +) / Double(durations.count)) ms; max \(durations.max() ?? 0) ms")
        }
    }
}
