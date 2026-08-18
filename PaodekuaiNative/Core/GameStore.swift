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
    let bombedMe: Int
    let bombedLeft: Int
    let bombedRight: Int

    var id: Int { handNo }

    enum CodingKeys: String, CodingKey {
        case handNo, winner, deltaMe, deltaLeft, deltaRight
        case remainMe, remainLeft, remainRight
        case bombMe, bombLeft, bombRight
        case bombedMe, bombedLeft, bombedRight
    }

    init(
        handNo: Int,
        winner: PlayerID,
        deltaMe: Int,
        deltaLeft: Int,
        deltaRight: Int,
        remainMe: Int,
        remainLeft: Int,
        remainRight: Int,
        bombMe: Int,
        bombLeft: Int,
        bombRight: Int,
        bombedMe: Int,
        bombedLeft: Int,
        bombedRight: Int
    ) {
        self.handNo = handNo
        self.winner = winner
        self.deltaMe = deltaMe
        self.deltaLeft = deltaLeft
        self.deltaRight = deltaRight
        self.remainMe = remainMe
        self.remainLeft = remainLeft
        self.remainRight = remainRight
        self.bombMe = bombMe
        self.bombLeft = bombLeft
        self.bombRight = bombRight
        self.bombedMe = bombedMe
        self.bombedLeft = bombedLeft
        self.bombedRight = bombedRight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        handNo = try c.decode(Int.self, forKey: .handNo)
        winner = try c.decode(PlayerID.self, forKey: .winner)
        deltaMe = try c.decode(Int.self, forKey: .deltaMe)
        deltaLeft = try c.decode(Int.self, forKey: .deltaLeft)
        deltaRight = try c.decode(Int.self, forKey: .deltaRight)
        remainMe = try c.decode(Int.self, forKey: .remainMe)
        remainLeft = try c.decode(Int.self, forKey: .remainLeft)
        remainRight = try c.decode(Int.self, forKey: .remainRight)
        bombMe = try c.decodeIfPresent(Int.self, forKey: .bombMe) ?? 0
        bombLeft = try c.decodeIfPresent(Int.self, forKey: .bombLeft) ?? 0
        bombRight = try c.decodeIfPresent(Int.self, forKey: .bombRight) ?? 0
        bombedMe = try c.decodeIfPresent(Int.self, forKey: .bombedMe) ?? 0
        bombedLeft = try c.decodeIfPresent(Int.self, forKey: .bombedLeft) ?? 0
        bombedRight = try c.decodeIfPresent(Int.self, forKey: .bombedRight) ?? 0
    }
}

struct SpecialPlayEffect: Identifiable, Equatable {
    enum Kind: Equatable {
        case bomb
        case airplane
    }

    let id = UUID()
    let kind: Kind
}

enum MoveAction: String, Codable {
    case play
    case pass
}

struct MoveRecord: Codable, Identifiable {
    let seq: Int
    let handNo: Int
    let player: PlayerID
    let action: MoveAction
    let cards: [String]
    let reason: String?

    var id: Int { seq }
}

struct AITuningConfig: Codable {
    var dangerCardThreshold: Int
    var avoidBombTurnThreshold: Int
    var maxHistoryToPersist: Int

    static let `default` = AITuningConfig(
        dangerCardThreshold: 2,
        avoidBombTurnThreshold: 2,
        maxHistoryToPersist: 500
    )
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
    var moveRecords: [MoveRecord]
    var nextMoveSeq: Int
    var aiTuning: AITuningConfig
    var ruleConfig: RuleConfig
    var bombCounts: [String: Int]
    var bombedCounts: [String: Int]
    var handBombDeltas: [String: Int]
    var pendingBombOwner: PlayerID?
    var pendingBombRank: Int?
    var hasDeclaredSingle: Bool

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
        case moveRecords
        case nextMoveSeq
        case aiTuning
        case ruleConfig
        case bombCounts
        case bombedCounts
        case handBombDeltas
        case pendingBombOwner
        case pendingBombRank
        case hasDeclaredSingle
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
        moveRecords: [MoveRecord],
        nextMoveSeq: Int,
        aiTuning: AITuningConfig,
        ruleConfig: RuleConfig,
        bombCounts: [String: Int],
        bombedCounts: [String: Int],
        handBombDeltas: [String: Int],
        pendingBombOwner: PlayerID?,
        pendingBombRank: Int?,
        hasDeclaredSingle: Bool = false
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
        self.moveRecords = moveRecords
        self.nextMoveSeq = nextMoveSeq
        self.aiTuning = aiTuning
        self.ruleConfig = ruleConfig
        self.bombCounts = bombCounts
        self.bombedCounts = bombedCounts
        self.handBombDeltas = handBombDeltas
        self.pendingBombOwner = pendingBombOwner
        self.pendingBombRank = pendingBombRank
        self.hasDeclaredSingle = hasDeclaredSingle
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
        moveRecords = try container.decodeIfPresent([MoveRecord].self, forKey: .moveRecords) ?? []
        nextMoveSeq = try container.decodeIfPresent(Int.self, forKey: .nextMoveSeq) ?? ((moveRecords.last?.seq ?? 0) + 1)
        aiTuning = try container.decodeIfPresent(AITuningConfig.self, forKey: .aiTuning) ?? .default
        ruleConfig = try container.decodeIfPresent(RuleConfig.self, forKey: .ruleConfig) ?? .hunanClassic
        bombCounts = try container.decodeIfPresent([String: Int].self, forKey: .bombCounts) ?? [:]
        bombedCounts = try container.decodeIfPresent([String: Int].self, forKey: .bombedCounts) ?? [:]
        handBombDeltas = try container.decodeIfPresent([String: Int].self, forKey: .handBombDeltas) ?? [:]
        pendingBombOwner = try container.decodeIfPresent(PlayerID.self, forKey: .pendingBombOwner)
        pendingBombRank = try container.decodeIfPresent(Int.self, forKey: .pendingBombRank)
        hasDeclaredSingle = try container.decodeIfPresent(Bool.self, forKey: .hasDeclaredSingle) ?? false
    }
}

final class PersistenceService {
    private let key = "paodekuai.native.v1.state"
    private let saveQueue = DispatchQueue(label: "com.paodekuai.persistence.save", qos: .utility)

    func save(_ state: PersistedGameState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        saveQueue.async { [key, data] in
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> PersistedGameState? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PersistedGameState.self, from: data)
    }
}

final class GameLogExporter {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let ioQueue = DispatchQueue(label: "com.paodekuai.logs.io", qos: .utility)

