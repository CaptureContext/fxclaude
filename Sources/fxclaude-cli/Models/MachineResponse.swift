import ArgumentParser
import Foundation
import FXClaudeClient

internal struct MachineResponse<Value: Encodable>: Encodable {
	internal let apiVersion: Int
	internal let ok: Bool
	internal let data: Value

	internal init(
		data: Value
	) {
		self.apiVersion = 1
		self.ok = true
		self.data = data
	}
}

internal struct MachineErrorResponse: Encodable {
	internal struct Details: Encodable {
		internal let code: String
		internal let message: String

		internal init(
			code: String,
			message: String
		) {
			self.code = code
			self.message = message
		}
	}

	internal let apiVersion: Int
	internal let ok: Bool
	internal let error: Details

	internal init(
		error: any Error
	) {
		self.apiVersion = 1
		self.ok = false
		self.error = .init(
			code: Self.code(for: error),
			message: AppCommand.message(for: error)
		)
	}
}

extension MachineErrorResponse {
	private static func code(
		for error: any Error
	) -> String {
		if let error = error as? FXClaudeError {
			return error.code
		}

		if error is ValidationError
			|| AppCommand.exitCode(for: error) == .validationFailure {
			return "invalid_arguments"
		}

		if error is ExitCode {
			return "process_failed"
		}

		if error is POSIXError {
			return "system_error"
		}

		return "internal_error"
	}
}
