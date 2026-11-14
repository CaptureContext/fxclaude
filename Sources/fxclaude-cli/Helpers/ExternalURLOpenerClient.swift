import AppKit
import Dependencies
import Foundation

internal struct ExternalURLOpenerClient: Sendable {
	internal var openInApplication: @MainActor @Sendable (URL, URL) async throws -> Void
	internal var openInBrowser: @MainActor @Sendable (URL) throws -> Void

	internal init(
		openInApplication: @escaping @MainActor @Sendable (URL, URL) async throws -> Void,
		openInBrowser: @escaping @MainActor @Sendable (URL) throws -> Void
	) {
		self.openInApplication = openInApplication
		self.openInBrowser = openInBrowser
	}
}

extension DependencyValues {
	private enum ExternalURLOpenerClientKey: DependencyKey {
		static var liveValue: ExternalURLOpenerClient {
			.init(
				openInApplication: { url, applicationURL in
					let configuration: NSWorkspace.OpenConfiguration = .init()
					configuration.activates = true

					_ = try await NSWorkspace.shared.open(
						[url],
						withApplicationAt: applicationURL,
						configuration: configuration
					)
				},
				openInBrowser: { url in
					guard NSWorkspace.shared.open(url)
					else { throw CocoaError(.fileNoSuchFile) }
				}
			)
		}

		// Commands may hold the opener without using it; only an actual open must be stubbed in tests.
		static var testValue: ExternalURLOpenerClient {
			.init(
				openInApplication: { url, _ in
					reportIssue("Unexpected request to open \(url.absoluteString) in an application.")
				},
				openInBrowser: { url in
					reportIssue("Unexpected request to open \(url.absoluteString) in a browser.")
				}
			)
		}
	}

	internal var _fxclaudeExternalURLOpener: ExternalURLOpenerClient {
		get { self[ExternalURLOpenerClientKey.self] }
		set { self[ExternalURLOpenerClientKey.self] = newValue }
	}
}
