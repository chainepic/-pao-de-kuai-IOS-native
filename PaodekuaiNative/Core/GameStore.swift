import Foundation
import Combine
import SwiftUI

struct RoundResult: Codable, Identifiable {
    let handNo: Int
    let winner: PlayerID
    let deltaMe: Int
    let deltaLeft: Int
    let deltaRight: Int
    let remainMe: Int
    let remainLeft: Int
    let remainRight: Int
    let bombMe: Int
    let bombLeft: Int
    let bombRight: Int

    var id: Int { handNo }
}

struct PersistedGameState: Codable {
    var handCards: [Card]
    var leftCards: [Card]
    var rightCards: [Card]
    var topCards: [Card]
    var selectedIDs: [String]
    var currentTurn: PlayerID
    var topOwner: PlayerID?
    var passCount: Int
    var handNo: Int
    var scores: [String: Int]
    var isFirstLeadTurn: Bool
    var gameFinished: Bool
    var roundResults: [RoundResult]
    var ruleConfig: RuleConfig
    var bombCounts: [String: Int]

    enum CodingKeys: String, CodingKey {
        case handCards
        case leftCards
        case rightCards
        case topCards
        case selectedIDs
        case currentTurn
        case topOwner
        case passCount
        case handNo
        case scores
        case isFirstLeadTurn
        case gameFinished
        case roundResults
        case ruleConfig
        case bombCounts
    }

    init(
        handCards: [Card],
        leftCards: [Card],
        rightCards: [Card],
        topCards: [Card],
        selectedIDs: [String],
        currentTurn: PlayerID,
        topOwner: PlayerID?,
        passCount: Int,
        handNo: Int,
        scores: [String: Int],
        isFirstLeadTurn: Bool,
        gameFinished: Bool,
        roundResults: [RoundResult],
        ruleConfig: RuleConfig,
        bombCounts: [String: Int]
    ) {
        self.handCards = handCards
        self.leftCards = leftCards
        self.rightCards = rightCards
        self.topCards = topCards
        self.selectedIDs = selectedIDs
        self.currentTurn = currentTurn
        self.topOwner = topOwner
        self.passCount = passCount
        self.handNo = handNo
        self.scores = scores
        self.isFirstLeadTurn = isFirstLeadTurn
        self.gameFinished = gameFinished
        self.roundResults = roundResults
        self.ruleConfig = ruleConfig
        self.bombCounts = bombCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handCards = try container.decode([Card].self, forKey: .handCards)
        leftCards = try container.decode([Card].self, forKey: .leftCards)
        rightCards = try container.decode([Card].self, forKey: .rightCards)
        topCards = try container.decode([Card].self, forKey: .topCards)
        selectedIDs = try container.decode([String].self, forKey: .selectedIDs)
        currentTurn = try container.decode(PlayerID.self, forKey: .currentTurn)
        topOwner = try container.decodeIfPresent(PlayerID.self, forKey: .topOwner)
        passCount = try container.decode(Int.self, forKey: .passCount)
        handNo = try container.decode(Int.self, forKey: .handNo)
        scores = try container.decode([String: Int].self, forKey: .scores)
        isFirstLeadTurn = try container.decode(Bool.self, forKey: .isFirstLeadTurn)
        gameFinished = try container.decode(Bool.self, forKey: .gameFinished)
        roundResults = try container.decodeIfPresent([RoundResult].self, forKey: .roundResults) ?? []
        ruleConfig = try container.decodeIfPresent(RuleConfig.self, forKey: .ruleConfig) ?? .hunanClassic
        bombCounts = try container.decodeIfPresent([String: Int].self, forKey: .bombCounts) ?? [:]
    }
}

final class PersistenceService {
    private let key = "paodekuai.native.v1.state"

    func save(_ state: PersistedGameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> PersistedGameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedGameState.self, from: data)
    }
}

