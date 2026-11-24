import AppKit

@MainActor
final class ScreenshotStore {
    static let shared = ScreenshotStore()

    private enum DefaultsKey {
        static let saveFolderPath = "saveFolderPath"
        static let autoSaveCaptures = "autoSaveCaptures"
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager
    }

    /// The folder the user chose, even if it is temporarily unavailable (for
    /// example while a cloud folder is still mounting after login).
    var configuredSaveFolderURL: URL? {
        guard let path = defaults.string(forKey: DefaultsKey.saveFolderPath) else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// The configured folder only while it is usable for writing.
    var saveFolderURL: URL? {
        guard let url = configuredSaveFolderURL else { return nil }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return url
    }

    var autoSaveCaptures: Bool {
        get { defaults.bool(forKey: DefaultsKey.autoSaveCaptures) }
        set { defaults.set(newValue, forKey: DefaultsKey.autoSaveCaptures) }
    }

    @discardableResult
    func chooseSaveFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Choose where sShooter saves screenshots."
        panel.directoryURL = saveFolderURL
            ?? fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first

        NSApp.activate()
        guard panel.runModal() == .OK, let folder = panel.url else { return nil }

        defaults.set(folder.path, forKey: DefaultsKey.saveFolderPath)
        return folder
    }

    func save(pngData: Data) throws -> URL? {
        let folder: URL
        if let configuredFolder = saveFolderURL {
            folder = configuredFolder
        } else if let chosenFolder = chooseSaveFolder() {
            folder = chosenFolder
        } else {
            return nil
        }

        let url = uniqueFileURL(in: folder)
        do {
            try pngData.write(to: url, options: .atomic)
        } catch {
            throw ScreenshotStoreError.writeFailed(url: url, underlying: error)
        }
        return url
    }

    @discardableResult
    func saveCapture(_ image: CGImage) throws -> URL? {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotStoreError.encodingFailed
        }
        return try save(pngData: data)
    }

    private func uniqueFileURL(in folder: URL) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let base = "Screenshot \(formatter.string(from: Date()))"

        var url = folder.appendingPathComponent("\(base).png")
        var suffix = 2
        while fileManager.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base)-\(suffix).png")
            suffix += 1
        }
        return url
    }
}

enum ScreenshotStoreError: LocalizedError {
    case encodingFailed
    case writeFailed(url: URL, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "The screenshot couldn’t be encoded as a PNG."
        case let .writeFailed(url, underlying):
            return "The screenshot couldn’t be saved to “\(url.path)”. \(underlying.localizedDescription)"
        }
    }
}
