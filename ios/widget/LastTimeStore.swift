import Foundation
import SQLite3

struct LastTimeItem: Identifiable {
    let id: Int
    let name: String
    let interval: Int?
    let lastOn: String?
    let latestEventID: String?
    let recordedAt: Int64?

    func daysAgo(on date: Date) -> Int? {
        guard let lastOn, let last = LastTimeStore.dayFormatter.date(from: lastOn) else { return nil }
        return max(Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last),
                                                   to: Calendar.current.startOfDay(for: date)).day ?? 0, 0)
    }

    func elapsed(on date: Date) -> String {
        guard let days = daysAgo(on: date) else { return "Not logged yet" }
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    func isDue(on date: Date) -> Bool {
        guard let interval, let days = daysAgo(on: date) else { return false }
        return days >= interval
    }
}

// SQLite transactions are shared with LastTimeRepo; no snapshot can overwrite a widget log.
enum LastTimeStore {
    static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    static func withDatabase<T>(path: String? = nil, _ body: (OpaquePointer) throws -> T) throws -> T {
        let databasePath: String
        if let path {
            databasePath = path
        } else {
            guard let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "group.com.aayushmau5.bnana"
            ) else { throw failure("Open bnana to set up Last time.") }
            databasePath = directory.appendingPathComponent("last_time.db").path
        }
        var connection: OpaquePointer?
        let status = sqlite3_open_v2(databasePath, &connection, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
        guard status == SQLITE_OK, let database = connection else {
            if let connection { sqlite3_close(connection) }
            throw failure("Open bnana to set up Last time.")
        }
        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 5_000)
        try execute(database, sql: "PRAGMA foreign_keys = ON")
        return try body(database)
    }

    static func items(path: String? = nil) throws -> [LastTimeItem] {
        try withDatabase(path: path) { database in
            let sql = """
                SELECT i.id, i.name, i.interval_days,
                  (SELECT MAX(occurred_on) FROM last_time_events WHERE item_id = i.id),
                  e.id, e.recorded_at
                FROM last_time_items i
                LEFT JOIN last_time_events e ON e.id =
                  (SELECT id FROM last_time_events WHERE item_id = i.id ORDER BY recorded_at DESC, id DESC LIMIT 1)
                WHERE i.pinned = 1 ORDER BY i.id LIMIT 3
                """
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw failure("Couldn’t load your counters. Open bnana and try again.")
            }
            defer { sqlite3_finalize(statement) }
            var result: [LastTimeItem] = []
            var status = sqlite3_step(statement)
            while status == SQLITE_ROW {
                result.append(LastTimeItem(
                    id: Int(sqlite3_column_int64(statement, 0)),
                    name: column(statement, 1) ?? "",
                    interval: sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 2)),
                    lastOn: column(statement, 3), latestEventID: column(statement, 4),
                    recordedAt: sqlite3_column_type(statement, 5) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 5)
                ))
                status = sqlite3_step(statement)
            }
            guard status == SQLITE_DONE else { throw failure("Couldn’t read your counters. Try again.") }
            return result
        }
    }

    static func log(itemID: Int, eventID: String, date: Date = .now, path: String? = nil) throws {
        try withDatabase(path: path) { database in
            try execute(database, sql: """
                INSERT INTO last_time_events (id, item_id, occurred_on, recorded_at)
                SELECT ?, id, ?, ? FROM last_time_items WHERE id = ? AND pinned = 1
                ON CONFLICT(id) DO NOTHING
                """, values: [eventID, dayFormatter.string(from: date), String(Int64(date.timeIntervalSince1970 * 1_000_000)), String(itemID)])
        }
    }

    static func undo(itemID: Int, eventID: String, path: String? = nil) throws {
        try withDatabase(path: path) { database in
            try execute(database, sql: "DELETE FROM last_time_events WHERE item_id = ? AND id = ?", values: [String(itemID), eventID])
        }
    }

    private static func column(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }

    private static func execute(_ database: OpaquePointer, sql: String, values: [String] = []) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw failure("Couldn’t save that change. Open bnana and try again.")
        }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            let status = value.withCString { sqlite3_bind_text(statement, Int32(index + 1), $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard status == SQLITE_OK else { throw failure("Couldn’t save that change. Try again.") }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure("Couldn’t save that change. Try again.") }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "Bnana.LastTime", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
