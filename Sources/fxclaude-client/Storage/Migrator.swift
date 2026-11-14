import Darwin
import Dependencies
import Foundation

final class Migrator: @unchecked Sendable {
	private let decoder: JSONDecoder
	private let encoder: JSONEncoder
	private let fileManager: FileManager
	private let lock: StorageLock
	private let paths: FXClaudePaths

	init(fileManager: FileManager) {
		@Dependency(\._fxclaudePaths)
		var paths

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let encoder = FXClaudeJSONCoding.encoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		self.encoder = encoder
		self.decoder = decoder
		self.fileManager = fileManager
		self.paths = paths
		self.lock = StorageLock(fileManager: fileManager, paths: paths)
	}

	init(
		fileManager: FileManager,
		paths: FXClaudePaths
	) {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let encoder = FXClaudeJSONCoding.encoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		self.encoder = encoder
		self.decoder = decoder
		self.fileManager = fileManager
		self.paths = paths
		self.lock = StorageLock(fileManager: fileManager, paths: paths)
	}

	func migrateIfNeeded() throws {
		try self.lock.withLock {
			try self.fileManager.createDirectory(
				at: self.paths.workspacesURL,
				withIntermediateDirectories: true,
				attributes: [.posixPermissions: 0o700]
			)

			guard self.fileManager.fileExists(atPath: self.paths.configurationURL.path) else {
				try self.bootstrap()
				return
			}

			try self.verifyV2()
			try self.createMissingWorkspaceDirectories()
		}
	}

	/// Creates per-workspace directories that a newer fxclaude added to the 2.0 layout.
	///
	/// Workspaces created before `claude-config` existed get an empty one on first use. Older fxclaude
	/// versions ignore the extra directory, so the schema version stays at 2.0.
	private func createMissingWorkspaceDirectories() throws {
		for workspace in try self.workspaceConfigurations() where workspace.kind == .managed {
			let directoryURL: URL = self.workspaceURL(workspace.id).appending(
				path: WorkspacesStorage.claudeConfigDirectoryName,
				directoryHint: .isDirectory
			)
			guard !self.fileManager.fileExists(atPath: directoryURL.path) else { continue }

			try self.fileManager.createDirectory(
				at: directoryURL,
				withIntermediateDirectories: false,
				attributes: [.posixPermissions: 0o700]
			)
		}
	}

	private func bootstrap() throws {
		let primaryID = WorkspaceID.generate()
		try self.writeWorkspaceConfiguration(.init(
			id: primaryID,
			name: Workspace.primaryName,
			kind: .primary
		))
		try self.write(
			StorageConfiguration(currentWorkspaceID: primaryID),
			to: self.paths.configurationURL
		)
	}

	private func verifyV2() throws {
		let configuration = try self.read(StorageConfiguration.self, from: self.paths.configurationURL)
		guard configuration.schemaVersion == .v2_0 else {
			throw FXClaudeError.unsupportedSchemaVersion(configuration.schemaVersion)
		}
		let workspaces = try self.workspaceConfigurations()
		guard workspaces.filter({ $0.kind == .primary }).count == 1 else {
			throw FXClaudeError.invalidStorage("schema 2.0 requires exactly one primary workspace")
		}
		guard workspaces.contains(where: { $0.id == configuration.currentWorkspaceID }) else {
			throw FXClaudeError.invalidStorage("current_workspace_id does not reference an existing workspace")
		}
		guard Set(workspaces.map(\.name)).count == workspaces.count else {
			throw FXClaudeError.invalidStorage("workspace names must be unique")
		}
	}

	private func workspaceConfigurations() throws -> [WorkspaceConfiguration] {
		try self.fileManager.contentsOfDirectory(
			at: self.paths.workspacesURL,
			includingPropertiesForKeys: [.isDirectoryKey],
			options: [.skipsHiddenFiles]
		)
		.filter { directory in
			(try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
				&& WorkspaceID(directory.lastPathComponent) != nil
		}
		.map { directory in
			guard let id = WorkspaceID(directory.lastPathComponent) else { preconditionFailure() }
			let value = try self.read(
				WorkspaceConfiguration.self,
				from: directory.appending(path: "workspace.json")
			)
			guard value.id == id else {
				throw FXClaudeError.invalidStorage("workspace directory and metadata IDs do not match")
			}
			return value
		}
	}

	private func writeWorkspaceConfiguration(_ configuration: WorkspaceConfiguration) throws {
		let directory = self.workspaceURL(configuration.id)
		try self.fileManager.createDirectory(
			at: directory,
			withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700]
		)
		try self.write(configuration, to: directory.appending(path: "workspace.json"))
	}

	private func workspaceURL(_ id: WorkspaceID) -> URL {
		self.paths.workspacesURL.appending(path: id.rawValue, directoryHint: .isDirectory)
	}

	private func read<Value: Decodable>(
		_ type: Value.Type,
		from url: URL
	) throws -> Value {
		try self.decoder.decode(type, from: Data(contentsOf: url))
	}

	private func write<Value: Encodable>(
		_ value: Value,
		to url: URL
	) throws {
		try self.fileManager.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700]
		)
		try self.encoder.encode(value).write(to: url, options: [.atomic])
	}

}
