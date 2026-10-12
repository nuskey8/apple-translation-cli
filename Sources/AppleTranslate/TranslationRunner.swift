import AppKit
import ArgumentParser
import SwiftUI
import Translation

/// Runs AppKit's event loop so system download sheets can be presented from a CLI.
@MainActor
final class TranslationRunner: NSObject, NSWindowDelegate {
    private var result: Result<String, Error>?
    private var window: NSWindow?

    func run(input: String, source: Locale.Language, target: Locale.Language) throws -> String {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let task = Task { @MainActor in
            let availability: LanguageAvailability
            if #available(macOS 26.4, *) {
                availability = LanguageAvailability(preferredStrategy: .lowLatency)
            } else {
                availability = LanguageAvailability()
            }
            let status = await availability.status(from: source, to: target)
            guard !Task.isCancelled else { return }
            switch status {
            case .installed:
                do {
                    let session: TranslationSession
                    if #available(macOS 26.4, *) {
                        session = TranslationSession(
                            installedSource: source, target: target, preferredStrategy: .lowLatency
                        )
                    } else {
                        session = TranslationSession(installedSource: source, target: target)
                    }
                    let response = try await session.translate(input)
                    finish(.success(response.targetText))
                } catch {
                    finish(.failure(error))
                }
            case .supported:
                showDownloadWindow(input: input, source: source, target: target)
            case .unsupported:
                finish(.failure(ValidationError("The requested translation language pair is unsupported.")))
            @unknown default:
                finish(.failure(ValidationError("Unable to determine translation language availability.")))
            }
        }
        app.run()
        task.cancel()
        window?.orderOut(nil)
        window?.delegate = nil
        window = nil
        guard let result else { throw CancellationError() }
        return try result.get()
    }

    private func showDownloadWindow(input: String, source: Locale.Language, target: Locale.Language) {
        let configuration: TranslationSession.Configuration
        if #available(macOS 26.4, *) {
            configuration = .init(source: source, target: target, preferredStrategy: .lowLatency)
        } else {
            configuration = .init(source: source, target: target)
        }
        let view = DownloadView(input: input, configuration: configuration) { [weak self] result in
            self?.finish(result)
        }
        FileHandle.standardError.write(Data(
            "translate: Select Download to allow language downloads.\n".utf8
        ))
        let window = TranslationHostWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = TransparentHostingView(rootView: view)
        self.window = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func windowWillBeginSheet(_ notification: Notification) {
        // Wait until AppKit attaches the sheet before configuring its movement.
        Task { @MainActor [weak self] in
            guard let sheet = self?.window?.attachedSheet else { return }
            sheet.isMovable = true
            sheet.isMovableByWindowBackground = true
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard self.result == nil else { return }
        self.result = result
        NSApplication.shared.stop(nil)
        // Wake the event loop after stop(), including completion without a window.
        if let event = NSEvent.otherEvent(
            with: .applicationDefined, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0
        ) {
            NSApplication.shared.postEvent(event, atStart: true)
        }
    }
}

private struct DownloadView: View {
    let input: String
    let configuration: TranslationSession.Configuration
    let completion: @MainActor (Result<String, Error>) -> Void

    var body: some View {
        Color.clear
        .frame(width: 640, height: 400)
        .translationTask(configuration) { @Sendable session in
            do {
                let response = try await session.translate(input)
                await completion(.success(response.targetText))
            } catch {
                await completion(.failure(error))
            }
        }
    }
}

/// Borderless windows need to accept key status to host interactive system sheets.
private final class TranslationHostWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Keep the presentation host transparent.
private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}
