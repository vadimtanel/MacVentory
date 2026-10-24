import Foundation
import Darwin

public enum LeftoverScanState: String, Sendable { case notScanned, scanning, completed, partial, failed, cancelled }
public struct LeftoverScanIssue: Sendable, Hashable, Identifiable {
    public var id: String { location + "\u{0}" + reason }
    public var location: String
    public var reason: String
    public var permissionDenied: Bool
    public var retryable: Bool
    public init(location: String, reason: String, permissionDenied: Bool = false, retryable: Bool = true) {
        self.location = location; self.reason = reason; self.permissionDenied = permissionDenied; self.retryable = retryable
    }
    public var message: String { location + ": " + reason }
}
public struct LeftoverScanResult: Sendable {
    public var groups: [AppDataDiscoveryResult]
    public var messages: [String]
    public var issues: [LeftoverScanIssue]
    public var state: LeftoverScanState
    public init(groups: [AppDataDiscoveryResult], messages: [String], issues: [LeftoverScanIssue] = [], state: LeftoverScanState) {
        self.groups = groups; self.messages = messages; self.issues = issues; self.state = state
    }
}
public protocol AppDataDirectoryListing: Sendable {
    func children(_ path: String) throws -> [URL]
    func boundedChildren(_ path: String, limit: Int) throws -> [URL]
}
public extension AppDataDirectoryListing {
    func boundedChildren(_ path: String, limit: Int) throws -> [URL] { Array(try children(path).prefix(limit)) }
}
public struct NativeAppDataDirectoryListing: AppDataDirectoryListing {
    public init() {}
    public func children(_ path: String) throws -> [URL] { try FileSystem.children(path) }
    public func boundedChildren(_ path: String, limit: Int) throws -> [URL] {
        // Direct POSIX enumeration keeps both memory and traversal bounded and surfaces
        // access errors; no descendant file contents are opened by enumeration.
        guard let directory = opendir(path) else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { closedir(directory) }
        var result: [URL] = []
        while result.count < limit {
            try Task.checkCancellation()
            errno = 0
            guard let entry = readdir(directory) else {
                if errno != 0 { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }; break
            }
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in pointer.withMemoryRebound(to: CChar.self, capacity: 1024) { String(cString: $0) } }
            if name != ".", name != ".." { result.append(URL(fileURLWithPath: path).appendingPathComponent(name)) }
        }
        return result
    }
}

