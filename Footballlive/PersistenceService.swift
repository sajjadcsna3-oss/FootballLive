import Foundation
import SwiftData

@MainActor final class PersistenceService {
    static func preferences(in context: ModelContext) throws -> UserPreferences {
        if let existing = try context.fetch(FetchDescriptor<UserPreferences>()).first { return existing }
        let value = UserPreferences(); context.insert(value); try context.save(); return value
    }
    static func replaceFollowedTeams(_ teams: [Team], in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<FollowedTeam>()).forEach(context.delete)
        teams.forEach { context.insert(FollowedTeam(teamID: $0.id, name: $0.name, badgeURLString: $0.badgeURL?.absoluteString)) }
        try context.save()
    }
}
