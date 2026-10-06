import UIKit
import WebKit

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private static let homeURL = URL(string: "https://movix.luxe")!
    private var retryURL = WebViewController.homeURL
    private var observations: [NSKeyValueObservation] = []

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.isOpaque = false
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let toolbar = UIToolbar()
    private let errorPanel = UIStackView()
    private let errorLabel = UILabel()
    private lazy var backItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(goBack))
    private lazy var forwardItem = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(goForward))

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildInterface()
        observeNavigation()
        load(Self.homeURL)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .allButUpsideDown }
    override var shouldAutorotate: Bool { true }

    private func buildInterface() {
        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.text = "Movix"
        title.font = .systemFont(ofSize: 20, weight: .bold)
        title.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(title)
        header.addSubview(spinner)

        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = .systemTeal
        progressView.isHidden = true
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        backItem.accessibilityLabel = "Retour"
        forwardItem.accessibilityLabel = "Avance"
        let homeItem = UIBarButtonItem(image: UIImage(systemName: "house"), style: .plain, target: self, action: #selector(goHome))
        homeItem.accessibilityLabel = "Accueil"
        let reloadItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(reload))
        reloadItem.accessibilityLabel = "Recharger"
        func space() -> UIBarButtonItem { UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) }
        toolbar.items = [backItem, space(), forwardItem, space(), homeItem, space(), reloadItem]

        [header, progressView, webView, toolbar].forEach(view.addSubview)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 44),
            title.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            spinner.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            progressView.topAnchor.constraint(equalTo: header.bottomAnchor),
            progressView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 50)
        ])
        buildErrorPanel()
    }

    private func buildErrorPanel() {
        errorPanel.axis = .vertical
        errorPanel.alignment = .center
        errorPanel.spacing = 16
        errorPanel.translatesAutoresizingMaskIntoConstraints = false
        errorPanel.isHidden = true

        let image = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        image.tintColor = .secondaryLabel
        image.contentMode = .scaleAspectFit
        image.translatesAutoresizingMaskIntoConstraints = false
        image.widthAnchor.constraint(equalToConstant: 40).isActive = true
        image.heightAnchor.constraint(equalToConstant: 40).isActive = true
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Réessayer"
        configuration.cornerStyle = .capsule
        button.configuration = configuration
        button.addTarget(self, action: #selector(retry), for: .touchUpInside)
        [image, errorLabel, button].forEach(errorPanel.addArrangedSubview)
        view.addSubview(errorPanel)
        NSLayoutConstraint.activate([
            errorPanel.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
            errorPanel.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
            errorPanel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            errorPanel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            errorPanel.widthAnchor.constraint(lessThanOrEqualToConstant: 380)
        ])
    }

    private func observeNavigation() {
        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] view, _ in
                self?.progressView.setProgress(Float(view.estimatedProgress), animated: true)
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] view, _ in
                guard let self = self else { return }
                self.progressView.isHidden = !view.isLoading
                view.isLoading ? self.spinner.startAnimating() : self.spinner.stopAnimating()
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] view, _ in
                self?.backItem.isEnabled = view.canGoBack
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] view, _ in
                self?.forwardItem.isEnabled = view.canGoForward
            }
        ]
    }

    private func load(_ url: URL) {
        retryURL = url
        errorPanel.isHidden = true
        webView.isHidden = false
        progressView.progress = 0
        webView.load(URLRequest(url: url))
    }

    @objc private func goBack() {
        errorPanel.isHidden = true
        webView.isHidden = false
        webView.goBack()
    }
    @objc private func goForward() {
        errorPanel.isHidden = true
        webView.isHidden = false
        webView.goForward()
    }
    @objc private func goHome() { load(Self.homeURL) }
    @objc private func reload() {
        if !errorPanel.isHidden { retry(); return }
        webView.reload()
    }
    @objc private func retry() { load(retryURL) }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        errorPanel.isHidden = true
        webView.isHidden = false
        progressView.progress = 0
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        retryURL = webView.url ?? Self.homeURL
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    private func show(_ error: Error) {
        let error = error as NSError
        guard !(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled) else { return }
        if let url = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL { retryURL = url }
        errorLabel.text = "Impossible de charger Movix.\n\n\(error.localizedDescription)"
        spinner.stopAnimating()
        progressView.isHidden = true
        webView.isHidden = true
        errorPanel.isHidden = false
        UIAccessibility.post(notification: .screenChanged, argument: errorLabel)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load(webView.url ?? retryURL)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        // ATS and WebKit perform their standard HTTPS and certificate checks.
        if ["https", "http", "about", "blob", "data"].contains(scheme) {
            if navigationAction.targetFrame?.isMainFrame == true, ["https", "http"].contains(scheme) { retryURL = url }
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            if ["mailto", "tel", "sms"].contains(scheme), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url,
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            load(url)
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: "Movix", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: "Movix", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: "Movix", message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in completionHandler(alert?.textFields?.first?.text) })
        present(alert, animated: true)
    }
}
