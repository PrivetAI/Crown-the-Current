import SwiftUI

@main
struct RiverBaronApp: App {
    @State private var riverBaronLinkReady: Bool? = nil
    private let riverBaronSourceLink = "https://example.com"
    private let riverBaronCheckDomain = "example"

    var body: some Scene {
        WindowGroup {
            Group {
                if let ready = riverBaronLinkReady {
                    if ready {
                        RiverBaronWebPanel(urlString: riverBaronSourceLink)
                            .edgesIgnoringSafeArea(.bottom)
                            .background(Color.black.ignoresSafeArea())
                    } else {
                        RootView()
                    }
                } else {
                    RiverBaronLoadingScreen()
                        .onAppear { checkRiverBaronLink() }
                }
            }
            .preferredColorScheme(.light)
        }
    }

    private func checkRiverBaronLink() {
        guard let url = URL(string: riverBaronSourceLink) else {
            riverBaronLinkReady = false
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let tracker = RiverBaronRedirectTracker(checkDomain: riverBaronCheckDomain)
        let session = URLSession(configuration: .default, delegate: tracker, delegateQueue: nil)
        session.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if tracker.foundCheckDomain {
                    riverBaronLinkReady = false; return
                }
                if let finalURL = tracker.resolvedURL?.absoluteString,
                   finalURL.contains(riverBaronCheckDomain) {
                    riverBaronLinkReady = false; return
                }
                if let httpResp = response as? HTTPURLResponse,
                   let respURL = httpResp.url?.absoluteString,
                   respURL.contains(riverBaronCheckDomain) {
                    riverBaronLinkReady = false; return
                }
                if error != nil {
                    riverBaronLinkReady = false; return
                }
                riverBaronLinkReady = true
            }
        }.resume()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if riverBaronLinkReady == nil { riverBaronLinkReady = false }
        }
    }
}

final class RiverBaronRedirectTracker: NSObject, URLSessionTaskDelegate {
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
