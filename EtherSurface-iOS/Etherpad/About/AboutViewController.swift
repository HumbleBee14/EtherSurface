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
        stack.alignment = .fill
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.layoutMargins = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.isLayoutMarginsRelativeArrangement = true
        scroll.addSubview(stack)

        let title = UILabel()
        title.text = "Etherpad"
        title.font = .systemFont(ofSize: 22, weight: .bold)
        title.textColor = textColor
        title.textAlignment = .center
        stack.addArrangedSubview(title)

        let tagline = UILabel()
        tagline.text = "A multi-touch synth for iPhone and iPad"
        tagline.font = .systemFont(ofSize: 13)
        tagline.textColor = textColor
        tagline.textAlignment = .center
        tagline.numberOfLines = 0
        stack.addArrangedSubview(tagline)

        stack.addArrangedSubview(makeSpacer(8))

        let visHeaderRow = UIStackView()
        visHeaderRow.axis = .horizontal
        visHeaderRow.alignment = .center
        visHeaderRow.spacing = 12

        let visHeader = UILabel()
        visHeader.text = "Visualizations"
        visHeader.font = .systemFont(ofSize: 15, weight: .semibold)
        visHeader.textColor = textColor
        visHeaderRow.addArrangedSubview(visHeader)

        visHeaderRow.addArrangedSubview(UIView())

        let visToggle = UISwitch()
        visToggle.isOn = !VisualEffects.current.isEmpty
        visToggle.addTarget(self, action: #selector(visualizationsMasterToggled(_:)),
                            for: .valueChanged)
        visHeaderRow.addArrangedSubview(visToggle)

        let headerContainer = UIView()
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        visHeaderRow.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(visHeaderRow)
        NSLayoutConstraint.activate([
            visHeaderRow.topAnchor.constraint(equalTo: headerContainer.topAnchor),
            visHeaderRow.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            visHeaderRow.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            visHeaderRow.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
        ])
        stack.addArrangedSubview(headerContainer)

        let grid = makeEffectGrid()
        effectGridView = grid
        grid.isHidden = !visToggle.isOn
        stack.addArrangedSubview(grid)

        stack.addArrangedSubview(makeSpacer(12))

        let splitRow = UIStackView()
        splitRow.axis = .horizontal
        splitRow.alignment = .center
        splitRow.spacing = 12

        let splitHeader = UILabel()
        splitHeader.text = "Split Mode"
        splitHeader.font = .systemFont(ofSize: 15, weight: .semibold)
        splitHeader.textColor = textColor
        splitRow.addArrangedSubview(splitHeader)

        splitRow.addArrangedSubview(UIView())

        let splitToggle = UISwitch()
        splitToggle.isOn = SplitModeController.isEnabled
        splitToggle.addTarget(self, action: #selector(splitModeToggled(_:)), for: .valueChanged)
        splitRow.addArrangedSubview(splitToggle)

        let splitContainer = UIView()
        splitContainer.translatesAutoresizingMaskIntoConstraints = false
        splitRow.translatesAutoresizingMaskIntoConstraints = false
        splitContainer.addSubview(splitRow)
        NSLayoutConstraint.activate([
            splitRow.topAnchor.constraint(equalTo: splitContainer.topAnchor),
            splitRow.bottomAnchor.constraint(equalTo: splitContainer.bottomAnchor),
            splitRow.leadingAnchor.constraint(equalTo: splitContainer.leadingAnchor, constant: 16),
            splitRow.trailingAnchor.constraint(equalTo: splitContainer.trailingAnchor, constant: -16),
        ])
        stack.addArrangedSubview(splitContainer)

        stack.addArrangedSubview(makeSpacer(12))

        stack.addArrangedSubview(makeLinkView(
            leading: "Developer: Dinesh (",
            linkText: "dineshy.com",
            url: URL(string: "https://dineshy.com")!,
            trailing: ")"))

        let creditLabel = UILabel()
        creditLabel.text = "Credits: Inspired by Paul Batchelor's EtherSurface Android app."
        creditLabel.font = .italicSystemFont(ofSize: 13)
        creditLabel.textColor = subtleColor
        creditLabel.textAlignment = .left
        creditLabel.numberOfLines = 0

        let creditContainer = UIView()
        creditContainer.translatesAutoresizingMaskIntoConstraints = false
        creditLabel.translatesAutoresizingMaskIntoConstraints = false
        creditContainer.addSubview(creditLabel)
        NSLayoutConstraint.activate([
            creditLabel.topAnchor.constraint(equalTo: creditContainer.topAnchor),
            creditLabel.bottomAnchor.constraint(equalTo: creditContainer.bottomAnchor),
            creditLabel.leadingAnchor.constraint(equalTo: creditContainer.leadingAnchor, constant: 16),
            creditLabel.trailingAnchor.constraint(equalTo: creditContainer.trailingAnchor, constant: -16),
        ])
        stack.addArrangedSubview(creditContainer)

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


        let closeBtn = UIButton(type: .close)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
        ])
    }

    private func makeLinkView(leading: String, linkText: String, url: URL,
                              trailing: String = "") -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tv.textContainer.lineFragmentPadding = 0
        tv.dataDetectorTypes = []
        tv.textAlignment = .left

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: textColor,
        ]
        let attr = NSMutableAttributedString(string: leading, attributes: attrs)
        attr.append(NSAttributedString(string: linkText, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: linkColor,
            .link: url,
        ]))
        if !trailing.isEmpty {
            attr.append(NSAttributedString(string: trailing, attributes: attrs))
        }
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

    private var chips: [(UIButton, VisualEffects)] = []
    private weak var effectGridView: UIView?

    private func makeEffectGrid() -> UIView {
        chips.removeAll()
        let items: [(String, VisualEffects)] = VisualEffects.all.map { ($0.label, $0) }

        let cols = 2
        let outer = UIStackView()
        outer.axis = .vertical
        outer.alignment = .fill
        outer.distribution = .fillEqually
        outer.spacing = 10

        var row: UIStackView?
        for (i, item) in items.enumerated() {
            if i % cols == 0 {
                row = UIStackView()
                row!.axis = .horizontal
                row!.spacing = 10
                row!.alignment = .fill
                row!.distribution = .fillEqually
                outer.addArrangedSubview(row!)
            }
            let chip = makeChip(label: item.0, effect: item.1)
            row!.addArrangedSubview(chip)
            chips.append((chip, item.1))
        }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        outer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            outer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            outer.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            outer.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        ])
        return container
    }

    private func makeChip(label: String, effect: VisualEffects) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(label, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.titleLabel?.numberOfLines = 2
        btn.titleLabel?.textAlignment = .center
        btn.titleLabel?.lineBreakMode = .byWordWrapping
        btn.layer.cornerRadius = 10
        btn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        btn.addAction(UIAction { [weak self] _ in self?.toggle(effect) }, for: .touchUpInside)
        applyChipStyle(btn, isOn: isChipOn(effect))
        return btn
    }

    private func applyChipStyle(_ btn: UIButton, isOn: Bool) {
        if isOn {
            btn.backgroundColor = linkColor
            btn.setTitleColor(bgColor, for: .normal)
        } else {
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
            btn.setTitleColor(textColor, for: .normal)
        }
    }

    private func isChipOn(_ effect: VisualEffects) -> Bool {
        effect.rawValue == 0 ? VisualEffects.current.isEmpty
                             : VisualEffects.current.contains(effect)
    }

    private func toggle(_ effect: VisualEffects) {
        var cur = VisualEffects.current
        if cur.contains(effect) { cur.remove(effect) } else { cur.insert(effect) }
        VisualEffects.current = cur
        refreshChips()
    }

    @objc private func visualizationsMasterToggled(_ sender: UISwitch) {
        if sender.isOn {
            if VisualEffects.current.isEmpty {
                VisualEffects.current = [.ripple]
                refreshChips()
            }
        } else {
            VisualEffects.current = .none
            refreshChips()
        }
        effectGridView?.isHidden = !sender.isOn
    }

    private func refreshChips() {
        for (btn, effect) in chips {
            applyChipStyle(btn, isOn: isChipOn(effect))
        }
    }

    @objc private func splitModeToggled(_ sender: UISwitch) {
        SplitModeController.isEnabled = sender.isOn
    }
}