/// Enumerates only direct children of known Library sources. An unknown directory is not
/// labelled orphaned: retrospective exact-ID leads remain possible until ownership is known.
public struct LeftoverDiscoveryService: Sendable {
    public var discovery: AppDataDiscoveryService
    private let listing: any AppDataDirectoryListing
    public init(discovery: AppDataDiscoveryService = AppDataDiscoveryService(), listing: any AppDataDirectoryListing = NativeAppDataDirectoryListing()) { self.discovery = discovery; self.listing = listing }
    public static func validBundleID(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count >= 3 && parts.allSatisfy { !$0.isEmpty && $0.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_").contains($0) } } && value.count < 255
    }
    private func manifestIdentity(at directory: URL) -> (id: String, name: String?)? {
        for filename in ["Info.plist", "package.json"] {
            let url = directory.appendingPathComponent(filename)
            guard url.path == FileSystem.canonical(url.path), let attributes = try? FileManager.default.attributesOfItem(atPath: url.path), attributes[.type] as? FileAttributeType == .typeRegular,
                  (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 1_048_576, let data = try? Data(contentsOf: url) else { continue }
            let metadata = filename == "Info.plist" ? (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any] : (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let id = metadata?["CFBundleIdentifier"] as? String ?? (metadata?["build"] as? [String: Any])?["appId"] as? String
            if let id, Self.validBundleID(id) {
                let name = metadata?["CFBundleDisplayName"] as? String ?? metadata?["CFBundleName"] as? String ?? metadata?["productName"] as? String ?? (metadata?["build"] as? [String: Any])?["productName"] as? String
                return (id, name.flatMap { !$0.isEmpty && !$0.contains("/") && $0.count < 256 ? $0 : nil })
            }
        }
        return nil
    }
    public func scan(records: [RemovedApplicationRecord], installed: [SoftwareItem], identityIndex: ApplicationIdentityIndex = .init(), discoverPersonalFolders: Bool = false, registeredApplication: @Sendable (String) -> Bool = { _ in false }) -> LeftoverScanResult {
        let deadline = Date().addingTimeInterval(30)
        let installedIDs = Set(installed.compactMap(\.bundleID))
        var identities: [String: ApplicationIdentity] = [:], retrospective = Set<String>()
        var manifestNames: [String: Set<String>] = [:]
        var manifestDisplayNames: [String: Set<String>] = [:]
        for record in records {
            if let id = record.bundleID, Self.validBundleID(id), !installedIDs.contains(id) { identities[id] = ApplicationIdentity(record: record) }
        }
        var messages: [String] = [], issues: [LeftoverScanIssue] = [], readableSources = 0
        let sources = ["Application Support", "Caches", "Preferences", "Containers", "Saved Application State", "Logs", "WebKit", "Group Containers"]
        for source in sources {
            if Task.isCancelled { return .init(groups: [], messages: ["Scan cancelled; previous results need refreshing."], state: .cancelled) }
            let root = discovery.library.appendingPathComponent(source)
            var urls: [URL]
            do { urls = try listing.children(root.path); readableSources += 1 }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { readableSources += 1; continue }
            catch {
                let permissionDenied = (error as NSError).code == NSFileReadNoPermissionError || error is ScanError
                issues.append(.init(location: source, reason: error.localizedDescription, permissionDenied: permissionDenied))
                continue
            }
            if urls.count > 5000 {
                let issue = LeftoverScanIssue(location: source, reason: "Only the first 5,000 entries were inspected.")
                issues.append(issue); urls = Array(urls.prefix(5000))
            }
            for url in urls {
                var id = url.lastPathComponent
                if source == "Preferences" { guard url.pathExtension == "plist" else { continue }; id = url.deletingPathExtension().lastPathComponent }
                if source == "Saved Application State" { guard url.pathExtension == "savedState" else { continue }; id = url.deletingPathExtension().lastPathComponent }
                if ["Application Support", "Caches"].contains(source), let manifest = manifestIdentity(at: url), (!Self.validBundleID(id) || id == manifest.id) {
                    id = manifest.id
                    manifestNames[id, default: []].insert(url.lastPathComponent)
                    if let name = manifest.name { manifestDisplayNames[id, default: []].insert(name) }
                }
                guard Self.validBundleID(id), !id.hasPrefix("com.apple."), !id.hasPrefix("org.vadimtanel.Macventory"), !installedIDs.contains(id), !registeredApplication(id) else { continue }
                if identities[id] == nil {
                    identities[id] = ApplicationIdentity(name: id, bundleID: id, evidence: "Exact identifier found in \(source); no historical installation or exclusive ownership has been established.", installed: false)
                    retrospective.insert(id)
                }
                // Preference dictionaries sometimes supply a display name. This is a bounded
                // local metadata correlation, not a substring/vendor-prefix guess.
                if source == "Preferences", let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   attributes[.type] as? FileAttributeType == .typeRegular,
                   (attributes[.size] as? NSNumber)?.intValue ?? Int.max <= 1_048_576,
                   let data = try? Data(contentsOf: url), let metadata = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                   metadata["CFBundleIdentifier"] as? String == id, let name = metadata["CFBundleName"] as? String, !name.contains("/"), !name.isEmpty {
                    identities[id]?.name = name
                    identities[id]?.namingSource = "Preference CFBundleIdentifier and CFBundleName"
                    identities[id]?.namingConfidence = "Local metadata; original bundle unavailable"
                }
            }
        }
        var groups: [AppDataDiscoveryResult] = []
        if identities.count > 300 { messages.append("Discovery is limited to 300 identity groups per scan.") }
        for (id, identity) in identities.sorted(by: { $0.key < $1.key }).prefix(300) {
            if Date() > deadline { messages.append("Discovery reached its 30-second time budget. Results are partial; no cleanup is enabled."); break }
            if Task.isCancelled { return .init(groups: groups, messages: messages + ["Scan cancelled; results are incomplete."], state: .cancelled) }
            guard !registeredApplication(id), !installedIDs.contains(id) else { continue }
            // Resolve a display name separately from the identity used to discover targets.
            // Historical naming must not introduce additional name-matched filesystem paths.
            var result = discovery.discover(for: identity)
            result.identity = identityIndex.resolve(identity)
            // A known extension of an installed parent is active application data,
            // even if the extension itself has no standalone Launch Services record.
            if let parent = result.identity.parentBundleID, installedIDs.contains(parent) || registeredApplication(parent) { continue }
            if result.identity.name == id, let names = manifestDisplayNames[id], names.count == 1, let name = names.first {
                result.identity.name = name
                result.identity.namingSource = "Local manifest with matching application identifier"
                result.identity.namingConfidence = "Local metadata; original bundle unavailable"
            }
            for name in manifestNames[id] ?? [] {
                var named = identity; named.name = name
                let existing = Set(result.candidates.map(\.path))
                result.candidates.append(contentsOf: discovery.discover(for: named).candidates.filter { !existing.contains($0.path) })
            }
            let recordIsFresh = records.contains { $0.bundleID == id && $0.removalDate <= Date().addingTimeInterval(300) && Date().timeIntervalSince($0.removalDate) < 30 * 86400 }
            if retrospective.contains(id) || !recordIsFresh {
                result.candidates = result.candidates.map { candidate in
                    var candidate = candidate
                    if candidate.classification == .verified {
                        candidate.classification = .possible; candidate.requiresExplicitSelection = true
                        candidate.explanation += " Fresh exclusive ownership evidence is unavailable; association is unverified and requires individual review."
                    }
                    return candidate
                }
            }
            result.candidates = result.candidates.map { candidate in
                var candidate = candidate
                if installed.contains(where: { app in candidate.path == discovery.library.appendingPathComponent("Application Support/" + app.name).path || candidate.path == discovery.library.appendingPathComponent("Caches/" + app.name).path }) {
                    candidate.classification = .protected; candidate.requiresExplicitSelection = true; candidate.explanation += " This location is also associated with an installed application."
                }
                return candidate
            }
            messages.append(contentsOf: result.messages)
            if !result.candidates.isEmpty { groups.append(result) }
        }
        if discoverPersonalFolders, !Task.isCancelled {
            var known = groups.map(\.identity) + records.map(ApplicationIdentity.init(record:))
            known += identityIndex.entries.map { entry in identityIndex.resolve(.init(name: entry.bundleID, bundleID: entry.bundleID, evidence: "Local identity history", installed: false)) }
            known = known.map { identityIndex.resolve($0) }
            known = known.filter { identity in
                guard let id = identity.bundleID else { return false }
                return !id.hasPrefix("com.apple.") && !id.hasPrefix("org.vadimtanel.Macventory") && !installedIDs.contains(id) && !registeredApplication(id) && !(identity.parentBundleID.map { installedIDs.contains($0) || registeredApplication($0) } ?? false)
            }
            let personal = PersonalFolderDiscoveryService(discovery: discovery, listing: listing).scan(identities: known)
            for group in personal.groups {
                if let index = groups.firstIndex(where: { $0.identity.id == group.identity.id }) { groups[index].candidates += group.candidates }
                else { groups.append(group) }
            }
            issues += personal.issues
        }
        let allMessages = Array(Set(messages + issues.map(\.message))).sorted()
        return .init(groups: groups, messages: allMessages, issues: Array(Set(issues)).sorted { $0.location < $1.location }, state: issues.isEmpty && messages.isEmpty ? .completed : readableSources == 0 ? .failed : .partial)
    }
}

public enum LeftoverGroupingMode: String, CaseIterable, Sendable { case application, identifier }

public struct LeftoverCandidateReference: Identifiable, Sendable {
    public var id: String { candidate.id }
    public var candidate: AppDataCandidate
    public var identity: ApplicationIdentity
    public init(candidate: AppDataCandidate, identity: ApplicationIdentity) { self.candidate = candidate; self.identity = identity }
}

/// Presentation-only grouping. Candidates retain their own identities so grouping never
/// broadens deletion scope or changes their eligibility.
public struct LeftoverPresentationGroup: Identifiable, Sendable {
    public var id: String
    public var name: String
    public var fallbackIdentifier: String?
    public var identities: [ApplicationIdentity]
    public var candidates: [LeftoverCandidateReference]
    public init(id: String, name: String, fallbackIdentifier: String?, identities: [ApplicationIdentity], candidates: [LeftoverCandidateReference]) {
        self.id = id; self.name = name; self.fallbackIdentifier = fallbackIdentifier; self.identities = identities; self.candidates = candidates
    }
    public var highestClassification: AppDataClassification {
        candidates.map(\.candidate.classification).max { lhs, rhs in
            let rank: [AppDataClassification: Int] = [.verified: 0, .possible: 1, .protected: 2]
            return rank[lhs, default: 0] < rank[rhs, default: 0]
        } ?? .possible
    }
    public var measuredSize: Int64 { candidates.compactMap(\.candidate.sizeBytes).reduce(0, +) }
    public var hasIncompleteSize: Bool { candidates.contains { !$0.candidate.sizeComplete || $0.candidate.sizeBytes == nil } }
    public static func make(from results: [AppDataDiscoveryResult], mode: LeftoverGroupingMode) -> [LeftoverPresentationGroup] {
        let usable = results.filter { !$0.candidates.isEmpty }
        switch mode {
        case .identifier:
            return usable.map { result in
                .init(id: "identifier:" + result.identity.id, name: result.identity.name, fallbackIdentifier: result.identity.bundleID, identities: [result.identity], candidates: result.candidates.map { .init(candidate: $0, identity: result.identity) })
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .application:
            var buckets: [String: [AppDataDiscoveryResult]] = [:]
            for result in usable {
                let parent = result.identity.parentApplicationName == nil ? nil : result.identity.parentBundleID
                let key = "application:" + (parent ?? result.identity.id)
                buckets[key, default: []].append(result)
            }
            return buckets.map { key, values in
                let identities = values.map(\.identity).sorted { lhs, rhs in
                    if lhs.parentBundleID == rhs.bundleID { return false }
                    if rhs.parentBundleID == lhs.bundleID { return true }
                    return lhs.id < rhs.id
                }
                let references: [LeftoverCandidateReference] = values.flatMap { result in result.candidates.map { LeftoverCandidateReference(candidate: $0, identity: result.identity) } }
                let parentName = identities.first { "application:" + ($0.parentBundleID ?? "") == key }?.parentApplicationName
                return .init(id: key, name: parentName ?? identities[0].name, fallbackIdentifier: identities[0].bundleID, identities: identities, candidates: references)
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
