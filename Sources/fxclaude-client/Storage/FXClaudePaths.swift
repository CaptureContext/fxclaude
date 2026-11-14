import Foundation
import Dependencies

public struct FXClaudePaths: Sendable {
	public let rootURL: URL
	public let primaryClaudeConfigURL: URL
	public let primaryUserDataURL: URL
	public let configurationURL: URL
	public let runtimeURL: URL
	public let storageLockURL: URL
	public let workspacesURL: URL

	public init(rootURL: URL) {
		self.init(
			rootURL: rootURL,
			primaryClaudeConfigURL: Self.primaryClaudeConfigURL(
				fileManager: .default,
				environment: ProcessInfo.processInfo.environment
			),
			primaryUserDataURL: Self.primaryUserDataURL(
				fileManager: .default,
				environment: ProcessInfo.processInfo.environment
			)
		)
	}

	@_spi(Internals)
	public init(
		rootURL: URL,
		primaryClaudeConfigURL: URL,
		primaryUserDataURL: URL
	) {
		self.rootURL = rootURL.standardizedFileURL
		self.primaryClaudeConfigURL = primaryClaudeConfigURL.standardizedFileURL
		self.primaryUserDataURL = primaryUserDataURL.standardizedFileURL
		self.configurationURL = self.rootURL.appending(
			path: "configuration.json",
			directoryHint: .notDirectory
		)
		self.runtimeURL = self.rootURL.appending(
			path: "runtime.json",
			directoryHint: .notDirectory
		)
		self.storageLockURL = self.rootURL.appending(
			path: "storage.lock",
			directoryHint: .notDirectory
		)
		self.workspacesURL = self.rootURL.appending(
			path: "workspaces",
			directoryHint: .isDirectory
		)
	}

	public static func create(fileManager: FileManager = .default) -> Self {
		self.create(
			fileManager: fileManager,
			environment: ProcessInfo.processInfo.environment
		)
	}

	@_spi(Internals)
	public static func create(
		fileManager: FileManager,
		environment: [String: String]
	) -> Self {
		let applicationSupportURL: URL = self.applicationSupportURL(fileManager: fileManager)
		return Self(
			rootURL: self.environmentDirectoryURL(
				named: "FXCLAUDE_HOME",
				environment: environment
			)
			?? applicationSupportURL.appending(
				path: "fxclaude",
				directoryHint: .isDirectory
			),
			primaryClaudeConfigURL: self.primaryClaudeConfigURL(
				fileManager: fileManager,
				environment: environment
			),
			primaryUserDataURL: self.primaryUserDataURL(
				fileManager: fileManager,
				environment: environment
			)
		)
	}
}

private extension FXClaudePaths {
	static func applicationSupportURL(fileManager: FileManager) -> URL {
		fileManager.urls(
			for: .applicationSupportDirectory,
			in: .userDomainMask
		).first
		?? fileManager.homeDirectoryForCurrentUser.appending(
			path: "Library/Application Support",
			directoryHint: .isDirectory
		)
	}

	static func primaryClaudeConfigURL(
		fileManager: FileManager,
		environment: [String: String]
	) -> URL {
		self.environmentDirectoryURL(named: "CLAUDE_CONFIG_DIR", environment: environment)
		?? fileManager.homeDirectoryForCurrentUser.appending(
			path: ".claude",
			directoryHint: .isDirectory
		)
	}

	static func primaryUserDataURL(
		fileManager: FileManager,
		environment: [String: String]
	) -> URL {
		self.environmentDirectoryURL(
			named: "CLAUDE_USER_DATA_DIR",
			environment: environment
		)
		?? self.applicationSupportURL(fileManager: fileManager).appending(
			path: "Claude",
			directoryHint: .isDirectory
		)
	}

	static func environmentDirectoryURL(
		named name: String,
		environment: [String: String]
	) -> URL? {
		guard let path = environment[name], !path.isEmpty else { return nil }
		return URL(
			filePath: NSString(string: path).expandingTildeInPath,
			directoryHint: .isDirectory
		).standardizedFileURL
	}
}

extension DependencyValues {
	private enum FXClaudePathsKey: DependencyKey {
		static var liveValue: FXClaudePaths { .create(fileManager: .default) }
	}

	@_spi(Internals)
	public var _fxclaudePaths: FXClaudePaths {

		get { self[FXClaudePathsKey.self] }
		set { self[FXClaudePathsKey.self] = newValue }
	}
}
