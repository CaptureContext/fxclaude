import AppKit
import Foundation

actor RaycastIntegration {
	init() {}

	func applicationStatus(for edition: RaycastEdition) async -> RaycastApplicationStatus {
		let applicationURL = await Self.applicationURL(for: edition)
		let version = applicationURL
			.flatMap(Bundle.init(url:))?
			.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
		return .init(
			edition: edition,
			applicationURL: applicationURL,
			version: version
		)
	}

	func applicationInstallation(for edition: RaycastEdition) async throws -> RaycastApplicationInstallation {
		if let applicationURL = await Self.applicationURL(for: edition) {
			return .alreadyInstalled(applicationURL)
		}

		switch edition {
		case .stable:
			return .command(.init(
				executable: "brew",
				arguments: ["install", "--cask", "raycast"],
				environment: [:]
			))

		case .beta:
			#if arch(arm64)
			guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
				throw FXClaudeError.raycastBetaUnsupportedPlatform
			}
			guard let url = URL(string: "https://www.raycast.com/new") else {
				throw CocoaError(.fileNoSuchFile)
			}

			return .externalDownload(url)
			#else
			throw FXClaudeError.raycastBetaUnsupportedPlatform
			#endif
		}
	}
}

private extension RaycastIntegration {
	@MainActor
	static func applicationURL(for edition: RaycastEdition) -> URL? {
		let bundleIdentifier: String
		let knownURL: URL
		switch edition {
		case .stable:
			bundleIdentifier = "com.raycast.macos"
			knownURL = URL(fileURLWithPath: "/Applications/Raycast.app")
		case .beta:
			bundleIdentifier = "com.raycast-x.macos"
			knownURL = URL(fileURLWithPath: "/Applications/Raycast Beta.app")
		}

		let discoveredURLs = NSWorkspace.shared.urlsForApplications(withBundleIdentifier: bundleIdentifier)
		return (discoveredURLs + [knownURL]).first { url in
			FileManager.default.fileExists(atPath: url.path)
				&& Bundle(url: url)?.bundleIdentifier == bundleIdentifier
		}
	}
}