@MainActor
final class GameStore: ObservableObject {
    @Published var handCards: [Card] = []
    @Published var leftCards: [Card] = []
    @Published var rightCards: [Card] = []
    @Published var topCards: [Card] = []
    @Published var selected: Set<String> = []
    @Published var currentTurn: PlayerID = .me
    @Published var topOwner: PlayerID?
    @Published var passCount = 0
    @Published var handNo = 1
    @Published var scoreMe = 0
    @Published var scoreLeft = 0
    @Published var scoreRight = 0
    @Published var isFirstLeadTurn = true
    @Published var gameFinished = false
    @Published var hint = L10n.text("hint_tap_new_game")
    @Published var roundResults: [RoundResult] = []
    @Published var ruleConfig: RuleConfig = .hunanClassic
    @Published var showWelcomeScreen = true
    @Published var isVoiceEnabled = SpeechService.isEnabled

    private let persistence = PersistenceService()
    private var passCycleTopKey = ""
    private var passCycleCandidates: [[Card]] = []
    private var passCycleIndex = -1
    private var bombCountMe = 0
    private var bombCountLeft = 0
    private var bombCountRight = 0

    func bootstrap() {
        isVoiceEnabled = SpeechService.isEnabled

        if let state = persistence.load() {
            apply(state)
        } else {
            newGame()
        }
    }

    func newGame() {
        let deal = PaodekuaiRules.deal16x3()
        handCards = deal.me
        leftCards = deal.left
        rightCards = deal.right
        topCards = []
        selected = []
        passCount = 0
        isFirstLeadTurn = true
        gameFinished = false
        topOwner = nil
        bombCountMe = 0
        bombCountLeft = 0
        bombCountRight = 0
        clearPassCycle()
        currentTurn = handCards.contains(where: { $0.raw == "3S" }) ? .me : (leftCards.contains(where: { $0.raw == "3S" }) ? .left : .right)
        hint = L10n.format("hint_new_round_first_format", name(currentTurn))
        save()
        runAiIfNeeded()
    }

    func toggle(_ card: Card) {
        guard currentTurn == .me, !gameFinished else { return }
        clearPassCycle()
        if selected.contains(card.id) {
            selected.remove(card.id)
        } else {
            selected.insert(card.id)
        }
        save()
    }

    func pass() {
        guard currentTurn == .me, !gameFinished else { return }
        if topCards.isEmpty {
            hint = L10n.text("hint_first_lead_no_pass")
            return
        }
        let beatCandidates = PaodekuaiRules.beatingCandidates(handCards, topCards: topCards, config: ruleConfig)
        if !beatCandidates.isEmpty {
            cycleForcedSelection(candidates: beatCandidates)
            return
        }
        clearPassCycle()
        
        applyPass(player: .me)
        runAiIfNeeded()
    }

    func playSelected() {
        guard currentTurn == .me, !gameFinished else { return }
        let cards = handCards.filter { selected.contains($0.id) }
        let picked = PaodekuaiRules.sort(cards)
        let play = PaodekuaiRules.detect(picked, config: ruleConfig)
        if !play.valid {
            hint = play.reason
            return
        }

        if ruleConfig.bombMustPlay, play.type != .bomb, hasBombToPlay(handCards, topCards: topCards) {
            hint = L10n.text("hint_bomb_must_play")
            return
        }

        if isFirstLeadTurn, handNo == 1, handCards.contains(where: { $0.raw == "3S" }), !picked.contains(where: { $0.raw == "3S" }) {
            hint = L10n.text("hint_first_turn_need_3s")
            return
        }

        let top = topCards.isEmpty ? nil : PaodekuaiRules.detect(topCards, config: ruleConfig)
        if !PaodekuaiRules.canBeat(play, top) {
            hint = L10n.text("hint_cannot_beat_top")
            return
        }

        clearPassCycle()
        
        applyPlay(player: .me, cards: picked, play: play)
        runAiIfNeeded()
    }

