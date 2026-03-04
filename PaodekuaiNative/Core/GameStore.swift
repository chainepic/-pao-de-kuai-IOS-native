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
    @Published var isMultiplayerMode = false
    @Published var showWelcomeScreen = true

    // Multiplayer Stubs
    @Published var errorMessage = ""
    @Published var roomCodeInput = ""
    @Published var nicknameInput = ""
    @Published var roomCode = ""
    @Published var inRoom = false
    @Published var roomPlayers: [RoomPlayer] = []
    @Published var isLoadingRoom = false
    @Published var isReadySubmitting = false
    @Published var roomHasGameState = false
    @Published var turnCountdown = 0
    @Published var isAutoTrustMode = false
    @Published var realtimeStatusText = "未连接"
    @Published var lastSyncText = "--:--:--"
    @Published var isVoiceEnabled = SpeechService.isEnabled

    var canOperateRoomSeats: Bool {
        roomPlayers.first(where: { $0.id == myPlayerID })?.isHost ?? false
    }

    var seatedPlayers: [RoomPlayer] {
        roomPlayers.filter { $0.seatNo != nil }
    }

    var myRoomPlayer: RoomPlayer? {
        roomPlayers.first(where: { $0.id == myPlayerID })
    }

    var meReady: Bool {
        myRoomPlayer?.isReady ?? false
    }

    var allSeatedPlayersReady: Bool {
        let seated = seatedPlayers
        return !seated.isEmpty && seated.allSatisfy { ($0.isReady ?? false) }
    }

    var canStartRoomGame: Bool {
        startBlockReason == nil
    }

    var snapshotVersionText: String {
        latestStateVersion >= 0 ? "\(latestStateVersion)" : "-"
    }

    var startBlockReason: String? {
        guard canOperateRoomSeats else { return "仅房主可开始" }
        guard !roomHasGameState else { return "对局已开始" }
        let seated = seatedPlayers
        guard seated.count == 3 else { return "需3人入座（当前\(seated.count)/3）" }
        let unready = seated.filter { !($0.isReady ?? false) }.map(\.nickname)
        if !unready.isEmpty {
            return "未准备：\(unready.joined(separator: "、"))"
        }
        let unobserved = seated
            .filter { !observedReadyPlayerIDs.contains($0.id) }
            .map(\.nickname)
        if !unobserved.isEmpty {
            return "请确认点击准备：\(unobserved.joined(separator: "、"))"
        }
        return nil
    }

    private let roomSessionPersistence = RoomSessionPersistence()
    private let identityService = IdentityService()
    private let roomService = RoomService()
    private let realtimeService = RealtimeService()

    private(set) var myPlayerID = ""
    private var mySeatNo: Int?
    private var latestStateVersion = -1
    private var actionInFlight = false
    private var turnTimerTask: Task<Void, Never>?
    private var currentTurnKey = ""
    private var readyBaselineCaptured = false
    private var lastReadyByPlayer: [String: Bool] = [:]
    private var observedReadyPlayerIDs: Set<String> = []

    private let persistence = PersistenceService()
    private var passCycleTopKey = ""
    private var passCycleCandidates: [[Card]] = []
    private var passCycleIndex = -1
    private var bombCountMe = 0
    private var bombCountLeft = 0
    private var bombCountRight = 0

    func bootstrap() {
        nicknameInput = identityService.loadNickname()
        myPlayerID = identityService.loadOrCreateClientID()
        realtimeStatusText = "未连接"
        lastSyncText = "--:--:--"
        isVoiceEnabled = SpeechService.isEnabled

        if let session = roomSessionPersistence.load() {
            roomCode = session.roomCode
            isMultiplayerMode = true
            inRoom = true
            attachRealtime(session: session)
        }

        if let state = persistence.load() {
            apply(state)
        } else {
            newGame()
        }
    }

    func newGame() {
        if isMultiplayerMode {
            guard inRoom else { hint = "请先加入房间"; return }
            guard canStartRoomGame else {
                hint = startBlockReason ?? "暂不可开始"
                return
            }
            Task { await startRoomGame() }
            return
        }
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
        guard !actionInFlight else { return }
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
        
        if isMultiplayerMode {
            if isAutoTrustMode { isAutoTrustMode = false }
            Task { await submitPass() }
            return
        }
        
        applyPass(player: .me)
        runAiIfNeeded()
    }

    func playSelected() {
        guard currentTurn == .me, !gameFinished else { return }
        guard !actionInFlight else { return }
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
        
        if isMultiplayerMode {
            if isAutoTrustMode { isAutoTrustMode = false }
            Task { await submitPlay(cards: picked) }
            return
        }
        
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
        if isMultiplayerMode {
            save()
            return
        }
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
        if isMultiplayerMode { return }
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

    // MARK: - Multiplayer Actions

    func seatNickname(_ seatNo: Int) -> String {
        roomPlayers.first(where: { $0.seatNo == seatNo })?.nickname ?? "空位"
    }

    func createRoom() async {
        let nickname = normalizedNickname()
        nicknameInput = nickname
        identityService.saveNickname(nickname)
        isLoadingRoom = true
        errorMessage = ""
        defer { isLoadingRoom = false }
        do {
            let res = try await roomService.performAction(action: "create_room", userID: myPlayerID, nickname: nickname)
            try acceptRoomResponse(res)
        } catch {
            errorMessage = roomService.mapError(error)
        }
    }

    func joinRoom() async {
        let code = roomCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { errorMessage = "请输入房间码"; return }
        let nickname = normalizedNickname()
        nicknameInput = nickname
        identityService.saveNickname(nickname)
        isLoadingRoom = true
        errorMessage = ""
        defer { isLoadingRoom = false }
        do {
            let res = try await roomService.performAction(action: "join_room", roomCode: code, userID: myPlayerID, nickname: nickname)
            try acceptRoomResponse(res)
        } catch {
            errorMessage = roomService.mapError(error)
        }
    }

    func leaveRoom() async {
        guard let session = roomSessionPersistence.load() else { return }
        do {
            _ = try await roomService.performAction(action: "leave_room", roomCode: session.roomCode, userID: myPlayerID)
        } catch {
            errorMessage = roomService.mapError(error)
        }
        realtimeService.stop()
        roomSessionPersistence.clear()
        inRoom = false
        isMultiplayerMode = false
        roomPlayers = []
        roomCode = ""
        mySeatNo = nil
        latestStateVersion = -1
        roomHasGameState = false
        stopTurnTimer(clearTrust: true)
        readyBaselineCaptured = false
        lastReadyByPlayer = [:]
        observedReadyPlayerIDs = []
        realtimeStatusText = "未连接"
        lastSyncText = "--:--:--"
        errorMessage = ""
        hint = "已离开房间"
    }

    func startRoomGame() async {
        guard canStartRoomGame else {
            hint = startBlockReason ?? "暂不可开始"
            return
        }
        guard let session = roomSessionPersistence.load() else { return }
        do {
            let response = try await roomService.performAction(action: "start_game", roomCode: session.roomCode, userID: myPlayerID)
            if let snapshot = response.snapshot {
                apply(snapshot: snapshot, myHandRaw: response.myHand)
            }
        } catch {
            errorMessage = roomService.mapError(error)
            hint = "开始失败"
        }
    }

    func setReady(_ ready: Bool) async {
        guard inRoom, !roomHasGameState else { return }
        guard let session = roomSessionPersistence.load() else { return }
        isReadySubmitting = true
        defer { isReadySubmitting = false }
        
        // Optimistic update for UI responsiveness
        let prevReady = meReady
        if let idx = roomPlayers.firstIndex(where: { $0.id == myPlayerID }) {
            let p = roomPlayers[idx]
            roomPlayers[idx] = RoomPlayer(id: p.id, nickname: p.nickname, isHost: p.isHost, isReady: ready, seatNo: p.seatNo)
        }
        
        do {
            let response = try await roomService.performAction(
                action: "set_ready",
                roomCode: session.roomCode,
                userID: myPlayerID,
                ready: ready
            )
            if let snapshot = response.snapshot {
                apply(snapshot: snapshot, myHandRaw: response.myHand)
            }
        } catch {
            // Revert optimistic update on error
            if let idx = roomPlayers.firstIndex(where: { $0.id == myPlayerID }) {
                let p = roomPlayers[idx]
                roomPlayers[idx] = RoomPlayer(id: p.id, nickname: p.nickname, isHost: p.isHost, isReady: prevReady, seatNo: p.seatNo)
            }
            
            let msg = roomService.mapError(error)
            if msg.localizedCaseInsensitiveContains("unknown action")
                || msg.localizedCaseInsensitiveContains("not support")
                || msg.localizedCaseInsensitiveContains("不支持") {
                errorMessage = "当前后端暂不支持 ready 接口（set_ready）"
                hint = "后端未实现准备接口，无法切换准备状态"
                return
            }
            errorMessage = msg
            hint = "准备状态更新失败"
        }
    }

    func assignSeat(targetPlayerID: String, seatNo: Int) async {
        _ = targetPlayerID
        _ = seatNo
        errorMessage = "当前后端不支持 assign_seat，请由后端开启该动作后再使用调座。"
    }

    func kickPlayer(_ targetPlayerID: String) async {
        guard inRoom, !roomHasGameState else { return }
        guard let session = roomSessionPersistence.load() else { return }
        do {
            let res = try await roomService.performAction(action: "kick_player", roomCode: session.roomCode, userID: myPlayerID, targetPlayerID: targetPlayerID)
            if let snapshot = res.snapshot {
                apply(snapshot: snapshot, myHandRaw: res.myHand)
            }
        } catch {
            errorMessage = roomService.mapError(error)
            hint = "踢出玩家失败"
        }
    }

    func reconnectRealtime() {
        guard inRoom, isMultiplayerMode else { return }
        guard let session = roomSessionPersistence.load() else { return }
        realtimeService.stop()
        realtimeStatusText = "连接中"
        hint = "正在重连实时通道..."
        attachRealtime(session: session)
    }

    func toggleVoiceEnabled() {
        let next = !isVoiceEnabled
        isVoiceEnabled = next
        SpeechService.setEnabled(next)
    }

    private func submitPlay(cards: [Card]) async {
        guard let session = roomSessionPersistence.load() else { return }
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            _ = try await roomService.performAction(action: "play_cards", roomCode: session.roomCode, userID: myPlayerID, cards: cards.map(\.raw))
        } catch {
            errorMessage = roomService.mapError(error)
            hint = "出牌失败：\(error.localizedDescription)"
        }
    }

    private func submitPass() async {
        guard let session = roomSessionPersistence.load() else { return }
        actionInFlight = true
        defer { actionInFlight = false }
        do {
            _ = try await roomService.performAction(action: "pass_turn", roomCode: session.roomCode, userID: myPlayerID)
        } catch {
            errorMessage = roomService.mapError(error)
            hint = "过牌失败：\(error.localizedDescription)"
        }
    }

    private func acceptRoomResponse(_ response: RoomActionResponse) throws {
        guard let code = response.roomCode, let snapshot = response.snapshot else {
            throw RoomService.RoomServiceError.server("服务返回数据不完整")
        }
        identityService.saveNickname(nicknameInput)
        roomCode = code
        roomCodeInput = code
        inRoom = true
        isMultiplayerMode = true
        latestStateVersion = -1
        stopTurnTimer(clearTrust: true)
        readyBaselineCaptured = false
        lastReadyByPlayer = [:]
        observedReadyPlayerIDs = []
        realtimeStatusText = "连接中"

        let session = LocalRoomSession(roomCode: code, playerID: myPlayerID)
        roomSessionPersistence.save(session)
        attachRealtime(session: session)

        apply(snapshot: snapshot, myHandRaw: response.myHand)
    }

    private func normalizedNickname() -> String {
        let value = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            return "玩家\(Int.random(in: 1000...9999))"
        }
        return String(value.prefix(16))
    }

    private func attachRealtime(session: LocalRoomSession) {
        realtimeService.start(
            wsBaseURL: ServerConfig.wsURL,
            roomCode: session.roomCode,
            playerID: session.playerID,
            onResponse: { [weak self] res in
                if let snap = res.snapshot {
                    self?.apply(snapshot: snap, myHandRaw: res.myHand)
                }
            },
            onStatus: { [weak self] status in
                self?.realtimeStatusText = status
            },
            onError: { [weak self] message in
                self?.errorMessage = message
                self?.realtimeStatusText = "连接异常"
            }
        )
    }

    private func apply(snapshot: RoomSnapshot, myHandRaw: [String]?) {
        roomPlayers = snapshot.players
        mySeatNo = snapshot.players.first(where: { $0.id == myPlayerID })?.seatNo
        roomHasGameState = snapshot.gameState != nil
        trackReadyState(snapshot.players)
        markSyncedNow()

        guard let game = snapshot.gameState else {
            stopTurnTimer(clearTrust: false)
            if canOperateRoomSeats {
                hint = canStartRoomGame ? "可开始游戏" : (startBlockReason ?? "等待玩家准备")
            } else {
                hint = meReady ? "已准备，等待房主开始" : "请点击准备"
            }
            return
        }

        if game.stateVersion <= latestStateVersion {
            return
        }
        latestStateVersion = game.stateVersion

        let mergedMyHand: [String]? = {
            if let myHandRaw, !myHandRaw.isEmpty { return myHandRaw }
            if let cards = snapshot.myHand, !cards.isEmpty { return cards }
            if let cards = snapshot.handCards, !cards.isEmpty { return cards }
            if let cards = snapshot.myCards, !cards.isEmpty { return cards }
            return myHandRaw
        }()
        if let raw = mergedMyHand {
            handCards = cardsFrom(rawCards: raw) ?? []
        }
        selected = []
        topCards = cardsFrom(rawCards: game.topCards) ?? []

        if let mySeatNo {
            currentTurn = mapSeatToPlayerID(game.currentTurnSeat, mySeat: mySeatNo)
            topOwner = mapSeatToPlayerID(game.topOwnerSeat, mySeat: mySeatNo)
            leftCards = placeholderCards(count: countForRelativeSeat(game.seatCardCounts, mySeat: mySeatNo, target: .left))
            rightCards = placeholderCards(count: countForRelativeSeat(game.seatCardCounts, mySeat: mySeatNo, target: .right))
            scoreMe = scoreForRelativeSeat(game.scores, mySeat: mySeatNo, target: .me)
            scoreLeft = scoreForRelativeSeat(game.scores, mySeat: mySeatNo, target: .left)
            scoreRight = scoreForRelativeSeat(game.scores, mySeat: mySeatNo, target: .right)
        }
        passCount = game.passCount
        handNo = game.handNo
        if let firstLead = game.isFirstLeadTurn {
            isFirstLeadTurn = firstLead
        }
        gameFinished = game.gameFinished
        updateTurnTimer(game: game)

        if game.gameFinished {
            stopTurnTimer(clearTrust: false)
            if let winner = game.winnerSeat, let mySeatNo {
                let winnerPos = mapSeatToPlayerID(winner, mySeat: mySeatNo)
                hint = "本手结束：\(name(winnerPos))获胜"
            } else {
                hint = "本手结束"
            }
        } else if currentTurn == .me {
            hint = isAutoTrustMode ? "轮到你出牌（托管中）" : "轮到你出牌"
        } else {
            hint = "等待其他玩家"
        }
    }

    private func markSyncedNow() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        lastSyncText = formatter.string(from: Date())
    }

    private func trackReadyState(_ players: [RoomPlayer]) {
        let seated = players.filter { $0.seatNo != nil }
        if !readyBaselineCaptured {
            readyBaselineCaptured = true
            lastReadyByPlayer = Dictionary(uniqueKeysWithValues: seated.map { ($0.id, $0.isReady ?? false) })
            observedReadyPlayerIDs = []
            return
        }
        for p in seated {
            let readyNow = p.isReady ?? false
            let prev = lastReadyByPlayer[p.id]
            if readyNow, prev == false {
                observedReadyPlayerIDs.insert(p.id)
            }
            if !readyNow {
                observedReadyPlayerIDs.remove(p.id)
            }
            lastReadyByPlayer[p.id] = readyNow
        }
        let seatedIDs = Set(seated.map(\.id))
        observedReadyPlayerIDs = observedReadyPlayerIDs.intersection(seatedIDs)
    }

    private func updateTurnTimer(game: RoomGameState) {
        guard isMultiplayerMode, inRoom, !game.gameFinished else {
            stopTurnTimer(clearTrust: false)
            return
        }
        guard currentTurn == .me else {
            stopTurnTimer(clearTrust: false)
            return
        }
        let turnKey = "\(game.stateVersion)|\(game.currentTurnSeat ?? -1)|\(game.topCards.joined(separator: ","))|\(handCards.count)"
        guard turnKey != currentTurnKey else { return }
        currentTurnKey = turnKey
        let seconds = isAutoTrustMode ? 2 : 15
        startTurnTimer(seconds: seconds)
    }

    private func startTurnTimer(seconds: Int) {
        stopTurnTimer(clearTrust: false)
        turnCountdown = seconds
        turnTimerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var left = seconds
            while !Task.isCancelled, left > 0 {
                self.turnCountdown = left
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                left -= 1
            }
            guard !Task.isCancelled else { return }
            self.turnCountdown = 0
            await self.handleTurnTimeout()
        }
    }

    private func stopTurnTimer(clearTrust: Bool) {
        turnTimerTask?.cancel()
        turnTimerTask = nil
        turnCountdown = 0
        currentTurnKey = ""
        if clearTrust {
            isAutoTrustMode = false
        }
    }

    private func handleTurnTimeout() async {
        guard isMultiplayerMode, inRoom, !gameFinished, currentTurn == .me else { return }
        guard !actionInFlight else { return }
        if !isAutoTrustMode {
            isAutoTrustMode = true
            hint = "15秒未操作，已进入托管"
        }
        if let picked = topCards.isEmpty
            ? PaodekuaiRules.chooseLead(handCards, firstTurnMustSpade3: isFirstLeadTurn && handNo == 1, config: ruleConfig)
            : PaodekuaiRules.chooseBeat(handCards, topCards: topCards, config: ruleConfig) {
            await submitPlay(cards: picked)
            return
        }
        if !topCards.isEmpty {
            await submitPass()
        }
    }

    private func mapSeatToPlayerID(_ seat: Int?, mySeat: Int) -> PlayerID {
        guard let seat else { return .me }
        if seat == mySeat { return .me }
        if seat == (mySeat + 1) % 3 { return .right }
        return .left
    }

    private func countForRelativeSeat(_ counts: [String: Int], mySeat: Int, target: PlayerID) -> Int {
        let seat = seatFor(target: target, mySeat: mySeat)
        return counts[String(seat)] ?? 0
    }

    private func scoreForRelativeSeat(_ scores: [String: Int], mySeat: Int, target: PlayerID) -> Int {
        let seat = seatFor(target: target, mySeat: mySeat)
        return scores[String(seat)] ?? 0
    }

    private func seatFor(target: PlayerID, mySeat: Int) -> Int {
        switch target {
        case .me: return mySeat
        case .right: return (mySeat + 1) % 3
        case .left: return (mySeat + 2) % 3
        }
    }

    private func cardsFrom(rawCards: [String]) -> [Card]? {
        let cards = rawCards.compactMap(Card.from(raw:))
        return cards.count == rawCards.count ? PaodekuaiRules.sort(cards) : nil
    }

    private func placeholderCards(count: Int) -> [Card] {
        guard let c = Card.from(raw: "3C") else { return [] }
        return Array(repeating: c, count: count)
    }
}

