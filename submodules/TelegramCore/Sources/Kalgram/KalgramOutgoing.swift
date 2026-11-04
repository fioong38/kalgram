import Foundation
import Postbox

// kalgram: what happens to a message as it is sent. The text rules follow Ghostgram's outgoing
// pipeline (GPLv2, github.com/ichmagmaus111/ghostgram). They run once per send and only when
// turned on, so they cost the battery nothing while the chat is merely open.

public struct KalgramTextRule: Codable, Equatable {
    public var source: String
    public var replacement: String

    public init(source: String, replacement: String) {
        self.source = source
        self.replacement = replacement
    }
}

public enum KalgramOutgoing {
    private static let antiCapsKey = "kalgram.outgoing.antiCaps"
    private static let wordReplacementKey = "kalgram.outgoing.wordReplacement"
    private static let rulesKey = "kalgram.outgoing.rules"

    // ALL CAPS becomes normal case
    public static var antiCaps: Bool {
        get {
            return UserDefaults.standard.bool(forKey: antiCapsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: antiCapsKey)
        }
    }

    // The user's replacement rules
    public static var wordReplacement: Bool {
        get {
            return UserDefaults.standard.bool(forKey: wordReplacementKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: wordReplacementKey)
        }
    }

    public static var rules: [KalgramTextRule] {
        get {
            guard let data = UserDefaults.standard.data(forKey: rulesKey), let rules = try? JSONDecoder().decode([KalgramTextRule].self, from: data) else {
                return []
            }
            return rules
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: rulesKey)
        }
    }

    // A new rule for a word already in the list takes its place
    public static func addRule(source: String, replacement: String) {
        let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty {
            return
        }
        var updated = rules.filter { $0.source.lowercased() != source.lowercased() }
        updated.append(KalgramTextRule(source: source, replacement: replacement.trimmingCharacters(in: .whitespacesAndNewlines)))
        rules = updated
    }
}

private struct KalgramTextEdit {
    let range: Range<Int>
    let replacement: String
}

private enum KalgramTextStages {
    private static let plainProtectedExpression = try? NSRegularExpression(pattern: "(?:^|(?<=\\s))[@#$/][\\p{L}\\p{N}_]+", options: [])
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    // Under these the text never changes: links, mentions, commands and code, marked or just typed
    static func protectedRanges(text: String, entities: [MessageTextEntity]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        for entity in entities {
            switch entity.type {
            case .Mention, .Hashtag, .BotCommand, .Url, .Email, .Code, .Pre, .TextUrl, .TextMention, .PhoneNumber, .BankCard, .TonAddress, .CustomEmoji, .FormattedDate:
                result.append(entity.range)
            default:
                break
            }
        }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let expressions: [NSRegularExpression?] = [plainProtectedExpression, linkDetector]
        for expression in expressions {
            expression?.enumerateMatches(in: text, options: [], range: fullRange, using: { match, _, _ in
                if let match {
                    result.append(match.range.location ..< (match.range.location + match.range.length))
                }
            })
        }
        return result
    }

    static func intersects(_ range: Range<Int>, _ protected: [Range<Int>]) -> Bool {
        return protected.contains(where: { $0.overlaps(range) })
    }

    private static func isWordCharacter(_ unit: UInt16) -> Bool {
        guard let scalar = Unicode.Scalar(unit) else {
            return false
        }
        return CharacterSet.alphanumerics.contains(scalar) || scalar == "_"
    }