    private func applyPlay(player: PlayerID, cards: [Card], play: PlayInfo) {
        setCards(player, PaodekuaiRules.remove(cards: cards, from: getCards(player)))
        topCards = PaodekuaiRules.sort(cards)
        topOwner = player
        passCount = 0
        isFirstLeadTurn = false
        selected = []
        clearPassCycle()
        incrementBombCountIfNeeded(player: player, play: play)
        hint = L10n.format("hint_played_cards_format", name(player), cards.map(\.raw).joined(separator: " "))
        SpeechService.speak(VoiceTextBuilder.playText(for: cards, play: play, language: L10n.currentLanguage()))

        if getCards(player).isEmpty {
            finishRound(winner: player)
            return
        }

        currentTurn = PaodekuaiRules.nextPlayer(player)
        save()
    }

    private func applyPass(player: PlayerID) {
        clearPassCycle()
        passCount += 1
        SpeechService.speak(L10n.format("voice_player_cannot_beat_format", name(player)))
        if passCount >= 2, let owner = topOwner {
            currentTurn = owner
            topCards = []
            topOwner = nil
            passCount = 0
            hint = L10n.format("hint_two_pass_reset_format", name(owner))
        } else {
            currentTurn = PaodekuaiRules.nextPlayer(player)
            hint = L10n.format("hint_player_pass_format", name(player))
        }
        save()
    }

    private func finishRound(winner: PlayerID) {
        gameFinished = true
        let remainMe = handCards.count
        let remainLeft = leftCards.count
        let remainRight = rightCards.count

        let pMe = winner == .me ? 0 : loserPenalty(remainMe)
        let pLeft = winner == .left ? 0 : loserPenalty(remainLeft)
        let pRight = winner == .right ? 0 : loserPenalty(remainRight)
        let gain = pMe + pLeft + pRight

        scoreMe += winner == .me ? gain : -pMe
        scoreLeft += winner == .left ? gain : -pLeft
        scoreRight += winner == .right ? gain : -pRight

        let result = RoundResult(
            handNo: handNo,
            winner: winner,
            deltaMe: winner == .me ? gain : -pMe,
            deltaLeft: winner == .left ? gain : -pLeft,
            deltaRight: winner == .right ? gain : -pRight,
            remainMe: remainMe,
            remainLeft: remainLeft,
            remainRight: remainRight,
            bombMe: bombCountMe,
            bombLeft: bombCountLeft,
            bombRight: bombCountRight
        )
        roundResults.append(result)
        if roundResults.count > 10 {
            roundResults = Array(roundResults.suffix(10))
        }

        hint = L10n.format("hint_round_finish_format", name(winner))
        SpeechService.speak(buildRoundFinishSpeech(result))
        handNo += 1
        save()
    }

    private func runAiIfNeeded() {
        guard !gameFinished, currentTurn != .me else {
            save()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !self.gameFinished, self.currentTurn != .me else { return }
            self.aiStep()
        }
    }

    private func aiStep() {
        let actor = currentTurn
        let cards = getCards(actor)
        let picked: [Card]? = topCards.isEmpty
            ? PaodekuaiRules.chooseLead(cards, firstTurnMustSpade3: isFirstLeadTurn && handNo == 1, config: ruleConfig)
            : PaodekuaiRules.chooseBeat(cards, topCards: topCards, config: ruleConfig)

        if let picked {
            applyPlay(player: actor, cards: picked, play: PaodekuaiRules.detect(picked, config: ruleConfig))
        } else {
            applyPass(player: actor)
        }
        runAiIfNeeded()
    }

    private func loserPenalty(_ remain: Int) -> Int {
        if remain <= 1 { return 0 }
        if remain == 16 { return 30 }
        if remain == 15 { return 15 }
        return remain
    }

    private func getCards(_ player: PlayerID) -> [Card] {
        switch player {
        case .me: return handCards
        case .left: return leftCards
        case .right: return rightCards
        }
    }

    private func setCards(_ player: PlayerID, _ cards: [Card]) {
        switch player {
        case .me: handCards = PaodekuaiRules.sort(cards)
        case .left: leftCards = PaodekuaiRules.sort(cards)
        case .right: rightCards = PaodekuaiRules.sort(cards)
        }
    }

