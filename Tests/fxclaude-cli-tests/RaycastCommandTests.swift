import ArgumentParser
import Dependencies
import Foundation
import FXClaudeClient
import Testing
@testable
import FXClaudeCLI

@Suite("Raycast command")
struct RaycastCommandTests {
	@Test("Install parses the Beta application component")
	func betaApplication() async throws {
		let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
			"app",
			"--beta",
		])
		#expect(command.component == .app)
		#expect(command.beta)
	}

	@Test("Install parses the extension browser override")
	func extensionBrowserOverride() throws {
		let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
			"extension",
			"--open-in-browser",
		])
		#expect(command.component == .raycastExtension)
		#expect(command.openInBrowser)
	}

	@Test("Integrations can enter the interactive Raycast status action")
	func interactiveIntegrationsRaycastStatus() async throws {
		let offeredValues = LockIsolated<[[String]]>([])
		let answers = LockIsolated(["raycast", "status"])
		let statusRequested = LockIsolated(false)
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			statusRequested.setValue(true)
			return .init(
				edition: edition,
				applicationURL: nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, options in
					offeredValues.withValue { $0.append(options.map(\.value)) }
					return answers.withValue { $0.removeFirst() }
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand = try .parse([])
			try await command.run()
		}

		#expect(offeredValues.value == [
			["attributes", "raycast"],
			["status", "install"],
		])
		#expect(statusRequested.value)
	}

	@Test("Bare Raycast command offers actions")
	func interactiveRaycastActions() async throws {
		let offeredValues = LockIsolated<[String]>([])
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, options in
					offeredValues.setValue(options.map(\.value))
					return "status"
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let parsed: any ParsableCommand = try AppCommand.parseAsRoot([
				"integrations",
				"raycast",
			])
			let command = try #require(parsed as? AppCommand.IntegrationsCommand.Raycast)
			try await command.run()
		}

		#expect(offeredValues.value == ["status", "install"])
	}

	@Test("Interactive installation offers every component")
	func interactiveInstallComponents() async throws {
		let applicationURL = URL(fileURLWithPath: "/Applications/Raycast.app")
		let offeredOptions = LockIsolated<[TerminalPromptOption]>([])
		var raycast = Integrations.Raycast()
		raycast.applicationInstallation = { edition in
			#expect(edition == .stable)
			return .alreadyInstalled(applicationURL)
		}
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: edition == .stable ? applicationURL : nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, options in
					offeredOptions.setValue(options)
					return "app"
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([])
			try await command.run()
		}

		#expect(offeredOptions.value.map(\.value) == [
			"app",
			"app-beta",
			"extension",
		])
		#expect(offeredOptions.value.map(\.label) == [
			"Raycast",
			"Raycast Beta",
			"Extension",
		])
	}

	@Test("Extension browser override opens the Raycast Store page directly")
	func openExtensionInBrowser() async throws {
		let openedURL = LockIsolated<URL?>(nil)

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeExternalURLOpener = .init(
				openInApplication: { _, _ in },
				openInBrowser: { openedURL.setValue($0) }
			)
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in nil },
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"extension",
				"--open-in-browser",
			])
			try await command.run()
		}

		#expect(openedURL.value?.absoluteString == "https://www.raycast.com/maximkrouk/fxclaude")
	}

	@Test("Extension installation selects an installed Raycast edition")
	func selectInstalledApplicationForExtension() async throws {
		let betaURL = URL(fileURLWithPath: "/Applications/Raycast Beta.app")
		let openedDeepLink = LockIsolated<URL?>(nil)
		let openedApplicationURL = LockIsolated<URL?>(nil)
		let offeredEditions = LockIsolated<[String]>([])
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: URL(
					fileURLWithPath: edition == .stable ? "/Applications/Raycast.app" : betaURL.path
				),
				version: edition == .stable ? "1.2.3" : "1.2.4-beta"
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeExternalURLOpener = .init(
				openInApplication: { deepLink, applicationURL in
					openedDeepLink.setValue(deepLink)
					openedApplicationURL.setValue(applicationURL)
				},
				openInBrowser: { _ in }
			)
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, options in
					offeredEditions.setValue(options.map(\.value))
					return RaycastEdition.beta.rawValue
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"extension",
			])
			try await command.run()
		}

		#expect(offeredEditions.value == ["stable", "beta"])
		#expect(openedDeepLink.value?.absoluteString == "raycast://extensions/maximkrouk/fxclaude")
		#expect(openedApplicationURL.value == betaURL)
	}

	@Test("Extension installation recommends Raycast with a browser fallback")
	func recommendRaycastForExtension() async throws {
		let offeredChoices = LockIsolated<[String]>([])
		let openedURL = LockIsolated<URL?>(nil)
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeExternalURLOpener = .init(
				openInApplication: { _, _ in },
				openInBrowser: { openedURL.setValue($0) }
			)
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, options in
					offeredChoices.setValue(options.map(\.value))
					return "browser"
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"extension",
			])
			try await command.run()
		}

		#expect(offeredChoices.value == ["install", "browser"])
		#expect(openedURL.value?.absoluteString == "https://www.raycast.com/maximkrouk/fxclaude")
	}

	@Test("Extension installation can install Raycast before opening")
	func installRaycastForExtension() async throws {
		let applicationURL = URL(fileURLWithPath: "/Applications/Raycast.app")
		let didInstall = LockIsolated(false)
		let didPrompt = LockIsolated(false)
		let openedDeepLink = LockIsolated<URL?>(nil)
		let openedApplicationURL = LockIsolated<URL?>(nil)
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: edition == .stable && didInstall.value ? applicationURL : nil,
				version: nil
			)
		}
		raycast.applicationInstallation = { edition in
			#expect(edition == .stable)
			didInstall.setValue(true)
			return .alreadyInstalled(applicationURL)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeExternalURLOpener = .init(
				openInApplication: { deepLink, applicationURL in
					openedDeepLink.setValue(deepLink)
					openedApplicationURL.setValue(applicationURL)
				},
				openInBrowser: { _ in }
			)
			$0._fxclaudeTerminalPrompts = .init(
				select: { _, _ in
					didPrompt.setValue(true)
					return nil
				},
				multiselect: { _, _ in nil },
				confirm: { _ in nil }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"extension",
				"--yes",
			])
			try await command.run()
		}

		#expect(didInstall.value)
		#expect(!didPrompt.value)
		#expect(openedDeepLink.value?.absoluteString == "raycast://extensions/maximkrouk/fxclaude")
		#expect(openedApplicationURL.value == applicationURL)
	}

	@Test("Machine installation requires an explicit component")
	func machineInstallRequiresComponent() async throws {
		let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse(["--json"])

		await #expect(throws: ValidationError.self) {
			try await command.run()
		}
	}

	@Test("Application installation executes with machine output")
	func machineInstallApplication() async throws {
		let applicationURL = URL(fileURLWithPath: "/Applications/Raycast.app")
		var raycast = Integrations.Raycast()
		raycast.applicationInstallation = { edition in
			#expect(edition == .stable)
			return .alreadyInstalled(applicationURL)
		}
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: applicationURL,
				version: "1.0.0"
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"app",
				"--json",
			])
			try await command.run()
		}
	}

	@Test("Status executes with machine output")
	func machineStatus() async throws {
		var raycast = Integrations.Raycast()
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Status = try .parse(["--json"])
			try await command.run()
		}
	}

	@Test("Install help lists the app and extension components")
	func componentHelp() {
		let installHelp: String = AppCommand.IntegrationsCommand.Raycast.Install.helpMessage()
		let raycastHelp: String = AppCommand.IntegrationsCommand.Raycast.helpMessage()

		#expect(installHelp.contains("(values: app, extension)"))
		#expect(!installHelp.contains("script-command"))
		#expect(!raycastHelp.contains("sync"))
		#expect(!raycastHelp.contains("uninstall"))
	}

	@Test("Raycast Beta download opens through the URL opener")
	func betaDownloadOpensInBrowser() async throws {
		let downloadURL = try #require(URL(string: "https://www.raycast.com/new"))
		let openedURL = LockIsolated<URL?>(nil)
		var raycast = Integrations.Raycast()
		raycast.applicationInstallation = { edition in
			#expect(edition == .beta)
			return .externalDownload(downloadURL)
		}
		raycast.applicationStatus = { edition in
			.init(
				edition: edition,
				applicationURL: nil,
				version: nil
			)
		}

		try await withDependencies {
			$0.fxClaudeClient = .init()
			$0._fxclaudeIntegrations = .init(raycast: raycast, attributes: .init())
			$0._fxclaudeExternalURLOpener = .init(
				openInApplication: { _, _ in },
				openInBrowser: { openedURL.setValue($0) }
			)
		} operation: {
			let command: AppCommand.IntegrationsCommand.Raycast.Install = try .parse([
				"app",
				"--beta",
				"--json",
			])
			try await command.run()
		}

		#expect(openedURL.value == downloadURL)
	}
}
