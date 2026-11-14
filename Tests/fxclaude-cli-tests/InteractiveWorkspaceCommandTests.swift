import ArgumentParser
import Dependencies
import Foundation
import FXClaudeClient
import Testing
@testable
import FXClaudeCLI

@Suite("Interactive workspace commands")
struct InteractiveWorkspaceCommandTests {
	@Test("Use selects from every workspace")
	func use() async throws {
		let primary: Workspace = Self.workspace(named: Workspace.primaryName, kind: .primary)
		let work: Workspace = Self.workspace(named: "work", kind: .managed)
		let options: LockIsolated<[TerminalPromptOption]> = .init([])
		let usedWorkspaceName: LockIsolated<String?> = .init(nil)
		var client: FXClaudeClient = .init()
		client.workspaces = { [primary, work] }
		client.currentWorkspace = { primary }
		client.useWorkspace = { usedWorkspaceName.setValue($0) }

		try await withDependencies {
			$0.fxClaudeClient = client
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, promptOptions in
					options.setValue(promptOptions)
					return work.name
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.WorkspaceCommand.Use = try .parse([])
			try await command.run()
		}

		#expect(options.value.map(\.value) == [Workspace.primaryName, work.name])
		#expect(options.value.map(\.hint) == ["current", nil])
		#expect(usedWorkspaceName.value == work.name)
	}

	@Test("Open presents the current workspace first")
	func open() async throws {
		let primary: Workspace = Self.workspace(named: Workspace.primaryName, kind: .primary)
		let personal: Workspace = Self.workspace(named: "personal", kind: .managed)
		let work: Workspace = Self.workspace(named: "work", kind: .managed)
		let options: LockIsolated<[TerminalPromptOption]> = .init([])
		let openedWorkspaceID: LockIsolated<WorkspaceID?> = .init(nil)
		var client: FXClaudeClient = .init()
		client.workspaces = { [primary, personal, work] }
		client.currentWorkspace = { work }
		client.openWorkspaceByID = {
			openedWorkspaceID.setValue($0)
			return 42
		}

		try await withDependencies {
			$0.fxClaudeClient = client
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, promptOptions in
					options.setValue(promptOptions)
					return work.id.rawValue
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.OpenCommand = try .parse([])
			try await command.run()
		}

		#expect(options.value.map(\.value) == [work.id.rawValue, primary.id.rawValue, personal.id.rawValue])
		#expect(options.value.first?.hint == "current")
		#expect(openedWorkspaceID.value == work.id)
	}

	@Test("Delete excludes primary and forwards every selected workspace")
	func delete() async throws {
		let primary: Workspace = Self.workspace(named: Workspace.primaryName, kind: .primary)
		let personal: Workspace = Self.workspace(named: "personal", kind: .managed)
		let work: Workspace = Self.workspace(named: "work", kind: .managed)
		let options: LockIsolated<[TerminalPromptOption]> = .init([])
		let deletedWorkspaceNames: LockIsolated<[String]> = .init([])
		var client: FXClaudeClient = .init()
		client.workspaces = { [primary, personal, work] }
		client.deleteWorkspaces = { deletedWorkspaceNames.setValue($0) }

		try await withDependencies {
			$0.fxClaudeClient = client
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in nil },
				multiselect: { _, promptOptions in
					options.setValue(promptOptions)
					return [personal.name, work.name]
				},
				confirm: { _ in true }
			)
		} operation: {
			let command: AppCommand.WorkspaceCommand.Delete = try .parse([])
			try await command.run()
		}

		#expect(options.value.map(\.value) == [personal.name, work.name])
		#expect(deletedWorkspaceNames.value == [personal.name, work.name])
	}

	@Test("Erase accepts multiple explicit workspaces without prompting for selection")
	func erase() async throws {
		let erasedWorkspaceNames: LockIsolated<[String]> = .init([])
		let didRequestSelection: LockIsolated<Bool> = .init(false)
		var client: FXClaudeClient = .init()
		client.eraseWorkspaces = { names in
			erasedWorkspaceNames.setValue(names)
			return names.map { Self.workspace(named: $0, kind: .managed) }
		}

		try await withDependencies {
			$0.fxClaudeClient = client
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in nil },
				multiselect: { _, _ in
					didRequestSelection.setValue(true)
					return nil
				},
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.WorkspaceCommand.Erase = try .parse([
				"work",
				"personal",
				"work",
				"--yes",
			])
			try await command.run()
		}

		#expect(!didRequestSelection.value)
		#expect(erasedWorkspaceNames.value == ["work", "personal"])
	}

	@Test("JSON use requires an explicit workspace without prompting")
	func jsonUse() async throws {
		let didPrompt: LockIsolated<Bool> = .init(false)

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in
					didPrompt.setValue(true)
					return nil
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.WorkspaceCommand.Use = try .parse(["--json"])
			await #expect(throws: ValidationError.self) {
				try await command.run()
			}
		}

		#expect(!didPrompt.value)
	}

	@Test("JSON deletion requires names and confirmation without prompting")
	func jsonDelete() async throws {
		let didPrompt: LockIsolated<Bool> = .init(false)

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in nil },
				multiselect: { _, _ in
					didPrompt.setValue(true)
					return nil
				},
				confirm: { _ in
					didPrompt.setValue(true)
					return nil
				}
			)
		} operation: {
			let missingNames: AppCommand.WorkspaceCommand.Delete = try .parse(["--json"])
			await #expect(throws: ValidationError.self) {
				try await missingNames.run()
			}

			let missingConfirmation: AppCommand.WorkspaceCommand.Delete = try .parse([
				"work",
				"--json",
			])
			await #expect(throws: ValidationError.self) {
				try await missingConfirmation.run()
			}
		}

		#expect(!didPrompt.value)
	}

	private static func workspace(
		named name: String,
		kind: WorkspaceKind
	) -> Workspace {
		.init(
			name: name,
			kind: kind,
			rootURL: nil,
			claudeConfigURL: nil,
			userDataURL: nil,
			integrations: [:]
		)
	}
}
