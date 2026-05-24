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

        stack.addArrangedSubview(makeSpacer(16))

        // Visualizations
        let visHeader = UILabel()
        visHeader.text = "Visualizations"
        visHeader.font = .systemFont(ofSize: 15, weight: .semibold)
        visHeader.textColor = textColor
        visHeader.textAlignment = .center
        stack.addArrangedSubview(visHeader)

        stack.addArrangedSubview(makeEffectGrid())

        stack.addArrangedSubview(makeSpacer(20))

        // Performance tip
        let tip = UILabel()
        tip.text = "Tip: for live performance, enable Guided Access (Settings → Accessibility) to disable system gestures."
        tip.font = .italicSystemFont(ofSize: 13)
        tip.textColor = subtleColor
        tip.textAlignment = .center
        tip.numberOfLines = 0
        stack.addArrangedSubview(tip)

        stack.addArrangedSubview(makeSpacer(12))

        // Developer credit
        let devLabel = UILabel()
        devLabel.text = "iOS app by Dinesh"
        devLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        devLabel.textColor = textColor
        devLabel.textAlignment = .center
        stack.addArrangedSubview(devLabel)

        // Personal site link
        stack.addArrangedSubview(makeLinkView(
            leading: "",
            linkText: "dineshy.com",
            url: URL(string: "https://dineshy.com")!))

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

    // MARK: - Visualization chips

    private var chips: [(UIButton, VisualEffects)] = []

    private func makeEffectGrid() -> UIView {
        chips.removeAll()
        let items: [(String, VisualEffects)] = [("None", .none)]
            + VisualEffects.all.map { ($0.label, $0) }

        let cols = 3
        let outer = UIStackView()
        outer.axis = .vertical
        outer.alignment = .center
        outer.spacing = 8

        var row: UIStackView?
        for (i, item) in items.enumerated() {
            if i % cols == 0 {
                row = UIStackView()
                row!.axis = .horizontal
                row!.spacing = 8
                row!.alignment = .center
                outer.addArrangedSubview(row!)
            }
            let chip = makeChip(label: item.0, effect: item.1)
            row!.addArrangedSubview(chip)
            chips.append((chip, item.1))
        }
        return outer
    }

    private func makeChip(label: String, effect: VisualEffects) -> UIButton {
        var cfg = UIButton.Configuration.plain()
        cfg.attributedTitle = chipAttributed(label: label, isOn: isChipOn(effect))
        cfg.baseForegroundColor = textColor
        cfg.background.cornerRadius = 10
        cfg.background.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        let btn = UIButton(configuration: cfg, primaryAction: UIAction { [weak self] _ in
            self?.toggle(effect)
        })
        return btn
    }

    private func isChipOn(_ effect: VisualEffects) -> Bool {
        effect.rawValue == 0 ? VisualEffects.current.isEmpty
                             : VisualEffects.current.contains(effect)
    }

    /// Bigger checkbox glyph + smaller label text, side-by-side in one
    /// attributed string so the box and label share a single tap target.
    private func chipAttributed(label: String, isOn: Bool) -> AttributedString {
        var box = AttributedString(isOn ? "☑ " : "☐ ")
        box.font = .systemFont(ofSize: 22)
        box.foregroundColor = textColor
        var name = AttributedString(label)
        name.font = .systemFont(ofSize: 14)
        name.foregroundColor = textColor
        return box + name
    }

    private func toggle(_ effect: VisualEffects) {
        if effect.rawValue == 0 {
            VisualEffects.current = .none
        } else {
            var cur = VisualEffects.current
            if cur.contains(effect) { cur.remove(effect) } else { cur.insert(effect) }
            VisualEffects.current = cur
        }
        refreshChips()
    }

    private func refreshChips() {
        for (btn, effect) in chips {
            let label = effect.rawValue == 0 ? "None" : effect.label
            var cfg = btn.configuration
            cfg?.attributedTitle = chipAttributed(label: label, isOn: isChipOn(effect))
            btn.configuration = cfg
        }
    }
}
