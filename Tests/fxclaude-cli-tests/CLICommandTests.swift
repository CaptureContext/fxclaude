import ArgumentParser
import Testing
@testable
import FXClaudeCLI

@Suite("CLI command")
struct CLICommandTests {
	@Test("Forwards arguments after the workspace")
	func forwardsArguments() async throws {
		let command: AppCommand.CLICommand = try .parse([
			"work",
			"--",
			"--model",
			"opus",
		])
		#expect(command.workspaceName == "work")
		#expect(command.arguments == ["--model", "opus"])
	}

	@Test("Forwards flags after the workspace without --")
	func forwardsFlagsWithoutSeparator() async throws {
		let command: AppCommand.CLICommand = try .parse([
			"work",
			"--resume",
		])
		#expect(command.workspaceName == "work")
		#expect(command.arguments == ["--resume"])
	}

	@Test("Defaults to the current workspace")
	func currentWorkspace() async throws {
		let command: AppCommand.CLICommand = try .parse([])
		#expect(command.workspaceName == nil)
		#expect(command.arguments.isEmpty)
	}

	@Test("A leading -- forwards everything to the current workspace")
	func forwardsArgumentsWithoutWorkspace() async throws {
		let command: AppCommand.CLICommand = try .parse([
			"--",
			"--resume",
			"work",
		])
		#expect(command.workspaceName == nil)
		#expect(command.arguments == ["--resume", "work"])
	}

	@Test("A leading flag forwards everything to the current workspace")
	func forwardsLeadingFlag() async throws {
		let command: AppCommand.CLICommand = try .parse([
			"--continue",
		])
		#expect(command.workspaceName == nil)
		#expect(command.arguments == ["--continue"])
	}

	@Test("A leading --help shows fxclaude's help, after -- it is forwarded")
	func help() async throws {
		#expect(throws: CleanExit.self) {
			try rejectHelpBeforePassthrough(["--help"], for: AppCommand.CLICommand())
		}
		#expect(throws: CleanExit.self) {
			try rejectHelpBeforePassthrough(["-h", "work"], for: AppCommand.ExecCommand())
		}
		#expect(throws: (any Error).self) {
			try AppCommand.CLICommand.parse(["--help"])
		}
		#expect(
			AppCommand.CLICommand.fullMessage(for: CleanExit.helpRequest(AppCommand.CLICommand()))
				.contains("Run Claude Code in a workspace.")
		)

		let forwarded: AppCommand.CLICommand = try .parse(["--", "--help"])
		#expect(forwarded.workspaceName == nil)
		#expect(forwarded.arguments == ["--help"])
	}

	@Test("Parses from the root")
	func rootSubcommand() async throws {
		let command: any ParsableCommand = try AppCommand.parseAsRoot([
			"cli",
			"work",
			"--",
			"--json",
		])
		let cli: AppCommand.CLICommand = try #require(command as? AppCommand.CLICommand)
		#expect(cli.workspaceName == "work")
		#expect(cli.arguments == ["--json"])
	}

	@Test("Flags after cli or exec are not fxclaude's --json")
	func passthroughMachineOutput() async throws {
		#expect(machineOutputArgumentValue(arguments: ["cli", "work", "--", "--json"]) == nil)
		#expect(machineOutputArgumentValue(arguments: ["exec", "--json"]) == nil)
		#expect(machineOutputArgumentValue(arguments: ["--json", "cli", "work"]) == true)
		#expect(machineOutputArgumentValue(arguments: ["open", "cli", "--json"]) == true)
	}
}
