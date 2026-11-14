import AppKit
import CoreServices
import Dependencies
import Foundation
import Testing
@_spi(Internals)
@testable
import FXClaudeClient

@Suite("Claude application controller")
struct ClaudeApplicationControllerTests {
	@Test("Discovers Claude using Anthropic's bundle identifier")
	@MainActor
	func applicationDiscovery() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }
		let applicationURL: URL = try fixture.makeApplication(named: "Claude")
		let controller: ClaudeApplicationController = self.controller(for: fixture)

		#expect(controller.applicationURL() == applicationURL.standardizedFileURL)
		#expect(ClaudeApplicationController.bundleIdentifier == "com.anthropic.claudefordesktop")
	}

	@Test("Rejects an unrelated bundle named Claude")
	@MainActor
	func bundleValidation() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }
		_ = try fixture.makeApplication(
			named: "Claude",
			bundleIdentifier: "example.unrelated"
		)

		#expect(self.controller(for: fixture).applicationURL() == nil)
	}

	@Test("Managed workspaces launch separate instances with distinct profile directories")
	@MainActor
	func isolatedLaunches() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		try withDependencies {
			$0.context = .live
			$0._fxclaudePaths = .init(rootURL: fixture.rootURL)
		} operation: {
			let storage: WorkspacesStorage = .init(fileManager: .default)
			let work: Workspace = try storage.createWorkspace(named: "work")
			let personal: Workspace = try storage.createWorkspace(named: "personal")
			let controller: ClaudeApplicationController = self.controller(for: fixture)
			let workConfiguration = try controller.launchConfiguration(for: work)
			let personalConfiguration = try controller.launchConfiguration(for: personal)
			let workPath: String = try #require(work.userDataURL).path
			let personalPath: String = try #require(personal.userDataURL).path
			let workConfigPath: String = try #require(work.claudeConfigURL).path
			let personalConfigPath: String = try #require(personal.claudeConfigURL).path

			#expect(workPath != personalPath)
			#expect(workConfigPath != personalConfigPath)
			#expect(workConfiguration.createsNewApplicationInstance)
			#expect(personalConfiguration.createsNewApplicationInstance)
			#expect(workConfiguration.activates)
			#expect(workConfiguration.environment == [
				"CLAUDE_CONFIG_DIR": workConfigPath,
				"CLAUDE_USER_DATA_DIR": workPath,
			])
			#expect(personalConfiguration.environment == [
				"CLAUDE_CONFIG_DIR": personalConfigPath,
				"CLAUDE_USER_DATA_DIR": personalPath,
			])
			#expect(workConfiguration.arguments == ["--user-data-dir=\(workPath)"])
			#expect(personalConfiguration.arguments == ["--user-data-dir=\(personalPath)"])
		}
	}

	@Test("Primary leaves the existing Claude profile unchanged")
	@MainActor
	func primaryLaunch() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }
		let primary: Workspace = .init(
			name: Workspace.primaryName,
			kind: .primary,
			rootURL: fixture.rootURL,
			claudeConfigURL: nil,
			userDataURL: nil
		)
		let configuration = try self.controller(for: fixture).launchConfiguration(for: primary)

		#expect(configuration.environment["CLAUDE_CONFIG_DIR"] == nil)
		#expect(configuration.environment["CLAUDE_USER_DATA_DIR"] == nil)
		#expect(configuration.arguments.isEmpty)
	}

	@Test("Missing managed paths cannot fall back to the primary profile")
	@MainActor
	func missingManagedPath() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }
		let workspace: Workspace = .init(
			name: "work",
			kind: .managed,
			rootURL: fixture.rootURL,
			claudeConfigURL: fixture.rootURL.appending(
				path: "claude-config",
				directoryHint: .isDirectory
			),
			userDataURL: nil
		)

		#expect(throws: FXClaudeError.workspaceNotFound("work")) {
			try self.controller(for: fixture).launchConfiguration(for: workspace)
		}
	}

	@Test("Reads app link schemes from the installed bundle and drops web schemes")
	@MainActor
	func urlSchemes() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }
		_ = try fixture.makeApplication(
			named: "Claude",
			urlSchemes: [
				["claude"],
				["msauth.com.anthropic.claudefordesktop", "HTTPS", "Claude"],
			]
		)

		#expect(try self.controller(for: fixture).urlSchemes() == [
			"claude",
			"msauth.com.anthropic.claudefordesktop",
		])
	}

	@Test("Link schemes need an installed Claude")
	@MainActor
	func urlSchemesWithoutApplication() async throws {
		let fixture: ClientTestFixture = try .init()
		defer { fixture.remove() }

		#expect(throws: FXClaudeError.applicationNotFound) {
			try self.controller(for: fixture).urlSchemes()
		}
	}

	@Test("The GURL Apple Event is addressed to one process ID and carries the link")
	func getURLEvent() throws {
		let link: String = "claude://login/callback?code=abc"
		let event: NSAppleEventDescriptor = ClaudeApplicationController.getURLEvent(
			url: try #require(URL(string: link)),
			processID: 4_321
		)
		let target: NSAppleEventDescriptor = try #require(
			event.attributeDescriptor(forKeyword: AEKeyword(keyAddressAttr))
		)
		let processID: Int32 = target.data.withUnsafeBytes { $0.load(as: Int32.self) }

		#expect(event.eventClass == AEEventClass(kInternetEventClass))
		#expect(event.eventID == AEEventID(kAEGetURL))
		#expect(target.descriptorType == DescType(typeKernelProcessID))
		#expect(processID == 4_321)
		#expect(event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue == link)
	}

	@Test("Apple Event failures explain what to do")
	func appleEventFailureMessages() {
		let denied: String = ClaudeApplicationController.appleEventFailureMessage(
			code: Int(errAEEventNotPermitted),
			processID: 12
		)
		let gone: String = ClaudeApplicationController.appleEventFailureMessage(
			code: Int(procNotFound),
			processID: 12
		)
		let rejected: String = ClaudeApplicationController.appleEventFailureMessage(
			code: Int(errAEEventNotHandled),
			processID: 12
		)

		#expect(denied.contains("Privacy & Security > Automation"))
		#expect(gone == "Claude (pid 12) is no longer running.")
		#expect(rejected == "Claude (pid 12) did not accept the link.")
	}

	@Test("A handler error in the reply counts as a failed delivery")
	func replyHandlerError() {
		let success: NSAppleEventDescriptor = .appleEvent(
			withEventClass: AEEventClass(kCoreEventClass),
			eventID: AEEventID(kAEAnswer),
			targetDescriptor: nil,
			returnID: AEReturnID(kAutoGenerateReturnID),
			transactionID: AETransactionID(kAnyTransactionID)
		)
		let failure: NSAppleEventDescriptor = .appleEvent(
			withEventClass: AEEventClass(kCoreEventClass),
			eventID: AEEventID(kAEAnswer),
			targetDescriptor: nil,
			returnID: AEReturnID(kAutoGenerateReturnID),
			transactionID: AETransactionID(kAnyTransactionID)
		)
		failure.setParam(
			NSAppleEventDescriptor(int32: Int32(errAEEventNotHandled)),
			forKeyword: AEKeyword(keyErrorNumber)
		)

		#expect(ClaudeApplicationController.handlerErrorCode(in: success) == nil)
		#expect(ClaudeApplicationController.handlerErrorCode(in: failure) == Int(errAEEventNotHandled))
	}

	@MainActor
	private func controller(
		for fixture: ClientTestFixture
	) -> ClaudeApplicationController {
		.init(
			applicationsDirectoryURL: fixture.applicationsURL,
			fileManager: .default,
			applicationURLsForBundleIdentifier: { _ in [] }
		)
	}
}
