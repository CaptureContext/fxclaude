import Foundation
import Dependencies
import DependenciesMacros

extension Integrations {
	@DependencyClient
	public struct Raycast: Sendable {
		public var applicationStatus: @Sendable (RaycastEdition) async throws -> RaycastApplicationStatus
		public var applicationInstallation: @Sendable (RaycastEdition) async throws -> RaycastApplicationInstallation
	}
}

extension DependencyValues {
	private enum RaycastIntegrationKey: DependencyKey {
		static var liveValue: Integrations.Raycast {
			let integration = RaycastIntegration()
			return .init(
				applicationStatus: {
					await integration.applicationStatus(for: $0)
				},
				applicationInstallation: {
					try await integration.applicationInstallation(for: $0)
				}
			)
		}
	}

	@_spi(Internals)
	public var _fxclaudeRaycast: Integrations.Raycast {
		get { self[RaycastIntegrationKey.self] }
		set { self[RaycastIntegrationKey.self] = newValue }
	}
}
