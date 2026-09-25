import AppKit
import WebKit
import CoreGraphics
import Darwin

private struct RenderFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

@MainActor
private final class DesignRenderer: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private let input: URL
    private let destination: URL
    private let preview: URL
    private var window: NSWindow!
    private var webView: WKWebView!
    private var finished = false
    private var beganExport = false
    private let width = 1242
    private let height = 2688

    init(input: URL, destination: URL, preview: URL) {
        self.input = input
        self.destination = destination
        self.preview = preview
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            print("START_LOCAL_ARTIFACT \(input.path)")
            guard FileManager.default.fileExists(atPath: input.path) else {
                throw RenderFailure("HTML does not exist: \(input.path)")
            }
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: preview.deletingLastPathComponent(), withIntermediateDirectories: true)
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = .nonPersistent()
            webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: configuration)
            webView.navigationDelegate = self
            webView.setValue(false, forKey: "drawsBackground")

            // A transparent, off-screen backing window permits WebKit painting
            // without placing a visible window on the user's desktop.
            window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.alphaValue = 0
            window.ignoresMouseEvents = true
            window.collectionBehavior = [.stationary, .ignoresCycle]
            window.contentView = webView
            window.orderBack(nil)

            Task { @MainActor in
                do {
                    // All assets for this artifact must be local. This rule
                    // blocks remote subresources as well as navigation.
                    let rules = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
                    let compiled = try await WKContentRuleListStore.default().compileContentRuleList(
                        forIdentifier: "WakeMusicLocalScreenshotRenderer", encodedContentRuleList: rules)
                    if let compiled { webView.configuration.userContentController.add(compiled) }
                    print("LOAD_LOCAL_ARTIFACT")
                    webView.loadFileURL(input, allowingReadAccessTo: input.deletingLastPathComponent())
                } catch { fail(error) }
            }
            Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.finished else { return }
                    self.fail(RenderFailure("Timed out waiting for local HTML rendering"))
                }
            }
        } catch { fail(error) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              url.isFileURL,
              url.standardizedFileURL.path.hasPrefix(input.deletingLastPathComponent().standardizedFileURL.path + "/") else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail(RenderFailure("WebKit content process terminated")) }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !beganExport else { return }
        beganExport = true
        print("LOCAL_NAVIGATION_FINISHED")
        Task { @MainActor in
            do {
                let readiness = try await webView.callAsyncJavaScript(#"""
                    await document.fonts.ready;
                    const images = Array.from(document.images);
                    await Promise.all(images.map(async image => {
                      await image.decode();
                      if (!image.complete || image.naturalWidth === 0) throw new Error('Missing image: ' + image.getAttribute('src'));
                    }));
                    const style = document.createElement('style');
                    style.id = 'native-png-export-style';
                    style.textContent = `
                      html, body { margin: 0 !important; padding: 0 !important; width: 1242px !important; min-width: 1242px !important; height: 2688px !important; overflow: hidden !important; }
                      *, *::before, *::after { animation: none !important; transition: none !important; caret-color: transparent !important; }
                      body * { visibility: hidden !important; }
                      [data-native-export-active], [data-native-export-active] * { visibility: visible !important; }
                      [data-native-export-active] { position: fixed !important; left: 0 !important; top: 0 !important; right: auto !important; bottom: auto !important; margin: 0 !important; width: 1242px !important; height: 2688px !important; min-width: 1242px !important; min-height: 2688px !important; max-width: 1242px !important; max-height: 2688px !important; transform: none !important; z-index: 2147483647 !important; }
                    `;
                    document.head.appendChild(style);
                    return {images: images.length, fonts: document.fonts.status};
                    """#, arguments: [:], in: nil, contentWorld: .page)
                print("LOCAL_ARTIFACT_READY \(String(describing: readiness))")
                for number in 1...6 {
                    let name = String(format: "%02d", number)
                    let id = "shot-" + name
                    let value = try await webView.callAsyncJavaScript(#"""
                        document.querySelectorAll('[data-native-export-active]').forEach(node => node.removeAttribute('data-native-export-active'));
                        const shot = document.getElementById(id);
                        if (!shot) throw new Error('Missing section #' + id);
                        // Neutralize preview-only ancestor transforms without
                        // changing the shot's internal design styles.
                        for (let node = shot.parentElement; node; node = node.parentElement) {
                          node.style.setProperty('transform', 'none', 'important');
                          node.style.setProperty('filter', 'none', 'important');
                          node.style.setProperty('perspective', 'none', 'important');
                          node.style.setProperty('contain', 'none', 'important');
                          node.style.setProperty('overflow', 'visible', 'important');
                        }
                        shot.setAttribute('data-native-export-active', '');
                        window.scrollTo(0, 0);
                        await document.fonts.ready;
                        await Promise.all(Array.from(shot.querySelectorAll('img')).map(image => image.decode()));
                        // An off-screen WebKit view may throttle animation
                        // frames, so also let an ordinary timer advance it.
                        await new Promise(resolve => {
                          setTimeout(resolve, 150);
                          requestAnimationFrame(() => requestAnimationFrame(resolve));
                        });
                        const rect = shot.getBoundingClientRect();
                        return {x: rect.x, y: rect.y, width: rect.width, height: rect.height};
                        """#, arguments: ["id": id], in: nil, contentWorld: .page)
                    guard let bounds = value as? [String: NSNumber],
                          let x = bounds["x"]?.doubleValue, let y = bounds["y"]?.doubleValue,
                          let w = bounds["width"]?.doubleValue, let h = bounds["height"]?.doubleValue,
                          abs(x) < 0.1, abs(y) < 0.1, abs(w - Double(width)) < 0.1, abs(h - Double(height)) < 0.1 else {
                        throw RenderFailure("Unexpected section geometry for \(id): \(String(describing: value))")
                    }
                    let options = WKSnapshotConfiguration()
                    options.rect = CGRect(x: x, y: y, width: w, height: h)
                    options.snapshotWidth = NSNumber(value: width)
                    options.afterScreenUpdates = true
                    let snapshot = try await webView.takeSnapshot(configuration: options)
                    var proposed = NSRect(origin: .zero, size: snapshot.size)
                    guard let cgImage = snapshot.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
                        throw RenderFailure("Could not read native snapshot \(id)")
                    }
                    let file = destination.appendingPathComponent(name + ".png")
                    try saveOpaque(image: cgImage, width: width, height: height, to: file)
                    print("EXPORTED \(file.path) \(width)x\(height) RGB opaque")
                }
                try contactSheet()
                print("PREVIEW \(preview.path)")
                finished = true
                window.orderOut(nil)
                NSApplication.shared.terminate(nil)
            } catch { fail(error) }
        }
    }

    private func context(width: Int, height: Int) throws -> CGContext {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw RenderFailure("Could not create opaque RGB bitmap")
        }
        context.setFillColor(CGColor(red: 0.035, green: 0.045, blue: 0.065, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        return context
    }

    private func saveOpaque(image: CGImage, width: Int, height: Int, to file: URL) throws {
        let bitmap = try context(width: width, height: height)
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        try saveContext(bitmap, to: file)
    }

    private func saveContext(_ context: CGContext, to file: URL) throws {
        guard let output = context.makeImage() else { throw RenderFailure("Bitmap creation failed") }
        let representation = NSBitmapImageRep(cgImage: output)
        guard !representation.hasAlpha,
              let data = representation.representation(using: .png, properties: [:]) else {
            throw RenderFailure("Opaque PNG encoding failed")
        }
        try data.write(to: file, options: .atomic)
    }

    private func contactSheet() throws {
        let thumbnailWidth = 414
        let thumbnailHeight = 896
        let padding = 32
        let sheetWidth = thumbnailWidth * 3 + padding * 4
        let sheetHeight = thumbnailHeight * 2 + padding * 3
        let bitmap = try context(width: sheetWidth, height: sheetHeight)
        for index in 0..<6 {
            let url = destination.appendingPathComponent(String(format: "%02d.png", index + 1))
            guard let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw RenderFailure("Cannot read exported slide for preview")
            }
            let x = padding + (index % 3) * (thumbnailWidth + padding)
            let y = sheetHeight - padding - thumbnailHeight - (index / 3) * (thumbnailHeight + padding)
            bitmap.draw(cgImage, in: CGRect(x: x, y: y, width: thumbnailWidth, height: thumbnailHeight))
        }
        try saveContext(bitmap, to: preview)
    }

    private func fail(_ error: Error) {
        guard !finished else { return }
        finished = true
        FileHandle.standardError.write(Data("RENDER_ERROR \(error)\n".utf8))
        window?.orderOut(nil)
        exit(1)
    }
}

@main
private enum Main {
    @MainActor static func main() {
        setbuf(stdout, nil)
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            FileHandle.standardError.write(Data("Usage: render-design DESIGN.html OUTPUT_DIRECTORY PREVIEW.png\n".utf8))
            exit(2)
        }
        let input = URL(fileURLWithPath: arguments[1]).standardizedFileURL
        let output = URL(fileURLWithPath: arguments[2]).standardizedFileURL
        let preview = URL(fileURLWithPath: arguments[3]).standardizedFileURL
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let renderer = DesignRenderer(input: input, destination: output, preview: preview)
        app.delegate = renderer
        withExtendedLifetime(renderer) { app.run() }
    }
}
