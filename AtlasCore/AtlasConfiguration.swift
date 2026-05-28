import Foundation

enum AtlasConfiguration {
    static let appGroupIdentifier = "group.com.wooshir.keygram"
    static let hapticsEnabledKey = "atlas.hapticsEnabled"
    static let autocorrectEnabledKey = "atlas.autocorrectEnabled"
    static let inferenceSuggestionsEnabledKey = "atlas.inferenceSuggestionsEnabled"
    static let personalizedAutocorrectEnabledKey = "atlas.personalizedAutocorrectEnabled"
    static let personalizedTypingEnabledKey = "atlas.personalizedTypingEnabled"
    static let personalizedTypingActivationThreshold = 1_000
    static let touchModelSchemaVersionKey = "atlas.touchModelSchemaVersion"
    static let currentTouchModelSchemaVersion = 3
    static let learnNewWordsEnabledKey = "atlas.learnNewWordsEnabled"
    static let engramLearningMigrationVersionKey = "atlas.engramLearningMigrationVersion"
    static let currentEngramLearningMigrationVersion = 2
    static let vocabularySize = 32_000
    static let attentionLayerCount = 4
    static let glaLayerCount = 4
    static let maxContextTokens = 512
    nonisolated static let maxSuggestions = 3
    nonisolated static let suggestionVocabularyLimit = 15_000
}
