import ArgumentParser
import Testing
@testable
import FXClaudeCLI

@Suite("Exec command")
struct ExecCommandTests {
	@Test("Forwards arguments after the workspace")
	func forwardsArguments() async throws {
		let command: AppCommand.ExecCommand = try .parse([
			"primary",
			"--",
			"--output-format",
			"json",
			"Summarize the diff",
		])
		#expect(command.workspaceName == "primary")
		#expect(command.arguments == [
			"--output-format",
			"json",
			"Summarize the diff",
		])
	}

	@Test("A prompt after a leading -- is not a workspace name")
	func promptWithoutWorkspace() async throws {
		let command: AppCommand.ExecCommand = try .parse([
			"--",
			"hello",
		])
		#expect(command.workspaceName == nil)
		#expect(command.arguments == ["hello"])
	}

	@Test("Accepts an empty argument list")
	func emptyArguments() async throws {
		let command: AppCommand.ExecCommand = try .parse([])
		#expect(command.workspaceName == nil)
		#expect(command.arguments.isEmpty)
	}
}
