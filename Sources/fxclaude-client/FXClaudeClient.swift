import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct FXClaudeClient: Sendable {
	public var prepareStorage: @Sendable () async throws -> Void
	public var workspaces: @Sendable () async throws -> [Workspace]
	public var currentWorkspace: @Sendable () async throws -> Workspace
	public var createWorkspace: @Sendable (String) async throws -> Workspace
	public var deleteWorkspace: @Sendable (String?) async throws -> Void
	public var deleteWorkspaces: @Sendable ([String]) async throws -> Void
	public var eraseWorkspace: @Sendable (String?) async throws -> Workspace
	public var eraseWorkspaces: @Sendable ([String]) async throws -> [Workspace]
	public var useWorkspace: @Sendable (String) async throws -> Void
	public var useWorkspaceByID: @Sendable (WorkspaceID) async throws -> Void
	public var openWorkspace: @Sendable (String?) async throws -> Int32
	public var openWorkspaceByID: @Sendable (WorkspaceID) async throws -> Int32
	public var openURL: @Sendable (_ url: String, _ workspaceName: String) async throws -> URLDelivery
	public var claudeInvocation: @Sendable (
		_ workspaceName: String?,
		_ arguments: [String]
	) async throws -> CommandInvocation
	public var status: @Sendable () async throws -> FXClaudeStatus
}

extension FXClaudeClient {
	public var integrations: Integrations {
		Dependency(\._fxclaudeIntegrations).wrappedValue
	}
}

extension DependencyValues {
	private enum FXClaudeClientKey: DependencyKey {
		static var liveValue: FXClaudeClient {
			let manager = ClaudeManager()
			return .init(
				prepareStorage: { try await manager.prepareStorage() },
				workspaces: { try await manager.workspaces() },
				currentWorkspace: { try await manager.currentWorkspace() },
				createWorkspace: { try await manager.createWorkspace(named: $0) },
				deleteWorkspace: manager.deleteWorkspace,
				deleteWorkspaces: manager.deleteWorkspaces,
				eraseWorkspace: manager.eraseWorkspace,
				eraseWorkspaces: manager.eraseWorkspaces,
				useWorkspace: { try await manager.useWorkspace(named: $0) },
				useWorkspaceByID: { try await manager.useWorkspace(id: $0) },
				openWorkspace: manager.openWorkspace,
				openWorkspaceByID: { try await manager.openWorkspace(id: $0) },
				openURL: { try await manager.openURL($0, inWorkspaceNamed: $1) },
				claudeInvocation: {
					try await manager.claudeInvocation(workspaceName: $0, arguments: $1)
				},
				status: manager.status
			)
		}
	}

	public var fxClaudeClient: FXClaudeClient {
		get { self[FXClaudeClientKey.self] }
		set { self[FXClaudeClientKey.self] = newValue }
	}
}
