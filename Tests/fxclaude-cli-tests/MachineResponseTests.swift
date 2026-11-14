import ArgumentParser
import Dependencies
import Foundation
import FXClaudeClient
import Testing
@testable
import FXClaudeCLI

@Suite("Machine response")
struct MachineResponseTests {
	@Test("Success responses use the versioned envelope")
	func success() async throws {
		let data: Data = try encodedJSON(MachineResponse(
			data: VersionOutput(version: "1.2.3")
		))
		let object: [String: Any] = try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)
		let output: [String: Any] = try #require(object["data"] as? [String: Any])

		#expect(object["api_version"] as? Int == 1)
		#expect(object["ok"] as? Bool == true)
		#expect(output["version"] as? String == "1.2.3")
	}

	@Test("Encoding failure fallback uses the machine JSON contract")
	func encodingFailureFallback() throws {
		let data: Data = .init(AppCommand.machineEncodingFailureResponse.utf8)
		let object: [String: Any] = try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)
		let error: [String: Any] = try #require(
			object["error"] as? [String: Any]
		)

		#expect(object["api_version"] as? Int == 1)
		#expect(object["apiVersion"] == nil)
		#expect(object["ok"] as? Bool == false)
		#expect(error["code"] as? String == "encoding_failed")
	}

	@Test("Client errors expose stable codes")
	func clientError() async throws {
		let response: MachineErrorResponse = .init(
			error: FXClaudeError.workspaceNotFound("work")
		)

		#expect(response.apiVersion == 1)
		#expect(!response.ok)
		#expect(response.error.code == "workspace_not_found")
		#expect(response.error.message == "Workspace 'work' does not exist.")
	}

	@Test("Validation errors use the invalid arguments code")
	func validationError() async throws {
		let response: MachineErrorResponse = .init(
			error: ValidationError("A workspace name is required.")
		)

		#expect(response.error.code == "invalid_arguments")
		#expect(response.error.message == "A workspace name is required.")
	}

	@Test("Workspace names do not swallow JSON flags")
	func workspaceNameArguments() async throws {
		for name in ["work", "cli", "exec"] {
			#expect(globalMachineOutputRequested(
				arguments: ["open", name, "--json"],
				environment: [:]
			))
		}
	}

	@Test("Environment enables JSON unless an argument disables it")
	func environmentJSON() async throws {
		let environment: [String: String] = ["FXCLAUDE_JSON": "1"]

		#expect(globalMachineOutputRequested(
			arguments: ["status"],
			environment: environment
		))
		#expect(!globalMachineOutputRequested(
			arguments: ["--no-json", "status"],
			environment: environment
		))
	}

	@Test("Commands read environment through the injected client")
	func injectedEnvironment() {
		withDependencies {
			$0._fxclaudeEnvironment = .init(values: {
				["FXCLAUDE_JSON": "1"]
			})
		} operation: {
			#expect(globalMachineOutputRequested(arguments: ["status"]))
			#expect(!globalMachineOutputRequested(arguments: ["--no-json", "status"]))
		}
	}


	@Test("Nested output properties use lower snake case")
	func lowerSnakeCase() async throws {
		let data: Data = try encodedJSON(MachineResponse(
			data: OpenWorkspaceOutput(workspaceName: "work", processID: 42)
		))
		let object: [String: Any] = try #require(
			JSONSerialization.jsonObject(with: data) as? [String: Any]
		)
		let output: [String: Any] = try #require(object["data"] as? [String: Any])

		#expect(output["workspace_name"] as? String == "work")
		#expect(output["process_id"] as? Int == 42)
		#expect(output["workspaceName"] == nil)
		#expect(output["processID"] == nil)
	}

	@Test("Every client error has a stable machine code")
	func clientErrorCodes() async throws {
		let cases: [(FXClaudeError, String)] = [
			(.applicationNotFound, "application_not_found"),
			(.ambiguousApplicationInstances([42]), "ambiguous_application_instances"),
			(.integrationAttributeNotFound("raycast.icon"), "integration_attribute_not_found"),
			(.invalidAttributePath("icons.(unknown)"), "invalid_attribute_path"),
			(.invalidStorage("missing metadata"), "invalid_storage"),
			(.invalidWorkspaceName("Work"), "invalid_workspace_name"),
			(.primaryWorkspaceMutation, "primary_workspace_mutation"),
			(.unsupportedSchemaVersion(.init(major: 3, minor: 0)), "unsupported_schema_version"),
			(.workspaceAlreadyExists("work"), "workspace_already_exists"),
			(.workspaceIsRunning("work"), "workspace_is_running"),
			(.workspaceNotFound("work"), "workspace_not_found"),
		]

		for (error, code) in cases {
			#expect(error.code == code)
		}
	}

}
