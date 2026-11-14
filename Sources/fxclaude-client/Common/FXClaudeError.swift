import Foundation

public enum FXClaudeError: Error, Equatable, LocalizedError, Sendable {
	case applicationNotFound
	case ambiguousApplicationInstances([Int32])
	case integrationAttributeNotFound(String)
	case invalidAttributePath(String)
	case invalidStorage(String)
	case invalidWorkspaceName(String)
	case primaryWorkspaceMutation
	case raycastBetaUnsupportedPlatform
	case unsupportedSchemaVersion(SchemaVersion)
	case unsupportedURL(String, supportedSchemes: [String])
	case urlDeliveryFailed(String)
	case workspaceAlreadyExists(String)
	case workspaceIsRunning(String)
	case workspaceNotFound(String)

	public var code: String {
		switch self {
		case .applicationNotFound: "application_not_found"
		case .ambiguousApplicationInstances: "ambiguous_application_instances"
		case .integrationAttributeNotFound: "integration_attribute_not_found"
		case .invalidAttributePath: "invalid_attribute_path"
		case .invalidStorage: "invalid_storage"
		case .invalidWorkspaceName: "invalid_workspace_name"
		case .primaryWorkspaceMutation: "primary_workspace_mutation"
		case .raycastBetaUnsupportedPlatform: "raycast_beta_unsupported_platform"
		case .unsupportedSchemaVersion: "unsupported_schema_version"
		case .unsupportedURL: "unsupported_url"
		case .urlDeliveryFailed: "url_delivery_failed"
		case .workspaceAlreadyExists: "workspace_already_exists"
		case .workspaceIsRunning: "workspace_is_running"
		case .workspaceNotFound: "workspace_not_found"
		}
	}

	public var errorDescription: String? {
		switch self {
		case .applicationNotFound:
			"No application with bundle identifier com.anthropic.claudefordesktop was found."

		case let .ambiguousApplicationInstances(processIDs):
			"Multiple unrecognized Claude instances are running: \(processIDs.map(String.init).joined(separator: ", "))."

		case let .integrationAttributeNotFound(path):
			"No integration attribute exists at '\(path)'."

		case let .invalidAttributePath(path):
			"Invalid integration attribute path '\(path)'."

		case let .invalidStorage(message):
			"Invalid fxclaude storage: \(message)"

		case let .invalidWorkspaceName(name):
			"Invalid workspace name '\(name)'. Use lowercase letters, numbers, and hyphens."

		case .primaryWorkspaceMutation:
			"The primary workspace cannot be created, erased, or deleted."

		case .raycastBetaUnsupportedPlatform:
			"Raycast Beta currently requires Apple silicon and macOS Tahoe or later."

		case let .unsupportedSchemaVersion(version):
			"Storage schema \(version) is unsupported. This fxclaude build supports schema 2.0."

		case let .unsupportedURL(url, supportedSchemes):
			"""
			Claude does not handle '\(url)'. \
			Supported schemes: \(supportedSchemes.map { "\($0)://" }.joined(separator: ", ")).
			"""

		case let .urlDeliveryFailed(message):
			"Could not deliver the link to Claude: \(message)"

		case let .workspaceAlreadyExists(name):
			"Workspace '\(name)' already exists."

		case let .workspaceIsRunning(name):
			"Workspace '\(name)' is currently open. Close it before continuing."

		case let .workspaceNotFound(name):
			"Workspace '\(name)' does not exist."
		}
	}
}
