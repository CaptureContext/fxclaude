import Foundation
import Testing
@testable
import FXClaudeClient

@Suite("fxclaude JSON coding")
struct FXClaudeJSONCodingTests {
	private struct Payload: Codable, Equatable {
		let apiVersion: Int
		let applicationURL: URL
		let processID: Int32
	}

	@Test("Encodes property names as lower snake case")
	func lowerSnakeCase() throws {
		let payload: Payload = .init(
			apiVersion: 1,
			applicationURL: URL(filePath: "/Applications/Claude.app"),
			processID: 42
		)
		let data: Data = try FXClaudeJSONCoding.encoder().encode(payload)
		let object: [String: Any] = try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)

		#expect(Set(object.keys) == [
			"api_version",
			"application_url",
			"process_id",
		])
	}

}
