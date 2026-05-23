// AboutViewController.swift — Etherpad About sheet.
//
// Native UIKit (UILabel / UITextView / UIImageView) — no WKWebView, so
// none of the WebContent / browser-engine-entitlement noise in the
// console. Renders title, developer credit, original-author credit
// for Paul Batchelor's Android version, and a tappable link.

import UIKit

final class AboutViewController: UIViewController {

    private let bgColor   = UIColor(red: 0x3b/255, green: 0x44/255, blue: 0x4b/255, alpha: 1)
    private let textColor = UIColor(red: 0x50/255, green: 0x72/255, blue: 0xa7/255, alpha: 1)
    private let linkColor = UIColor(red: 0xe9/255, green: 0xd6/255, blue: 0x6b/255, alpha: 1)
    private let subtleColor = UIColor(white: 1.0, alpha: 0.55)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.backgroundColor = bgColor
        view.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutMargins = UIEdgeInsets(top: 40, left: 28, bottom: 40, right: 28)
        stack.isLayoutMarginsRelativeArrangement = true
        scroll.addSubview(stack)

        // Title
        let title = UILabel()
        title.text = "Etherpad"
        title.font = .systemFont(ofSize: 36, weight: .bold)
        title.textColor = textColor
        title.textAlignment = .center
        stack.addArrangedSubview(title)

        // Tagline
        let tagline = UILabel()
        tagline.text = "A multi-touch synth for iPhone and iPad"
        tagline.font = .systemFont(ofSize: 16)
        tagline.textColor = textColor
        tagline.textAlignment = .center
        tagline.numberOfLines = 0
        stack.addArrangedSubview(tagline)

        stack.addArrangedSubview(makeSpacer(8))

        // Developer credit
        let devLabel = UILabel()
        devLabel.text = "iOS app by Dinesh (aka HumbleBee)"
        devLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        devLabel.textColor = textColor
        devLabel.textAlignment = .center
        stack.addArrangedSubview(devLabel)

        // Personal site link
        stack.addArrangedSubview(makeLinkView(
            leading: "",
            linkText: "dineshy.com",
            url: URL(string: "https://dineshy.com")!))

        stack.addArrangedSubview(makeSpacer(16))

        // Engine credit
        let engineLabel = UILabel()
        engineLabel.text = "Sound engine: Csound"
        engineLabel.font = .systemFont(ofSize: 15)
        engineLabel.textColor = subtleColor
        engineLabel.textAlignment = .center
        stack.addArrangedSubview(engineLabel)

        stack.addArrangedSubview(makeLinkView(
            leading: "",
            linkText: "csounds.com",
            url: URL(string: "https://www.csounds.com")!))

        stack.addArrangedSubview(makeSpacer(20))

        // One-line credit to the original Android author.
        let creditLabel = UILabel()
        creditLabel.text = "Inspired by the original EtherSurface by Paul Batchelor."
        creditLabel.font = .italicSystemFont(ofSize: 13)
        creditLabel.textColor = subtleColor
        creditLabel.textAlignment = .center
        creditLabel.numberOfLines = 0
        stack.addArrangedSubview(creditLabel)

        // Logo
        if let logo = UIImage(named: "logo_shadow") ?? UIImage(named: "logo") {
            stack.addArrangedSubview(makeSpacer(20))
            let iv = UIImageView(image: logo)
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.heightAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
            stack.addArrangedSubview(iv)
        }

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])

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

    /// Centred paragraph with a single tappable link.
    private func makeLinkView(leading: String, linkText: String, url: URL) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.dataDetectorTypes = []
        tv.textAlignment = .center

        let attr = NSMutableAttributedString(string: leading, attributes: [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: textColor,
        ])
        attr.append(NSAttributedString(string: linkText, attributes: [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: linkColor,
            .link: url,
        ]))
        tv.attributedText = attr
        tv.linkTextAttributes = [.foregroundColor: linkColor]
        return tv
    }

    private func makeSpacer(_ height: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}
