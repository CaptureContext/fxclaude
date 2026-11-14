import ArgumentParser
import Dependencies
import FXClaudeClient

extension AppCommand {
	internal struct WorkspaceCommand: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			commandName: "workspace",
			abstract: "Manage isolated Claude workspaces.",
			subcommands: [
				List.self,
				Create.self,
				Delete.self,
				Erase.self,
				Paths.self,
				Use.self,
				OpenCommand.self,
			],
			defaultSubcommand: List.self
		)

		internal init() {}
	}
}
