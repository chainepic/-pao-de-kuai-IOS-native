import Foundation

enum PlayerID: String, Codable, CaseIterable {
    case me
    case left
    case right
}

enum Suit: String, Codable, CaseIterable {
    case hearts = "H"
    case spades = "S"
    case diamonds = "D"
    case clubs = "C"

    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .spades: return "♠"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        }
    }
}

enum Rank: String, Codable, CaseIterable {
    case r3 = "3"
    case r4 = "4"
    case r5 = "5"
    case r6 = "6"
    case r7 = "7"
    case r8 = "8"
    case r9 = "9"
    case t = "T"
    case j = "J"
    case q = "Q"
    case k = "K"
    case a = "A"
    case r2 = "2"

    var power: Int {
        switch self {
        case .r3: return 0
        case .r4: return 1
        case .r5: return 2
        case .r6: return 3
        case .r7: return 4
        case .r8: return 5
        case .r9: return 6
        case .t: return 7
        case .j: return 8
        case .q: return 9
        case .k: return 10
        case .a: return 11
        case .r2: return 12
        }
    }
}

struct Card: Codable, Hashable, Identifiable {
    let rank: Rank
    let suit: Suit

    var id: String { raw }
    var raw: String { "\(rank.rawValue)\(suit.rawValue)" }
    var power: Int { rank.power * 10 + suitOrder }
    var isRed: Bool { suit == .hearts || suit == .diamonds }

    private var suitOrder: Int {
        switch suit {
        case .clubs: return 0
        case .diamonds: return 1
        case .spades: return 2
        case .hearts: return 3
        }
    }

    static func from(raw: String) -> Card? {
        guard raw.count == 2 else { return nil }
        let rankStr = String(raw.prefix(1))
        let suitStr = String(raw.suffix(1))
        guard let rank = Rank(rawValue: rankStr), let suit = Suit(rawValue: suitStr) else { return nil }
        return Card(rank: rank, suit: suit)
    }
}

enum PlayType: String, Codable {
    case single
    case pair
    case straight
    case consecutivePairs
    case triple
    case tripleWithOne
    case tripleWithTwo
    case airplaneWithWings
    case bomb
    case invalid
}

struct PlayInfo: Codable {
    let type: PlayType
    let mainRank: Int
    let length: Int
    let pairCount: Int
    let tripleCount: Int
    let valid: Bool
    let reason: String
}

enum RulePreset: String, Codable, CaseIterable, Identifiable {
    case hunanClassic
    case relaxed
    case bombPriority
    case custom

    var id: String { rawValue }
}

struct RuleConfig: Codable {
    var preset: RulePreset
    var allowTripleWithOne: Bool
    var allowTripleWithoutWing: Bool
    var bombMustPlay: Bool

    static var hunanClassic: RuleConfig {
        .init(preset: .hunanClassic, allowTripleWithOne: false, allowTripleWithoutWing: false, bombMustPlay: false)
    }

    static var relaxed: RuleConfig {
        .init(preset: .relaxed, allowTripleWithOne: true, allowTripleWithoutWing: true, bombMustPlay: false)
    }

    static var bombPriority: RuleConfig {
        .init(preset: .bombPriority, allowTripleWithOne: true, allowTripleWithoutWing: true, bombMustPlay: true)
    }

    static func presetValue(_ preset: RulePreset) -> RuleConfig {
        switch preset {
        case .hunanClassic:
            return .hunanClassic
        case .relaxed:
            return .relaxed
        case .bombPriority:
            return .bombPriority
        case .custom:
            return .hunanClassic
        }
    }
}

enum PaodekuaiRules {
    static func hunanDeck() -> [Card] {
        let removed: Set<String> = ["2H", "2D", "2C", "AD"]
        var deck: [Card] = []
        for rank in Rank.allCases {
            for suit in Suit.allCases {
                let card = Card(rank: rank, suit: suit)
                if !removed.contains(card.raw) {
                    deck.append(card)
                }
            }
        }
        return sort(deck)
    }

    static func sort(_ cards: [Card]) -> [Card] {
        cards.sorted { $0.power < $1.power }
    }

    static func deal16x3() -> (me: [Card], left: [Card], right: [Card]) {
        var deck = hunanDeck().shuffled()
        let me = sort(Array(deck.prefix(16)))
        deck.removeFirst(16)
        let left = sort(Array(deck.prefix(16)))
        deck.removeFirst(16)
        let right = sort(Array(deck.prefix(16)))
        return (me, left, right)
    }

    static func remove(cards: [Card], from hand: [Card]) -> [Card] {
        var need: [String: Int] = [:]
        cards.forEach { need[$0.raw, default: 0] += 1 }
        return hand.filter { c in
            let left = need[c.raw, default: 0]
            if left > 0 {
                need[c.raw] = left - 1
                return false
            }
            return true
        }
    }