    struct GameLogPayload: Codable {
        let generatedAt: Date
        let handNo: Int
        let scoreMe: Int
        let scoreLeft: Int
        let scoreRight: Int
        let aiTuning: AITuningConfig
        let roundResults: [RoundResult]
        let moveRecords: [MoveRecord]
    }

    struct SelfPlaySummary: Codable {
        struct PlayerSummary: Codable {
            let wins: Int
            let score: Int
            let bombsPlayed: Int
            let bombedCount: Int
        }

        let generatedAt: Date
        let hands: Int
        let config: RuleConfig
        let playerMe: PlayerSummary
        let playerLeft: PlayerSummary
        let playerRight: PlayerSummary
    }

    struct SelfPlayHandLog: Codable {
        struct SelfPlayMoveLog: Codable {
            struct StateSnapshot: Codable {
                let topCards: [String]
                let topOwner: PlayerID?
                let handCount: Int
                let nextHandCount: Int
                let previousHandCount: Int
                let legalActionCount: Int
                let legalActionCountEstimated: Bool
                let forcedBombRuleTriggered: Bool
            }

            let seq: Int
            let handNo: Int
            let player: PlayerID
            let action: MoveAction
            let cards: [String]
            let reason: String?
            let chosenPlayType: PlayType?
            let snapshot: StateSnapshot
        }

        let handNo: Int
        let firstTurnPlayer: PlayerID
        let initialMe: [String]
        let initialLeft: [String]
        let initialRight: [String]
        let moves: [SelfPlayMoveLog]
        let winner: PlayerID
        let remainMe: Int
        let remainLeft: Int
        let remainRight: Int
        let deltaMe: Int
        let deltaLeft: Int
        let deltaRight: Int
        let cumulativeScoreMe: Int
        let cumulativeScoreLeft: Int
        let cumulativeScoreRight: Int
        let bombMe: Int
        let bombLeft: Int
        let bombRight: Int
        let bombedMe: Int
        let bombedLeft: Int
        let bombedRight: Int
    }

    struct SelfPlayDetailPayload: Codable {
        let generatedAt: Date
        let hands: Int
        let config: RuleConfig
        let aiTuning: AITuningConfig
        let summary: SelfPlaySummary
        let handLogs: [SelfPlayHandLog]
    }

