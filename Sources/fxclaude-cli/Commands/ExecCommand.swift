import ArgumentParser
import Dependencies
import FXClaudeClient

extension AppCommand {
	internal struct ExecCommand: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			commandName: "exec",
			abstract: "Run Claude Code non-interactively (claude -p) in a workspace.",
			discussion: """
			Runs `claude -p` from PATH with the same workspace environment as `fxclaude cli`.
			"""
		)

		@Argument(
			parsing: .captureForPassthrough,
			help: .init(
				"""
				An optional workspace name (defaults to the current workspace), then the arguments \
				forwarded to claude -p. Put -- before them when the first one could be read as a \
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
			try rejectMachineOutput(for: "exec")

			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let invocation: CommandInvocation = try await client.claudeInvocation(
				self.workspaceName,
				["-p"] + self.arguments
			)
			try replaceProcess(with: invocation)
		}
	}
}
