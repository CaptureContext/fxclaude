import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("fxclaude paths")
struct FXClaudePathsTests {
	@Test("Primary paths use standard Claude locations by default")
	func primaryDefaults() async throws {
		let fileManager: FileManager = .default
		let paths: FXClaudePaths = .create(
			fileManager: fileManager,
			environment: [:]
		)
		let applicationSupportURL: URL = try #require(fileManager.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first)

		#expect(paths.primaryClaudeConfigURL == fileManager.homeDirectoryForCurrentUser.appending(
			path: ".claude",
			directoryHint: .isDirectory
		).standardizedFileURL)
		#expect(paths.primaryUserDataURL == applicationSupportURL.appending(
			path: "Claude",
			directoryHint: .isDirectory
		).standardizedFileURL)
	}

	@Test("Primary paths honor Claude environment overrides")
	func primaryEnvironmentOverrides() async throws {
		let paths: FXClaudePaths = .create(
			fileManager: .default,
			environment: [
				"CLAUDE_CONFIG_DIR": "/tmp/claude-config",
				"CLAUDE_USER_DATA_DIR": "/tmp/claude-user-data",
			]
		)

		#expect(paths.primaryClaudeConfigURL.path == "/tmp/claude-config")
		#expect(paths.primaryUserDataURL.path == "/tmp/claude-user-data")
	}
}
