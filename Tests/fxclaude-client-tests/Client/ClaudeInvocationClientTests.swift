import Dependencies
import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("Claude invocation client")
struct ClaudeInvocationClientTests {
	@Test("Sets CLAUDE_CONFIG_DIR only for managed workspaces")
	func workspaceEnvironment() async throws {
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

			let primaryInvocation: CommandInvocation = try await client.claudeInvocation(
				Workspace.primaryName,
				["--version"]
			)
			#expect(primaryInvocation == .init(
				executable: "claude",
				arguments: ["--version"],
				environment: [:]
			))

			let workspace: Workspace = try await client.createWorkspace("work")
			let managedInvocation: CommandInvocation = try await client.claudeInvocation(
				workspace.name,
				["-p", "hello"]
			)
			#expect(managedInvocation == .init(
				executable: "claude",
				arguments: ["-p", "hello"],
				environment: [
					"CLAUDE_CONFIG_DIR": try #require(workspace.claudeConfigURL).path,
				]
			))
		}
	}

	@Test("Uses the current workspace when no name is given")
	func currentWorkspace() async throws {
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
			try await client.useWorkspace(workspace.name)

			let invocation: CommandInvocation = try await client.claudeInvocation(nil, [])
			#expect(invocation.environment == [
				"CLAUDE_CONFIG_DIR": try #require(workspace.claudeConfigURL).path,
			])
		}
	}

	@Test("Rejects an unknown workspace")
	func missingWorkspace() async throws {
		let fixture: ClientTestFixture = try .init()
		let application: ClaudeApplicationSpy = .init()
		defer { fixture.remove() }

		await withDependencies {
			$0.context = .live
			$0._fxclaudeApplication = application.client
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			await #expect(throws: FXClaudeError.workspaceNotFound("missing")) {
				try await client.claudeInvocation("missing", [])
			}
		}
	}
}
