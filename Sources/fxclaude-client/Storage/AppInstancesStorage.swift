import Dependencies
import DependenciesMacros
import Foundation

struct ApplicationInstanceRecord: Codable, Equatable, Sendable {
	let bundleURL: URL
	let launchDate: Date
	let processID: Int32

	init(
		bundleURL: URL,
		launchDate: Date,
		processID: Int32
	) {
		self.bundleURL = bundleURL
		self.launchDate = launchDate
		self.processID = processID
	}

	private enum CodingKeys: String, CodingKey {
		case bundleURL = "bundle_url"
		case launchDate = "launch_date"
		case processID = "process_id"
	}
}

@DependencyClient
struct AppInstancesStorageClient {
	var list: @Sendable () throws -> [WorkspaceID: ApplicationInstanceRecord]
	var find: @Sendable (_ for: WorkspaceID) throws -> ApplicationInstanceRecord?
	var save: @Sendable (ApplicationInstanceRecord, _ for: WorkspaceID) throws -> Void
	var remove: @Sendable (_ for: WorkspaceID) throws -> Void
}

extension DependencyValues {
	private enum AppInstancesStorageClientKey: DependencyKey {
		static var liveValue: AppInstancesStorageClient {
			let storage = AppInstancesStorage(fileManager: .default)
			return .init(
				list: storage.records,
				find: storage.record,
				save: storage.setRecord,
				remove: { try storage.setRecord(nil, forWorkspaceID: $0) }
			)
		}
	}

	var _fxclaudeAppInstances: AppInstancesStorageClient {
		get { self[AppInstancesStorageClientKey.self] }
		set { self[AppInstancesStorageClientKey.self] = newValue }
	}
}

final class AppInstancesStorage: @unchecked Sendable {
	private let decoder: JSONDecoder
	private let encoder: JSONEncoder
	private let fileManager: FileManager
	private let lock: StorageLock
	private let paths: FXClaudePaths

	init(fileManager: FileManager = .default) {
		@Dependency(\._fxclaudePaths)
		var paths

		let encoder = FXClaudeJSONCoding.encoder()
		encoder.dateEncodingStrategy = .iso8601
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		self.decoder = decoder
		self.encoder = encoder
		self.fileManager = fileManager
		self.paths = paths
		self.lock = StorageLock(fileManager: fileManager, paths: paths)
	}

	func records() throws -> [WorkspaceID: ApplicationInstanceRecord] {
		try Migrator(fileManager: self.fileManager, paths: self.paths).migrateIfNeeded()
		guard self.fileManager.fileExists(atPath: self.paths.runtimeURL.path) else { return [:] }
		let runtime = try self.decoder.decode(
			RuntimeConfiguration.self,
			from: Data(contentsOf: self.paths.runtimeURL)
		)
		guard runtime.schemaVersion == .v2_0 else {
			throw FXClaudeError.unsupportedSchemaVersion(runtime.schemaVersion)
		}
		return runtime.instances
	}

	func record(forWorkspaceID id: WorkspaceID) throws -> ApplicationInstanceRecord? {
		try self.records()[id]
	}

	func setRecord(
		_ record: ApplicationInstanceRecord?,
		forWorkspaceID id: WorkspaceID
	) throws {
		try Migrator(fileManager: self.fileManager, paths: self.paths).migrateIfNeeded()
		try self.lock.withLock {
			var records = try self.loadRecords()
			records[id] = record
			try self.save(records: records)
		}
	}

	private func loadRecords() throws -> [WorkspaceID: ApplicationInstanceRecord] {
		guard self.fileManager.fileExists(atPath: self.paths.runtimeURL.path) else { return [:] }
		let runtime = try self.decoder.decode(
			RuntimeConfiguration.self,
			from: Data(contentsOf: self.paths.runtimeURL)
		)
		guard runtime.schemaVersion == .v2_0 else {
			throw FXClaudeError.unsupportedSchemaVersion(runtime.schemaVersion)
		}

		return runtime.instances
	}

	private func save(records: [WorkspaceID: ApplicationInstanceRecord]) throws {
		try self.fileManager.createDirectory(
			at: self.paths.rootURL,
			withIntermediateDirectories: true,
			attributes: [.posixPermissions: 0o700]
		)
		try self.encoder.encode(RuntimeConfiguration(instances: records)).write(
			to: self.paths.runtimeURL,
			options: [.atomic]
		)
	}
}
