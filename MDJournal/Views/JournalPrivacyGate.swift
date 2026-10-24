import SwiftUI
import UIKit

struct JournalPrivacyGate<Content: View>: View {
    @EnvironmentObject private var appLock: JournalAppLockStore
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let covered = appLock.needsPrivacyCover(sceneIsActive: scenePhase == .active)
        ZStack {
            content
                .privacySensitive()
                .allowsHitTesting(!covered)
                .accessibilityHidden(covered)
            if covered {
                ScrollView {
                    VStack(spacing: 20) {
                        Image(systemName: "lock.doc")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(JournalTheme.accent)
                            .accessibilityHidden(true)
                        Text("留给自己的文字")
                            .font(.system(.title2, design: .serif))
                        Text("使用设备密码或生物识别解锁日记。")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        if appLock.isAuthenticating {
                            ProgressView("正在验证身份")
                        } else if scenePhase == .active {
                            Button("解锁日记") { Task { await appLock.unlock() } }
                                .buttonStyle(.borderedProminent)
                                .tint(JournalTheme.accent)
                                .foregroundStyle(JournalTheme.onAccent)
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("journal.unlock")
                        }
                        if let message = appLock.message, scenePhase == .active {
                            Text(message).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity, minHeight: 300)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(JournalTheme.paper.ignoresSafeArea())
                .accessibilityIdentifier("journal.privacy-cover")
            }
        }
        .background {
            JournalWindowPrivacyShield(appLock: appLock, sceneIsActive: scenePhase == .active)
                .frame(width: 0, height: 0)
        }
        .onAppear { appLock.handleScenePhase(scenePhase) }
        .onChange(of: scenePhase) { appLock.handleScenePhase($0) }
    }
}

private struct JournalWindowPrivacyShield: UIViewRepresentable {
    @ObservedObject var appLock: JournalAppLockStore
    let sceneIsActive: Bool

    func makeUIView(context: Context) -> JournalShieldAnchor {
        JournalShieldAnchor()
    }

    func updateUIView(_ view: JournalShieldAnchor, context: Context) {
        view.update(appLock: appLock, sceneIsActive: sceneIsActive)
    }

    static func dismantleUIView(_ view: JournalShieldAnchor, coordinator: ()) {
        view.detach()
    }
}

private final class JournalShieldAnchor: UIView {
    private weak var appLock: JournalAppLockStore?
    private var sceneIsActive = true
    private var isResigningActive = false
    private let shield = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let unlockButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        shield.backgroundColor = UIColor(named: "JournalPaper") ?? .systemBackground
        shield.accessibilityViewIsModal = true
        shield.accessibilityIdentifier = "journal.window-privacy-cover"
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        titleLabel.text = "日记已锁定"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        unlockButton.setTitle("解锁日记", for: .normal)
        unlockButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        unlockButton.titleLabel?.adjustsFontForContentSizeCategory = true
        unlockButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        unlockButton.addAction(UIAction { [weak self] _ in
            guard let appLock = self?.appLock else { return }
            Task { await appLock.unlock() }
        }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [titleLabel, messageLabel, unlockButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        shield.addSubview(scroll)
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: shield.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: shield.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: shield.safeAreaLayoutGuide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: shield.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 32),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        NotificationCenter.default.addObserver(
            self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { shield.removeFromSuperview() }
        refresh()
    }

    func update(appLock: JournalAppLockStore, sceneIsActive: Bool) {
        self.appLock = appLock
        self.sceneIsActive = sceneIsActive
        refresh()
    }

    func detach() {
        shield.removeFromSuperview()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func willResignActive() {
        isResigningActive = true
        refresh()
    }

    @objc private func didBecomeActive() {
        isResigningActive = false
        refresh()
    }

    private func refresh() {
        guard let appLock, let window else { return }
        let active = sceneIsActive && !isResigningActive
        let covered = appLock.needsPrivacyCover(sceneIsActive: active)
        guard covered else { shield.removeFromSuperview(); return }
        shield.frame = window.bounds
        if shield.superview !== window {
            window.endEditing(true)
            window.addSubview(shield)
        }
        window.bringSubviewToFront(shield)
        unlockButton.isHidden = !active || appLock.isAuthenticating
        messageLabel.text = appLock.isAuthenticating ? "正在验证身份…" : (appLock.message ?? "使用设备密码或生物识别继续。")
    }
}