    static func detect(_ cards: [Card], config: RuleConfig = .hunanClassic) -> PlayInfo {
        let sorted = sort(cards)
        let len = sorted.count
        if len == 0 { return invalid(L10n.text("invalid_no_selection")) }

        let groups = Dictionary(grouping: sorted, by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        let counts = groups.values.map(\.count).sorted(by: >)
        let has2 = ranks.contains(Rank.r2.power)

        if len == 1 {
            return .init(type: .single, mainRank: ranks[0], length: 1, pairCount: 0, tripleCount: 0, valid: true, reason: "")
        }
        if len == 2, counts[0] == 2 {
            return .init(type: .pair, mainRank: ranks[0], length: 2, pairCount: 1, tripleCount: 0, valid: true, reason: "")
        }
        if len == 3, counts[0] == 3, config.allowTripleWithoutWing {
            return .init(type: .triple, mainRank: ranks[0], length: 3, pairCount: 0, tripleCount: 1, valid: true, reason: "")
        }
        if len == 4, counts[0] == 3, config.allowTripleWithOne {
            return .init(type: .tripleWithOne, mainRank: ranks.first(where: { groups[$0]?.count == 3 }) ?? -1, length: 4, pairCount: 0, tripleCount: 1, valid: true, reason: "")
        }
        if len == 4, counts[0] == 4 {
            return .init(type: .bomb, mainRank: ranks.first(where: { groups[$0]?.count == 4 }) ?? -1, length: 4, pairCount: 0, tripleCount: 0, valid: true, reason: "")
        }
        if len >= 4, len.isMultiple(of: 2), counts[0] == 2, counts.last == 2, !has2, isConsecutive(ranks) {
            return .init(type: .consecutivePairs, mainRank: ranks.last ?? -1, length: len, pairCount: ranks.count, tripleCount: 0, valid: true, reason: "")
        }
        if len >= 5, counts[0] == 1, !has2, isConsecutive(ranks) {
            return .init(type: .straight, mainRank: ranks.last ?? -1, length: len, pairCount: 0, tripleCount: 0, valid: true, reason: "")
        }
        if len == 5, counts[0] == 3 {
            return .init(type: .tripleWithTwo, mainRank: ranks.first(where: { groups[$0]?.count == 3 }) ?? -1, length: 5, pairCount: 0, tripleCount: 1, valid: true, reason: "")
        }

        let triplets = ranks.filter { groups[$0]?.count == 3 }
        if triplets.count >= 2, !triplets.contains(Rank.r2.power), isConsecutive(triplets) {
            let wingCount = len - triplets.count * 3
            if wingCount == triplets.count * 2 {
                return .init(type: .airplaneWithWings, mainRank: triplets.last ?? -1, length: len, pairCount: 0, tripleCount: triplets.count, valid: true, reason: "")
            }
        }

        return invalid(L10n.text("invalid_shape"))
    }

    static func canBeat(_ next: PlayInfo, _ top: PlayInfo?) -> Bool {
        guard next.valid else { return false }
        guard let top else { return true }
        guard top.valid else { return true }

        if next.type == .bomb && top.type != .bomb { return true }
        if top.type == .bomb && next.type != .bomb { return false }
        if next.type != top.type { return false }
        if next.length != top.length { return false }
        return next.mainRank > top.mainRank
    }

    static func chooseLead(_ hand: [Card], firstTurnMustSpade3: Bool, config: RuleConfig = .hunanClassic) -> [Card]? {
        let cards = sort(hand)
        guard !cards.isEmpty else { return nil }
        if firstTurnMustSpade3, let c = cards.first(where: { $0.raw == "3S" }) {
            return [c]
        }

        let groups = Dictionary(grouping: cards, by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        let bombs = bombCandidates(groups: groups, ranks: ranks, top: nil)
        if config.bombMustPlay, let firstBomb = bombs.first {
            return firstBomb
        }

        if let pairRank = ranks.first(where: { (groups[$0]?.count ?? 0) >= 2 }) {
            return Array(groups[pairRank]!.prefix(2))
        }
        return [cards[0]]
    }

    static func chooseBeat(_ hand: [Card], topCards: [Card], config: RuleConfig = .hunanClassic) -> [Card]? {
        beatingCandidates(hand, topCards: topCards, config: config).first
    }

    static func beatingCandidates(_ hand: [Card], topCards: [Card], config: RuleConfig = .hunanClassic) -> [[Card]] {
        let top = detect(topCards, config: config)
        guard top.valid else { return [] }
        let sortedHand = sort(hand)
        let groups = Dictionary(grouping: sortedHand, by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        var result: [[Card]] = []
        let bombs = bombCandidates(groups: groups, ranks: ranks, top: top)

        if config.bombMustPlay, !bombs.isEmpty {
            return uniquePlays(bombs)
        }

        switch top.type {
        case .single:
            var singles: [(cards: [Card], rankGroupSize: Int)] = []
            for r in ranks where r > top.mainRank {
                if let c = groups[r]?.first {
                    singles.append(([c], groups[r]?.count ?? 0))
                }
            }
            singles.sort {
                if $0.rankGroupSize != $1.rankGroupSize { return $0.rankGroupSize < $1.rankGroupSize }
                return ($0.cards.first?.power ?? 0) < ($1.cards.first?.power ?? 0)
            }
            result.append(contentsOf: singles.map(\.cards))

        case .pair:
            for r in ranks where r > top.mainRank {
                if (groups[r]?.count ?? 0) >= 2 {
                    result.append(Array(groups[r]!.prefix(2)))
                }
            }

        case .straight:
            let seqRanks = consecutiveRankWindows(ranks.filter { $0 != Rank.r2.power }, length: top.length)
            for seq in seqRanks where (seq.last ?? -1) > top.mainRank {
                let cards = seq.compactMap { groups[$0]?.first }
                if cards.count == top.length {
                    result.append(cards)
                }
            }

        case .consecutivePairs:
            let pairRanks = ranks.filter { ($0 != Rank.r2.power) && ((groups[$0]?.count ?? 0) >= 2) }
            let seqRanks = consecutiveRankWindows(pairRanks, length: top.length / 2)
            for seq in seqRanks where (seq.last ?? -1) > top.mainRank {
                var cards: [Card] = []
                for r in seq {
                    cards.append(contentsOf: Array(groups[r]!.prefix(2)))
                }
                if cards.count == top.length {
                    result.append(cards)
                }
            }

        case .triple:
            for r in ranks where (r > top.mainRank) && ((groups[r]?.count ?? 0) >= 3) {
                result.append(Array(groups[r]!.prefix(3)))
            }

        case .tripleWithOne:
            for tr in ranks where (tr > top.mainRank) && ((groups[tr]?.count ?? 0) >= 3) {
                let main = Array(groups[tr]!.prefix(3))
                let remaining = remove(cards: main, from: sortedHand)
                for wing in preferredSingleWings(from: remaining).prefix(12) {
                    result.append(main + [wing])
                }
            }

        case .tripleWithTwo:
            let tripleRanks = ranks.filter { ($0 > top.mainRank) && ((groups[$0]?.count ?? 0) >= 3) }
            for tr in tripleRanks {
                let main = Array(groups[tr]!.prefix(3))
                let remaining = remove(cards: main, from: sortedHand)
                let wings = preferredTwoCardWings(from: remaining)
                for wing in wings.prefix(12) {
                    result.append(main + wing)
                }
            }

        case .airplaneWithWings:
            let needTriples = top.tripleCount
            let tripleRanks = ranks.filter { ($0 != Rank.r2.power) && ((groups[$0]?.count ?? 0) >= 3) }
            let tripSeqs = consecutiveRankWindows(tripleRanks, length: needTriples)
            for seq in tripSeqs where (seq.last ?? -1) > top.mainRank {
                var main: [Card] = []
                for r in seq {
                    main.append(contentsOf: Array(groups[r]!.prefix(3)))
                }
                let wingNeed = needTriples * 2
                let remaining = remove(cards: main, from: sortedHand)
                let wing = preferredWingCards(from: remaining, need: wingNeed)
                if wing.count == wingNeed {
                    result.append(main + wing)
                }
            }

        case .bomb:
            result.append(contentsOf: bombs)

        case .invalid:
            break
        }

        if top.type != .bomb {
            result.append(contentsOf: bombs)
        }

        return uniquePlays(result)
    }

    static func nextPlayer(_ p: PlayerID) -> PlayerID {
        switch p {
        case .me: return .right
        case .right: return .left
        case .left: return .me
        }
    }

    private static func isConsecutive(_ ranks: [Int]) -> Bool {
        guard ranks.count >= 2 else { return true }
        for i in 1..<ranks.count where ranks[i] != ranks[i - 1] + 1 {
            return false
        }
        return true
    }

    private static func consecutiveRankWindows(_ ranks: [Int], length: Int) -> [[Int]] {
        guard length > 0, ranks.count >= length else { return [] }
        let sortedRanks = ranks.sorted()
        var windows: [[Int]] = []
        for i in 0...(sortedRanks.count - length) {
            let slice = Array(sortedRanks[i..<(i + length)])
            if isConsecutive(slice) {
                windows.append(slice)
            }
        }
        return windows
    }

    private static func preferredTwoCardWings(from cards: [Card]) -> [[Card]] {
        let sortedCards = sort(cards)
        guard sortedCards.count >= 2 else { return [] }
        let groups = Dictionary(grouping: sortedCards, by: { $0.rank.power })

        var pairs: [([Card], Int, Int)] = []
        for i in 0..<(sortedCards.count - 1) {
            for j in (i + 1)..<sortedCards.count {
                let c1 = sortedCards[i]
                let c2 = sortedCards[j]
                let isPair = c1.rank.power == c2.rank.power ? 1 : 0
                let attachPenalty = (groups[c1.rank.power]?.count ?? 0) + (groups[c2.rank.power]?.count ?? 0)
                pairs.append(([c1, c2], isPair, attachPenalty))
            }
        }

        pairs.sort {
            if $0.1 != $1.1 { return $0.1 < $1.1 } // Prefer two singles over a pair.
            if $0.2 != $1.2 { return $0.2 < $1.2 } // Prefer breaking weaker groups first.
            let lhsPower = ($0.0[0].power + $0.0[1].power)
            let rhsPower = ($1.0[0].power + $1.0[1].power)
            return lhsPower < rhsPower
        }

        return uniquePlays(pairs.map(\.0))
    }

    private static func preferredSingleWings(from cards: [Card]) -> [Card] {
        let sortedCards = sort(cards)
        let groups = Dictionary(grouping: sortedCards, by: { $0.rank.power })
        return sortedCards.sorted {
            let c0 = groups[$0.rank.power]?.count ?? 0
            let c1 = groups[$1.rank.power]?.count ?? 0
            if c0 != c1 { return c0 < c1 } // Prefer not breaking pairs/triples first.
            return $0.power < $1.power
        }
    }

    private static func preferredWingCards(from cards: [Card], need: Int) -> [Card] {
        guard need > 0 else { return [] }
        let sortedCards = sort(cards)
        let groups = Dictionary(grouping: sortedCards, by: { $0.rank.power })
        let singleRanks = groups.keys.filter { (groups[$0]?.count ?? 0) == 1 }.sorted()

        var picked: [Card] = []
        for r in singleRanks {
            if let c = groups[r]?.first {
                picked.append(c)
                if picked.count == need { return picked }
            }
        }

        for c in sortedCards where !picked.contains(c) {
            picked.append(c)
            if picked.count == need { return picked }
        }
        return picked
    }

    private static func uniquePlays(_ plays: [[Card]]) -> [[Card]] {
        var seen: Set<String> = []
        var unique: [[Card]] = []
        for play in plays {
            let key = sort(play).map(\.raw).joined(separator: "|")
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(sort(play))
            }
        }
        return unique
    }

    private static func bombCandidates(groups: [Int: [Card]], ranks: [Int], top: PlayInfo?) -> [[Card]] {
        let isTopBomb = top?.type == .bomb
        let topRank = top?.mainRank ?? -1
        var bombs: [[Card]] = []
        for r in ranks where (groups[r]?.count ?? 0) >= 4 {
            if !isTopBomb || r > topRank {
                bombs.append(Array(groups[r]!.prefix(4)))
            }
        }
        return bombs
    }

    private static func invalid(_ reason: String) -> PlayInfo {
        .init(type: .invalid, mainRank: -1, length: 0, pairCount: 0, tripleCount: 0, valid: false, reason: reason)
    }
}

enum VoiceTextBuilder {
    static func playText(for cards: [Card], play: PlayInfo, language: AppLanguage = L10n.currentLanguage()) -> String {
        guard play.valid else { return "" }
        switch play.type {
        case .single:
            return rankSpeech(cards.first?.rank, language: language)
        case .pair:
            return L10n.text("voice_pair_prefix", language: language) + rankSpeech(cards.first?.rank, language: language)
        case .triple:
            return L10n.text("voice_triple", language: language)
        case .tripleWithOne:
            return L10n.text("voice_triple_with_one", language: language)
        case .bomb:
            return rankSpeech(cards.first?.rank, language: language) + L10n.text("voice_bomb_suffix", language: language)
        case .straight:
            return L10n.text("voice_straight", language: language)
        case .tripleWithTwo:
            return L10n.text("voice_triple_with_two", language: language)
        case .airplaneWithWings:
            return L10n.text("voice_airplane_with_wings", language: language)
        case .consecutivePairs:
            return L10n.text("voice_consecutive_pairs", language: language)
        case .invalid:
            return ""
        }
    }

    private static func rankSpeech(_ rank: Rank?, language: AppLanguage) -> String {
        guard let rank else { return "" }
        switch rank {
        case .a: return L10n.text("voice_rank_a", language: language)
        case .t: return L10n.text("voice_rank_t", language: language)
        case .r2: return L10n.text("voice_rank_2", language: language)
        case .j: return L10n.text("voice_rank_j", language: language)
        case .q: return L10n.text("voice_rank_q", language: language)
        case .k: return "K"
        default: return rank.rawValue
        }
    }
}
