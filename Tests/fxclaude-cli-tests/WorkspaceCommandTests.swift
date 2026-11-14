import ArgumentParser
import Testing
@testable
import FXClaudeCLI

@Suite("Workspace command")
struct WorkspaceCommandTests {
	@Test("Create parses lifecycle flags")
	func create() async throws {
		let command: AppCommand.WorkspaceCommand.Create = try .parse([
			"work",
			"--use",
			"--open",
			"--json",
		])
		#expect(command.name == "work")
		#expect(command.use)
		#expect(command.open)
		#expect(command.json == true)

		let interactive: AppCommand.WorkspaceCommand.Create = try .parse([])
		#expect(interactive.name == nil)
	}

	@Test("Delete parses multiple workspaces and confirmation flag")
	func delete() async throws {
		let explicit: AppCommand.WorkspaceCommand.Delete = try .parse([
			"work",
			"personal",
			"--yes",
			"--json",
		])
		#expect(explicit.names == ["work", "personal"])
		#expect(explicit.yes)
		#expect(explicit.json == true)

		let interactive: AppCommand.WorkspaceCommand.Delete = try .parse([])
		#expect(interactive.names.isEmpty)
		#expect(!interactive.yes)
	}

	@Test("Erase parses multiple workspaces and confirmation flag")
	func erase() async throws {
		let explicit: AppCommand.WorkspaceCommand.Erase = try .parse([
			"work",
			"personal",
			"--yes",
			"--json",
		])
		#expect(explicit.names == ["work", "personal"])
		#expect(explicit.yes)
		#expect(explicit.json == true)

		let interactive: AppCommand.WorkspaceCommand.Erase = try .parse([])
		#expect(interactive.names.isEmpty)
		#expect(!interactive.yes)
	}

	@Test("Use requires a workspace")
	func use() async throws {
		let command: AppCommand.WorkspaceCommand.Use = try .parse(["work"])
		#expect(command.name == "work")

		let interactive: AppCommand.WorkspaceCommand.Use = try .parse([])
		#expect(interactive.name == nil)
	}
}
