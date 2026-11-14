import ArgumentParser
import Dependencies
import Darwin
import Foundation
import FXClaudeClient

@main
internal struct AppCommand: AsyncParsableCommand {
	internal static let version: String = "0.1.0"
	internal static let machineEncodingFailureResponse: String = """
	{
	  "api_version": 1,
	  "error": {
	    "code": "encoding_failed",
	    "message": "Unable to encode the error response."
	  },
	  "ok": false
	}
	"""

	@Flag(
		inversion: .prefixedNo,
		exclusivity: .chooseLast,
		help: "Print versioned machine-readable JSON from supported commands. Defaults from FXCLAUDE_JSON."
	)
	internal var json: Bool?

	internal static let configuration: CommandConfiguration = .init(
		commandName: "fxclaude",
		abstract: "Manage isolated Claude desktop workspaces.",
		version: Self.version,
			subcommands: [
			WorkspaceCommand.self,
			WorkspaceCommand.Use.self,
			WorkspaceCommand.Delete.self,
			WorkspaceCommand.Erase.self,
			OpenCommand.self,
			OpenURLCommand.self,
			CLICommand.self,
			ExecCommand.self,
			StatusCommand.self,
			IntegrationsCommand.self,
			VersionCommand.self,
		],
		defaultSubcommand: nil
	)

	internal init() {}

	internal static func main() async {
		var rawOutputRequested: Bool = false

		do {
			let command: any ParsableCommand = try await Self.asyncParseAsRoot()
			rawOutputRequested = Self.rawOutputRequested(command)
			try await Self.prepareForExecution(command)

			try await Self.execute(command)
		} catch {
			guard
				!rawOutputRequested,
				globalMachineOutputRequested(),
				!(error is CleanExit)
			else {
				Self.exit(withError: error)
			}

			do {
				try printMachineError(error)
			} catch {
				FileHandle.standardError.write(
					Data("\(Self.machineEncodingFailureResponse)\n".utf8)
				)
			}

			Darwin.exit(Self.exitCode(for: error).rawValue)
		}
	}

	internal static func rawOutputRequested(
		_ command: any ParsableCommand,
		arguments: [String] = .init(CommandLine.arguments.dropFirst())
	) -> Bool {
		guard
			let paths = command as? WorkspaceCommand.Paths,
			paths.printComponent != nil,
			paths.json != true,
			machineOutputArgumentValue(arguments: arguments) != true
		else { return false }

		return true
	}

	internal static func prepareForExecution(
		_ command: any ParsableCommand
	) async throws {
		@Dependency(\.fxClaudeClient)
		var client: FXClaudeClient

		try await client.prepareStorage()
	}

	private static func execute(
		_ command: any ParsableCommand
	) async throws {
		var command: any ParsableCommand = command

		if var asyncCommand = command as? any AsyncParsableCommand {
			try await asyncCommand.run()
		} else {
			try command.run()
		}
	}
}

internal struct VersionCommand: ParsableCommand {
	internal static let configuration: CommandConfiguration = .init(
		commandName: "version",
		abstract: "Show the fxclaude version."
	)

	@Flag(
		inversion: .prefixedNo,
		exclusivity: .chooseLast,
		help: "Print a versioned machine-readable JSON response. Defaults from FXCLAUDE_JSON."
	)
	internal var json: Bool?

	internal init() {}

	internal func run() throws {
		if machineOutputRequested(self.json) {
			try printMachineResponse(VersionOutput(version: AppCommand.version))
			return
		}

		Swift.print(AppCommand.version)
	}
}
