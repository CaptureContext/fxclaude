import Dependencies
import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("Application instances storage")
struct AppInstancesStorageTests {
	@Test("Runtime records persist process identity and can be removed")
	func recordLifecycle() async throws {
		let fixture: ClientTestFixture = try .init()
		let applicationURL: URL = fixture.applicationsURL.appending(path: "Claude.app")
		defer { fixture.remove() }

		try withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: AppInstancesStorage = .init(fileManager: .default)
			let workspaceID = WorkspaceID.generate()
			try storage.setRecord(
				.init(
					bundleURL: applicationURL,
					launchDate: Date(timeIntervalSince1970: 1_000),
					processID: 42
				),
				forWorkspaceID: workspaceID
			)
			let data: Data = try .init(contentsOf: fixture.rootURL.appending(
				path: "runtime.json"
			))
			let object: [String: Any] = try #require(
				JSONSerialization.jsonObject(with: data) as? [String: Any]
			)
			#expect(object["schema_version"] as? String == "2.0")
			let instances = try #require(object["instances"] as? [String: Any])
			let record: [String: Any] = try #require(instances[workspaceID.rawValue] as? [String: Any])
			#expect(Set(record.keys) == ["bundle_url", "launch_date", "process_id"])
			#expect(try storage.record(forWorkspaceID: workspaceID)?.processID == 42)
			#expect(try storage.record(forWorkspaceID: workspaceID)?.bundleURL == applicationURL)
			try storage.setRecord(nil, forWorkspaceID: workspaceID)
			#expect(try storage.record(forWorkspaceID: workspaceID) == nil)

		}
	}
}
