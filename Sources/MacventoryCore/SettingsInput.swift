import Foundation

public enum SettingsInput {
    public static func days(_ value: Int, within range: ClosedRange<Int>) -> Int { min(range.upperBound, max(range.lowerBound, value)) }
    public static func paths(_ text: String, separator: String) -> [String] {
        text.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
public enum AppLinks {
    public static let linkedIn = URL(string: "https://www.linkedin.com/in/vadim-tanel/")!
    public static let githubProfile = URL(string: "https://github.com/vadimtanel/")!
    public static let projectRepository = URL(string: "https://github.com/vadimtanel/MacVentory")!
}
