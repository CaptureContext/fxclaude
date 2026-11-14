import Foundation
@_spi(Internals)
@testable
import FXClaudeClient

final class ClientTestFixture {
	let applicationURL: URL
	let applicationsURL: URL
	let executableURL: URL
	let rootURL: URL

	init() throws {
		let rootURL: URL = FileManager.default.temporaryDirectory.appending(
			path: "fxclaude-tests-\(UUID().uuidString)",
			directoryHint: .isDirectory
		)
		self.applicationURL = rootURL.appending(
			path: "fixtures/Claude.app",
			directoryHint: .isDirectory
		)
		self.applicationsURL = rootURL.appending(
			path: "fixtures/Applications",
			directoryHint: .isDirectory
		)
		self.executableURL = rootURL.appending(
			path: "fixtures/bin/fxclaude",
			directoryHint: .notDirectory
		)
		self.rootURL = rootURL

		try FileManager.default.createDirectory(
			at: self.applicationURL,
			withIntermediateDirectories: true,
			attributes: nil
		)
		try self.createExecutable(at: self.executableURL)
	}

	func makeExecutable(named name: String) throws -> URL {
		let url: URL = self.executableURL
		.deletingLastPathComponent()
		.appending(path: name, directoryHint: .notDirectory)
		try self.createExecutable(at: url)
		return url
	}

	func makeApplication(
		named name: String,
		bundleIdentifier: String = ClaudeApplicationController.bundleIdentifier,
		urlSchemes: [[String]] = []
	) throws -> URL {
		let applicationURL: URL = self.applicationsURL.appending(
			path: "\(name).app",
			directoryHint: .isDirectory
		)
		let contentsURL: URL = applicationURL.appending(
			path: "Contents",
			directoryHint: .isDirectory
		)
		try FileManager.default.createDirectory(
			at: contentsURL,
			withIntermediateDirectories: true,
			attributes: nil
		)
		var information: [String: Any] = [
			"CFBundleIdentifier": bundleIdentifier,
			"CFBundleName": name,
			"CFBundlePackageType": "APPL",
			"CFBundleVersion": "1",
		]
		if !urlSchemes.isEmpty {
			information["CFBundleURLTypes"] = urlSchemes.map { ["CFBundleURLSchemes": $0] }
		}
		let data: Data = try PropertyListSerialization.data(
			fromPropertyList: information,
			format: .xml,
			options: 0
		)
		try data.write(
			to: contentsURL.appending(path: "Info.plist"),
			options: [.atomic]
		)
		return applicationURL
	}

	func remove() {
		try? FileManager.default.removeItem(at: self.rootURL)
	}

	private func createExecutable(at url: URL) throws {
		try FileManager.default.createDirectory(
			at: url.deletingLastPathComponent(),
			withIntermediateDirectories: true,
			attributes: nil
		)
		try "#!/bin/sh\nexit 0\n".write(
			to: url,
			atomically: true,
			encoding: .utf8
		)
		try FileManager.default.setAttributes(
			[.posixPermissions: 0o700],
			ofItemAtPath: url.path
		)
	}
}

actor ClaudeApplicationSpy {
	struct Snapshot: Equatable, Sendable {
		let openedWorkspaceNames: [String]
		let removedWorkspaceNames: [String]
		let sentURLs: [SentURL]
		let launchedURLs: [LaunchedURL]
	}

	struct SentURL: Equatable, Sendable {
		let url: URL
		let processID: Int32
	}

	struct LaunchedURL: Equatable, Sendable {
		let workspaceName: String
		let url: URL
	}

	private let applicationURLValue: URL?
	private let openedProcessID: Int32
	private var openedWorkspaceNames: [String] = []
	private var processIDs: [String: Int32]
	private var removedWorkspaceNames: [String] = []
	private var sentURLs: [SentURL] = []
	private var launchedURLs: [LaunchedURL] = []
	private let urlSchemesValue: [String]?
	private let sendError: FXClaudeError?

	init(
		applicationURL: URL? = nil,
		openedProcessID: Int32 = 4_242,
		processIDs: [String: Int32] = [:],
		urlSchemes: [String]? = ["claude", "msauth.com.anthropic.claudefordesktop"],
		sendError: FXClaudeError? = nil
	) {
		self.applicationURLValue = applicationURL
		self.openedProcessID = openedProcessID
		self.processIDs = processIDs
		self.urlSchemesValue = urlSchemes
		self.sendError = sendError
	}

	nonisolated var client: ClaudeApplicationClient {
		.init(
			applicationURL: { await self.applicationURL() },
			open: { await self.open($0) },
			runningProcessID: { await self.runningProcessID(for: $0) },
			urlSchemes: { try await self.urlSchemes() },
			sendURL: { try await self.sendURL($0, toProcessID: $1) },
			launchWithURL: { await self.launch($0, with: $1) },
			removeRecord: { await self.removeRecord(for: $0.name) }
		)
	}

	func setProcessID(
		_ processID: Int32?,
		forWorkspaceNamed name: String
	) {
		self.processIDs[name] = processID
	}

	func snapshot() -> Snapshot {
		.init(
			openedWorkspaceNames: self.openedWorkspaceNames,
			removedWorkspaceNames: self.removedWorkspaceNames,
			sentURLs: self.sentURLs,
			launchedURLs: self.launchedURLs
		)
	}

	private func applicationURL() -> URL? {
		self.applicationURLValue
	}

	private func open(_ workspace: Workspace) -> Int32 {
		self.openedWorkspaceNames.append(workspace.name)
		self.processIDs[workspace.name] = self.openedProcessID
		return self.openedProcessID
	}

	private func runningProcessID(for workspace: Workspace) -> Int32? {
		self.processIDs[workspace.name]
	}

	private func urlSchemes() throws -> [String] {
		guard let urlSchemesValue else { throw FXClaudeError.applicationNotFound }
		return urlSchemesValue
	}

	private func sendURL(
		_ url: URL,
		toProcessID processID: Int32
	) throws {
		if let sendError { throw sendError }
		self.sentURLs.append(.init(url: url, processID: processID))
	}

	private func launch(
		_ workspace: Workspace,
		with url: URL
	) -> Int32 {
		self.launchedURLs.append(.init(workspaceName: workspace.name, url: url))
		self.processIDs[workspace.name] = self.openedProcessID
		return self.openedProcessID
	}

	private func removeRecord(for name: String) {
		self.processIDs.removeValue(forKey: name)
		self.removedWorkspaceNames.append(name)
	}

}
