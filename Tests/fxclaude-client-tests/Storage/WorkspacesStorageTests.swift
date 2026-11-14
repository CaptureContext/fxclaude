import Dependencies
import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("Workspace storage")
struct WorkspacesStorageTests {
	@Test("Primary is reserved and names are validated")
	func protectedNames() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			#expect(throws: FXClaudeError.primaryWorkspaceMutation) {
				try storage.createWorkspace(named: Workspace.primaryName)
			}
			#expect(throws: FXClaudeError.primaryWorkspaceMutation) {
				try storage.deleteWorkspace(named: Workspace.primaryName)
			}
			#expect(throws: FXClaudeError.primaryWorkspaceMutation) {
				try storage.eraseWorkspace(named: Workspace.primaryName)
			}
			#expect(throws: FXClaudeError.invalidWorkspaceName("Work Profile")) {
				try storage.createWorkspace(named: "Work Profile")
			}
		}
	}

	@Test("Missing workspaces are rejected")
	func missingWorkspace() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			#expect(throws: FXClaudeError.workspaceNotFound("missing")) {
				try storage.workspace(named: "missing")
			}
		}
	}

	@Test("Erase preserves workspace directories and integration metadata while removing managed data")
	func eraseWorkspace() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		try withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			var workspace: Workspace = try storage.createWorkspace(named: "work")
			workspace.integrations["test"] = .dictionary([
				"enabled": .bool(true),
			])
			_ = try storage.saveWorkspace(workspace)
			try storage.useWorkspace(named: workspace.name)

			let claudeConfigURL: URL = try #require(workspace.claudeConfigURL)
			try "{}".write(
				to: claudeConfigURL.appending(path: "settings.json"),
				atomically: true,
				encoding: .utf8
			)

			let userDataURL: URL = try #require(workspace.userDataURL)
			let nestedURL: URL = userDataURL.appending(
				path: "nested",
				directoryHint: .isDirectory
			)
			try FileManager.default.createDirectory(
				at: nestedURL,
				withIntermediateDirectories: false,
				attributes: nil
			)
			try "settings".write(
				to: nestedURL.appending(path: "config.json"),
				atomically: true,
				encoding: .utf8
			)
			try "session".write(
				to: userDataURL.appending(path: ".session"),
				atomically: true,
				encoding: .utf8
			)

			let erasedWorkspace: Workspace = try storage.eraseWorkspace(named: workspace.name)
			#expect(erasedWorkspace.integrations == workspace.integrations)
			#expect(try storage.currentWorkspaceName() == workspace.name)
			#expect(try FileManager.default.contentsOfDirectory(atPath: claudeConfigURL.path).isEmpty)
			#expect(FileManager.default.fileExists(atPath: claudeConfigURL.path))
			#expect(try FileManager.default.contentsOfDirectory(atPath: userDataURL.path).isEmpty)
			#expect(FileManager.default.fileExists(atPath: userDataURL.path))
		}
	}

	@Test("Managed workspaces get private Claude config and user data directories")
	func managedDirectories() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		try withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			let workspace: Workspace = try storage.createWorkspace(named: "work")
			let rootURL: URL = try #require(workspace.rootURL)

			#expect(
				workspace.claudeConfigURL == rootURL.appending(
					path: "claude-config",
					directoryHint: .isDirectory
				)
			)
			#expect(
				workspace.userDataURL == rootURL.appending(
					path: "user-data",
					directoryHint: .isDirectory
				)
			)

			for directoryURL in [workspace.claudeConfigURL, workspace.userDataURL] {
				let path: String = try #require(directoryURL).path
				let attributes = try FileManager.default.attributesOfItem(atPath: path)
				#expect(attributes[.type] as? FileAttributeType == .typeDirectory)
				#expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
			}
		}
	}

	@Test("Preparing storage adds a missing Claude config directory to existing managed workspaces")
	func backfillsClaudeConfigDirectory() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		try withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			let workspace: Workspace = try storage.createWorkspace(named: "work")
			let claudeConfigURL: URL = try #require(workspace.claudeConfigURL)
			let userDataURL: URL = try #require(workspace.userDataURL)
			try "session".write(
				to: userDataURL.appending(path: ".session"),
				atomically: true,
				encoding: .utf8
			)
			// Simulate a workspace created before claude-config existed.
			try FileManager.default.removeItem(at: claudeConfigURL)

			try storage.prepare()

			let attributes = try FileManager.default.attributesOfItem(atPath: claudeConfigURL.path)
			#expect(attributes[.type] as? FileAttributeType == .typeDirectory)
			#expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
			#expect(FileManager.default.fileExists(atPath: userDataURL.appending(path: ".session").path))

			let primary: Workspace = try storage.workspace(named: Workspace.primaryName)
			#expect(primary.claudeConfigURL != claudeConfigURL)
		}
	}
}
