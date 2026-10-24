import Foundation

public struct PersonalFolderDiscoveryService: Sendable {
    public var discovery: AppDataDiscoveryService
    public var listing: any AppDataDirectoryListing
    public init(discovery: AppDataDiscoveryService, listing: any AppDataDirectoryListing = NativeAppDataDirectoryListing()) { self.discovery = discovery; self.listing = listing }
    public func scan(identities: [ApplicationIdentity]) -> (groups: [AppDataDiscoveryResult], issues: [LeftoverScanIssue]) {
        var groups: [AppDataDiscoveryResult] = [], issues: [LeftoverScanIssue] = []
        let deadline = Date().addingTimeInterval(5)
        var measuredFolders = 0
        let known = Array(Dictionary(identities.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.id < $1.id }.prefix(300)
        func folded(_ value: String) -> String { value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
        func association(_ identity: ApplicationIdentity, folder: String) -> String? {
            let name = folded(folder)
            if !identity.name.isEmpty, identity.name != identity.bundleID, folded(identity.name) == name { return "The folder name matches \(identity.name)." }
            guard let id = identity.bundleID else { return nil }
            if folded(id) == name { return "The folder name matches the application identifier." }
            // A bounded identifier lead is useful even when the original display name
            // was lost. It confers no naming confidence, parentage or ownership.
            let component = folded(id.split(separator: ".").last.map(String.init) ?? "")
            let broadNames: Set<String> = ["data", "cache", "caches", "logs", "files", "shared", "backup", "backups", "support", "documents", "downloads", "desktop"]
            if name.count >= 4, !broadNames.contains(name), component.hasPrefix(name), component.count - name.count <= 16 {
                return "The folder name resembles the identifier component \(component); this association is uncertain."
            }
            return nil
        }
        for location in ["Documents", "Downloads", "Desktop"] {
            let root = discovery.home.appendingPathComponent(location)
            guard root.path == FileSystem.canonical(root.path) else {
                issues.append(.init(location: location, reason: "This personal location is linked. It was not scanned.", retryable: false)); continue
            }
            let urls: [URL]
            do { urls = try listing.boundedChildren(root.path, limit: 501) }
            catch let error as NSError where error.domain == NSPOSIXErrorDomain && error.code == 2 { continue }
            catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) { continue }
            catch {
                let denied = (error as NSError).code == NSFileReadNoPermissionError || (error as NSError).code == 13
                issues.append(.init(location: location, reason: error.localizedDescription, permissionDenied: denied)); continue
            }
            if urls.count > 500 { issues.append(.init(location: location, reason: "Only the first 500 direct children were considered.")) }
            for url in urls.sorted(by: { $0.path < $1.path }).prefix(500) {
                if Task.isCancelled || Date() > deadline || measuredFolders >= 30 { issues.append(.init(location: location, reason: "Personal-folder discovery reached its time or 30-folder measurement limit.")); return (groups, issues) }
                // Listings supplied by providers/tests cannot introduce nested/out-of-root paths.
                guard url.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL else { continue }
                let matches = known.filter { association($0, folder: url.lastPathComponent) != nil }
                guard !matches.isEmpty else { continue }
                measuredFolders += 1
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values?.isDirectory == true || values?.isSymbolicLink == true else { continue }
                var candidate: AppDataCandidate
                if matches.count == 1, let safe = discovery.manualCandidate(path: url.path, maximumEntries: 500) {
                    candidate = safe; candidate.category = "Personal Folder"
                    candidate.explanation = (association(matches[0], folder: url.lastPathComponent) ?? "Possible folder association.") + " This is not exclusive ownership. Manual review is required; personal files may be lost."
                } else {
                    candidate = .init(path: url.path, category: "Personal Folder", classification: .protected, explanation: matches.count > 1 ? "Several known applications match this folder name. Shared ownership is unresolved." : "This folder is linked, inaccessible or unsafe. Cleanup is blocked.", sizeBytes: nil, sizeComplete: false, requiresExplicitSelection: true, allowedRoot: root.path, identity: FileIdentity(path: url.path))
                }
                let identity = matches.count == 1 ? matches[0] : ApplicationIdentity(name: "Shared folder: " + url.lastPathComponent, bundleID: nil, evidence: "Ambiguous personal folder association", installed: false)
                if let index = groups.firstIndex(where: { $0.identity.id == identity.id }) { groups[index].candidates.append(candidate) }
                else { groups.append(.init(identity: identity, candidates: [candidate])) }
            }
        }
        return (groups, issues)
    }
}
