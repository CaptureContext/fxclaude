import ArgumentParser
import Dependencies
import FXClaudeClient

extension AppCommand {
	internal struct CLICommand: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			commandName: "cli",
			abstract: "Run Claude Code in a workspace.",
			discussion: """
			Runs `claude` from PATH. Managed workspaces set CLAUDE_CONFIG_DIR to the workspace's \
			claude-config directory; the primary workspace keeps ~/.claude or the CLAUDE_CONFIG_DIR \
			already in the environment.
			"""
		)

		@Argument(
			parsing: .captureForPassthrough,
			help: .init(
				"""
				An optional workspace name (defaults to the current workspace), then the arguments \
				forwarded to Claude Code. Put -- before them when the first one could be read as a \
				workspace name.
				""",
				valueName: "workspace] [-- <arguments>"
			)
		)
		internal var passthroughArguments: [String] = []

		internal var workspaceName: String? { splitPassthroughArguments(self.passthroughArguments).workspaceName }
		internal var arguments: [String] { splitPassthroughArguments(self.passthroughArguments).arguments }

		internal init() {}

		internal func validate() throws {
			try rejectHelpBeforePassthrough(self.passthroughArguments, for: self)
		}

		internal func run() async throws {
			try rejectMachineOutput(for: "cli")

			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let invocation: CommandInvocation = try await client.claudeInvocation(
				self.workspaceName,
				self.arguments
			)
			try replaceProcess(with: invocation)
		}
	}
}
