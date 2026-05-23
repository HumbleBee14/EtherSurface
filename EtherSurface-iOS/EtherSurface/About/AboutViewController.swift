// AboutViewController.swift — port of AboutActivity.java
//
// Shows the about.html page in a WKWebView, presented as a modal sheet.

import UIKit
import WebKit

final class AboutViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0x3b/255, green: 0x44/255, blue: 0x4b/255, alpha: 1)

        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = view.backgroundColor
        webView.scrollView.backgroundColor = view.backgroundColor
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Try to load bundled about.html, fall back to inline text
        if let htmlURL = Bundle.main.url(forResource: "about", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            let fallback = """
            <html>
            <head><meta name="viewport" content="width=device-width, initial-scale=1">
            <style>body{font-family:-apple-system;color:#eee;background:#3b444b;padding:20px;}</style></head>
            <body>
            <h1>EtherSurface</h1>
            <p>A multi-touch synthesizer originally written in 2014 by Paul Batchelor at CCRMA.</p>
            <p>iOS port &copy; 2026. Sound engine powered by Csound 6.</p>
            <p>Licensed under GPL-3.0.</p>
            </body></html>
            """
            webView.loadHTMLString(fallback, baseURL: nil)
        }

        // Close button
        let closeBtn = UIButton(type: .close)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        ])
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
