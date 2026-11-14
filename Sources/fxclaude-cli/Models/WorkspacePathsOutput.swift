import Foundation
import FXClaudeClient

internal enum WorkspacePathComponent: String, CaseIterable, Codable, Equatable, Sendable {
	case workspaceRoot = "workspace-root"
	case claudeConfig = "claude-config"
	case userData = "user-data"
}

internal struct ResolvedWorkspacePaths: Equatable, Sendable {
	internal let workspace: Workspace
	internal let workspaceRootURL: URL
	internal let claudeConfigURL: URL
	internal let userDataURL: URL

	internal init(
		workspace: Workspace
	) throws {
		guard
			let workspaceRootURL = workspace.rootURL,
			let claudeConfigURL = workspace.claudeConfigURL,
			let userDataURL = workspace.userDataURL
		else {
			throw FXClaudeError.invalidStorage(
				"workspace paths are missing for \(workspace.name)"
			)
		}

		self.workspace = workspace
		self.workspaceRootURL = workspaceRootURL
		self.claudeConfigURL = claudeConfigURL
		self.userDataURL = userDataURL
	}

	internal func url(
		for component: WorkspacePathComponent
	) -> URL {
		switch component {
		case .workspaceRoot: self.workspaceRootURL
		case .claudeConfig: self.claudeConfigURL
		case .userData: self.userDataURL
		}
	}
}

internal struct WorkspacePathSections: Equatable, Sendable {
	internal let workspaceRoot: Bool
	internal let claudeConfig: Bool
	internal let userData: Bool

	internal init(
		workspaceRoot: Bool,
		claudeConfig: Bool,
		userData: Bool
	) {
		self.workspaceRoot = workspaceRoot
		self.claudeConfig = claudeConfig
		self.userData = userData
	}
}

internal struct WorkspacePathsOutput: Encodable {
	internal let workspaceID: WorkspaceID
	internal let workspaceName: String
	internal let workspaceKind: WorkspaceKind
	internal let workspaceRootURL: URL?
	internal let claudeConfigURL: URL?
	internal let userDataURL: URL?

	internal init(
		paths: ResolvedWorkspacePaths,
		sections: WorkspacePathSections
	) {
		self.workspaceID = paths.workspace.id
		self.workspaceName = paths.workspace.name
		self.workspaceKind = paths.workspace.kind
		self.workspaceRootURL = sections.workspaceRoot ? paths.workspaceRootURL : nil
		self.claudeConfigURL = sections.claudeConfig ? paths.claudeConfigURL : nil
		self.userDataURL = sections.userData ? paths.userDataURL : nil
	}
}
