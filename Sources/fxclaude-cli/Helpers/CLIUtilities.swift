import ArgumentParser
import ConsoleKitTerminal
import Darwin
import Foundation
import FXClaudeClient
import Subprocess

@MainActor
internal final class TerminalReporter {
	internal let console: Terminal

	internal init(
		assumeYes: Bool = false
	) {
		let console: Terminal = .init()
		console.confirmOverride = assumeYes ? true : nil

		if currentEnvironment()["NO_COLOR"] != nil {
			console.stylizedOutputOverride = false
		}

		self.console = console
	}

	internal func info(_ message: String) {
		self.console.info(message)
	}

	internal func success(_ message: String) {
		self.console.success(message)
	}

	internal func warning(_ message: String) {
		self.console.warning(message)
	}

	internal func confirm(_ message: String) -> Bool {
		self.console.confirm(message.consoleText(.warning))
	}

	internal func ask(_ message: String) -> String {
		self.console.ask(message.consoleText(.info))
	}

	internal func choose<Value: CustomStringConvertible>(
		_ message: String,
		from values: [Value]
	) -> Value {
		self.console.choose(
			message.consoleText(.info),
			from: values
		)
	}
}

/// Replaces the current process with the invocation, resolving the executable from `PATH`.
internal func replaceProcess(
	with invocation: CommandInvocation
) throws -> Never {
	for (key, value) in invocation.environment {
		guard setenv(key, value, 1) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
	}

	let argumentStrings: [String] = [invocation.executable] + invocation.arguments
	var arguments: [UnsafeMutablePointer<CChar>?] = argumentStrings.map { argument in
		strdup(argument)
	}

	arguments.append(nil)

	defer {
		for argument in arguments where argument != nil {
			free(argument)
		}
	}

	execvp(invocation.executable, &arguments)

	throw POSIXError(.init(rawValue: errno) ?? .ENOENT)
}

/// Runs the invocation as a child process, resolving the executable from `PATH`, and returns its exit status.
internal func runProcess(
	_ invocation: CommandInvocation,
	suppressOutput: Bool = false
) async throws -> Int32 {
	let environment: [String: String] = currentEnvironment().merging(
		invocation.environment,
		uniquingKeysWith: { _, newValue in newValue }
	)
	let configuration: Subprocess.Configuration = .init(
		executable: invocation.executable.contains("/")
		? .path(.init(invocation.executable))
		: .name(invocation.executable),
		arguments: .init(
			executablePathOverride: invocation.executable,
			remainingValues: invocation.arguments
		),
		environment: .custom(.init(uniqueKeysWithValues: environment.map { key, value in
			(.init(stringLiteral: key), value)
		}))
	)
	let status: TerminationStatus

	if suppressOutput {
		status = try await Subprocess.run(
			configuration,
			input: .currentStandardInput,
			output: .discarded,
			error: .discarded
		).terminationStatus

	} else {
		status = try await Subprocess.run(
			configuration,
			input: .currentStandardInput,
			output: .currentStandardOutput,
			error: .currentStandardError
		).terminationStatus
	}

	switch status {
	case let .exited(code): return code
	case let .signaled(signal): return signal
	}
}

/// Drops the `--` that separates fxclaude's arguments from the forwarded ones.
internal func forwardedArguments(from arguments: [String]) -> [String] {
	guard arguments.first == "--" else { return arguments }
	return .init(arguments.dropFirst())
}

/// Splits `[workspace] [--] <arguments>` captured by `cli` and `exec`.
///
/// Workspace names never start with `-`, so a leading `--` or flag means the current workspace and
/// everything is forwarded.
internal func splitPassthroughArguments(
	_ arguments: [String]
) -> (workspaceName: String?, arguments: [String]) {
	guard let first = arguments.first, !first.hasPrefix("-") else {
		return (nil, forwardedArguments(from: arguments))
	}
	return (first, forwardedArguments(from: .init(arguments.dropFirst())))
}

/// Shows fxclaude's help for `cli --help`; `cli -- --help` still reaches Claude Code.
internal func rejectHelpBeforePassthrough(
	_ arguments: [String],
	for command: any ParsableCommand
) throws {
	guard let first = arguments.first, first == "-h" || first == "--help" else { return }
	throw CleanExit.helpRequest(command)
}

extension Array where Element == String {
	internal func uniqued() -> [String] {
		var values: Set<String> = []
		return self.filter { values.insert($0).inserted }
	}

	internal var workspaceDescription: String {
		if self.count == 1 {
			return "workspace '\(self[0])'"
		}
		return "workspaces \(self.map { "'\($0)'" }.joined(separator: ", "))"
	}
}

internal func machineOutputRequested(
	_ localValue: Bool?
) -> Bool {
	localValue ?? globalMachineOutputRequested()
}

internal func globalMachineOutputRequested(
	arguments: [String] = .init(CommandLine.arguments.dropFirst()),
	environment: [String: String]? = nil
) -> Bool {
	let environment = environment ?? currentEnvironment()
	if let argumentValue = machineOutputArgumentValue(arguments: arguments) {
		return argumentValue
	}

	return (try? environmentSwitch(
		named: "FXCLAUDE_JSON",
		in: environment
	))
	?? false
}

internal func machineOutputArgumentValue(
	arguments: [String] = .init(CommandLine.arguments.dropFirst())
) -> Bool? {
	// Flags after a `cli` or `exec` subcommand belong to Claude Code, not fxclaude. Only the
	// subcommand position counts, so a workspace named `cli` or `exec` keeps its flags.
	let subcommandIndex: Int? = arguments.firstIndex { !$0.hasPrefix("-") }
	let relevantArguments: ArraySlice<String> = subcommandIndex
		.flatMap { ["cli", "exec"].contains(arguments[$0]) ? arguments[..<$0] : nil }
	?? arguments[...]

	var argumentValue: Bool?

	for argument in relevantArguments {
		switch argument {
		case "--json":
			argumentValue = true

		case "--no-json":
			argumentValue = false

		default:
			break
		}
	}

	return argumentValue
}

internal func environmentSwitch(
	named name: String,
	in environment: [String: String]? = nil
) throws -> Bool? {
	let environment = environment ?? currentEnvironment()
	guard let value = environment[name], !value.isEmpty else { return nil }

	switch value {
	case "1":
		return true

	case "-1", "0":
		return false

	default:
		throw ValidationError(
			"Environment variable \(name) must be 1, -1, or unset."
		)
	}
}

internal func rejectMachineOutput(
	for commandName: String
) throws {
	guard !globalMachineOutputRequested() else {
		throw ValidationError("--json is not supported by the \(commandName) command.")
	}
}

internal func encodedJSON<Value: Encodable>(
	_ value: Value
) throws -> Data {
	let encoder: JSONEncoder = FXClaudeJSONCoding.encoder()
	encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
	return try encoder.encode(value)
}

internal func printMachineResponse<Value: Encodable>(
	_ value: Value
) throws {
	try writeJSON(
		MachineResponse(data: value),
		to: .standardOutput
	)
}

internal func printMachineError(
	_ error: any Error
) throws {
	try writeJSON(
		MachineErrorResponse(error: error),
		to: .standardError
	)
}

private func writeJSON<Value: Encodable>(
	_ value: Value,
	to fileHandle: FileHandle
) throws {
	var data: Data = try encodedJSON(value)
	data.append(contentsOf: [0x0A])

	try fileHandle.write(contentsOf: data)
}
