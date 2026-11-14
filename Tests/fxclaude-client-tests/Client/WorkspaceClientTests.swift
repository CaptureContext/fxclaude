import Dependencies
import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("Workspace client")
struct WorkspaceClientTests {
	@Test("Primary workspace exposes its effective directories")
	func primaryDirectories() async throws {
		let fixture: ClientTestFixture = try .init()
		let primaryClaudeConfigURL: URL = fixture.rootURL.appending(
			path: "primary-claude-config",
			directoryHint: .isDirectory
		)
		let primaryUserDataURL: URL = fixture.rootURL.appending(
			path: "primary-user-data",
			directoryHint: .isDirectory
		)
		defer { fixture.remove() }

		try await withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(
				rootURL: fixture.rootURL,
				primaryClaudeConfigURL: primaryClaudeConfigURL,
				primaryUserDataURL: primaryUserDataURL
			)
		} operation: {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let primary: Workspace = try await client.currentWorkspace()
			let rootURL: URL = try #require(primary.rootURL)

			#expect(primary.kind == .primary)
			#expect(rootURL.lastPathComponent == primary.id.rawValue)
			#expect(FileManager.default.fileExists(
				atPath: rootURL.appending(path: "workspace.json").path
			))
			#expect(primary.claudeConfigURL == primaryClaudeConfigURL.standardizedFileURL)
			#expect(primary.userDataURL == primaryUserDataURL.standardizedFileURL)
			#expect(!FileManager.default.fileExists(atPath: primaryClaudeConfigURL.path))
		}
	}

	@Test("Creates, selects, opens, and deletes a workspace")
	func lifecycle() async throws {
		let fixture: ClientTestFixture = try .init()
		let application: ClaudeApplicationSpy = .init()
		defer { fixture.remove() }

		try await withDependencies {
			$0.context = .live
			$0._fxclaudeApplication = application.client
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let workspace: Workspace = try await client.createWorkspace("work")
			#expect(workspace.kind == .managed)
			#expect(try await client.workspaces().map(\.name) == ["primary", "work"])

			try await client.useWorkspace(workspace.name)
			#expect(try await client.currentWorkspace().name == workspace.name)

			#expect(try await client.openWorkspace(workspace.name) == 4_242)
			await application.setProcessID(nil, forWorkspaceNamed: workspace.name)

			try await client.deleteWorkspace(workspace.name)
			#expect(try await client.workspaces().map(\.name) == [Workspace.primaryName])
			#expect(try await client.currentWorkspace().name == Workspace.primaryName)
		}

		let snapshot: ClaudeApplicationSpy.Snapshot = await application.snapshot()
		#expect(snapshot.removedWorkspaceNames == ["work"])
	}

	@Test("Rejects mutation while a workspace is running")
	func runningWorkspace() async throws {
		let fixture: ClientTestFixture = try .init()
		let application: ClaudeApplicationSpy = .init()
		defer { fixture.remove() }

		try await withDependencies {
			$0.context = .live
			$0._fxclaudeApplication = application.client
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let workspace: Workspace = try await client.createWorkspace("work")
			await application.setProcessID(9_001, forWorkspaceNamed: workspace.name)

			await #expect(throws: FXClaudeError.workspaceIsRunning(workspace.name)) {
				_ = try await client.eraseWorkspace(workspace.name)
			}
			await #expect(throws: FXClaudeError.workspaceIsRunning(workspace.name)) {
				try await client.deleteWorkspace(workspace.name)
			}
			#expect(try await client.workspaces().map(\.name) == ["primary", "work"])
		}
	}

	@Test("Batch deletion validates every workspace before deleting any")
	func batchDeletionPreflight() async throws {
		let fixture: ClientTestFixture = try .init()
		let application: ClaudeApplicationSpy = .init()
		defer { fixture.remove() }

		try await withDependencies {
			$0.context = .live
			$0._fxclaudeApplication = application.client
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let work: Workspace = try await client.createWorkspace("work")
			let personal: Workspace = try await client.createWorkspace("personal")
			await application.setProcessID(9_001, forWorkspaceNamed: personal.name)

			await #expect(throws: FXClaudeError.workspaceIsRunning(personal.name)) {
				try await client.deleteWorkspaces([work.name, personal.name])
			}
			#expect(try await client.workspaces().map(\.name) == [
				Workspace.primaryName,
				personal.name,
				work.name,
			])

			await application.setProcessID(nil, forWorkspaceNamed: personal.name)
			try await client.deleteWorkspaces([
				work.name,
				personal.name,
				work.name,
			])
			#expect(try await client.workspaces().map(\.name) == [Workspace.primaryName])
		}
	}
}
