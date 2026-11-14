import ArgumentParser
import Dependencies
import Foundation
import FXClaudeClient

extension AppCommand {
	internal struct StatusCommand: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			commandName: "status",
			abstract: "Show fxclaude status with optionally expanded sections."
		)

		@Flag(
			inversion: .prefixedNo,
			exclusivity: .chooseLast,
			help: "Print a versioned machine-readable JSON response. Defaults from FXCLAUDE_JSON."
		)
		internal var json: Bool?

		@Flag(
			inversion: .prefixedNo,
			exclusivity: .chooseLast,
			help: "List every optional status section. Defaults from FXCLAUDE_STATUS_ALL."
		)
		internal var all: Bool?

		@Flag(
			inversion: .prefixedNo,
			exclusivity: .chooseLast,
			help: "List workspaces. Defaults from FXCLAUDE_STATUS_LIST_WORKSPACES; -1 disables it even when all is enabled."
		)
		internal var listWorkspaces: Bool?

		internal init() {}

		internal func run() async throws {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			let sections: StatusSections = try self.sections()
			let status: FXClaudeStatus = try await client.status()

			if machineOutputRequested(self.json) {
				try printMachineResponse(StatusOutput(
					status: status,
					sections: sections
				))
				return
			}

			let reporter: TerminalReporter = await .init()
			await reporter.info("Current workspace: \(status.currentWorkspace)")
			await reporter.info("Support directory: \(status.supportDirectoryURL.path)")
			await reporter.info(
				"Application: \(status.applicationURL?.path ?? "not found")"
			)

			if sections.workspaces {
				await reporter.info("")
				await reporter.info("Workspaces:")
				for workspace in status.workspaces {
					let currentMarker: String = workspace.isCurrent ? "*" : " "
					let processDescription: String = workspace.processID
					.map { "running · pid \($0)" }
					?? "stopped"

					await reporter.info(
						"\(currentMarker) \(workspace.workspace.name)\t\(processDescription)"
					)
				}
			}

		}
	}
}

extension AppCommand.StatusCommand {
	internal func sections(
		environment: [String: String]? = nil
	) throws -> StatusSections {
		let environment = environment ?? currentEnvironment()
		let environmentAll: Bool? = try environmentSwitch(
			named: "FXCLAUDE_STATUS_ALL",
			in: environment
		)
		let environmentWorkspaces: Bool? = try environmentSwitch(
			named: "FXCLAUDE_STATUS_LIST_WORKSPACES",
			in: environment
		)
		let all: Bool = self.all ?? environmentAll ?? false
		return .init(
			workspaces: self.listWorkspaces
			?? environmentWorkspaces
			?? all
		)
	}
}
