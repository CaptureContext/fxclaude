import Foundation
import Dependencies

actor ClaudeManager {
	@Dependency(\._fxclaudeApplication)
	private var application

	@Dependency(\._fxclaudePaths)
	private var paths: FXClaudePaths

	@Dependency(\._fxclaudeWorkspaces)
	private var workspacesStorage: WorkspacesStorageClient

	init() {}

	func workspaces() throws -> [Workspace] {
		try workspacesStorage.list()
	}

	func prepareStorage() throws {
		try self.workspacesStorage.prepare()
	}

	func currentWorkspace() throws -> Workspace {
		try workspacesStorage.currentWorkspace()
	}

	func createWorkspace(named name: String) async throws -> Workspace {
		let workspace: Workspace = try self.workspacesStorage.create(name)
		return workspace
	}

	func deleteWorkspace(named name: String?) async throws {
		let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: name)
		try await self.deleteWorkspaces([workspace])
	}

	func deleteWorkspaces(named names: [String]) async throws {
		try await self.deleteWorkspaces(
			try self.managedWorkspaces(named: names)
		)
	}

	func eraseWorkspace(named name: String?) async throws -> Workspace {
		let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: name)
		return try await self.eraseWorkspaces([workspace])[0]
	}

	func eraseWorkspaces(named names: [String]) async throws -> [Workspace] {
		try await self.eraseWorkspaces(
			try self.managedWorkspaces(named: names)
		)
	}

	func useWorkspace(named name: String) throws {
		try self.workspacesStorage.setCurrent(self.workspacesStorage.findWorkspace(named: name))
	}

	func useWorkspace(id: WorkspaceID) throws {
		try self.workspacesStorage.setCurrent(self.workspacesStorage.findWorkspaceByID(id))
	}

	func openWorkspace(named name: String?) async throws -> Int32 {
		let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: name)
		return try await self.application.open(workspace)
	}

	func openWorkspace(id: WorkspaceID) async throws -> Int32 {
		try await self.application.open(self.workspacesStorage.findWorkspaceByID(id))
	}

	/// Builds the `claude` command line for a workspace.
	///
	/// Managed workspaces point Claude Code at their own config directory. The primary workspace sets
	/// nothing, so Claude Code keeps `~/.claude` or a `CLAUDE_CONFIG_DIR` already in the environment.
	func claudeInvocation(
		workspaceName: String?,
		arguments: [String]
	) throws -> CommandInvocation {
		let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: workspaceName)
		let environment: [String: String]

		if workspace.kind == .managed {
			guard let claudeConfigURL = workspace.claudeConfigURL
			else { throw FXClaudeError.workspaceNotFound(workspace.name) }

			environment = ["CLAUDE_CONFIG_DIR": claudeConfigURL.path]

		} else {
			environment = [:]
		}

		return .init(
			executable: "claude",
			arguments: arguments,
			environment: environment
		)
	}

	/// Delivers an app link to one workspace's Claude instance.
	///
	/// A running instance gets a `kAEGetURL` Apple Event addressed to its process ID.
	/// Otherwise a new instance launches with the workspace's environment and the link.
	/// Neither path asks Launch Services to route the link by scheme.
	func openURL(
		_ rawURL: String,
		inWorkspaceNamed name: String
	) async throws -> URLDelivery {
		let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: name)
		let schemes: [String] = try await self.application.urlSchemes()

		guard
			let url = URL(string: rawURL),
			let scheme = url.scheme?.lowercased(),
			schemes.contains(scheme)
		else { throw FXClaudeError.unsupportedURL(rawURL, supportedSchemes: schemes) }

		if let processID = try await self.application.runningProcessID(workspace) {
			try await self.application.sendURL(url, processID)
			return .init(
				workspace: workspace,
				url: url,
				processID: processID,
				method: .appleEvent
			)
		}

		return .init(
			workspace: workspace,
			url: url,
			processID: try await self.application.launchWithURL(workspace, url),
			method: .launch
		)
	}

	func status() async throws -> FXClaudeStatus {
		let currentWorkspace = try self.workspacesStorage.currentWorkspace()
		var workspaceStatuses: [WorkspaceStatus] = []

		for workspace in try self.workspacesStorage.list() {
			workspaceStatuses.append(.init(
				workspace: workspace,
				isCurrent: workspace.id == currentWorkspace.id,
				processID: try await self.application.runningProcessID(workspace)
			))
		}

		return .init(
			currentWorkspace: currentWorkspace.name,
			currentWorkspaceID: currentWorkspace.id,
			supportDirectoryURL: self.paths.rootURL,
			applicationURL: await self.application.applicationURL(),
			workspaces: workspaceStatuses
		)
	}
}

extension ClaudeManager {
	private func managedWorkspaces(named names: [String]) throws -> [Workspace] {
		var resolvedNames: Set<String> = []

		return try names.compactMap { name in
			guard resolvedNames.insert(name).inserted else { return nil }

			let workspace: Workspace = try self.workspacesStorage.findWorkspace(named: name)

			guard workspace.kind == .managed else { throw FXClaudeError.primaryWorkspaceMutation }

			return workspace
		}
	}

	private func ensureStopped(_ workspaces: [Workspace]) async throws {
		for workspace in workspaces {
			guard try await self.application.runningProcessID(workspace) == nil
			else { throw FXClaudeError.workspaceIsRunning(workspace.name) }
		}
	}

	private func deleteWorkspaces(_ workspaces: [Workspace]) async throws {
		try await self.ensureStopped(workspaces)

		for workspace in workspaces {
			guard workspace.kind == .managed else { throw FXClaudeError.primaryWorkspaceMutation }

			try self.workspacesStorage.delete(workspace)
			try await self.application.removeRecord(workspace)
		}
	}

	private func eraseWorkspaces(_ workspaces: [Workspace]) async throws -> [Workspace] {
		try await self.ensureStopped(workspaces)

		var erasedWorkspaces: [Workspace] = []

		for workspace in workspaces {
			guard workspace.kind == .managed else { throw FXClaudeError.primaryWorkspaceMutation }

			erasedWorkspaces.append(try self.workspacesStorage.erase(workspace))
			try await self.application.removeRecord(workspace)
		}

		return erasedWorkspaces
	}
}
