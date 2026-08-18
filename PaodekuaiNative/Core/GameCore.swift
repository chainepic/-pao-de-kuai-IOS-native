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

    nonisolated var power: Int {
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

nonisolated struct Card: Codable, Hashable, Identifiable {
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

nonisolated struct RuleConfig: Codable {
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

nonisolated enum PaodekuaiRules {
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
        if len == 5 {
            if let tripleRank = ranks.first(where: { (groups[$0]?.count ?? 0) >= 3 }) {
                return .init(type: .tripleWithTwo, mainRank: tripleRank, length: 5, pairCount: 0, tripleCount: 1, valid: true, reason: "")
            }
        }

        let triplets = ranks.filter { (groups[$0]?.count ?? 0) >= 3 }
        if triplets.count >= 2, !triplets.contains(Rank.r2.power) {
            // Find all valid consecutive airplane bodies within triplets
            var maxAirplaneLength = 0
            var mainRank = -1
            
            var currentSeq: [Int] = []
            for rank in triplets {
                if currentSeq.isEmpty {
                    currentSeq.append(rank)
                } else if currentSeq.last! + 1 == rank {
                    currentSeq.append(rank)
                } else {
                    if currentSeq.count >= 2 {
                        let wingCount = len - currentSeq.count * 3
                        if wingCount == currentSeq.count * 2 {
                            maxAirplaneLength = max(maxAirplaneLength, currentSeq.count)
                            mainRank = currentSeq.last!
                        }
                    }
                    currentSeq = [rank]
                }
            }
            if currentSeq.count >= 2 {
                let wingCount = len - currentSeq.count * 3
                if wingCount == currentSeq.count * 2 {
                    maxAirplaneLength = max(maxAirplaneLength, currentSeq.count)
                    mainRank = currentSeq.last!
                }
            }
            
            if maxAirplaneLength >= 2 {
                return .init(type: .airplaneWithWings, mainRank: mainRank, length: len, pairCount: 0, tripleCount: maxAirplaneLength, valid: true, reason: "")
            }
        }
        
        // Handle case where some "wings" are actually pairs or triples that happen to be consecutive with the main triplets
        // E.g., 666777888 where 8 is part of the airplane and not a wing
        if len >= 10 { // min length for 2 triplets + 4 wings
            let possibleTriplets = ranks.filter { (groups[$0]?.count ?? 0) >= 3 }
            if possibleTriplets.count >= 2, !possibleTriplets.contains(Rank.r2.power) {
                // Find all consecutive sequences of length >= 2
                var maxAirplaneLength = 0
                var mainRank = -1
                
                var currentSeq: [Int] = []
                for rank in possibleTriplets {
                    if currentSeq.isEmpty {
                        currentSeq.append(rank)
                    } else if currentSeq.last! + 1 == rank {
                        currentSeq.append(rank)
                    } else {
                        if currentSeq.count >= 2 {
                            let airplaneLength = currentSeq.count
                            let wingCount = len - airplaneLength * 3
                            if wingCount == airplaneLength * 2 {
                                maxAirplaneLength = max(maxAirplaneLength, airplaneLength)
                                mainRank = currentSeq.last!
                            }
                        }
                        currentSeq = [rank]
                    }
                }
                
                if currentSeq.count >= 2 {
                    let airplaneLength = currentSeq.count
                    let wingCount = len - airplaneLength * 3
                    if wingCount == airplaneLength * 2 {
                        maxAirplaneLength = max(maxAirplaneLength, airplaneLength)
                        mainRank = currentSeq.last!
                    }
                }
                
                if maxAirplaneLength >= 2 {
                    return .init(type: .airplaneWithWings, mainRank: mainRank, length: len, pairCount: 0, tripleCount: maxAirplaneLength, valid: true, reason: "")
                }
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

    static func chooseLead(
        _ hand: [Card],
        firstTurnMustSpade3: Bool,
        config: RuleConfig = .hunanClassic,
        nextPlayerCardCount: Int = Int.max,
        previousPlayerCardCount: Int = Int.max,
        hasDangerPlayer: Bool = false
    ) -> [Card]? {
        let cards = sort(hand)
        guard !cards.isEmpty else { return nil }
        
        let allPlays = allValidPlays(from: hand, config: config)
        guard !allPlays.isEmpty else { return [cards[0]] }
        
        var validPlays = allPlays
        if firstTurnMustSpade3 {
            validPlays = allPlays.filter { $0.contains(where: { $0.raw == "3S" }) }
            if !cards.contains(where: { $0.rank == .r2 }) {
                let nonSinglePlays = validPlays.filter { detect($0, config: config).type != .single }
                if !nonSinglePlays.isEmpty {
                    validPlays = nonSinglePlays
                }
            }
            if validPlays.isEmpty {
                if let c = cards.first(where: { $0.raw == "3S" }) {
                    return [c]
                }
            }
        }
        
        if nextPlayerCardCount <= 1 || previousPlayerCardCount <= 1 {
            // Under danger, prefer plays that are NOT single.
            let nonSingles = validPlays.filter { detect($0, config: config).type != .single }
            if !nonSingles.isEmpty {
                return nonSingles.min {
                    scoreLeadCandidate($0, hand: hand, config: config, hasDangerPlayer: hasDangerPlayer) < scoreLeadCandidate($1, hand: hand, config: config, hasDangerPlayer: hasDangerPlayer)
                }
            }
            
            // If we MUST play a single, play the HIGHEST single possible.
            let singles = validPlays.filter { detect($0, config: config).type == .single }
            if let highestSingle = singles.max(by: { detect($0, config: config).mainRank < detect($1, config: config).mainRank }) {
                return highestSingle
            }
            if let highest = cards.last { return [highest] }
        }
        
        return validPlays.min {
            scoreLeadCandidate($0, hand: hand, config: config, hasDangerPlayer: hasDangerPlayer) < scoreLeadCandidate($1, hand: hand, config: config, hasDangerPlayer: hasDangerPlayer)
        }
    }

    static func chooseBeat(
        _ hand: [Card],
        topCards: [Card],
        config: RuleConfig = .hunanClassic,
        nextPlayerCardCount: Int = Int.max,
        previousPlayerCardCount: Int = Int.max,
        hasDangerPlayer: Bool = false
    ) -> [Card]? {
        let candidates = beatingCandidates(hand, topCards: topCards, config: config)
        guard !candidates.isEmpty else { return nil }
        let top = detect(topCards, config: config)

        if nextPlayerCardCount <= 1, top.type == .single {
            let sortedHand = sort(hand)
            if let highestSingle = sortedHand.last(where: { card in
                canBeat(detect([card], config: config), top)
            }) {
                return [highestSingle]
            }
        }

        let isDanger = nextPlayerCardCount <= 1 || previousPlayerCardCount <= 1

        return candidates.min {
            scoreBeatCandidate($0, hand: hand, top: top, config: config, isDanger: isDanger, nextCardCount: nextPlayerCardCount, hasDangerPlayer: hasDangerPlayer) < scoreBeatCandidate($1, hand: hand, top: top, config: config, isDanger: isDanger, nextCardCount: nextPlayerCardCount, hasDangerPlayer: hasDangerPlayer)
        }
    }

    static func beatingCandidates(_ hand: [Card], topCards: [Card], config: RuleConfig = .hunanClassic) -> [[Card]] {
        let top = detect(topCards, config: config)
        guard top.valid else { return [] }
        let sortedHand = sort(hand)
        let groups = Dictionary(grouping: sortedHand, by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        var result: [[Card]] = []
        let bombs = bombCandidates(groups: groups, ranks: ranks, top: top)

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
                for wing in preferredSingleWings(from: remaining) {
                    result.append(main + [wing])
                }
            }

        case .tripleWithTwo:
            let tripleRanks = ranks.filter { ($0 > top.mainRank) && ((groups[$0]?.count ?? 0) >= 3) }
            for tr in tripleRanks {
                let main = Array(groups[tr]!.prefix(3))
                let remaining = remove(cards: main, from: sortedHand)
                let wings = preferredTwoCardWings(from: remaining)
                for wing in wings {
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
                for wing in preferredWingCombinations(from: remaining, need: wingNeed) {
                    result.append(main + wing)
                }
            }

        case .bomb:
            result.append(contentsOf: bombs)

        case .invalid:
            break
        }

        if top.type != .bomb {
            if config.bombMustPlay, !bombs.isEmpty, result.isEmpty {
                return uniquePlays(bombs)
            }
            result.append(contentsOf: bombs)
        }

        return uniquePlays(result)
    }

    static func mustPlayBomb(
        hand: [Card],
        topCards: [Card],
        selectedPlay: PlayInfo,
        config: RuleConfig = .hunanClassic
    ) -> Bool {
        guard config.bombMustPlay else { return false }
        guard !topCards.isEmpty else { return false }
        guard selectedPlay.type != .bomb else { return false }

        let candidates = beatingCandidates(hand, topCards: topCards, config: config)
        guard !candidates.isEmpty else { return false }

        let candidateTypes = candidates.map { detect($0, config: config).type }
        return candidateTypes.contains(.bomb) && !candidateTypes.contains { $0 != .bomb }
    }

    static func nextPlayer(_ p: PlayerID) -> PlayerID {
        switch p {
        case .me: return .right
        case .right: return .left
        case .left: return .me
        }
    }

    static func previousPlayer(_ p: PlayerID) -> PlayerID {
        switch p {
        case .me: return .left
        case .right: return .me
        case .left: return .right
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

        var pairs: [([Card], Int)] = []
        for i in 0..<(sortedCards.count - 1) {
            for j in (i + 1)..<sortedCards.count {
                let c1 = sortedCards[i]
                let c2 = sortedCards[j]
                let wing = [c1, c2]
                pairs.append((wing, wingAttachmentPenalty(wingCards: wing, handGroups: groups, remainingCardCount: sortedCards.count - wing.count)))
            }
        }

        pairs.sort {
            if $0.1 != $1.1 { return $0.1 < $1.1 }
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

    private static func preferredWingCombinations(from cards: [Card], need: Int, limit: Int = 80) -> [[Card]] {
        guard need > 0 else { return [[]] }
        let sortedCards = sort(cards)
        guard sortedCards.count >= need else { return [] }
        let groups = Dictionary(grouping: sortedCards, by: { $0.rank.power })

        var combinations: [[Card]] = []
        var current: [Card] = []

        func build(start: Int) {
            if current.count == need {
                combinations.append(current)
                return
            }

            let remainingNeed = need - current.count
            guard sortedCards.count - start >= remainingNeed else { return }

            for index in start..<sortedCards.count {
                current.append(sortedCards[index])
                build(start: index + 1)
                current.removeLast()
            }
        }

        build(start: 0)
        combinations.sort {
            let lhsPenalty = wingAttachmentPenalty(wingCards: $0, handGroups: groups, remainingCardCount: sortedCards.count - $0.count)
            let rhsPenalty = wingAttachmentPenalty(wingCards: $1, handGroups: groups, remainingCardCount: sortedCards.count - $1.count)
            if lhsPenalty != rhsPenalty { return lhsPenalty < rhsPenalty }
            let lhsPower = $0.reduce(0) { $0 + $1.power }
            let rhsPower = $1.reduce(0) { $0 + $1.power }
            return lhsPower < rhsPower
        }

        return uniquePlays(Array(combinations.prefix(limit)))
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

    static func allValidPlays(from hand: [Card], config: RuleConfig) -> [[Card]] {
        var plays: [[Card]] = []
        let sortedHand = sort(hand)
        let groups = Dictionary(grouping: sortedHand, by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        
        // Singles
        for r in ranks { plays.append([groups[r]!.first!]) }
        
        // Pairs
        for r in ranks where groups[r]!.count >= 2 { plays.append(Array(groups[r]!.prefix(2))) }
        
        // Triples
        for r in ranks where groups[r]!.count >= 3 { 
            let main = Array(groups[r]!.prefix(3))
            if config.allowTripleWithoutWing { plays.append(main) }
            
            let remaining = remove(cards: main, from: sortedHand)
            if config.allowTripleWithOne {
                for wing in preferredSingleWings(from: remaining) {
                    plays.append(main + [wing])
                }
            }
            let wings = preferredTwoCardWings(from: remaining)
            for wing in wings {
                if wing.count == 2 {
                    plays.append(main + wing)
                }
            }
        }
        
        // Bombs
        plays.append(contentsOf: bombCandidates(groups: groups, ranks: ranks, top: nil))
        
        // Straights
        let singleRanks = ranks.filter { $0 != Rank.r2.power }
        for len in 5...12 {
            let seqs = consecutiveRankWindows(singleRanks, length: len)
            for seq in seqs {
                let cards = seq.compactMap { groups[$0]?.first }
                if cards.count == len { plays.append(cards) }
            }
        }
        
        // Consecutive Pairs
        let pairRanks = ranks.filter { ($0 != Rank.r2.power) && ((groups[$0]?.count ?? 0) >= 2) }
        for len in 2...10 {
            let seqs = consecutiveRankWindows(pairRanks, length: len)
            for seq in seqs {
                var cards: [Card] = []
                for r in seq { cards.append(contentsOf: Array(groups[r]!.prefix(2))) }
                if cards.count == len * 2 { plays.append(cards) }
            }
        }
        
        // Airplane
        let tripleRanks = ranks.filter { ($0 != Rank.r2.power) && ((groups[$0]?.count ?? 0) >= 3) }
        for len in 2...5 {
            let tripSeqs = consecutiveRankWindows(tripleRanks, length: len)
            for seq in tripSeqs {
                var main: [Card] = []
                for r in seq { main.append(contentsOf: Array(groups[r]!.prefix(3))) }
                let wingNeed = len * 2
                let remaining = remove(cards: main, from: sortedHand)
                for wing in preferredWingCombinations(from: remaining, need: wingNeed) {
                    plays.append(main + wing)
                }
            }
        }
        
        return uniquePlays(plays)
    }

    private static func isEssentialToStraight(rank: Int, handRanks: [Int]) -> Bool {
        guard rank != Rank.r2.power else { return false }
        
        func getStraightRanks(ranks: [Int]) -> Set<Int> {
            var straightRanks = Set<Int>()
            for start in 0...Rank.a.power - 4 {
                var isStraight = true
                for i in 0..<5 {
                    if !ranks.contains(start + i) {
                        isStraight = false
                        break
                    }
                }
                if isStraight {
                    for i in 0..<5 {
                        straightRanks.insert(start + i)
                    }
                }
            }
            return straightRanks
        }
        
        let beforeRanks = getStraightRanks(ranks: handRanks)
        if !beforeRanks.contains(rank) { return false }
        
        let remaining = handRanks.filter { $0 != rank }
        let afterRanks = getStraightRanks(ranks: remaining)
        
        for r in beforeRanks where r != rank {
            if !afterRanks.contains(r) {
                return true
            }
        }
        
        return false
    }

    private static func isPartOfConsecutivePairs(rank: Int, groups: [Int: [Card]]) -> Bool {
        guard rank != Rank.r2.power else { return false }
        for start in max(0, rank - 1)...rank {
            var isConseq = true
            for i in 0..<2 {
                let r = start + i
                if r == Rank.r2.power || (groups[r]?.count ?? 0) < 2 {
                    isConseq = false
                    break
                }
            }
            if isConseq { return true }
        }
        return false
    }

    private static func isPartOfAirplane(rank: Int, groups: [Int: [Card]]) -> Bool {
        guard rank != Rank.r2.power else { return false }
        for start in max(0, rank - 1)...rank {
            var isAirplane = true
            for i in 0..<2 {
                let r = start + i
                if r == Rank.r2.power || (groups[r]?.count ?? 0) < 3 {
                    isAirplane = false
                    break
                }
            }
            if isAirplane { return true }
        }
        return false
    }

    private static func wingCards(in candidate: [Card], play: PlayInfo) -> [Card] {
        var groups = Dictionary(grouping: sort(candidate), by: { $0.rank.power })

        switch play.type {
        case .tripleWithOne, .tripleWithTwo:
            let main = Array((groups[play.mainRank] ?? []).prefix(3))
            return remove(cards: main, from: candidate)

        case .airplaneWithWings:
            guard play.tripleCount > 0 else { return [] }
            let firstRank = play.mainRank - play.tripleCount + 1
            var main: [Card] = []
            for rank in firstRank...play.mainRank {
                let cards = Array((groups[rank] ?? []).prefix(3))
                main.append(contentsOf: cards)
                groups[rank] = Array((groups[rank] ?? []).dropFirst(cards.count))
            }
            return remove(cards: main, from: candidate)

        default:
            return []
        }
    }

    private static func wingAttachmentPenalty(
        wingCards: [Card],
        handGroups: [Int: [Card]],
        remainingCardCount: Int
    ) -> Int {
        guard !wingCards.isEmpty else { return 0 }

        let wingGroups = Dictionary(grouping: wingCards, by: { $0.rank.power })
        var penalty = 0

        for (rank, usedCards) in wingGroups {
            let used = usedCards.count
            let total = handGroups[rank]?.count ?? used

            switch total {
            case 1:
                penalty += rank * 12
            case 2:
                penalty += used == 2 ? 250 + rank * 25 : 2500 + rank * 150
            case 3:
                penalty += used == 3 ? 4500 + rank * 100 : 7000 + rank * 220
            default:
                penalty += 100000
            }

            switch rank {
            case Rank.k.power:
                penalty += used * 250
            case Rank.a.power:
                penalty += used * 700
            case Rank.r2.power:
                penalty += used * 1500
            default:
                break
            }
        }

        if remainingCardCount <= 2 {
            penalty /= 3
        } else if remainingCardCount <= 5 {
            penalty /= 2
        }

        return penalty
    }

    private static func calculateSplitPenalty(
        candidateGroups: [Int: [Card]],
        handGroups: [Int: [Card]],
        handRanks: [Int],
        candidatePlayType: PlayType
    ) -> Int {
        var splitPenalty = 0
        for (rank, candCards) in candidateGroups {
            let used = candCards.count
            let total = handGroups[rank]?.count ?? 0
            let remaining = total - used
            
            if total == 4 && candidatePlayType != .bomb {
                splitPenalty += 100000
            }
            
            if remaining > 0 {
                if total == 3 && candidatePlayType != .triple && candidatePlayType != .tripleWithOne && candidatePlayType != .tripleWithTwo && candidatePlayType != .airplaneWithWings {
                    var triplePenalty = 10000
                    if rank == Rank.a.power { triplePenalty = 80000 }
                    else if rank == Rank.k.power { triplePenalty = 60000 }
                    else if rank == Rank.q.power { triplePenalty = 40000 }
                    else if rank == Rank.j.power { triplePenalty = 20000 }
                    splitPenalty += triplePenalty
                }
                else if total == 2 && candidatePlayType != .pair && candidatePlayType != .consecutivePairs {
                    var pairPenalty = 1000
                    if rank == Rank.r2.power { pairPenalty = 10000 }
                    else if rank == Rank.a.power { pairPenalty = 6000 }
                    else if rank == Rank.k.power { pairPenalty = 3000 }
                    else { pairPenalty = 1000 + rank * 50 }
                    splitPenalty += pairPenalty
                }
            }
            
            // Massive penalties for breaking multi-card structures to protect them over hoarding control cards
            if remaining == 0 {
                if candidatePlayType != .straight && candidatePlayType != .consecutivePairs && candidatePlayType != .airplaneWithWings {
                    if isPartOfAirplane(rank: rank, groups: handGroups) {
                        splitPenalty += 50000
                    } else if total >= 2 && isPartOfConsecutivePairs(rank: rank, groups: handGroups) {
                        splitPenalty += 30000
                    } else if isEssentialToStraight(rank: rank, handRanks: handRanks) {
                        splitPenalty += 20000
                    }
                }
            } else if remaining == 1 {
                if total >= 2 && candidatePlayType != .consecutivePairs && candidatePlayType != .airplaneWithWings {
                    if isPartOfConsecutivePairs(rank: rank, groups: handGroups) {
                        splitPenalty += 30000
                    }
                }
                if total >= 3 && candidatePlayType != .airplaneWithWings {
                    if isPartOfAirplane(rank: rank, groups: handGroups) {
                        splitPenalty += 50000
                    }
                }
            } else if remaining == 2 {
                if total >= 3 && candidatePlayType != .airplaneWithWings {
                    if isPartOfAirplane(rank: rank, groups: handGroups) {
                        splitPenalty += 50000
                    }
                }
            }
        }
        return splitPenalty
    }

    private static func scoreLeadCandidate(_ candidate: [Card], hand: [Card], config: RuleConfig, hasDangerPlayer: Bool) -> Int {
        let play = detect(candidate, config: config)
        let groups = Dictionary(grouping: sort(hand), by: { $0.rank.power })
        let handRanks = Array(groups.keys)
        let candidateGroups = Dictionary(grouping: candidate, by: { $0.rank.power })
        
        let splitPenalty = calculateSplitPenalty(candidateGroups: candidateGroups, handGroups: groups, handRanks: handRanks, candidatePlayType: play.type)
        let wingPenalty = wingAttachmentPenalty(
            wingCards: wingCards(in: candidate, play: play),
            handGroups: groups,
            remainingCardCount: max(0, hand.count - candidate.count)
        )
        
        var lengthReward: Int
        switch play.type {
        case .straight, .consecutivePairs, .airplaneWithWings:
            lengthReward = play.length * 200 // Big reward for long combinations to prevent short-sighted leads
        case .pair:
            lengthReward = play.length * 50
        case .single:
            lengthReward = 0
        case .triple, .tripleWithOne, .tripleWithTwo:
            lengthReward = play.length * 100
        case .bomb:
            lengthReward = 0
        case .invalid:
            lengthReward = 0
        }
        
        var handStrength = 0
        for rank in handRanks {
            if groups[rank]?.count == 4 { handStrength += 50 }
        }
        handStrength += (groups[Rank.r2.power]?.count ?? 0) * 15
        handStrength += (groups[Rank.a.power]?.count ?? 0) * 10
        handStrength += (groups[Rank.k.power]?.count ?? 0) * 6
        handStrength += (groups[Rank.q.power]?.count ?? 0) * 4
        handStrength += (groups[Rank.j.power]?.count ?? 0) * 2
        
        var smallSinglesCount = 0
        for rank in handRanks where rank < Rank.j.power {
            if groups[rank]?.count == 1 && !isEssentialToStraight(rank: rank, handRanks: handRanks) {
                smallSinglesCount += 1
            }
        }
        let triplesCount = handRanks.filter { (groups[$0]?.count ?? 0) == 3 }.count
        
        handStrength -= smallSinglesCount * 5
        let isWeakHand = handStrength < 15
        
        if isWeakHand {
            // Defensive / Disruptive play: force out opponents' big pairs or triples
            if play.type == .consecutivePairs { lengthReward += 400 } // Super high reward for consecutive pairs
            if play.type == .pair && play.mainRank < Rank.j.power { lengthReward += 150 } // Prefer playing small pairs
            if (play.type == .triple || play.type == .tripleWithOne || play.type == .tripleWithTwo || play.type == .airplaneWithWings) && play.mainRank < Rank.j.power {
                lengthReward += 200 // Force out their big triples
            }
            if play.type == .single {
                // Highly discourage leading small singles that don't do any damage when hand is weak
                lengthReward -= 100
            }
        }
        
        // --- COOPERATIVE PLAY AGAINST DANGER PLAYER ---
        // If someone is about to win (hasDangerPlayer), and they passed or it's not their turn yet,
        // we should prioritize playing PAIRS or MULTI-CARD combinations over SINGLES if possible.
        // Even if we play a pair and the other non-danger player beats it, they might lead something 
        // the danger player can't beat.
        if hasDangerPlayer && play.type != .single {
            lengthReward += 500 // Make playing pairs more attractive to not feed danger player singles
        }
        
        // --- BAIT & CONTROL TACTIC ---
        // Active "fishing" strategy: if we hold strong pairs (KK, AA), we should bait opponents
        // by playing small pairs or consecutive pairs to force them to break their structures.
        let hasControlPairs = (groups[Rank.k.power]?.count ?? 0) >= 2 || 
                              (groups[Rank.a.power]?.count ?? 0) >= 2
                              
        let hasAbsoluteControlSingles = (groups[Rank.a.power]?.count ?? 0) >= 1 || 
                                        (groups[Rank.r2.power]?.count ?? 0) >= 1
                                        
        if play.type == .pair && play.mainRank < Rank.k.power {
            if hasControlPairs {
                // Encourage leading small pairs when we have control pairs to take back lead
                lengthReward += 200 
            }
        }
        
        if play.type == .consecutivePairs && play.mainRank < Rank.k.power {
            if hasControlPairs || hasAbsoluteControlSingles {
                // Massive reward for playing small consecutive pairs to force big structure breaks
                lengthReward += 300
            }
        }
        
        // If we have absolute control singles (A or 2), leading a small, useless single is a great way to unload garbage
        // Note: 2 is only a single control, as there is only one 2 in Hunan Paodekuai.
        if play.type == .single && play.mainRank < Rank.j.power && splitPenalty == 0 {
            if hasAbsoluteControlSingles {
                lengthReward += 150
            }
        }
        
        // Strongly discourage leading control singles unless we have to.
        // We should keep them to regain lead after opponents play big cards.
        if play.type == .single && play.mainRank >= Rank.a.power {
            lengthReward -= 200
        }
        
        // --- SINGLE CARD STRATEGY ---
        if play.type == .single {
            if triplesCount > 0 {
                // If we have triples, we don't necessarily play smallest singles. We want to draw out big cards and save small ones for wings.
                if play.mainRank >= Rank.t.power && play.mainRank <= Rank.k.power {
                    lengthReward += 200 // Encourage playing medium/large singles
                } else if play.mainRank < Rank.t.power {
                    lengthReward -= 150 // Discourage playing small singles
                }
            }
        }
        // -----------------------------
        
        let baseScore = play.mainRank * 10 - lengthReward
        let bombPenalty = play.type == .bomb ? 5000 : 0
        
        return baseScore + splitPenalty + wingPenalty + bombPenalty
    }

    private static func scoreBeatCandidate(_ candidate: [Card], hand: [Card], top: PlayInfo, config: RuleConfig, isDanger: Bool, nextCardCount: Int, hasDangerPlayer: Bool) -> Int {
        let groups = Dictionary(grouping: sort(hand), by: { $0.rank.power })
        let handRanks = Array(groups.keys)
        let candidatePlay = detect(candidate, config: config)
        let candidateGroups = Dictionary(grouping: candidate, by: { $0.rank.power })

        let splitPenalty = calculateSplitPenalty(candidateGroups: candidateGroups, handGroups: groups, handRanks: handRanks, candidatePlayType: candidatePlay.type)
        var wingPenalty = wingAttachmentPenalty(
            wingCards: wingCards(in: candidate, play: candidatePlay),
            handGroups: groups,
            remainingCardCount: max(0, hand.count - candidate.count)
        )
        if isDanger {
            wingPenalty /= 2
        }

        // Exponential strategic value to fiercely protect high control cards
        var strategicValue = 0
        switch candidatePlay.mainRank {
        case Rank.t.power: strategicValue = 100
        case Rank.j.power: strategicValue = 200
        case Rank.q.power: strategicValue = 400
        case Rank.k.power: strategicValue = 1000
        case Rank.a.power: strategicValue = 3000
        case Rank.r2.power: strategicValue = 6000
        default: strategicValue = candidatePlay.mainRank * 10
        }
        
        var baseStrength = strategicValue * candidatePlay.length

        var bombPenalty = 0
        if candidatePlay.type == .bomb && top.type != .bomb {
            let isEarlyGame = hand.count > 8 || nextCardCount > 8
            if isEarlyGame && candidatePlay.mainRank < Rank.j.power {
                bombPenalty = 45000 // Huge penalty for small bombs early on
            } else {
                bombPenalty = 25000
            }
        }
        
        // --- COOPERATIVE PLAY AGAINST DANGER PLAYER ---
        // If someone is about to win (hasDangerPlayer), and they passed or it's not their turn yet,
        // we should prioritize playing PAIRS or MULTI-CARD combinations over SINGLES if possible.
        // Even if we play a pair and the other non-danger player beats it, they might lead something 
        // the danger player can't beat.
        if hasDangerPlayer && candidatePlay.type != .single {
            baseStrength -= 1000 // Heavily favor non-single beats when there is a danger player
        }
        
        if isDanger && candidatePlay.type == .single {
            let dangerPenalty = (20 - candidatePlay.mainRank) * 4000
            return dangerPenalty + splitPenalty + wingPenalty + bombPenalty + baseStrength
        }

        return baseStrength + splitPenalty + wingPenalty + bombPenalty
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

struct VoiceLine {
    let clips: [VoiceClip]
    let fallbackText: String
    let language: AppLanguage
    let minimumPlaybackDelay: TimeInterval

    var isEmpty: Bool {
        clips.isEmpty && fallbackText.isEmpty
    }

    init(
        clips: [VoiceClip],
        fallbackText: String,
        language: AppLanguage,
        minimumPlaybackDelay: TimeInterval = 0
    ) {
        self.clips = clips
        self.fallbackText = fallbackText
        self.language = language
        self.minimumPlaybackDelay = minimumPlaybackDelay
    }
}

enum VoiceClip: String, CaseIterable {
    case rank3 = "rank_3"
    case rank4 = "rank_4"
    case rank5 = "rank_5"
    case rank6 = "rank_6"
    case rank7 = "rank_7"
    case rank8 = "rank_8"
    case rank9 = "rank_9"
    case rankT = "rank_t"
    case rankJ = "rank_j"
    case rankQ = "rank_q"
    case rankK = "rank_k"
    case rankA = "rank_a"
    case rank2 = "rank_2"
    case pair3 = "pair_3"
    case pair4 = "pair_4"
    case pair5 = "pair_5"
    case pair6 = "pair_6"
    case pair7 = "pair_7"
    case pair8 = "pair_8"
    case pair9 = "pair_9"
    case pairT = "pair_t"
    case pairJ = "pair_j"
    case pairQ = "pair_q"
    case pairK = "pair_k"
    case pairA = "pair_a"
    case pair2 = "pair_2"
    case bomb3 = "bomb_3"
    case bomb4 = "bomb_4"
    case bomb5 = "bomb_5"
    case bomb6 = "bomb_6"
    case bomb7 = "bomb_7"
    case bomb8 = "bomb_8"
    case bomb9 = "bomb_9"
    case bombT = "bomb_t"
    case bombJ = "bomb_j"
    case bombQ = "bomb_q"
    case bombK = "bomb_k"
    case bombA = "bomb_a"
    case bomb2 = "bomb_2"
    case pairPrefix = "pair_prefix"
    case bombSuffix = "bomb_suffix"
    case straight = "straight"
    case triple = "triple"
    case tripleWithOne = "triple_with_one"
    case tripleWithTwo = "triple_with_two"
    case airplaneWithWings = "airplane_with_wings"
    case airplaneWithWings2 = "airplane_with_wings_2"
    case airplaneWithWings3 = "airplane_with_wings_3"
    case airplaneWithWings4 = "airplane_with_wings_4"
    case airplaneWithWings5 = "airplane_with_wings_5"
    case consecutivePairs = "consecutive_pairs"
    case doublePair = "double_pair"
    case triplePair = "triple_pair"
    case quadruplePair = "quadruple_pair"
    case quintuplePair = "quintuple_pair"
    case sextuplePair = "sextuple_pair"
    case septuplePair = "septuple_pair"
    case declareSingle = "declare_single"
    case pass = "pass"
    case passMe = "pass_me"
    case passLeft = "pass_left"
    case passRight = "pass_right"
    case finishMe = "finish_me"
    case finishLeft = "finish_left"
    case finishRight = "finish_right"
}

enum VoiceTextBuilder {
    static func playLine(for cards: [Card], play: PlayInfo, language: AppLanguage = L10n.currentLanguage()) -> VoiceLine {
        VoiceLine(
            clips: playClips(for: cards, play: play, language: language),
            fallbackText: playText(for: cards, play: play, language: language),
            language: language,
            minimumPlaybackDelay: minimumPlaybackDelay(for: play)
        )
    }

    static func declareSingleLine(language: AppLanguage = L10n.currentLanguage()) -> VoiceLine {
        VoiceLine(
            clips: [.declareSingle],
            fallbackText: L10n.text("voice_declare_single", language: language),
            language: language
        )
    }

    static func cannotBeatLine(player: PlayerID, playerName: String, language: AppLanguage = L10n.currentLanguage()) -> VoiceLine {
        VoiceLine(
            clips: [language == .en ? .passLeft : .pass],
            fallbackText: L10n.format("voice_player_cannot_beat_format", language: language, playerName),
            language: language
        )
    }

    static func roundFinishLine(winner: PlayerID, playerName: String, language: AppLanguage = L10n.currentLanguage()) -> VoiceLine {
        VoiceLine(
            clips: [finishClip(for: winner)],
            fallbackText: L10n.format("speech_round_finish_format", language: language, playerName),
            language: language
        )
    }

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

    private static func playClips(for cards: [Card], play: PlayInfo, language: AppLanguage) -> [VoiceClip] {
        guard play.valid else { return [] }
        switch play.type {
        case .single:
            return rankClip(cards.first?.rank).map { [$0] } ?? []
        case .pair:
            return pairClip(cards.first?.rank).map { [$0] } ?? []
        case .triple:
            return [.triple]
        case .tripleWithOne:
            return [.tripleWithOne]
        case .bomb:
            return bombClip(cards.first?.rank).map { [$0] } ?? []
        case .straight:
            return [.straight]
        case .tripleWithTwo:
            return [.tripleWithTwo]
        case .airplaneWithWings:
            return airplaneClip(tripleCount: play.tripleCount)
        case .consecutivePairs:
            return consecutivePairClip(pairCount: play.pairCount, language: language)
        case .invalid:
            return []
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

    private static func rankClip(_ rank: Rank?) -> VoiceClip? {
        guard let rank else { return nil }
        switch rank {
        case .r3: return .rank3
        case .r4: return .rank4
        case .r5: return .rank5
        case .r6: return .rank6
        case .r7: return .rank7
        case .r8: return .rank8
        case .r9: return .rank9
        case .t: return .rankT
        case .j: return .rankJ
        case .q: return .rankQ
        case .k: return .rankK
        case .a: return .rankA
        case .r2: return .rank2
        }
    }

    private static func pairClip(_ rank: Rank?) -> VoiceClip? {
        guard let rank else { return nil }
        switch rank {
        case .r3: return .pair3
        case .r4: return .pair4
        case .r5: return .pair5
        case .r6: return .pair6
        case .r7: return .pair7
        case .r8: return .pair8
        case .r9: return .pair9
        case .t: return .pairT
        case .j: return .pairJ
        case .q: return .pairQ
        case .k: return .pairK
        case .a: return .pairA
        case .r2: return .pair2
        }
    }

    private static func bombClip(_ rank: Rank?) -> VoiceClip? {
        guard let rank else { return nil }
        switch rank {
        case .r3: return .bomb3
        case .r4: return .bomb4
        case .r5: return .bomb5
        case .r6: return .bomb6
        case .r7: return .bomb7
        case .r8: return .bomb8
        case .r9: return .bomb9
        case .t: return .bombT
        case .j: return .bombJ
        case .q: return .bombQ
        case .k: return .bombK
        case .a: return .bombA
        case .r2: return .bomb2
        }
    }

    private static func airplaneClip(tripleCount: Int) -> [VoiceClip] {
        switch tripleCount {
        case 2: return [.airplaneWithWings2]
        case 3: return [.airplaneWithWings3]
        case 4: return [.airplaneWithWings4]
        case 5: return [.airplaneWithWings5]
        default: return [.airplaneWithWings]
        }
    }

    private static func consecutivePairClip(pairCount: Int, language: AppLanguage) -> [VoiceClip] {
        if language == .zhHans {
            return [.consecutivePairs]
        }
        switch pairCount {
        case 2: return [.doublePair]
        case 3: return [.triplePair]
        case 4: return [.quadruplePair]
        case 5: return [.quintuplePair]
        case 6: return [.sextuplePair]
        case 7: return [.septuplePair]
        default: return [.consecutivePairs]
        }
    }

    private static func minimumPlaybackDelay(for play: PlayInfo) -> TimeInterval {
        switch play.type {
        case .bomb:
            return 1.6
        case .airplaneWithWings:
            return 2.5
        default:
            return 0
        }
    }

    private static func finishClip(for player: PlayerID) -> VoiceClip {
        switch player {
        case .me: return .finishMe
        case .left: return .finishLeft
        case .right: return .finishRight
        }
    }
}
