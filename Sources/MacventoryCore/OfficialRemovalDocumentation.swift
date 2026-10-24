import Foundation

/// Documentation is a fixed HTTPS provider destination, never a command source.
/// Resolve redirects only on explicit user action; never during inventory discovery.
public enum OfficialRemovalDocumentation {
    public static func permits(_ url: URL, original: URL) -> Bool {
        let hosts: Set<String> = ["docs.brew.sh", "guide.macports.org", "nix.dev", "help.steampowered.com", "support.setapp.com", "support.apple.com", "www.jetbrains.com"]
        return url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443) && url.host == original.host && url.host.map(hosts.contains) == true
    }
    public static func resolve(_ original: URL) async throws -> URL {
        guard permits(original, original: original) else { throw ScanError.process("Official documentation identity could not be verified") }
        let delegate = DocumentationRedirectDelegate(original: original)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        config.httpCookieStorage = nil; config.urlCache = nil
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: original); request.httpMethod = "HEAD"
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let final = response.url,
              permits(final, original: original) else { throw ScanError.process("The official documentation link could not be verified or redirected outside its provider. No page was opened.") }
        return final
    }
}
private final class DocumentationRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    let original: URL
    init(original: URL) { self.original = original }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(request.url.map { OfficialRemovalDocumentation.permits($0, original: original) } == true ? request : nil)
    }
}
