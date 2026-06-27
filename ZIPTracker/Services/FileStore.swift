import Foundation

/// Thin filesystem helper for on-device exports, scoped to Application Support.
///
/// Nothing here touches the network; files live under
/// `Application Support/ZIPTracker/Exports`.
struct FileStore {

    let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// `…/Application Support/ZIPTracker`
    func rootDirectory() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent(AppConstants.Export.rootDirectoryName, isDirectory: true)
        try ensureDirectory(root)
        return root
    }

    /// `…/Application Support/ZIPTracker/Exports`
    func exportsDirectory() throws -> URL {
        let dir = try rootDirectory().appendingPathComponent(AppConstants.Export.directoryName, isDirectory: true)
        try ensureDirectory(dir)
        return dir
    }

    @discardableResult
    func write(_ data: Data, fileName: String) throws -> URL {
        let url = try exportsDirectory().appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    func write(_ string: String, fileName: String) throws -> URL {
        try write(Data(string.utf8), fileName: fileName)
    }

    func existingExports() throws -> [URL] {
        let dir = try exportsDirectory()
        let urls = try fileManager.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        return urls.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return l > r
        }
    }

    func delete(_ url: URL) throws {
        try fileManager.removeItem(at: url)
    }

    private func ensureDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