// MARK: - Multiplayer Models & Services

enum ServerConfig {
    static let baseURL = "https://paodekuai.pokerjudge.com"
    static let wsURL = "wss://paodekuai.pokerjudge.com"
}

struct RoomPlayer: Codable, Identifiable {
    let id: String
    let nickname: String
    let isHost: Bool
    let isReady: Bool?
    let seatNo: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case isHost = "is_host"
        case isReady = "is_ready"
        case ready
        case seatNo = "seat_no"
    }

    init(id: String, nickname: String, isHost: Bool, isReady: Bool?, seatNo: Int?) {
        self.id = id
        self.nickname = nickname
        self.isHost = isHost
        self.isReady = isReady
        self.seatNo = seatNo
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? "玩家"
        isHost = try c.decodeIfPresent(Bool.self, forKey: .isHost) ?? false
        if let v = try c.decodeIfPresent(Bool.self, forKey: .isReady) {
            isReady = v
        } else {
            isReady = try c.decodeIfPresent(Bool.self, forKey: .ready)
        }
        seatNo = try c.decodeIfPresent(Int.self, forKey: .seatNo)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(isHost, forKey: .isHost)
        try c.encodeIfPresent(isReady, forKey: .isReady)
        try c.encodeIfPresent(seatNo, forKey: .seatNo)
    }
}

