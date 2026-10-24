import Foundation

public struct SourceRemovalGuide: Sendable {
    public var instructions: String
    public var documentation: URL?
    public static func forItem(_ item: SoftwareItem) -> Self {
        let identity = "Selected identity: \(item.packageID ?? item.bundleID ?? "unverified")\(item.version.map { " · " + $0 } ?? ""). Location: \(item.path ?? item.attributes["Expected application paths"] ?? "not verified"). "
        let text: String, link: String?
        switch item.primarySource {
        case .homebrewCask:
            text = "Review the exact cask and prefix in Homebrew. Use its normal cask uninstall workflow; a missing app can cause an error. Do not use force, zap, cleanup or edit Caskroom metadata. If normal removal fails, review Homebrew's official support guidance before repair/reinstall. Hooks may affect privileged services or shared components. Refresh Installation Status after completing the external workflow."
            link = "https://docs.brew.sh/Manpage#uninstall-remove-rm-options-installed_formulainstalled_cask-"
        case .homebrewFormula:
            text = "Review installed dependents and all installed versions in this Homebrew prefix. Use Homebrew's formula uninstall operation for this exact token. Do not override dependencies, remove other packages or run cleanup."
            link = "https://docs.brew.sh/Manpage"
        case .macPorts:
            text = "This installation did not meet the exact direct-operation checks shown above. Review its port, installed version/variants, prefix and dependents in MacPorts. Direct execution is supported for verified eligible installations; privileged execution requires the signed helper and macOS approval. Do not use recursive dependent removal or force. Authentication stays in the official tool."
            link = "https://guide.macports.org/#using.port.uninstall"
        case .nix:
            text = "Review the exact profile and element with Nix. For a modern imperative profile, use nix profile remove for the exact element in that profile. Legacy and declarative installations require their own configuration workflow. Direct execution requires a verified user-owned modern mutable profile and supported named-element contract. The preview explains which requirement is missing for this installation. Never delete store paths or run garbage collection to remove a selected app."
            link = "https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-profile-remove.html"
        case .steam:
            text = "Open Steam → Library, match the selected App ID and library, then Manage → Uninstall. Keep saves, shared libraries and user-created content. Afterwards refresh this inventory; launching Steam is not proof of removal."
            link = "https://help.steampowered.com/"
        case .setapp:
            text = "No documented targeted uninstall command or reliable uninstall deep link was established for this installation. Open Setapp → On This Mac, select the exact app, and review its Uninstall options. Choose application-only removal to retain data. Review any wider scope yourself; do not uninstall Setapp to remove one application. Refresh after completion."
            link = "https://support.setapp.com/"
        case .toolbox:
            text = "The documented macOS workflow is interactive inside Toolbox; no supported exact-version uninstall API/CLI or targeted uninstall deep link was established. Open JetBrains Toolbox, select this exact IDE version and installation path, then use its Uninstall action. Preserve other installed versions and projects. Refresh after completion."
            link = "https://www.jetbrains.com/help/idea/uninstall.html"
        case .appStore:
            text = "Quit the app and use Finder → Move to Trash if macOS permits it. Local App Store receipt presence is not authenticated purchase evidence. Account purchase records, subscriptions and documents remain. Required macOS apps cannot be removed."
            link = "https://support.apple.com/102610"
        case .pkg:
            text = "Review the vendor's signed uninstaller or official removal instructions. A receipt is historical evidence, not an inverse install script. pkgutil --forget does not uninstall software. No payload deletion or receipt cleanup is automated."
            link = "https://support.apple.com/102610"
        case .unmanaged:
            text = "Check for a trusted vendor uninstaller or an uninstall action inside the application first. If none is established, eligible standalone bundles can be moved to recoverable Trash after ownership checks. That removes only the bundle; external components and data remain."
            link = "https://support.apple.com/102610"
        case .unknown:
            text = "Refresh all ownership sources and review their evidence. No removal mechanism is selected while ownership is incomplete or conflicting."
            link = nil
        }
        return .init(instructions: identity + text, documentation: link.flatMap(URL.init(string:)))
    }
}
public enum CaskEffectReview {
    public static func allowsAutomation(_ receipt: [String: Any], item: SoftwareItem) -> Bool {
        let flight = receipt["uninstall_flight_blocks"]
        guard flight == nil || (flight as? Bool) == false,
              let artifacts = receipt["uninstall_artifacts"] as? [[String: Any]], !artifacts.isEmpty else { return false }
        return artifacts.allSatisfy { artifact in
            guard Set(artifact.keys).isSubset(of: ["app", "font", "binary", "zap", "uninstall"]) else { return false }
            guard let raw = artifact["uninstall"] else { return true }
            guard let directives = raw as? [[String: Any]], !directives.isEmpty, let bundleID = item.bundleID else { return false }
            // Official, declarative quit of this exact bundle identity is reviewed.
            // Scripts, signals, privileged services and shared deletion require handoff.
            return directives.allSatisfy { directive in
                guard Set(directive.keys) == ["quit"] else { return false }
                let targets = (directive["quit"] as? [String]) ?? (directive["quit"] as? String).map { [$0] } ?? []
                return !targets.isEmpty && targets.allSatisfy { $0 == bundleID }
            }
        }
    }
    public static func hasQuitDirective(_ receipt: [String: Any]) -> Bool {
        (receipt["uninstall_artifacts"] as? [[String: Any]] ?? []).contains { ($0["uninstall"] as? [[String: Any]])?.contains { $0["quit"] != nil } == true }
    }

    public static func describe(_ receipt: [String: Any]) -> String {
        let keys = Set((receipt["uninstall_artifacts"] as? [[String: Any]] ?? []).flatMap { $0.keys }).subtracting(["zap"])
        var effects = [String]()
        if keys.contains("uninstall") { effects.append("vendor uninstall directives that may run scripts, remove files or change services") }
        if keys.contains("pkg") || keys.contains("installer") { effects.append("installer-managed components") }
        if receipt["uninstall_flight_blocks"] != nil { effects.append("executable uninstall flight blocks") }
        if effects.isEmpty { effects.append("additional artifacts: " + keys.sorted().joined(separator: ", ")) }
        return "Homebrew supports this cask's official uninstall workflow. Its installed metadata declares " + effects.joined(separator: "; ") + "."
    }
}
