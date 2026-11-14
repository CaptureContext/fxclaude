import Foundation
import Dependencies

public struct Integrations: Sendable {
	public var raycast: Raycast
	public var attributes: IntegrationAttributes

	public init(
		raycast: Raycast,
		attributes: IntegrationAttributes
	) {
		self.raycast = raycast
		self.attributes = attributes
	}
}

extension DependencyValues {
	public var _fxclaudeIntegrations: Integrations {
		get {
			.init(
				raycast: _fxclaudeRaycast,
				attributes: _fxclaudeIntegrationAttributes
			)
		}
		set {
			self._fxclaudeRaycast = newValue.raycast
			self._fxclaudeIntegrationAttributes = newValue.attributes
		}
	}
}
