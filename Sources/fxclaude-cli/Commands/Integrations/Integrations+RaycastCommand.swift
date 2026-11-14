import ArgumentParser
import Dependencies
import Foundation
import FXClaudeClient

extension AppCommand.IntegrationsCommand.Raycast {
	internal enum Component: String, CaseIterable, ExpressibleByArgument {
		case app
		case raycastExtension = "extension"
	}

	internal struct Status: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			abstract: "Show Raycast integration status."
		)

		@Flag(
			inversion: .prefixedNo,
			exclusivity: .chooseLast,
			help: "Print a versioned machine-readable JSON response. Defaults from FXCLAUDE_JSON."
		)
		internal var json: Bool?

		internal init() {}

		internal func run() async throws {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			var applications: [RaycastApplicationStatus] = []

			for edition in RaycastEdition.allCases {
				applications.append(
					try await client.integrations.raycast.applicationStatus(edition)
				)
			}

			if machineOutputRequested(self.json) {
				try printMachineResponse(Output(applications: applications))
				return
			}

			let reporter: TerminalReporter = await .init()

			for application in applications {
				let description: String = application.applicationURL == nil
				? "not installed"
				: "installed · \(application.version ?? "unknown version")"

				await reporter.info("\(application.edition.displayName): \(description)")
			}
		}
	}
}

extension AppCommand.IntegrationsCommand.Raycast {
	internal struct Install: AsyncParsableCommand {
		internal static let configuration: CommandConfiguration = .init(
			abstract: "Install Raycast or the fxclaude Raycast extension."
		)

		@Argument(help: "Component to install. Omit to choose interactively.")
		internal var component: Component?

		@Flag(help: "Target Raycast Beta instead of stable Raycast.")
		internal var beta: Bool = false

		@Flag(help: "Open the fxclaude extension page in the default browser.")
		internal var openInBrowser: Bool = false

		@Flag(name: .shortAndLong, help: "Accept confirmation prompts.")
		internal var yes: Bool = false

		@Flag(
			inversion: .prefixedNo,
			exclusivity: .chooseLast,
			help: "Print a versioned machine-readable JSON response without prompting. Defaults from FXCLAUDE_JSON."
		)
		internal var json: Bool?

		internal init() {}

		internal func run() async throws {
			@Dependency(\.fxClaudeClient)
			var client: FXClaudeClient

			@Dependency(\._fxclaudeExternalURLOpener)
			var externalURLOpener: ExternalURLOpenerClient

			@Dependency(\._fxclaudeTerminalPrompts)
			var prompts: TerminalPromptsClient

			let json = machineOutputRequested(self.json)

			guard !json || self.component != nil else {
				throw ValidationError("An integration component is required when using --json.")
			}
			guard !self.openInBrowser || self.component == .raycastExtension else {
				throw ValidationError("--open-in-browser is only available for the extension component.")
			}

			let reporter: TerminalReporter = await .init(assumeYes: self.yes)
			let edition: RaycastEdition = self.beta ? .beta : .stable

			switch self.component {
			case .app:
				let result = try await self.installApplication(
					edition: edition,
					client: client,
					externalURLOpener: externalURLOpener,
					reporter: json ? nil : reporter,
					suppressOutput: json
				)

				if json {
					try printMachineResponse(Output(
						component: Component.app.rawValue,
						outcome: result.outcome,
						application: result.status
					))
				}

			case .raycastExtension:
				guard
					let result = try await self.installExtension(
						client: client,
						externalURLOpener: externalURLOpener,
						prompts: prompts,
						reporter: json ? nil : reporter,
						json: json
					)
				else { return }

				if json {
					try printMachineResponse(Output(
						component: Component.raycastExtension.rawValue,
						outcome: result.outcome,
						application: result.application
					))
				}

			case nil:
				guard
					let rawComponent = try prompts.select(
						"Choose a component to install:",
						[
							.init(
								value: InteractiveComponent.app.rawValue,
								label: "Raycast",
								hint: nil
							),
							.init(
								value: InteractiveComponent.betaApp.rawValue,
								label: "Raycast Beta",
								hint: nil
							),
							.init(
								value: InteractiveComponent.raycastExtension.rawValue,
								label: "Extension",
								hint: "Install the fxclaude Raycast extension"
							),
						]
					)
				else { return }

				guard let component = InteractiveComponent(rawValue: rawComponent)
				else { throw ValidationError("Unsupported Raycast installation component.") }

				switch component {
				case .app:
					_ = try await self.installApplication(
						edition: .stable,
						client: client,
						externalURLOpener: externalURLOpener,
						reporter: reporter,
						suppressOutput: false
					)

				case .betaApp:
					_ = try await self.installApplication(
						edition: .beta,
						client: client,
						externalURLOpener: externalURLOpener,
						reporter: reporter,
						suppressOutput: false
					)

				case .raycastExtension:
					_ = try await self.installExtension(
						client: client,
						externalURLOpener: externalURLOpener,
						prompts: prompts,
						reporter: reporter,
						json: false
					)
				}
			}
		}
	}
}

extension AppCommand.IntegrationsCommand.Raycast.Status {
	private struct Output: Encodable {
		let applications: [RaycastApplicationStatus]
	}
}

extension AppCommand.IntegrationsCommand.Raycast.Install {
	internal static let extensionDeepLink: String = "raycast://extensions/maximkrouk/fxclaude"
	internal static let extensionStorePage: String = "https://www.raycast.com/maximkrouk/fxclaude"

	private enum InteractiveComponent: String {
		case app
		case betaApp = "app-beta"
		case raycastExtension = "extension"
	}