    private static func adaptCase(of matched: String, to replacement: String) -> String {
        let letters = matched.filter { $0.isLetter }
        if letters.count > 1 && letters.allSatisfy({ $0.isUppercase }) {
            return replacement.uppercased()
        }
        if let first = letters.first, first.isUppercase, let replacementFirst = replacement.first {
            return String(replacementFirst).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    // Whole words only, one pass: a replacement is never fed into another rule
    static func wordReplacementEdits(text: String, rules: [KalgramTextRule], protected: [Range<Int>]) -> [KalgramTextEdit] {
        let string = text as NSString
        let units = Array(text.utf16)
        var matches: [KalgramTextEdit] = []
        for rule in rules {
            var searchRange = NSRange(location: 0, length: string.length)
            while searchRange.length > 0 {
                let found = string.range(of: rule.source, options: [.caseInsensitive], range: searchRange)
                if found.location == NSNotFound || found.length == 0 {
                    break
                }
                let range = found.location ..< (found.location + found.length)
                searchRange = NSRange(location: range.upperBound, length: string.length - range.upperBound)
                if range.lowerBound > 0 && isWordCharacter(units[range.lowerBound - 1]) {
                    continue
                }
                if range.upperBound < units.count && isWordCharacter(units[range.upperBound]) {
                    continue
                }
                if intersects(range, protected) {
                    continue
                }
                matches.append(KalgramTextEdit(range: range, replacement: adaptCase(of: string.substring(with: found), to: rule.replacement)))
            }
        }
        matches.sort(by: { lhs, rhs in
            if lhs.range.lowerBound != rhs.range.lowerBound {
                return lhs.range.lowerBound < rhs.range.lowerBound
            }
            return lhs.range.count > rhs.range.count
        })
        var result: [KalgramTextEdit] = []
        var lastEnd = 0
        for match in matches where match.range.lowerBound >= lastEnd {
            result.append(match)
            lastEnd = match.range.upperBound
        }
        return result
    }

    static func antiCapsEdits(text: String, protected: [Range<Int>]) -> [KalgramTextEdit] {
        var items: [(character: Character, range: Range<Int>)] = []
        var offset = 0
        for character in text {
            let length = String(character).utf16.count
            items.append((character, offset ..< (offset + length)))
            offset += length
        }

        var letters = 0
        var uppercase = 0
        var lowercase = 0
        for item in items where item.character.isLetter && !intersects(item.range, protected) {
            letters += 1
            if item.character.isUppercase {
                uppercase += 1
            } else if item.character.isLowercase {
                lowercase += 1
            }
        }
        if letters < 4 {
            return []
        }
        if lowercase != 0 && Double(uppercase) / Double(letters) < 0.8 {
            return []
        }

        var result: [KalgramTextEdit] = []
        var sentenceStart = true
        for item in items {
            let character = item.character
            let isProtected = intersects(item.range, protected)
            if character.isLetter {
                if !isProtected {
                    let updated = sentenceStart ? String(character).uppercased() : String(character).lowercased()
                    if updated != String(character) {
                        result.append(KalgramTextEdit(range: item.range, replacement: updated))
                    }
                }
                sentenceStart = false
            } else if character == "." || character == "!" || character == "?" || character == "…" || character.isNewline {
                sentenceStart = true
            } else if character.isNumber || isProtected {
                sentenceStart = false
            }
        }
        return result
    }

    // `edits` are in ascending order and do not overlap. Formatting moves with the text.
    static func apply(_ edits: [KalgramTextEdit], text: String, entities: [MessageTextEntity]) -> (String, [MessageTextEntity]) {
        if edits.isEmpty {
            return (text, entities)
        }
        let result = NSMutableString(string: text)
        for edit in edits.reversed() {
            result.replaceCharacters(in: NSRange(location: edit.range.lowerBound, length: edit.range.count), with: edit.replacement)
        }
        func mapped(_ position: Int, isEnd: Bool) -> Int {
            var shift = 0
            for edit in edits {
                let newLength = (edit.replacement as NSString).length
                if position >= edit.range.upperBound {
                    shift += newLength - edit.range.count
                } else if position > edit.range.lowerBound {
                    return edit.range.lowerBound + shift + (isEnd ? newLength : 0)
                } else {
                    break
                }
            }
            return position + shift
        }
        var updatedEntities: [MessageTextEntity] = []
        for entity in entities {
            let lower = mapped(entity.range.lowerBound, isEnd: false)
            let upper = mapped(entity.range.upperBound, isEnd: true)
            if lower < upper {
                updatedEntities.append(MessageTextEntity(range: lower ..< upper, type: entity.type))
            }
        }
        return (result as String, updatedEntities)
    }
}

private func kalgramTransformedText(_ message: EnqueueMessage) -> EnqueueMessage {
    guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, !text.isEmpty else {
        return message
    }
    // Rich messages derive their text from the page, inline results and quick replies go as they are
    if attributes.contains(where: { $0 is RichTextMessageAttribute || $0 is OutgoingChatContextResultMessageAttribute || $0 is OutgoingQuickReplyMessageAttribute }) {
        return message
    }
    var entities: [MessageTextEntity] = []
    var entitiesIndex: Int?
    for i in 0 ..< attributes.count {
        if let attribute = attributes[i] as? TextEntitiesMessageAttribute {
            entities = attribute.entities
            entitiesIndex = i
            break
        }
    }

    var updatedText = text
    var updatedEntities = entities
    if KalgramOutgoing.wordReplacement {
        let rules = KalgramOutgoing.rules
        if !rules.isEmpty {
            let protected = KalgramTextStages.protectedRanges(text: updatedText, entities: updatedEntities)
            (updatedText, updatedEntities) = KalgramTextStages.apply(KalgramTextStages.wordReplacementEdits(text: updatedText, rules: rules, protected: protected), text: updatedText, entities: updatedEntities)
        }
    }
    if KalgramOutgoing.antiCaps && !updatedText.hasPrefix("/") {
        let protected = KalgramTextStages.protectedRanges(text: updatedText, entities: updatedEntities)
        (updatedText, updatedEntities) = KalgramTextStages.apply(KalgramTextStages.antiCapsEdits(text: updatedText, protected: protected), text: updatedText, entities: updatedEntities)
    }
    if updatedText == text {
        return message
    }

    var updatedAttributes = attributes
    if let entitiesIndex {
        updatedAttributes[entitiesIndex] = TextEntitiesMessageAttribute(entities: updatedEntities)
    }
    return .message(text: updatedText, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
}

// Runs inside the send's transaction, so the chat's peer is known
func kalgramApplyOutgoing(_ messages: [(Bool, EnqueueMessage)], transaction: Transaction, account: Account, peerId: PeerId) -> [(Bool, EnqueueMessage)] {
    var result = messages
    let hasTextRules = KalgramOutgoing.antiCaps || KalgramOutgoing.wordReplacement
    // Bots get exactly what was typed: commands, button texts, codes
    let isBot = (transaction.getPeer(peerId) as? TelegramUser)?.botInfo != nil
    if hasTextRules && !isBot {
        result = result.map { ($0.0, kalgramTransformedText($0.1)) }
    }
    return result
}