struct RoomGameState: Codable {
    let stateVersion: Int
    let currentTurnSeat: Int?
    let topCards: [String]
    let topOwnerSeat: Int?
    let isFirstLeadTurn: Bool?
    let gameFinished: Bool
    let winnerSeat: Int?
    let seatCardCounts: [String: Int]
    let scores: [String: Int]
    let passCount: Int
    let handNo: Int

    enum CodingKeys: String, CodingKey {
        case stateVersion = "state_version"
        case currentTurnSeat = "current_turn_seat"
        case topCards = "top_cards"
        case topOwnerSeat = "top_owner_seat"
        case isFirstLeadTurn = "is_first_lead_turn"
        case gameFinished = "game_finished"
        case winnerSeat = "winner_seat"
        case seatCardCounts = "seat_card_counts"
        case scores
        case passCount = "pass_count"
        case handNo = "hand_no"
    }
}

struct RoomSnapshot: Codable {
    let players: [RoomPlayer]
    let gameState: RoomGameState?
    let myHand: [String]?
    let handCards: [String]?
    let myCards: [String]?

    enum CodingKeys: String, CodingKey {
        case players
        case gameState = "game_state"
        case myHand = "my_hand"
        case handCards = "hand_cards"
        case myCards = "my_cards"
    }
}

