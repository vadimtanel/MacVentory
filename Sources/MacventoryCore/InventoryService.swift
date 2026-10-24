import Foundation

public enum InventoryMerger {
    public static func merge(_ discoveries: [SoftwareItem], uncertainOwnership: Bool = false) -> [SoftwareItem] {
        var owners: [String: String] = [:]
        for item in discoveries where item.primarySource == .steam {
            for path in item.relatedPaths { owners[FileSystem.canonical(path)] = item.id }
        }
        var result: [String: SoftwareItem] = [:]
        for item in discoveries.sorted(by: { $0.id == $1.id ? rank($0.primarySource) < rank($1.primarySource) : $0.id < $1.id }) {
            let id = item.path.flatMap { owners[FileSystem.canonical($0)] } ?? item.id
            guard var existing = result[id] else { var item = item; item.id = id; result[id] = item; continue }
            let incomingWins = rank(item.primarySource) < rank(existing.primarySource)
            let old = existing
            if incomingWins { existing = item; existing.id = id }
            let other = incomingWins ? old : item
            existing.sources = Array(Set(existing.sources + other.sources)).sorted { $0.source.rawValue < $1.source.rawValue }
            existing.version = existing.version ?? other.version
            existing.bundleID = existing.bundleID ?? other.bundleID
            existing.packageID = existing.packageID ?? other.packageID
            let identifiers = Set([existing.packageID, other.packageID].compactMap { $0 } + (existing.attributes["Related package identifiers"]?.components(separatedBy: ", ") ?? []))
            if identifiers.count > 1 { existing.attributes["Related package identifiers"] = identifiers.sorted().joined(separator: ", ") }
            existing.vendor = existing.vendor ?? other.vendor
            existing.relatedPaths = Array(Set(existing.relatedPaths + other.relatedPaths)).sorted()
            if existing.installedAt == nil { existing.installedAt = other.installedAt; existing.evidence["installedAt"] = other.evidence["installedAt"] }
            if existing.lastOpenedAt == nil { existing.lastOpenedAt = other.lastOpenedAt; existing.evidence["lastOpenedAt"] = other.evidence["lastOpenedAt"] }
            if existing.sizeBytes == nil { existing.sizeBytes = other.sizeBytes; existing.evidence["sizeBytes"] = other.evidence["sizeBytes"] }
            existing.stale = existing.stale || other.stale
            let managerSources: Set<InstallSource> = [.homebrewCask, .homebrewFormula, .macPorts, .nix, .steam, .setapp, .toolbox]
            if managerSources.contains(existing.primarySource), existing.primarySource == other.primarySource {
                let first = [existing.packageID, existing.attributes["Homebrew executable"], existing.attributes["Prefix"], existing.attributes["Profile"]].compactMap { $0 }.joined(separator: "|")
                let second = [other.packageID, other.attributes["Homebrew executable"], other.attributes["Prefix"], other.attributes["Profile"]].compactMap { $0 }.joined(separator: "|")
                if first != second { existing.attributes["Conflicting manager identities"] = [first, second].sorted().joined(separator: "\n") }
            }
            existing.attributes.merge(other.attributes) { current, _ in current }
            for (key, value) in other.evidence where existing.evidence[key] == nil { existing.evidence[key] = value }
            existing.health = existing.health ?? other.health
            result[id] = existing
        }
        for (id, var item) in result {
            let managers = Set(item.sources.filter { $0.evidence.confidence == .verified && [.homebrewCask, .homebrewFormula, .macPorts, .nix, .steam, .setapp, .toolbox].contains($0.source) }.map(\.source))
            if managers.count > 1 || item.attributes["Conflicting manager identities"] != nil {
                item.primarySource = .unknown
                item.sources.append(.init(.unknown, Evidence("Conflicting ownership evidence", confidence: .unknown)))
            } else if item.primarySource == .unmanaged && uncertainOwnership {
                item.primarySource = .unknown
                item.sources.append(.init(.unknown, Evidence("Ownership scan incomplete", confidence: .unknown, availability: .partial)))
            }
            if item.health == nil { item.health = InstallationHealthClassifier.classify(item) }
            if item.primarySource != .unmanaged { item.sources.removeAll { $0.source == .unmanaged } }
            result[id] = item
        }
        return result.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private static func rank(_ source: InstallSource) -> Int {
        switch source {
        case .steam: 0
        case .homebrewCask, .homebrewFormula, .macPorts, .nix: 1
        case .setapp, .toolbox: 2
        case .appStore: 3
        case .pkg: 4
        case .unmanaged: 5
        case .unknown: 6
        }
    }
}

public struct InventorySnapshot: Codable, Sendable {
    public var schemaVersion = 1
    public var savedAt = Date()
    public var items: [SoftwareItem]
    public var reports: [SourceReport]
    public var observations: [String: [SoftwareItem]]
    public init(items: [SoftwareItem], reports: [SourceReport], observations: [String: [SoftwareItem]] = [:]) {
        self.items = items; self.reports = reports; self.observations = observations
    }
}
public enum InventoryEvent: Sendable {
    case report(SourceReport)
    case items([SoftwareItem])
    case progress(String)
}

public actor InventoryService {
    public init() {}
    public static func scanners(configuration: ScanConfiguration) -> [any SoftwareScanner] {
        var roots = ["/Applications", "~/Applications"] + configuration.customAppDirectories
        if configuration.externalVolumes, let volumes = try? FileSystem.children("/Volumes") {
            roots += volumes.map { $0.appendingPathComponent("Applications").path }
        }
        if !configuration.externalVolumes { roots = roots.filter { !FileSystem.canonical($0).hasPrefix("/Volumes/") } }
        let native = NativeScanner(roots: roots, includeSystem: configuration.showSystem, allowExternal: configuration.externalVolumes)
        return [native, AppStoreScanner(native: native),
                HomebrewScanner(source: .homebrewCask, prefixes: configuration.homebrewPrefixes),
                HomebrewScanner(source: .homebrewFormula, prefixes: configuration.homebrewPrefixes),
                PKGScanner(includeSystem: configuration.showSystem),
                MacPortsScanner(executable: configuration.macPortsExecutable),
                NixScanner(executable: configuration.nixExecutable), SetappScanner(),
                SteamScanner(allowExternal: configuration.externalVolumes), ToolboxScanner(roots: ["~/Applications", "~/Library/Application Support/JetBrains/Toolbox/apps"] + configuration.additionalProviderRoots)]
    }
    public func scan(configuration: ScanConfiguration, previous: InventorySnapshot?, measureSizes: Bool = true,
                     scanners override: [any SoftwareScanner]? = nil,
                     event: @Sendable @escaping (InventoryEvent) async -> Void) async -> InventorySnapshot {
        let scanners = override ?? Self.scanners(configuration: configuration)
        var observations = previous?.observations ?? [:]
        var reports: [SourceReport] = []
        var iterator = scanners.makeIterator()
        await withTaskGroup(of: ScanResult.self) { group in
            func schedule(_ scanner: any SoftwareScanner) {
                group.addTask {
                    await event(.report(SourceReport(scanner.source, .scanning)))
                    do { return try await scanner.scan() }
                    catch is CancellationError { return ScanResult(scanner.source, state: .canceled) }
                    catch { return ScanResult(scanner.source, state: .failed, message: error.localizedDescription) }
                }
            }
            for _ in 0..<3 { if let scanner = iterator.next() { schedule(scanner) } }
            while let result = await group.next() {
                reports.append(result.report)
                let key = result.report.source.rawValue
                if [.completed, .empty, .notInstalled].contains(result.report.state) {
                    observations[key] = result.items
                } else {
                    var retained = observations[key] ?? []
                    for index in retained.indices { retained[index].stale = true }
                    let freshIDs = Set(result.items.map(\.id))
                    observations[key] = retained.filter { !freshIDs.contains($0.id) } + result.items
                }
                await event(.report(result.report))
                let uncertain = reports.contains { [.failed, .canceled, .unsupported].contains($0.state) }
                await event(.items(InventoryMerger.merge(observations.values.flatMap { $0 }, uncertainOwnership: uncertain)))
                if !Task.isCancelled, let scanner = iterator.next() { schedule(scanner) }
            }
        }
        // Sources not reached after cancellation remain visibly canceled, not zero/absent.
        for scanner in scanners where !reports.contains(where: { $0.source == scanner.source }) {
            let report = SourceReport(scanner.source, .canceled)
            reports.append(report); await event(.report(report))
            if let old = observations[scanner.source.rawValue] {
                observations[scanner.source.rawValue] = old.map { var item = $0; item.stale = true; return item }
            }
        }
        let uncertain = reports.contains { [.failed, .canceled, .unsupported].contains($0.state) }
        var items = InventoryMerger.merge(observations.values.flatMap { $0 }, uncertainOwnership: uncertain)
        if measureSizes && !Task.isCancelled {
            await event(.progress("Calculating logical footprints…"))
            var pending = items.indices.filter { items[$0].path != nil }.makeIterator()
            await withTaskGroup(of: (Int, Int64?, Evidence).self) { group in
                func schedule(_ index: Int) {
                    let path = items[index].path!
                    group.addTask {
                        do {
                            let size = try SizeMeasurer.measure(path)
                            return (index, size.complete ? size.bytes : nil, Evidence("Filesystem logical size", availability: size.complete ? .available : .partial, explanation: size.complete ? "Hard links counted once within footprint; shared dependencies and external links excluded" : "Incomplete traversal; partial bytes not presented as a complete size"))
                        } catch is CancellationError { return (index, nil, Evidence("Size scan canceled", confidence: .unknown, availability: .unknown)) }
                        catch { return (index, nil, Evidence("Filesystem", confidence: .unknown, availability: .accessDenied, explanation: error.localizedDescription)) }
                    }
                }
                for _ in 0..<2 { if let index = pending.next() { schedule(index) } }
                while let (index, size, evidence) = await group.next() {
                    items[index].sizeBytes = size; items[index].evidence["sizeBytes"] = evidence
                    await event(.items(items))
                    if !Task.isCancelled, let index = pending.next() { schedule(index) }
                }
            }
        }
        for index in items.indices where items[index].evidence["sizeBytes"]?.availability == .calculating {
            items[index].evidence["sizeBytes"]?.availability = .unknown
        }
        await event(.items(items))
        return InventorySnapshot(items: items, reports: reports, observations: observations)
    }
}