    private func save() {
        persistence.save(
            .init(
                handCards: handCards,
                leftCards: leftCards,
                rightCards: rightCards,
                topCards: topCards,
                selectedIDs: Array(selected),
                currentTurn: currentTurn,
                topOwner: topOwner,
                passCount: passCount,
                handNo: handNo,
                scores: ["me": scoreMe, "left": scoreLeft, "right": scoreRight],
                isFirstLeadTurn: isFirstLeadTurn,
                gameFinished: gameFinished,
                roundResults: roundResults,
                ruleConfig: ruleConfig,
                bombCounts: ["me": bombCountMe, "left": bombCountLeft, "right": bombCountRight]
            )
        )
    }

    private func apply(_ state: PersistedGameState) {
        handCards = state.handCards
        leftCards = state.leftCards
        rightCards = state.rightCards
        topCards = state.topCards
        selected = Set(state.selectedIDs)
        currentTurn = state.currentTurn
        topOwner = state.topOwner
        passCount = state.passCount
        handNo = state.handNo
        scoreMe = state.scores["me", default: 0]
        scoreLeft = state.scores["left", default: 0]
        scoreRight = state.scores["right", default: 0]
        isFirstLeadTurn = state.isFirstLeadTurn
        gameFinished = state.gameFinished
        roundResults = state.roundResults
        ruleConfig = state.ruleConfig
        bombCountMe = state.bombCounts["me", default: 0]
        bombCountLeft = state.bombCounts["left", default: 0]
        bombCountRight = state.bombCounts["right", default: 0]
        hint = L10n.text("hint_restored_local_state")
    }

    func refreshLocalizedHintForCurrentState() {
        if gameFinished, let last = roundResults.last {
            hint = L10n.format("hint_round_finish_format", name(last.winner))
            return
        }
        if currentTurn == .me {
            if topCards.isEmpty {
                hint = L10n.format("hint_new_round_first_format", name(currentTurn))
            } else {
                hint = L10n.text("hint_action_ready")
            }
            return
        }
        hint = L10n.format("hint_waiting_player_format", name(currentTurn))
    }

    func name(_ p: PlayerID) -> String {
        switch p {
        case .me: return L10n.text("player_me")
        case .left: return L10n.text("player_left")
        case .right: return L10n.text("player_right")
        }
    }

    func formatRoundResult(_ item: RoundResult) -> String {
        L10n.format(
            "round_result_line_format",
            item.handNo,
            name(item.winner),
            item.deltaMe,
            item.deltaLeft,
            item.deltaRight
        )
    }

    func setRulePreset(_ preset: RulePreset) {
        if preset == .custom { return }
        ruleConfig = RuleConfig.presetValue(preset)
        save()
    }

    func setAllowTripleWithOne(_ enabled: Bool) {
        ruleConfig.allowTripleWithOne = enabled
        ruleConfig.preset = .custom
        save()
    }

    func setAllowTripleWithoutWing(_ enabled: Bool) {
        ruleConfig.allowTripleWithoutWing = enabled
        ruleConfig.preset = .custom
        save()
    }

    func setBombMustPlay(_ enabled: Bool) {
        ruleConfig.bombMustPlay = enabled
        ruleConfig.preset = .custom
        save()
    }

    func beginManualSelection() {
        clearPassCycle()
    }

    func applyDragSelection(card: Card, selecting: Bool) {
        if selecting {
            selected.insert(card.id)
        } else {
            selected.remove(card.id)
        }
    }

    func endManualSelection() {
        if currentTurn == .me, !gameFinished, !topCards.isEmpty {
            hint = L10n.text("hint_action_ready")
        }
        save()
    }

    private func cycleForcedSelection(candidates: [[Card]]) {
        let topKey = cardsKey(topCards)
        let candidateKeys = candidates.map(cardsKey)
        let currentKeys = passCycleCandidates.map(cardsKey)
        let shouldReset = topKey != passCycleTopKey || candidateKeys != currentKeys

        if shouldReset {
            passCycleTopKey = topKey
            passCycleCandidates = candidates
            passCycleIndex = 0
        } else {
            passCycleIndex = (passCycleIndex + 1) % max(1, passCycleCandidates.count)
        }

        guard passCycleCandidates.indices.contains(passCycleIndex) else { return }
        selected = Set(passCycleCandidates[passCycleIndex].map(\.id))
        hint = L10n.format("hint_must_beat_cycle_format", passCycleIndex + 1, passCycleCandidates.count)
        save()
    }

