import UIKit
import WebKit

final class WebDefenderManager {
    private let suspiciousExtensions = [".exe", ".apk", ".msi", ".dmg", ".bat", ".cmd", ".scr", ".jar"]

    func isSafeURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        let value = url.absoluteString.lowercased()

        if value.contains("javascript:") || value.contains("data:") || value.contains("file:") {
            return false
        }

        return !suspiciousExtensions.contains { value.contains($0) }
    }

    func statusText(for url: URL?) -> String {
        isSafeURL(url) ? "WebDefender: Protected" : "WebDefender: Blocked"
    }
}

final class BrowserViewController: UIViewController {
    private let toolbar = UIToolbar()
    private let urlField = UITextField()
    private let statusLabel = UILabel()
    private let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let core = BrowserCoreController()
    private let defender = WebDefenderManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureWebView()
        configureToolbar()
        loadInitialPage()
    }

    private func configureWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureToolbar() {
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        let backButton = UIBarButtonItem(title: "←", style: .plain, target: self, action: #selector(goBack))
        let forwardButton = UIBarButtonItem(title: "→", style: .plain, target: self, action: #selector(goForward))
        let reloadButton = UIBarButtonItem(title: "↻", style: .plain, target: self, action: #selector(reloadPage))
        let downloadButton = UIBarButtonItem(title: "Download", style: .plain, target: self, action: #selector(downloadCurrentPage))

        statusLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = .systemGreen
        statusLabel.text = defender.statusText(for: webView.url)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 1
        let statusItem = UIBarButtonItem(customView: statusLabel)

        urlField.borderStyle = .roundedRect
        urlField.placeholder = "Search or enter URL"
        urlField.returnKeyType = .go
        urlField.autocapitalizationType = .none
        urlField.autocorrectionType = .no
        urlField.delegate = self

        let addressItem = UIBarButtonItem(customView: urlField)
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.setItems([backButton, forwardButton, reloadButton, downloadButton, statusItem, flexible, addressItem], animated: false)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func loadInitialPage() {
        let url = URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: url))
    }

    @objc private func goBack() {
        webView.goBack()
    }

    @objc private func goForward() {
        webView.goForward()
    }

    @objc private func reloadPage() {
        webView.reload()
    }

    @objc private func downloadCurrentPage() {
        guard let url = webView.url else { return }

        if !defender.isSafeURL(url) {
            let alert = UIAlertController(title: "WebDefender", message: "This download is blocked because it looks unsafe.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let fileName = url.lastPathComponent.isEmpty ? "download.bin" : url.lastPathComponent
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)

        let task = URLSession.shared.downloadTask(with: url) { location, _, error in
            guard let location, error == nil else { return }
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                print("Download failed: \(error)")
            }
        }
        task.resume()

        let alert = UIAlertController(title: "Download started", message: "Saved to your Files/Documents directory.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func navigate(to rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalized: String
        let lower = trimmed.lowercased()
        if lower.contains("://") {
            normalized = trimmed
        } else if lower.contains(".") || lower.contains("/") {
            normalized = "https://" + trimmed
        } else {
            normalized = "https://www.google.com/search?q=" + trimmed.replacingOccurrences(of: " ", with: "+")
        }

        if let url = URL(string: normalized) {
            webView.load(URLRequest(url: url))
        }
    }
}

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigate(to: textField.text ?? "")
        textField.resignFirstResponder()
        return true
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlField.text = webView.url?.absoluteString ?? ""
        statusLabel.text = defender.statusText(for: webView.url)
        statusLabel.textColor = defender.isSafeURL(webView.url) ? .systemGreen : .systemRed
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if !defender.isSafeURL(url) {
            let alert = UIAlertController(title: "WebDefender", message: "This page was blocked for security reasons.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }
}

final class BrowserCoreController {
    init() {
        // This is the native app bridge point for C++/Rust logic.
        // The actual C++ browser engine and Rust safety modules would be wired here.
    }
}
