import Foundation
import Observation
import VlogifyEngine
import os

/// Notes typed on the day page and on a room's page. **Local only.**
///
/// One JSON file per page in the app-group container. Nothing here touches `Backend`;
/// nothing here ever leaves the phone except through the user's own iCloud backup, which
/// is why the folder is *not* excluded from backup the way the clip cache is. Deleting the
/// account wipes it, because it is the user's and the user asked for everything gone.
@MainActor
@Observable
final class NotesStore {
    enum Scope: Hashable, Sendable {
        case day(DayKey)
        case room(String)

        var fileName: String {
            switch self {
            case .day(let day): return "day-\(day).json"
            case .room(let id): return "room-\(id).json"
            }
        }
    }

    struct Page: Codable, Equatable, Sendable {
        var title: String = ""
        var blocks: [Block] = []
    }

    struct Block: Codable, Equatable, Identifiable, Sendable {
        enum Kind: String, Codable, Sendable { case text, heading, todo }
        var id: UUID = UUID()
        var kind: Kind = .text
        var text: String = ""
        var done: Bool = false
    }

    private let root: URL
    private var pages: [Scope: Page] = [:]
    private let logger = Logger(subsystem: "com.matthewpark.vlogify", category: "notes")

    init(root: URL? = nil) {
        let base = root
            ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.matthewpark.vlogify")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.root = base.appendingPathComponent("notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func page(_ scope: Scope) -> Page {
        if let cached = pages[scope] { return cached }
        let url = root.appendingPathComponent(scope.fileName)
        let loaded = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Page.self, from: $0) } ?? Page()
        pages[scope] = loaded
        return loaded
    }

    func update(_ scope: Scope, _ change: (inout Page) -> Void) {
        var page = self.page(scope)
        change(&page)
        pages[scope] = page
        let url = root.appendingPathComponent(scope.fileName)
        do {
            try JSONEncoder().encode(page).write(to: url, options: .atomic)
        } catch {
            logger.error("could not save \(scope.fileName): \(error.localizedDescription)")
        }
    }

    /// Whether a page has anything typed on it (used to decide which past days are
    /// worth navigating to).
    func hasContent(_ scope: Scope) -> Bool {
        let page = self.page(scope)
        return !page.title.isEmpty || page.blocks.contains { !$0.text.isEmpty }
    }

    /// Every day whose page has something typed on it, read from the files on disk.
    func daysWithNotes() -> Set<DayKey> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        var days = Set<DayKey>()
        for name in names where name.hasPrefix("day-") && name.hasSuffix(".json") {
            let parts = name.dropFirst(4).dropLast(5).split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            let day = DayKey(year: parts[0], month: parts[1], day: parts[2])
            if hasContent(.day(day)) { days.insert(day) }
        }
        return days
    }

    func wipe() {
        pages = [:]
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
}