    private func logsDirectoryURL() -> URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docs.appendingPathComponent("paodekuai_logs", isDirectory: true)
    }

    func selfPlaySummaryURL() -> URL? {
        guard let dir = logsDirectoryURL() else { return nil }
        let url = dir.appendingPathComponent("selfplay-summary.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func latestGameLogURL() -> URL? {
        guard let dir = logsDirectoryURL() else { return nil }
        let url = dir.appendingPathComponent("latest-game-log.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func selfPlayDetailURL() -> URL? {
        guard let dir = logsDirectoryURL() else { return nil }
        let url = dir.appendingPathComponent("selfplay-detail.json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func export(payload: GameLogPayload) {
        guard let data = try? encoder.encode(payload) else { return }
        ioQueue.async { [weak self, data] in
            guard let self else { return }
            guard let dir = self.logsDirectoryURL() else { return }
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let latestURL = dir.appendingPathComponent("latest-game-log.json")
                try data.write(to: latestURL, options: .atomic)
            } catch {
                // Keep game loop stable even if file writing fails.
                print("Failed to export game logs: \(error)")
            }
        }
    }

    func exportSelfPlaySummary(_ summary: SelfPlaySummary) -> String? {
        do {
            guard let dir = logsDirectoryURL() else { return nil }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let latestURL = dir.appendingPathComponent("selfplay-summary.json")
            let data = try encoder.encode(summary)
            try data.write(to: latestURL, options: .atomic)
            return latestURL.path
        } catch {
            print("Failed to export self-play summary: \(error)")
            return nil
        }
    }

    func exportSelfPlayDetail(_ payload: SelfPlayDetailPayload) -> String? {
        do {
            guard let dir = logsDirectoryURL() else { return nil }
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let detailURL = dir.appendingPathComponent("selfplay-detail.json")
            let data = try encoder.encode(payload)
            try data.write(to: detailURL, options: .atomic)
            return detailURL.path
        } catch {
            print("Failed to export self-play detail: \(error)")
            return nil
        }
    }
}

@MainActor
final class GameStore: ObservableObject {
    private struct SelfPlaySimulationResult {
        let summary: GameLogExporter.SelfPlaySummary
        let detail: GameLogExporter.SelfPlayDetailPayload
    }

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
    @Published var moveRecords: [MoveRecord] = []
    @Published var aiTuning: AITuningConfig = .default
    @Published var autoSelfPlayEnabled = false
    @Published var selfPlayHandsTarget = 200
    @Published var isSelfPlayRunning = false
    @Published var selfPlayStatusMessage = ""
    @Published var ruleConfig: RuleConfig = .hunanClassic
    @Published var showWelcomeScreen = true
    @Published var isVoiceEnabled = SpeechService.isEnabled
    @Published private(set) var hasDeclaredSingle = false
    @Published var specialPlayEffect: SpecialPlayEffect?

    private let persistence = PersistenceService()
    private var passCycleTopKey = ""
    private var passCycleCandidates: [[Card]] = []
    private var passCycleIndex = -1
    private var bombCountMe = 0
    private var bombCountLeft = 0
    private var bombCountRight = 0
    private var bombedMe = 0
    private var bombedLeft = 0
    private var bombedRight = 0
    private var handBombDeltaMe = 0
    private var handBombDeltaLeft = 0
    private var handBombDeltaRight = 0
    private var pendingBombOwner: PlayerID?
    private var pendingBombRank: Int?
    private var nextMoveSeq = 1
    private var nextAiDelay: TimeInterval = 1.5
    private let logExporter = GameLogExporter()
    private var hasBootstrapped = false

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        isVoiceEnabled = SpeechService.isEnabled

        if let state = persistence.load() {
            apply(state)
        } else {
            newGame()
        }

    }

    func newGame() {
        scoreMe = 0
        scoreLeft = 0
        scoreRight = 0
        roundResults = []
        handNo = 1
        moveRecords = []
        nextMoveSeq = 1

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
        bombedMe = 0
        bombedLeft = 0
        bombedRight = 0
        handBombDeltaMe = 0
        handBombDeltaLeft = 0
        handBombDeltaRight = 0
        pendingBombOwner = nil
        pendingBombRank = nil
        hasDeclaredSingle = false
        clearPassCycle()
        currentTurn = handCards.contains(where: { $0.raw == "3S" }) ? .me : (leftCards.contains(where: { $0.raw == "3S" }) ? .left : .right)
        hint = L10n.format("hint_new_round_first_format", name(currentTurn))
        save()
        runAiIfNeeded()
    }

    func startNextHand() {
        guard gameFinished else { return }
        let leader = roundResults.last?.winner ?? .me

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
        bombedMe = 0
        bombedLeft = 0
        bombedRight = 0
        handBombDeltaMe = 0
        handBombDeltaLeft = 0
        handBombDeltaRight = 0
        pendingBombOwner = nil
        pendingBombRank = nil
        hasDeclaredSingle = false
        clearPassCycle()
        currentTurn = leader
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

    var canDeclareSingle: Bool {
        handCards.count == 1 && !gameFinished && !hasDeclaredSingle
    }

    func declareSingle() {
        guard canDeclareSingle else { return }
        hasDeclaredSingle = true
        SpeechService.play(VoiceTextBuilder.declareSingleLine())
        hint = L10n.text("hint_declared_single")
        save()
        runAiIfNeeded()
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

        if shouldForceBombResponse(hand: handCards, topCards: topCards, selectedPlay: play) {
            hint = L10n.text("hint_bomb_must_play")
            return
        }

        if requiresHighestSinglePlay(player: .me, cards: picked, play: play) {
            hint = L10n.text("hint_must_play_highest_single_when_next_one_card")
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

    private func applyPlay(player: PlayerID, cards: [Card], play: PlayInfo, reason: String? = nil) {
        setCards(player, PaodekuaiRules.remove(cards: cards, from: getCards(player)))
        topCards = PaodekuaiRules.sort(cards)
        appendMoveRecord(player: player, action: .play, cards: cards, reason: reason)
        topOwner = player
        passCount = 0
        isFirstLeadTurn = false
        selected = []
        clearPassCycle()
        incrementBombCountIfNeeded(player: player, play: play)
        registerBombIfNeeded(player: player, play: play)
        hint = L10n.format("hint_played_cards_format", name(player), cards.map(\.raw).joined(separator: " "))
        let voiceLine = VoiceTextBuilder.playLine(for: cards, play: play, language: L10n.currentLanguage())
        SpeechService.play(voiceLine)
        nextAiDelay = max(1.5, voiceLine.minimumPlaybackDelay)
        triggerSpecialEffectIfNeeded(for: play)

        if getCards(player).isEmpty {
            finishRound(winner: player)
            return
        }

        currentTurn = PaodekuaiRules.nextPlayer(player)
        save()
    }

    private func applyPass(player: PlayerID, reason: String? = nil) {
        clearPassCycle()
        appendMoveRecord(player: player, action: .pass, cards: [], reason: reason)
        passCount += 1
        SpeechService.play(VoiceTextBuilder.cannotBeatLine(player: player, playerName: name(player)))
        nextAiDelay = 1.5
        if passCount >= 2, let owner = topOwner {
            settlePendingBombIfNeeded()
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
        settlePendingBombIfNeeded()
        gameFinished = true
        let remainMe = handCards.count
        let remainLeft = leftCards.count
        let remainRight = rightCards.count

        let pMe = winner == .me ? 0 : loserPenalty(remainMe)
        let pLeft = winner == .left ? 0 : loserPenalty(remainLeft)
        let pRight = winner == .right ? 0 : loserPenalty(remainRight)
        let gain = pMe + pLeft + pRight

        let baseDeltaMe = winner == .me ? gain : -pMe
        let baseDeltaLeft = winner == .left ? gain : -pLeft
        let baseDeltaRight = winner == .right ? gain : -pRight
        scoreMe += baseDeltaMe
        scoreLeft += baseDeltaLeft
        scoreRight += baseDeltaRight

        let result = RoundResult(
            handNo: handNo,
            winner: winner,
            deltaMe: baseDeltaMe + handBombDeltaMe,
            deltaLeft: baseDeltaLeft + handBombDeltaLeft,
            deltaRight: baseDeltaRight + handBombDeltaRight,
            remainMe: remainMe,
            remainLeft: remainLeft,
            remainRight: remainRight,
            bombMe: bombCountMe,
            bombLeft: bombCountLeft,
            bombRight: bombCountRight,
            bombedMe: bombedMe,
            bombedLeft: bombedLeft,
            bombedRight: bombedRight
        )
        roundResults.append(result)
        if roundResults.count > 10 {
            roundResults = Array(roundResults.suffix(10))
        }

        hint = L10n.format("hint_round_finish_format", name(winner))
        SpeechService.play(buildRoundFinishSpeech(result))
        handNo += 1
        save()
    }

    private func triggerSpecialEffectIfNeeded(for play: PlayInfo) {
        let kind: SpecialPlayEffect.Kind?
        switch play.type {
        case .bomb:
            kind = .bomb
        case .airplaneWithWings:
            kind = .airplane
        default:
            kind = nil
        }
        guard let kind else { return }

        specialPlayEffect = SpecialPlayEffect(kind: kind)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.specialPlayEffect = nil
        }
    }

    private func runAiIfNeeded() {
        guard !gameFinished else {
            save()
            return
        }
        if currentTurn == .me {
            if tryAutoRespondIfDeclaredSingle() {
                return
            }
            save()
            return
        }
        let delay = nextAiDelay
        nextAiDelay = 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.gameFinished, self.currentTurn != .me else { return }
            self.aiStep()
        }
    }

    private func aiStep() {
        let actor = currentTurn
        let cards = getCards(actor)
        let nextPlayerCardCount = getCards(PaodekuaiRules.nextPlayer(actor)).count
        let previousPlayerCardCount = getCards(PaodekuaiRules.previousPlayer(actor)).count
        let isNextDanger = nextPlayerCardCount <= aiTuning.dangerCardThreshold
        let isPreviousDanger = previousPlayerCardCount <= aiTuning.dangerCardThreshold
        var picked: [Card]?
        var decisionReason = "fallback"
        if topCards.isEmpty {
            if let allIn = allInLeadIfPossible(cards: cards) {
                picked = allIn
                decisionReason = "all_in_lead"
            } else if let endgame = bestEndgameLead(cards: cards) {
                picked = endgame
                decisionReason = "endgame_min_turns_lead"
            } else {
                let strategic = strategicLead(
                    cards: cards,
                    nextPlayerCardCount: nextPlayerCardCount,
                    previousPlayerCardCount: previousPlayerCardCount
                )
                if let strategic {
                    picked = strategic
                    decisionReason = "strategic_lead"
                } else {
                    picked = PaodekuaiRules.chooseLead(
                        cards,
                        firstTurnMustSpade3: isFirstLeadTurn && handNo == 1,
                        config: ruleConfig,
                        nextPlayerCardCount: getCards(PaodekuaiRules.nextPlayer(actor)).count,
                        previousPlayerCardCount: getCards(PaodekuaiRules.previousPlayer(actor)).count,
                        hasDangerPlayer: isNextDanger || isPreviousDanger
                    )
                    decisionReason = "default_lead"
                }
            }
        } else {
            if let allIn = allInBeatIfPossible(cards: cards) {
                picked = allIn
                decisionReason = "all_in_beat"
            } else if let endgame = bestEndgameBeat(cards: cards, topCards: topCards) {
                picked = endgame
                decisionReason = "endgame_min_turns_beat"
            } else {
                picked = PaodekuaiRules.chooseBeat(
                    cards,
                    topCards: topCards,
                    config: ruleConfig,
                    nextPlayerCardCount: nextPlayerCardCount,
                    previousPlayerCardCount: previousPlayerCardCount,
                    hasDangerPlayer: isNextDanger || isPreviousDanger
                )
                decisionReason = "default_beat"
            }
        }

        if let forced = forcedHighestSinglePlay(for: actor), let current = picked, current.count == 1 {
            picked = forced
            decisionReason = "forced_highest_single"
        }

        if let current = picked, shouldAvoidBombNow(playCards: current, isDangerRound: isNextDanger || isPreviousDanger) {
            let alternatives = PaodekuaiRules.beatingCandidates(cards, topCards: topCards, config: ruleConfig)
                .filter { PaodekuaiRules.detect($0, config: ruleConfig).type != .bomb }

            if let alternative = alternatives.first {
                picked = alternative
                decisionReason = "avoid_bomb_save_for_late"
            }
        }

        // Enforce "bomb only mandatory when no non-bomb beat is available".
        if !topCards.isEmpty, let currentPlay = picked {
            _ = PaodekuaiRules.detect(currentPlay, config: ruleConfig)
            // Even if we picked a non-bomb, switch only when bomb is the sole way to beat.
        }

        if picked == nil && !topCards.isEmpty && ruleConfig.bombMustPlay {
            let candidates = PaodekuaiRules.beatingCandidates(cards, topCards: topCards, config: ruleConfig)
            if let bomb = candidates.first(where: { PaodekuaiRules.detect($0, config: ruleConfig).type == .bomb }) {
                picked = bomb
                decisionReason = "forced_bomb_play_from_pass"
            }
        } else if !topCards.isEmpty, let currentPlay = picked {
            let playInfo = PaodekuaiRules.detect(currentPlay, config: ruleConfig)
            if Self.shouldForceBombResponseForSimulation(hand: cards, topCards: topCards, selectedPlay: playInfo, config: ruleConfig) {
                let candidates = PaodekuaiRules.beatingCandidates(cards, topCards: topCards, config: ruleConfig)
                if let bomb = candidates.first(where: { PaodekuaiRules.detect($0, config: ruleConfig).type == .bomb }) {
                    picked = bomb
                    decisionReason = "forced_bomb_play"
                }
            }
        }

        if let picked {
            applyPlay(player: actor, cards: picked, play: PaodekuaiRules.detect(picked, config: ruleConfig), reason: decisionReason)
        } else {
            applyPass(player: actor, reason: "no_valid_play")
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
                moveRecords: moveRecords,
                nextMoveSeq: nextMoveSeq,
                aiTuning: aiTuning,
                ruleConfig: ruleConfig,
                bombCounts: ["me": bombCountMe, "left": bombCountLeft, "right": bombCountRight],
                bombedCounts: ["me": bombedMe, "left": bombedLeft, "right": bombedRight],
                handBombDeltas: ["me": handBombDeltaMe, "left": handBombDeltaLeft, "right": handBombDeltaRight],
                pendingBombOwner: pendingBombOwner,
                pendingBombRank: pendingBombRank,
                hasDeclaredSingle: hasDeclaredSingle
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
        moveRecords = state.moveRecords
        nextMoveSeq = state.nextMoveSeq
        aiTuning = state.aiTuning
        ruleConfig = state.ruleConfig
        bombCountMe = state.bombCounts["me", default: 0]
        bombCountLeft = state.bombCounts["left", default: 0]
        bombCountRight = state.bombCounts["right", default: 0]
        bombedMe = state.bombedCounts["me", default: 0]
        bombedLeft = state.bombedCounts["left", default: 0]
        bombedRight = state.bombedCounts["right", default: 0]
        handBombDeltaMe = state.handBombDeltas["me", default: 0]
        handBombDeltaLeft = state.handBombDeltas["left", default: 0]
        handBombDeltaRight = state.handBombDeltas["right", default: 0]
        pendingBombOwner = state.pendingBombOwner
        pendingBombRank = state.pendingBombRank
        hasDeclaredSingle = state.hasDeclaredSingle
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

    func formatMoveRecord(_ item: MoveRecord) -> String {
        switch item.action {
        case .play:
            return L10n.format(
                "move_play_format",
                item.handNo,
                name(item.player),
                item.cards.joined(separator: " ")
            )
        case .pass:
            return L10n.format(
                "move_pass_format",
                item.handNo,
                name(item.player)
            )
        }
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

    func setDangerCardThreshold(_ value: Int) {
        aiTuning.dangerCardThreshold = min(max(value, 1), 4)
        save()
    }

    func setAvoidBombTurnThreshold(_ value: Int) {
        aiTuning.avoidBombTurnThreshold = min(max(value, 1), 6)
        save()
    }

    func setMaxHistoryToPersist(_ value: Int) {
        aiTuning.maxHistoryToPersist = min(max(value, 100), 5000)
        if moveRecords.count > aiTuning.maxHistoryToPersist {
            moveRecords = Array(moveRecords.suffix(aiTuning.maxHistoryToPersist))
        }
        save()
    }

    func setSelfPlayHandsTarget(_ value: Int) {
        selfPlayHandsTarget = min(max(value, 10), 50000)
    }

    func setAutoSelfPlayEnabled(_ enabled: Bool) {
        if !enabled {
            autoSelfPlayEnabled = false
            return
        }
        guard !isSelfPlayRunning else { return }
        autoSelfPlayEnabled = true
        isSelfPlayRunning = true
        selfPlayStatusMessage = L10n.format("selfplay_status_running_format", selfPlayHandsTarget)
        let hands = selfPlayHandsTarget
        let config = ruleConfig
        let tuning = aiTuning
        Task {
            let result = await Task.detached(priority: .utility) {
                Self.runSelfPlaySimulation(hands: hands, config: config, tuning: tuning)
            }.value
            let summaryPath = logExporter.exportSelfPlaySummary(result.summary)
            let detailPath = logExporter.exportSelfPlayDetail(result.detail)
            isSelfPlayRunning = false
            autoSelfPlayEnabled = false
            if let summaryPath, let detailPath {
                selfPlayStatusMessage = L10n.format("selfplay_status_done_with_detail_format", summaryPath, detailPath)
            } else if let summaryPath {
                selfPlayStatusMessage = L10n.format("selfplay_status_done_format", summaryPath)
            } else if let detailPath {
                selfPlayStatusMessage = L10n.format("selfplay_status_done_detail_only_format", detailPath)
            } else {
                selfPlayStatusMessage = L10n.text("selfplay_status_failed")
            }
        }
    }

    func selfPlaySummaryFileURL() -> URL? {
        logExporter.selfPlaySummaryURL()
    }

    func latestGameLogFileURL() -> URL? {
        logExporter.latestGameLogURL()
    }

    func selfPlayDetailFileURL() -> URL? {
        logExporter.selfPlayDetailURL()
    }

    func selfPlaySummaryJSONString() -> String? {
        guard let url = logExporter.selfPlaySummaryURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    func latestGameLogJSONString() -> String? {
        guard let url = logExporter.latestGameLogURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    func selfPlayDetailJSONString() -> String? {
        guard let url = logExporter.selfPlayDetailURL(),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return String(decoding: data, as: UTF8.self)
    }

    func toggleVoiceEnabled() {
        isVoiceEnabled.toggle()
        SpeechService.setEnabled(isVoiceEnabled)
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

    @discardableResult
    private func tryAutoRespondIfDeclaredSingle() -> Bool {
        guard hasDeclaredSingle, currentTurn == .me, !gameFinished, handCards.count == 1 else { return false }
        let card = handCards[0]

        if topCards.isEmpty {
            let play = PaodekuaiRules.detect([card], config: ruleConfig)
            guard play.valid else { return false }
            applyPlay(player: .me, cards: [card], play: play, reason: "declared_single_lead")
            return true
        }

        let topPlay = PaodekuaiRules.detect(topCards, config: ruleConfig)
        if topPlay.type == .single {
            let myPlay = PaodekuaiRules.detect([card], config: ruleConfig)
            if PaodekuaiRules.canBeat(myPlay, topPlay) {
                applyPlay(player: .me, cards: [card], play: myPlay, reason: "declared_single_beat")
                return true
            }
        }

        applyPass(player: .me, reason: "declared_single_auto_pass")
        return true
    }

    private func cardsKey(_ cards: [Card]) -> String {
        PaodekuaiRules.sort(cards).map(\.raw).joined(separator: "|")
    }

    private func shouldForceBombResponse(hand: [Card], topCards: [Card], selectedPlay: PlayInfo) -> Bool {
        PaodekuaiRules.mustPlayBomb(
            hand: hand,
            topCards: topCards,
            selectedPlay: selectedPlay,
            config: ruleConfig
        )
    }

    private func appendMoveRecord(player: PlayerID, action: MoveAction, cards: [Card], reason: String? = nil) {
        let item = MoveRecord(
            seq: nextMoveSeq,
            handNo: handNo,
            player: player,
            action: action,
            cards: cards.map(\.raw),
            reason: reason
        )
        nextMoveSeq += 1
        moveRecords.append(item)
        if moveRecords.count > aiTuning.maxHistoryToPersist {
            moveRecords = Array(moveRecords.suffix(aiTuning.maxHistoryToPersist))
        }
        exportLogs()
    }

    private func requiresHighestSinglePlay(player: PlayerID, cards: [Card], play: PlayInfo) -> Bool {
        guard play.type == .single, cards.count == 1 else { return false }
        let next = PaodekuaiRules.nextPlayer(player)
        guard getCards(next).count == 1 else { return false }
        guard let highest = PaodekuaiRules.sort(getCards(player)).last else { return false }
        return cards[0].id != highest.id
    }

    private func forcedHighestSinglePlay(for player: PlayerID) -> [Card]? {
        let next = PaodekuaiRules.nextPlayer(player)
        guard getCards(next).count == 1 else { return nil }
        guard let highest = PaodekuaiRules.sort(getCards(player)).last else { return nil }
        let forced = [highest]
        let top = topCards.isEmpty ? nil : PaodekuaiRules.detect(topCards, config: ruleConfig)
        let forcedPlay = PaodekuaiRules.detect(forced, config: ruleConfig)
        guard PaodekuaiRules.canBeat(forcedPlay, top) else { return nil }
        return forced
    }

    private func allInLeadIfPossible(cards: [Card]) -> [Card]? {
        let all = PaodekuaiRules.sort(cards)
        guard !all.isEmpty else { return nil }
        guard PaodekuaiRules.detect(all, config: ruleConfig).valid else { return nil }
        if isFirstLeadTurn, handNo == 1, cards.contains(where: { $0.raw == "3S" }) {
            return all.contains(where: { $0.raw == "3S" }) ? all : nil
        }
        return all
    }

    private func allInBeatIfPossible(cards: [Card]) -> [Card]? {
        let all = PaodekuaiRules.sort(cards)
        guard !all.isEmpty else { return nil }
        let play = PaodekuaiRules.detect(all, config: ruleConfig)
        guard play.valid else { return nil }
        let top = topCards.isEmpty ? nil : PaodekuaiRules.detect(topCards, config: ruleConfig)
        return PaodekuaiRules.canBeat(play, top) ? all : nil
    }

    private func strategicLead(cards: [Card], nextPlayerCardCount: Int, previousPlayerCardCount: Int) -> [Card]? {
        let sorted = PaodekuaiRules.sort(cards)
        guard !sorted.isEmpty else { return nil }

        if isFirstLeadTurn,
           handNo == 1,
           let s3 = sorted.first(where: { $0.raw == "3S" }),
           sorted.contains(where: { $0.rank == .r2 }) {
            return [s3]
        }

        // Pressure mode: downstream danger, lead a higher single to block entry.
        if nextPlayerCardCount <= aiTuning.dangerCardThreshold, let highest = sorted.last {
            return [highest]
        }

        // Tempo mode: upstream danger, prefer medium-low natural pair to retain future control.
        return nil
    }

    private func shouldAvoidBombNow(playCards: [Card], isDangerRound: Bool) -> Bool {
        let play = PaodekuaiRules.detect(playCards, config: ruleConfig)
        guard play.type == .bomb else { return false }
        if isDangerRound { return false }

        let nextCount = getCards(PaodekuaiRules.nextPlayer(currentTurn)).count
        let prevCount = getCards(PaodekuaiRules.previousPlayer(currentTurn)).count
        let myCount = getCards(currentTurn).count

        if (nextCount <= 3 || prevCount <= 3) && myCount >= 10 {
            return false
        }

        let remaining = PaodekuaiRules.remove(cards: playCards, from: getCards(currentTurn))
        var memo: [String: Int] = [:]
        let turns = estimatedTurnsToFinish(cards: remaining, memo: &memo)
        return turns > aiTuning.avoidBombTurnThreshold
    }

    private func exportLogs() {
        let payload = GameLogExporter.GameLogPayload(
            generatedAt: Date(),
            handNo: handNo,
            scoreMe: scoreMe,
            scoreLeft: scoreLeft,
            scoreRight: scoreRight,
            aiTuning: aiTuning,
            roundResults: roundResults,
            moveRecords: moveRecords
        )
        logExporter.export(payload: payload)
    }

    private func bestEndgameLead(cards: [Card]) -> [Card]? {
        let sorted = PaodekuaiRules.sort(cards)
        guard (2...8).contains(sorted.count) else { return nil }
        let candidates = validSubsets(from: sorted)
        guard !candidates.isEmpty else { return nil }

        var memo: [String: Int] = [:]
        var best: [Card]?
        var bestTurns = Int.max
        var bestStrength = Int.max
        for candidate in candidates {
            if isFirstLeadTurn, handNo == 1, cards.contains(where: { $0.raw == "3S" }), !candidate.contains(where: { $0.raw == "3S" }) {
                continue
            }
            let rest = PaodekuaiRules.remove(cards: candidate, from: sorted)
            let turns = 1 + estimatedTurnsToFinish(cards: rest, memo: &memo)
            let play = PaodekuaiRules.detect(candidate, config: ruleConfig)
            let strength = play.mainRank * 10 + play.length
            if turns < bestTurns || (turns == bestTurns && strength < bestStrength) {
                best = candidate
                bestTurns = turns
                bestStrength = strength
            }
        }
        return best
    }

    private func bestEndgameBeat(cards: [Card], topCards: [Card]) -> [Card]? {
        let sorted = PaodekuaiRules.sort(cards)
        guard (2...8).contains(sorted.count) else { return nil }
        let candidates = PaodekuaiRules.beatingCandidates(sorted, topCards: topCards, config: ruleConfig)
        guard !candidates.isEmpty else { return nil }

        var memo: [String: Int] = [:]
        let nextCount = getCards(PaodekuaiRules.nextPlayer(currentTurn)).count
        var best: [Card]?
        var bestTurns = Int.max
        var bestStrength = nextCount <= 1 ? Int.min : Int.max
        for candidate in candidates {
            let rest = PaodekuaiRules.remove(cards: candidate, from: sorted)
            let turns = 1 + estimatedTurnsToFinish(cards: rest, memo: &memo)
            let play = PaodekuaiRules.detect(candidate, config: ruleConfig)
            let strength = play.mainRank * 10 + play.length
            let betterStrength = nextCount <= 1 ? (strength > bestStrength) : (strength < bestStrength)
            if turns < bestTurns || (turns == bestTurns && betterStrength) {
                best = candidate
                bestTurns = turns
                bestStrength = strength
            }
        }
        return best
    }

    private func estimatedTurnsToFinish(cards: [Card], memo: inout [String: Int]) -> Int {
        let sorted = PaodekuaiRules.sort(cards)
        if sorted.isEmpty { return 0 }
        let key = sorted.map(\.raw).joined(separator: "|")
        if let cached = memo[key] { return cached }
        if PaodekuaiRules.detect(sorted, config: ruleConfig).valid {
            memo[key] = 1
            return 1
        }

        let subsets = validSubsets(from: sorted)
        if subsets.isEmpty {
            memo[key] = sorted.count
            return sorted.count
        }
        var best = max(1, sorted.count)
        for subset in subsets {
            let rest = PaodekuaiRules.remove(cards: subset, from: sorted)
            best = min(best, 1 + estimatedTurnsToFinish(cards: rest, memo: &memo))
            if best <= 2 { break }
        }
        memo[key] = best
        return best
    }

    private func validSubsets(from cards: [Card]) -> [[Card]] {
        let sorted = PaodekuaiRules.sort(cards)
        let n = sorted.count
        guard n > 0, n <= 8 else { return [] }

        var result: [[Card]] = []
        var seen = Set<String>()
        let maxMask = 1 << n
        for mask in 1..<maxMask {
            var subset: [Card] = []
            for i in 0..<n where (mask & (1 << i)) != 0 {
                subset.append(sorted[i])
            }
            let normalized = PaodekuaiRules.sort(subset)
            let key = normalized.map(\.raw).joined(separator: "|")
            if seen.contains(key) { continue }
            let play = PaodekuaiRules.detect(normalized, config: ruleConfig)
            if play.valid {
                seen.insert(key)
                result.append(normalized)
            }
        }
        return result
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

    private func registerBombIfNeeded(player: PlayerID, play: PlayInfo) {
        guard play.type == .bomb else { return }
        if let rank = pendingBombRank, play.mainRank <= rank {
            return
        }
        pendingBombOwner = player
        pendingBombRank = play.mainRank
    }

    private func settlePendingBombIfNeeded() {
        guard let owner = pendingBombOwner else { return }
        let losers = PlayerID.allCases.filter { $0 != owner }
        guard losers.count == 2 else { return }
        applyBombScore(to: owner, delta: 20)
        applyBombScore(to: losers[0], delta: -10)
        applyBombScore(to: losers[1], delta: -10)
        incrementBombedCount(for: losers[0])
        incrementBombedCount(for: losers[1])
        pendingBombOwner = nil
        pendingBombRank = nil
    }

    private func applyBombScore(to player: PlayerID, delta: Int) {
        switch player {
        case .me:
            scoreMe += delta
            handBombDeltaMe += delta
        case .left:
            scoreLeft += delta
            handBombDeltaLeft += delta
        case .right:
            scoreRight += delta
            handBombDeltaRight += delta
        }
    }

    private func incrementBombedCount(for player: PlayerID) {
        switch player {
        case .me: bombedMe += 1
        case .left: bombedLeft += 1
        case .right: bombedRight += 1
        }
    }

    private nonisolated static func runSelfPlaySimulation(hands: Int, config: RuleConfig, tuning: AITuningConfig) -> SelfPlaySimulationResult {
        let totalHands = max(1, hands)
        var wins: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
        var scores: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
        var bombsPlayed: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
        var bombedCounts: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
        var handLogs: [GameLogExporter.SelfPlayHandLog] = []
        handLogs.reserveCapacity(totalHands)
        var globalMoveSeq = 1

        for handIndex in 1...totalHands {
            let deal = PaodekuaiRules.deal16x3()
            var cards: [PlayerID: [Card]] = [.me: deal.me, .left: deal.left, .right: deal.right]
            var currentTurn: PlayerID = cards[.me]!.contains(where: { $0.raw == "3S" }) ? .me : (cards[.left]!.contains(where: { $0.raw == "3S" }) ? .left : .right)
            let firstTurnPlayer = currentTurn
            var topCards: [Card] = []
            var topOwner: PlayerID?
            var passCount = 0
            var isFirstLeadTurn = true
            var pendingBombOwner: PlayerID?
            var pendingBombRank: Int?
            var handBombDelta: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
            var handBombPlayed: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
            var handBombedCount: [PlayerID: Int] = [.me: 0, .left: 0, .right: 0]
            var handMoveRecords: [GameLogExporter.SelfPlayHandLog.SelfPlayMoveLog] = []
            let firstGameHand = handIndex == 1
            var winner: PlayerID = .me
            var finished = false

            while !finished {
                let actor = currentTurn
                let handCards = cards[actor] ?? []
                let next = PaodekuaiRules.nextPlayer(actor)
                let previous = PaodekuaiRules.previousPlayer(actor)
                let nextCount = cards[next]?.count ?? 0
                let prevCount = cards[previous]?.count ?? 0
                let isNextDanger = nextCount <= tuning.dangerCardThreshold
                let isPrevDanger = prevCount <= tuning.dangerCardThreshold
                let picked: [Card]?
                let legalActionCount: Int
                let legalActionCountEstimated: Bool
                if topCards.isEmpty {
                    legalActionCount = 1
                    legalActionCountEstimated = true
                    picked = PaodekuaiRules.chooseLead(
                        handCards,
                        firstTurnMustSpade3: isFirstLeadTurn && firstGameHand,
                        config: config,
                        nextPlayerCardCount: nextCount,
                        previousPlayerCardCount: prevCount,
                        hasDangerPlayer: isNextDanger || isPrevDanger
                    )
                } else {
                    let candidates = PaodekuaiRules.beatingCandidates(handCards, topCards: topCards, config: config)
                    legalActionCount = candidates.isEmpty ? 1 : candidates.count
                    legalActionCountEstimated = false
                    picked = PaodekuaiRules.chooseBeat(
                        handCards,
                        topCards: topCards,
                        config: config,
                        nextPlayerCardCount: nextCount,
                        previousPlayerCardCount: prevCount,
                        hasDangerPlayer: isNextDanger || isPrevDanger
                    )
                }

                guard let selected = picked, !selected.isEmpty else {
                    let snapshot = GameLogExporter.SelfPlayHandLog.SelfPlayMoveLog.StateSnapshot(
                        topCards: topCards.map(\.raw),
                        topOwner: topOwner,
                        handCount: handCards.count,
                        nextHandCount: nextCount,
                        previousHandCount: prevCount,
                        legalActionCount: legalActionCount,
                        legalActionCountEstimated: legalActionCountEstimated,
                        forcedBombRuleTriggered: false
                    )
                    handMoveRecords.append(
                        .init(
                            seq: globalMoveSeq,
                            handNo: handIndex,
                            player: actor,
                            action: .pass,
                            cards: [],
                            reason: "no_valid_play",
                            chosenPlayType: nil,
                            snapshot: snapshot
                        )
                    )
                    globalMoveSeq += 1
                    passCount += 1
                    if passCount >= 2, let owner = topOwner {
                        Self.settlePendingBombForSimulation(
                            pendingOwner: &pendingBombOwner,
                            pendingRank: &pendingBombRank,
                            handBombDelta: &handBombDelta,
                            bombedCounts: &bombedCounts,
                            handBombedCounts: &handBombedCount
                        )
                        currentTurn = owner
                        topCards = []
                        topOwner = nil
                        passCount = 0
                    } else {
                        currentTurn = next
                    }
                    continue
                }

                let playCards = PaodekuaiRules.sort(selected)
                let play = PaodekuaiRules.detect(playCards, config: config)
                if !play.valid {
                    let snapshot = GameLogExporter.SelfPlayHandLog.SelfPlayMoveLog.StateSnapshot(
                        topCards: topCards.map(\.raw),
                        topOwner: topOwner,
                        handCount: handCards.count,
                        nextHandCount: nextCount,
                        previousHandCount: prevCount,
                        legalActionCount: legalActionCount,
                        legalActionCountEstimated: legalActionCountEstimated,
                        forcedBombRuleTriggered: false
                    )
                    handMoveRecords.append(
                        .init(
                            seq: globalMoveSeq,
                            handNo: handIndex,
                            player: actor,
                            action: .pass,
                            cards: [],
                            reason: "invalid_selection",
                            chosenPlayType: nil,
                            snapshot: snapshot
                        )
                    )
                    globalMoveSeq += 1
                    passCount += 1
                    currentTurn = next
                    continue
                }

                let topBeforeCards = topCards
                let topBeforeOwner = topOwner
                // Enforce "bomb only mandatory when no non-bomb beat available".
                var forcedBombResponse = false
                if let currentPlay = picked {
                    let playInfo = PaodekuaiRules.detect(currentPlay, config: config)
                    forcedBombResponse = Self.shouldForceBombResponseForSimulation(
                        hand: handCards,
                        topCards: topCards,
                        selectedPlay: playInfo,
                        config: config
                    )
                }

                if picked == nil && !topCards.isEmpty && config.bombMustPlay {
                    let candidates = PaodekuaiRules.beatingCandidates(handCards, topCards: topCards, config: config)
                    if candidates.contains(where: { PaodekuaiRules.detect($0, config: config).type == .bomb }) {
                        forcedBombResponse = true
                    }
                }

                if forcedBombResponse {
                    let forced = PaodekuaiRules.beatingCandidates(handCards, topCards: topCards, config: config)
                    if let bomb = forced.first(where: { PaodekuaiRules.detect($0, config: config).type == .bomb }) {
                        topCards = bomb
                    } else {
                        topCards = playCards
                    }
                } else {
                    topCards = playCards
                }

                let actualPlay = PaodekuaiRules.detect(topCards, config: config)
                cards[actor] = PaodekuaiRules.remove(cards: topCards, from: handCards)
                let playReason = forcedBombResponse ? "forced_bomb_play" : (actualPlay.type == .bomb ? "default_bomb" : "default_play")
                let snapshot = GameLogExporter.SelfPlayHandLog.SelfPlayMoveLog.StateSnapshot(
                    topCards: topBeforeCards.map(\.raw),
                    topOwner: topBeforeOwner,
                    handCount: handCards.count,
                    nextHandCount: nextCount,
                    previousHandCount: prevCount,
                    legalActionCount: legalActionCount,
                    legalActionCountEstimated: legalActionCountEstimated,
                    forcedBombRuleTriggered: forcedBombResponse
                )
                handMoveRecords.append(
                    .init(
                        seq: globalMoveSeq,
                        handNo: handIndex,
                        player: actor,
                        action: .play,
                        cards: topCards.map(\.raw),
                        reason: playReason,
                        chosenPlayType: actualPlay.type,
                        snapshot: snapshot
                    )
                )
                globalMoveSeq += 1
                topOwner = actor
                passCount = 0
                isFirstLeadTurn = false

                if actualPlay.type == .bomb {
                    bombsPlayed[actor, default: 0] += 1
                    handBombPlayed[actor, default: 0] += 1
                    if pendingBombOwner == nil || actualPlay.mainRank > (pendingBombRank ?? -1) {
                        pendingBombOwner = actor
                        pendingBombRank = actualPlay.mainRank
                    }
                }

                if cards[actor]?.isEmpty == true {
                    Self.settlePendingBombForSimulation(
                        pendingOwner: &pendingBombOwner,
                        pendingRank: &pendingBombRank,
                        handBombDelta: &handBombDelta,
                        bombedCounts: &bombedCounts,
                        handBombedCounts: &handBombedCount
                    )
                    winner = actor
                    finished = true
                } else {
                    currentTurn = next
                }
            }

            let remainMe = cards[.me]?.count ?? 0
            let remainLeft = cards[.left]?.count ?? 0
            let remainRight = cards[.right]?.count ?? 0
            let pMe = winner == .me ? 0 : Self.loserPenaltyForSimulation(remainMe)
            let pLeft = winner == .left ? 0 : Self.loserPenaltyForSimulation(remainLeft)
            let pRight = winner == .right ? 0 : Self.loserPenaltyForSimulation(remainRight)
            let gain = pMe + pLeft + pRight

            let deltaMe = (winner == .me ? gain : -pMe) + handBombDelta[.me, default: 0]
            let deltaLeft = (winner == .left ? gain : -pLeft) + handBombDelta[.left, default: 0]
            let deltaRight = (winner == .right ? gain : -pRight) + handBombDelta[.right, default: 0]
            scores[.me, default: 0] += deltaMe
            scores[.left, default: 0] += deltaLeft
            scores[.right, default: 0] += deltaRight
            wins[winner, default: 0] += 1

            handLogs.append(
                .init(
                    handNo: handIndex,
                    firstTurnPlayer: firstTurnPlayer,
                    initialMe: deal.me.map(\.raw),
                    initialLeft: deal.left.map(\.raw),
                    initialRight: deal.right.map(\.raw),
                    moves: handMoveRecords,
                    winner: winner,
                    remainMe: remainMe,
                    remainLeft: remainLeft,
                    remainRight: remainRight,
                    deltaMe: deltaMe,
                    deltaLeft: deltaLeft,
                    deltaRight: deltaRight,
                    cumulativeScoreMe: scores[.me, default: 0],
                    cumulativeScoreLeft: scores[.left, default: 0],
                    cumulativeScoreRight: scores[.right, default: 0],
                    bombMe: handBombPlayed[.me, default: 0],
                    bombLeft: handBombPlayed[.left, default: 0],
                    bombRight: handBombPlayed[.right, default: 0],
                    bombedMe: handBombedCount[.me, default: 0],
                    bombedLeft: handBombedCount[.left, default: 0],
                    bombedRight: handBombedCount[.right, default: 0]
                )
            )
        }

        let summary: GameLogExporter.SelfPlaySummary = .init(
            generatedAt: Date(),
            hands: totalHands,
            config: config,
            playerMe: .init(
                wins: wins[.me, default: 0],
                score: scores[.me, default: 0],
                bombsPlayed: bombsPlayed[.me, default: 0],
                bombedCount: bombedCounts[.me, default: 0]
            ),
            playerLeft: .init(
                wins: wins[.left, default: 0],
                score: scores[.left, default: 0],
                bombsPlayed: bombsPlayed[.left, default: 0],
                bombedCount: bombedCounts[.left, default: 0]
            ),
            playerRight: .init(
                wins: wins[.right, default: 0],
                score: scores[.right, default: 0],
                bombsPlayed: bombsPlayed[.right, default: 0],
                bombedCount: bombedCounts[.right, default: 0]
            )
        )

        let detail: GameLogExporter.SelfPlayDetailPayload = .init(
            generatedAt: Date(),
            hands: totalHands,
            config: config,
            aiTuning: tuning,
            summary: summary,
            handLogs: handLogs
        )
        return .init(summary: summary, detail: detail)
    }

    private nonisolated static func settlePendingBombForSimulation(
        pendingOwner: inout PlayerID?,
        pendingRank: inout Int?,
        handBombDelta: inout [PlayerID: Int],
        bombedCounts: inout [PlayerID: Int],
        handBombedCounts: inout [PlayerID: Int]
    ) {
        guard let owner = pendingOwner else { return }
        let losers = PlayerID.allCases.filter { $0 != owner }
        guard losers.count == 2 else { return }
        handBombDelta[owner, default: 0] += 20
        handBombDelta[losers[0], default: 0] -= 10
        handBombDelta[losers[1], default: 0] -= 10
        bombedCounts[losers[0], default: 0] += 1
        bombedCounts[losers[1], default: 0] += 1
        handBombedCounts[losers[0], default: 0] += 1
        handBombedCounts[losers[1], default: 0] += 1
        pendingOwner = nil
        pendingRank = nil
    }

    private nonisolated static func loserPenaltyForSimulation(_ remain: Int) -> Int {
        if remain <= 1 { return 0 }
        if remain == 16 { return 30 }
        if remain == 15 { return 15 }
        return remain
    }

    private nonisolated static func shouldForceBombResponseForSimulation(hand: [Card], topCards: [Card], selectedPlay: PlayInfo, config: RuleConfig) -> Bool {
        PaodekuaiRules.mustPlayBomb(
            hand: hand,
            topCards: topCards,
            selectedPlay: selectedPlay,
            config: config
        )
    }

    private func buildRoundFinishSpeech(_ result: RoundResult) -> VoiceLine {
        return VoiceTextBuilder.roundFinishLine(winner: result.winner, playerName: name(result.winner))
    }

}