struct RoomActionResponse: Codable {
    let ok: Bool
    let roomCode: String?
    let snapshot: RoomSnapshot?
    let myHand: [String]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case roomCode = "room_code"
        case snapshot
        case myHand = "my_hand"
        case error
    }
}

struct LocalRoomSession: Codable {
    var roomCode: String
    var playerID: String
}

final class RoomSessionPersistence {
    private let key = "paodekuai.native.v1.room_session"

    func save(_ session: LocalRoomSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func load() -> LocalRoomSession? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LocalRoomSession.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

final class IdentityService {
    private let clientIDKey = "runfast.multiplayer.client_id"
    private let nicknameKey = "runfast.multiplayer.nickname"

    func loadOrCreateClientID() -> String {
        if let existing = UserDefaults.standard.string(forKey: clientIDKey), !existing.isEmpty {
            return existing
        }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: clientIDKey)
        return value
    }

    func saveNickname(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed, forKey: nicknameKey)
    }

    func loadNickname() -> String {
        UserDefaults.standard.string(forKey: nicknameKey) ?? ""
    }
}

final class RoomService {
    enum RoomServiceError: Error, LocalizedError {
        case invalidURL
        case server(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL 配置无效"
            case .server(let message): return message
            case .badResponse: return "服务返回异常"
            }
        }
    }

    private let session: URLSession = .shared

    func performAction(
        action: String,
        roomCode: String? = nil,
        userID: String,
        nickname: String? = nil,
        cards: [String]? = nil,
        targetPlayerID: String? = nil,
        seatNo: Int? = nil,
        ready: Bool? = nil
    ) async throws -> RoomActionResponse {
        var payload: [String: Any] = [
            "action": action,
            "user_id": userID
        ]
        if let roomCode { payload["room_code"] = roomCode }
        if let nickname {
            payload["username"] = nickname
            payload["nickname"] = nickname
        }
        if let cards { payload["cards"] = cards }
        if let targetPlayerID { payload["target_player_id"] = targetPlayerID }
        if let seatNo { payload["seat_no"] = seatNo }
        if let ready { payload["ready"] = ready }
        return try await request(baseURL: ServerConfig.baseURL, payload: payload)
    }

    private func request(baseURL: String, payload: [String: Any]) async throws -> RoomActionResponse {
        guard let url = URL(string: baseURL + "/api/action") else {
            throw RoomServiceError.invalidURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw RoomServiceError.badResponse
        }

        if let decoded = try? JSONDecoder().decode(RoomActionResponse.self, from: data) {
            guard http.statusCode == 200, decoded.ok else {
                throw RoomServiceError.server(decoded.error ?? "请求失败(\(http.statusCode))")
            }
            return decoded
        }

        if (300...399).contains(http.statusCode) {
            let location = http.value(forHTTPHeaderField: "Location") ?? "unknown"
            throw RoomServiceError.server("服务重定向(\(http.statusCode)) -> \(location)")
        }

        let body = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let brief = body.isEmpty ? "empty body" : String(body.prefix(180))
        throw RoomServiceError.server("服务异常(\(http.statusCode)): \(brief)")
    }

    func mapError(_ error: Error) -> String {
        if let e = error as? RoomServiceError {
            return e.localizedDescription
        }
        if let e = error as? URLError {
            if e.code == .secureConnectionFailed {
                return "网络错误(-1200): HTTPS 握手失败，请检查是否启用了本地代理/抓包或是否绕过了 CDN。"
            }
            if e.code == .cannotFindHost {
                let host = URL(string: ServerConfig.baseURL)?.host ?? "当前域名"
                return "网络错误(-1003): 域名无法解析（\(host)），请确认 DNS 是否已生效。"
            }
            return "网络错误(\(e.code.rawValue)): \(e.localizedDescription)"
        }
        return error.localizedDescription
    }
}

