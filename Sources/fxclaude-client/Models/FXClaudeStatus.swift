import Foundation

public struct FXClaudeStatus: Codable, Equatable, Sendable {
	public let currentWorkspace: String
	public let currentWorkspaceID: WorkspaceID
	public let supportDirectoryURL: URL
	public let applicationURL: URL?
	public let workspaces: [WorkspaceStatus]

	public init(
		currentWorkspace: String,
		currentWorkspaceID: WorkspaceID,
		supportDirectoryURL: URL,
		applicationURL: URL?,
		workspaces: [WorkspaceStatus]
	) {
		self.currentWorkspace = currentWorkspace
		self.currentWorkspaceID = currentWorkspaceID
		self.supportDirectoryURL = supportDirectoryURL
		self.applicationURL = applicationURL
		self.workspaces = workspaces
	}
}