    private func clearPassCycle() {
        passCycleTopKey = ""
        passCycleCandidates = []
        passCycleIndex = -1
    }

    private func cardsKey(_ cards: [Card]) -> String {
        PaodekuaiRules.sort(cards).map(\.raw).joined(separator: "|")
    }

    private func hasBombToPlay(_ hand: [Card], topCards: [Card]) -> Bool {
        let top = topCards.isEmpty ? nil : PaodekuaiRules.detect(topCards, config: ruleConfig)
        return !bombCandidates(in: hand, top: top).isEmpty
    }

    private func bombCandidates(in hand: [Card], top: PlayInfo?) -> [[Card]] {
        let groups = Dictionary(grouping: PaodekuaiRules.sort(hand), by: { $0.rank.power })
        let ranks = groups.keys.sorted()
        let isTopBomb = top?.type == .bomb
        let topRank = top?.mainRank ?? -1
        var result: [[Card]] = []
        for r in ranks where (groups[r]?.count ?? 0) >= 4 {
            if !isTopBomb || r > topRank {
                result.append(Array(groups[r]!.prefix(4)))
            }
        }
        return result
    }

    private func incrementBombCountIfNeeded(player: PlayerID, play: PlayInfo) {
        guard play.type == .bomb else { return }
        switch player {
        case .me: bombCountMe += 1
        case .left: bombCountLeft += 1
        case .right: bombCountRight += 1
        }
    }

    private func buildRoundFinishSpeech(_ result: RoundResult) -> String {
        let others = PlayerID.allCases.filter { $0 != result.winner }
        guard others.count == 2 else { return "" }
        let firstLose = others[0]
        let secondLose = others[1]
        let remainFirst = remainCount(for: firstLose, result: result)
        let remainSecond = remainCount(for: secondLose, result: result)
        let deltaFirst = deltaScore(for: firstLose, result: result)
        let deltaSecond = deltaScore(for: secondLose, result: result)
        let bombFirst = bombCount(for: firstLose, result: result)
        let bombSecond = bombCount(for: secondLose, result: result)
        var bombPart = ""
        let bombChunks: [String] = [
            result.bombMe > 0 ? L10n.format("speech_bomb_item_format", name(.me), result.bombMe) : "",
            bombFirst > 0 ? L10n.format("speech_bomb_item_format", name(firstLose), bombFirst) : "",
            bombSecond > 0 ? L10n.format("speech_bomb_item_format", name(secondLose), bombSecond) : ""
        ].filter { !$0.isEmpty }
        if !bombChunks.isEmpty {
            bombPart = L10n.format("speech_bomb_prefix_format", bombChunks.joined(separator: "，"))
        }
        return L10n.format(
            "speech_round_finish_format",
            name(result.winner),
            name(firstLose),
            remainFirst,
            name(secondLose),
            remainSecond,
            bombPart,
            name(.me),
            result.deltaMe,
            name(firstLose),
            deltaFirst,
            name(secondLose),
            deltaSecond
        )
    }

    private func remainCount(for player: PlayerID, result: RoundResult) -> Int {
        switch player {
        case .me: return result.remainMe
        case .left: return result.remainLeft
        case .right: return result.remainRight
        }
    }

    private func deltaScore(for player: PlayerID, result: RoundResult) -> Int {
        switch player {
        case .me: return result.deltaMe
        case .left: return result.deltaLeft
        case .right: return result.deltaRight
        }
    }

    private func bombCount(for player: PlayerID, result: RoundResult) -> Int {
        switch player {
        case .me: return result.bombMe
        case .left: return result.bombLeft
        case .right: return result.bombRight
        }
    }

}