@MainActor
final class RealtimeService {
    private var webSocketTask: URLSessionWebSocketTask?
    private var running = false

    func start(
        wsBaseURL: String,
        roomCode: String,
        playerID: String,
        onResponse: @escaping (RoomActionResponse) -> Void,
        onStatus: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        stop()
        running = true
        onStatus("连接中")
        
        guard let url = URL(string: "\(wsBaseURL)/ws/\(roomCode)/\(playerID)") else {
            onError("Invalid WebSocket URL")
            onStatus("连接地址无效")
            return
        }
        
        let request = URLRequest(url: url)
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        receiveMessage(onResponse: onResponse, onStatus: onStatus, onError: onError)
    }

    private func receiveMessage(
        onResponse: @escaping (RoomActionResponse) -> Void,
        onStatus: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard running else { return }
        
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self, self.running else { return }
                
                switch result {
                case .success(let message):
                    onStatus("已连接")
                    switch message {
                    case .string(let text):
                        if let data = text.data(using: .utf8) {
                            self.handleData(data, onResponse: onResponse, onError: onError)
                        }
                    case .data(let data):
                        self.handleData(data, onResponse: onResponse, onError: onError)
                    @unknown default:
                        break
                    }
                    
                    self.receiveMessage(onResponse: onResponse, onStatus: onStatus, onError: onError)
                    
                case .failure(let error):
                    onStatus("连接断开")
                    onError(error.localizedDescription)
                }
            }
        }
    }
    
    private func handleData(_ data: Data, onResponse: @escaping (RoomActionResponse) -> Void, onError: @escaping (String) -> Void) {
        Task { @MainActor in
            do {
                let response = try JSONDecoder().decode(RoomActionResponse.self, from: data)
                onResponse(response)
            } catch {
                print("Failed to decode WS message: \(error)")
            }
        }
    }

    func stop() {
        running = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
}
