import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum JournalBackupError: LocalizedError, Equatable {
    case tooLarge
    case tooManyEntries
    case invalidFormat
    case duplicateIdentifiers
    case readProtected
    case stalePreview

    var errorDescription: String? {
        switch self {
        case .tooLarge: return "文件超过 25 MB，请分批整理后再导入。"
        case .tooManyEntries: return "单次最多导入 10,000 篇日记。"
        case .invalidFormat: return "文件不是有效的 MD Journal JSON 备份，现有日记没有改变。"
        case .duplicateIdentifiers: return "备份内有重复的日记 ID，无法安全合并。现有日记没有改变。"
        case .readProtected: return "原日记文件读取失败，已暂停修改。请先导出原文件或重试读取。"
        case .stalePreview: return "预览后日记已发生变化，请重新预览再确认。"
        }
    }
}

struct JournalBackupImportPreview: Identifiable, Sendable {
    let id = UUID()
    let entries: [JournalEntry]
    let newEntryCount: Int
    let existingEntryCount: Int
    let basedOnRevision: UInt64
}

enum JournalBackupCodec {
    static let maximumBytes = 25 * 1024 * 1024
    static let maximumEntries = 10_000

    static func encode(_ entries: [JournalEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(entries)
    }

    static func decode(_ data: Data) throws -> [JournalEntry] {
        guard data.count <= maximumBytes else { throw JournalBackupError.tooLarge }
        let entries: [JournalEntry]
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([JournalEntry].self, from: data)
        } catch {
            throw JournalBackupError.invalidFormat
        }
        guard entries.count <= maximumEntries else { throw JournalBackupError.tooManyEntries }
        try validateIdentifiers(entries)
        return entries
    }

    static func validateIdentifiers(_ entries: [JournalEntry]) throws {
        var identifiers = Set<UUID>()
        for entry in entries {
            guard identifiers.insert(entry.id).inserted else { throw JournalBackupError.duplicateIdentifiers }
        }
    }

    static func readBoundedData(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while let chunk = try handle.read(upToCount: min(64 * 1024, maximumBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
            guard data.count <= maximumBytes else { throw JournalBackupError.tooLarge }
        }
        return data
    }
}

struct JournalBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw JournalBackupError.invalidFormat }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
