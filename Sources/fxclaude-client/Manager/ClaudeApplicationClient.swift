import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct ClaudeApplicationClient: Sendable {
	var applicationURL: @Sendable () async -> URL?
	var open: @Sendable (Workspace) async throws -> Int32
	var runningProcessID: @Sendable (Workspace) async throws -> Int32?
	var urlSchemes: @Sendable () async throws -> [String]
	var sendURL: @Sendable (_ url: URL, _ processID: Int32) async throws -> Void
	var launchWithURL: @Sendable (_ workspace: Workspace, _ url: URL) async throws -> Int32
	var removeRecord: @Sendable (_ workspace: Workspace) async throws -> Void
}

extension DependencyValues {
	private enum ClaudeApplicationClientKey: DependencyKey {
		static var liveValue: ClaudeApplicationClient {
			.init(
				applicationURL: {
					let controller: ClaudeApplicationController = await .init()
					return await controller.applicationURL()
				},
				open: {
					let controller: ClaudeApplicationController = await .init()
					return try await controller.open(workspace: $0)
				},
				runningProcessID: {
					let controller: ClaudeApplicationController = await .init()
					return try await controller.runningProcessID(for: $0)
				},
				urlSchemes: {
					let controller: ClaudeApplicationController = await .init()
					return try await controller.urlSchemes()
				},
				sendURL: { url, processID in
					let controller: ClaudeApplicationController = await .init()
					try await controller.send(url: url, toProcessID: processID)
				},
				launchWithURL: { workspace, url in
					let controller: ClaudeApplicationController = await .init()
					return try await controller.launch(workspace: workspace, with: url)
				},
				removeRecord: {
					let controller: ClaudeApplicationController = await .init()
					try await controller.removeRecord(forWorkspaceID: $0.id)
				}
			)
		}
	}

	var _fxclaudeApplication: ClaudeApplicationClient {
		get { self[ClaudeApplicationClientKey.self] }
		set { self[ClaudeApplicationClientKey.self] = newValue }
	}
}
