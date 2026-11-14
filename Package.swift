// swift-tools-version: 6.3

import PackageDescription

let package = Package(
	name: "fxclaude",
	platforms: [
		.macOS(.v14),
	],
	products: [
		.executable(
			name: "fxclaude",
			targets: ["FXClaudeCLI"]
		),
	],
	dependencies: [
		.package(
			url: "https://github.com/swiftlang/swift-subprocess.git",
			.upToNextMajor(from: "1.0.0")
		),
		.package(
			url: "https://github.com/apple/swift-argument-parser.git",
			.upToNextMajor(from: "1.8.2")
		),
		.package(
			url: "https://github.com/vapor/console-kit.git",
			.upToNextMajor(from: "4.16.0")
		),
		.package(
			url: "https://github.com/pointfreeco/swift-dependencies.git",
			.upToNextMajor(from: "1.14.1")
		),
		.package(
			url: "https://github.com/pointfreeco/swift-case-paths.git",
			.upToNextMajor(from: "1.9.0")
		),
		.package(
			url: "https://github.com/pointfreeco/swift-parsing.git",
			.upToNextMajor(from: "0.15.0")
		),
		.package(
			url: "https://github.com/pointfreeco/swift-custom-dump.git",
			// Keep the IssueReporting package graph used by Dependencies 1.14.
			.upToNextMinor(from: "1.6.1")
		),
		.package(
			url: "https://github.com/onmyway133/Promptberry.git",
			.upToNextMajor(from: "1.0.0")
		),
	],
	targets: [
		.executableTarget(
			name: "FXClaudeCLI",
			dependencies: [
				.target(
					name: "FXClaudeClient",
					condition: nil
				),
				.product(
					name: "ArgumentParser",
					package: "swift-argument-parser"
				),
				.product(
					name: "ConsoleKitTerminal",
					package: "console-kit"
				),
				.product(
					name: "Dependencies",
					package: "swift-dependencies"
				),
				.product(
					name: "Promptberry",
					package: "Promptberry"
				),
				.product(
					name: "Subprocess",
					package: "swift-subprocess"
				),
			],
			path: "Sources/fxclaude-cli"
		),
		.target(
			name: "FXClaudeClient",
			dependencies: [
				.target(
					name: "FXClaudeFS",
					condition: nil
				),
				.product(
					name: "Dependencies",
					package: "swift-dependencies"
				),
				.product(
					name: "DependenciesMacros",
					package: "swift-dependencies"
				),
				.product(
					name: "CasePaths",
					package: "swift-case-paths"
				),
				.product(
					name: "Parsing",
					package: "swift-parsing"
				),
			],
			path: "Sources/fxclaude-client"
		),
		.target(
			name: "FXClaudeFS",
			dependencies: [],
			path: "Sources/fxclaude-fs"
		),
		.testTarget(
			name: "FXClaudeCLITests",
			dependencies: [
				.target(
					name: "FXClaudeCLI",
					condition: nil
				),
				.target(
					name: "FXClaudeClient",
					condition: nil
				),
				.product(
					name: "CustomDump",
					package: "swift-custom-dump"
				),
			],
			path: "Tests/fxclaude-cli-tests"
		),
		.testTarget(
			name: "FXClaudeClientTests",
			dependencies: [
				.target(
					name: "FXClaudeClient",
					condition: nil
				),
			],
			path: "Tests/fxclaude-client-tests"
		),
	],
	swiftLanguageModes: [.v6]
)