	private enum Outcome: String, Encodable {
		case alreadyInstalled = "already-installed"
		case downloadOpened = "download-opened"
		case extensionOpened = "extension-opened"
		case installed
		case storePageOpened = "store-page-opened"
	}

	private struct Output: Encodable {
		let component: String
		let outcome: Outcome
		let application: RaycastApplicationStatus?
	}

	private struct ExtensionInstallationResult {
		let outcome: Outcome
		let application: RaycastApplicationStatus?
	}

	@MainActor
	private func installApplication(
		edition: RaycastEdition,
		client: FXClaudeClient,
		externalURLOpener: ExternalURLOpenerClient,
		reporter: TerminalReporter?,
		suppressOutput: Bool
	) async throws -> (outcome: Outcome, status: RaycastApplicationStatus) {
		let installation: RaycastApplicationInstallation = try await client.integrations.raycast.applicationInstallation(
			edition
		)
		let outcome: Outcome

		switch installation {
		case let .alreadyInstalled(applicationURL):
			reporter?.success("\(edition.displayName) is already installed at \(applicationURL.path).")
			outcome = .alreadyInstalled

		case let .command(invocation):
			reporter?.info("Installing \(edition.displayName) using Homebrew…")

			let exitCode: Int32 = try await runProcess(
				invocation,
				suppressOutput: suppressOutput
			)

			guard exitCode == 0 else { throw ExitCode(exitCode) }

			reporter?.success("Installed \(edition.displayName).")
			outcome = .installed

		case let .externalDownload(url):
			reporter?.info("Opening the official \(edition.displayName) download…")

			try externalURLOpener.openInBrowser(url)
			outcome = .downloadOpened
		}

		return (
			outcome,
			try await client.integrations.raycast.applicationStatus(edition)
		)
	}

	@MainActor
	private func installExtension(
		client: FXClaudeClient,
		externalURLOpener: ExternalURLOpenerClient,
		prompts: TerminalPromptsClient,
		reporter: TerminalReporter?,
		json: Bool
	) async throws -> ExtensionInstallationResult? {
		guard
			let deepLink = URL(string: Self.extensionDeepLink),
			let storePageURL = URL(string: Self.extensionStorePage)
		else { throw CocoaError(.fileNoSuchFile) }

		if self.openInBrowser {
			try externalURLOpener.openInBrowser(storePageURL)
			reporter?.success("Opened the fxclaude extension page in your browser.")
			return .init(outcome: .storePageOpened, application: nil)
		}

		var installedApplications: [RaycastApplicationStatus] = []

		for edition in RaycastEdition.allCases {
			let status: RaycastApplicationStatus = try await client.integrations.raycast.applicationStatus(
				edition
			)
			if status.applicationURL != nil {
				installedApplications.append(status)
			}
		}

		let selectedApplication: RaycastApplicationStatus

		if self.beta {
			guard let beta = installedApplications.first(where: { $0.edition == .beta }) else {
				throw ValidationError(
					"Raycast Beta is not installed. Install it first or use --open-in-browser."
				)
			}
			selectedApplication = beta

		} else if installedApplications.count == 1, let application = installedApplications.first {
			selectedApplication = application

		} else if installedApplications.count > 1 {
			if json {
				guard let stable = installedApplications.first(where: { $0.edition == .stable })
				else { throw ValidationError("Raycast is not installed.") }
				selectedApplication = stable

			} else {
				let options: [TerminalPromptOption] = installedApplications.map { application in
					.init(
						value: application.edition.rawValue,
						label: application.edition.displayName,
						hint: application.version
					)
				}

				guard
					let selection = try prompts.select(
						"Open the fxclaude extension with:",
						options
					)
				else { return nil }
				guard
					let edition = RaycastEdition(rawValue: selection),
					let application = installedApplications.first(where: { $0.edition == edition })
				else { throw ValidationError("Unsupported Raycast edition.") }

				selectedApplication = application
			}

		} else {
			if !self.yes {
				guard !json else {
					throw ValidationError(
						"Raycast is not installed. Pass --yes to install it or use --open-in-browser."
					)
				}

				guard
					let selection = try prompts.select(
						"Raycast is not installed:",
						[
							.init(
								value: "install",
								label: "Install Raycast",
								hint: "Recommended · then open the fxclaude extension"
							),
							.init(
								value: "browser",
								label: "Open in Browser",
								hint: "View the extension without installing Raycast"
							),
						]
					)
				else { return nil }

				if selection == "browser" {
					try externalURLOpener.openInBrowser(storePageURL)
					reporter?.success("Opened the fxclaude extension page in your browser.")
					return .init(outcome: .storePageOpened, application: nil)
				}

				guard selection == "install"
				else { throw ValidationError("Unsupported extension installation choice.") }
			}

			let installation = try await self.installApplication(
				edition: .stable,
				client: client,
				externalURLOpener: externalURLOpener,
				reporter: reporter,
				suppressOutput: json
			)
			guard installation.status.applicationURL != nil else {
				throw ValidationError("Raycast must finish installing before the extension can be opened.")
			}
			selectedApplication = installation.status
		}

		guard let applicationURL = selectedApplication.applicationURL
		else { throw ValidationError("The selected Raycast application could not be found.") }

		try await externalURLOpener.openInApplication(deepLink, applicationURL)
		reporter?.success("Opened the fxclaude extension in \(selectedApplication.edition.displayName).")

		return .init(
			outcome: .extensionOpened,
			application: selectedApplication
		)
	}
}
