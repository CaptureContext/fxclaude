import Foundation
import FXClaudeClient

internal struct StatusOutput: Encodable {
	internal let currentWorkspace: String
	internal let currentWorkspaceID: WorkspaceID
	internal let supportDirectoryURL: URL
	internal let applicationURL: URL?
	internal let workspaces: [WorkspaceStatus]?

	internal init(
		status: FXClaudeStatus,
		sections: StatusSections
	) {
		self.currentWorkspace = status.currentWorkspace
		self.currentWorkspaceID = status.currentWorkspaceID
		self.supportDirectoryURL = status.supportDirectoryURL
		self.applicationURL = status.applicationURL
		self.workspaces = sections.workspaces ? status.workspaces : nil
	}
}

internal struct StatusSections: Equatable {
	internal let workspaces: Bool

	internal init(
		workspaces: Bool
	) {
		self.workspaces = workspaces
	}
}
