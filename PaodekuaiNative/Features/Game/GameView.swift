import SwiftUI

struct GameView: View {
    private enum DragSelectionMode {
        case select
        case deselect
    }

    @EnvironmentObject var store: GameStore
    @EnvironmentObject var monetization: MonetizationStore
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.zhHans.rawValue
    @State private var showNewGameConfirm = false
    @State private var showRules = false
    @State private var dragSelectionMode: DragSelectionMode?
    @State private var touchedCardIDs: Set<String> = []
    @State private var dragSelectingActive = false
    @State private var playerToKick: RoomPlayer?
    private let handCardWidth: CGFloat = 50
    private let handCardStep: CGFloat = 22

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.35, blue: 0.22), Color(red: 0.03, green: 0.2, blue: 0.13)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                header
                roomPanel
                opponents
                tablePile
                myHand
                actions
                hint
                roundHistory
            }
            .padding(12)
        }
        .sheet(isPresented: $showRules) {
            RulesView()
                .environmentObject(store)
                .environmentObject(monetization)
        }
        .fullScreenCover(isPresented: $monetization.showAdBreak) {
            AdBreakView {
                monetization.finishAdBreak()
            }
        }
        .alert(L10n.text("confirm_new_game_title"), isPresented: $showNewGameConfirm) {
            Button(L10n.text("confirm"), role: .destructive) {
                store.newGame()
            }
            Button(L10n.text("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("confirm_new_game_message"))
        }
        .onChange(of: languageRawValue) { _, _ in
            store.refreshLocalizedHintForCurrentState()
        }
        .onChange(of: store.roundResults.count) { _, _ in
            monetization.recordCompletedHand()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: {
                    withAnimation {
                        store.showWelcomeScreen = true
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text("app_title"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(L10n.format("hand_no_format", store.handNo))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.format("score_me_format", store.scoreMe))
                    Text(L10n.format("score_left_format", store.scoreLeft))
                    Text(L10n.format("score_right_format", store.scoreRight))
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 8) {
                Text(L10n.text("language"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Picker("", selection: $languageRawValue) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Button(store.isVoiceEnabled ? "语音开" : "语音关") {
                    store.toggleVoiceEnabled()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .frame(width: 88)
            }
            if !monetization.isPremium {
                HStack {
                    Text(L10n.format("ad_countdown_format", monetization.handsLeftUntilAd))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if monetization.purchaseInProgress {
                        ProgressView()
                            .tint(.white)
                    }
                    Button(L10n.text("remove_ads_price")) {
                        Task { await monetization.purchaseRemoveAds() }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 120)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    
                    Button(L10n.text("restore_purchase")) {
                        Task { await monetization.restorePurchases() }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .frame(width: 90)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                if let error = monetization.purchaseErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.yellow.opacity(0.95))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private var roomPanel: some View {
        if store.isMultiplayerMode {
            multiplayerRoomPanel
        }
    }

    private var multiplayerRoomPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("房间")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Spacer()
                if store.inRoom {
                    Text("房间码 \(store.roomCode)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            if !store.inRoom {
                multiplayerLobbyInputs
            } else {
                seatBoard
                multiplayerRoomActions
            }

            if !store.errorMessage.isEmpty {
                Text(store.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.95))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .cornerRadius(10)
    }

    private var multiplayerLobbyInputs: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("输入你的昵称", text: $store.nicknameInput)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
            }
            HStack(spacing: 8) {
                TextField("输入房间码", text: $store.roomCodeInput)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .padding(8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(8)
                Button("开房") {
                    Task { await store.createRoom() }
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(store.isLoadingRoom)
                Button("加入") {
                    Task { await store.joinRoom() }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.isLoadingRoom)
            }
            if store.isLoadingRoom {
                ProgressView("连接中...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var multiplayerRoomActions: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if store.canOperateRoomSeats {
                    Button("开始") {
                        Task { await store.startRoomGame() }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(!store.canStartRoomGame)
                }
                Button("离开房间") {
                    Task { await store.leaveRoom() }
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            if store.canOperateRoomSeats, !store.canStartRoomGame, let reason = store.startBlockReason {
                Text("未满足开始条件：\(reason)")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var seatBoard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("座位（0/1/2）")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 8) {
                ForEach([0, 1, 2], id: \.self) { seat in
                    seatCard(for: seat)
                }
            }
        }
        .alert("提示", isPresented: Binding(
            get: { playerToKick != nil },
            set: { if !$0 { playerToKick = nil } }
        )) {
            Button("踢出", role: .destructive) {
                if let p = playerToKick {
                    Task { await store.kickPlayer(p.id) }
                }
                playerToKick = nil
            }
            Button("取消", role: .cancel) {
                playerToKick = nil
            }
        } message: {
            if let p = playerToKick {
                Text("是否踢出玩家 \(p.nickname)？")
            }
        }
    }

    private func seatCard(for seat: Int) -> some View {
        VStack(spacing: 6) {
            Text("Seat \(seat)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
            
            let player = store.roomPlayers.first(where: { $0.seatNo == seat })
            
            Text(player?.nickname ?? "空位")
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
                .onTapGesture {
                    if let p = player,
                       store.canOperateRoomSeats,
                       p.id != store.myPlayerID,
                       !(p.isReady ?? false),
                       !store.roomHasGameState {
                        playerToKick = p
                    }
                }
            
                    if let player = player {
                        if player.id == store.myPlayerID {
                            Toggle("", isOn: Binding(
                                get: { player.isReady ?? false },
                                set: { newValue in
                                    if !store.roomHasGameState && !store.isReadySubmitting {
                                        Task { await store.setReady(newValue) }
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                            .scaleEffect(0.65)
                            .frame(width: 44, height: 28)
                            .contentShape(Rectangle()) // <--- 扩大点击热区
                            .disabled(store.isReadySubmitting || store.roomHasGameState)
                        } else {
                            Text((player.isReady ?? false) ? "已准备" : "未准备")
                                .font(.caption2)
                                .foregroundStyle((player.isReady ?? false) ? .green : .yellow)
                                .frame(height: 20)
                        }
                    } else {
                        Text("-")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(height: 20)
                    }
            seatAssignMenu(seatNo: seat)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.black.opacity(0.16))
        .cornerRadius(8)
    }

    private func seatAssignMenu(seatNo: Int) -> some View {
        let _ = seatNo
        return Text("后端暂不支持调座")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
    }

    private var opponents: some View {
        HStack(spacing: 10) {
            opponentBox(title: store.name(.left), cards: store.leftCards.count, active: store.currentTurn == .left)
            opponentBox(title: store.name(.me), cards: store.handCards.count, active: store.currentTurn == .me)
            opponentBox(title: store.name(.right), cards: store.rightCards.count, active: store.currentTurn == .right)
        }
    }

    private func opponentBox(title: String, cards: Int, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            Text(L10n.format("remaining_cards_format", cards)).font(.caption)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(active ? Color.blue.opacity(0.35) : Color.black.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(active ? Color.blue.opacity(0.9) : Color.white.opacity(0.15), lineWidth: active ? 2 : 1)
        )
        .cornerRadius(10)
    }

    private var tablePile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("table_pile"))
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -28) {
                    ForEach(store.topCards) { card in
                        cardView(card, selected: false)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
            .frame(height: 80)
            if let owner = store.topOwner {
                Text(L10n.format("recent_play_format", store.name(owner)))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.18))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .cornerRadius(10)
    }

    private var myHand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.text("my_hand"))
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.white)
                Spacer()
                Text(L10n.format("selected_count_format", store.selected.count))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }
            GeometryReader { proxy in
                let count = store.handCards.count
                let cardWidth = handCardWidth
                let step = handCardStep

                ZStack(alignment: .topLeading) {
                    ForEach(Array(store.handCards.enumerated()), id: \.element.id) { index, card in
                        let isSelected = store.selected.contains(card.id)
                        cardView(card, selected: isSelected)
                            .offset(x: CGFloat(index) * step, y: isSelected ? -14 : 0)
                            .zIndex(Double(index))
                            .onTapGesture {
                                store.beginManualSelection()
                                store.toggle(card)
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 16)
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            startDragSelection()
                            handleDragSelection(at: value.location, count: count, cardWidth: cardWidth, step: step)
                        }
                        .onEnded { _ in
                            finishDragSelection()
                        }
                )
            }
            .frame(height: 100)
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .cornerRadius(10)
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(store.gameFinished ? L10n.text("next_hand") : L10n.text("play")) {
                    if store.gameFinished {
                        store.newGame()
                    } else {
                        store.playSelected()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.isMultiplayerMode && !store.inRoom)
                
                Button(L10n.text("pass")) { store.pass() }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(store.isMultiplayerMode && !store.inRoom)
            }
            HStack(spacing: 8) {
                Button(L10n.text("new_game")) { showNewGameConfirm = true }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(store.isMultiplayerMode && !store.canStartRoomGame)
                Button(L10n.text("rules")) { showRules = true }
                    .buttonStyle(SecondaryActionButtonStyle())
            }
            if store.isMultiplayerMode && store.inRoom && !store.gameFinished {
                Text("当前出牌：\(store.name(store.currentTurn))")
                    .font(.footnote.bold())
                    .foregroundStyle(store.currentTurn == .me ? .green : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if store.currentTurn == .me {
                    Text(store.isAutoTrustMode ? "托管中：\(store.turnCountdown)s 后自动操作" : "出牌倒计时：\(store.turnCountdown)s")
                        .font(.caption)
                        .foregroundStyle(store.isAutoTrustMode ? .yellow : .white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if store.isAutoTrustMode {
                    Text("托管已开启，轮到你时将自动出牌")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var hint: some View {
        Text(store.hint)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.black.opacity(0.2))
            .cornerRadius(10)
    }

    private var roundHistory: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text("round_history"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            if store.roundResults.isEmpty {
                Text(L10n.text("round_history_empty"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                HStack(spacing: 0) {
                    headerCell(L10n.text("round_col_hand"))
                    headerCell(L10n.text("round_col_me"))
                    headerCell(L10n.text("round_col_left"))
                    headerCell(L10n.text("round_col_right"))
                }
                .padding(.bottom, 2)
                ForEach(store.roundResults.suffix(5).reversed()) { item in
                    HStack(spacing: 0) {
                        rowCell("\(item.handNo)")
                        rowCell(scoreCellText(item.deltaMe))
                        rowCell(scoreCellText(item.deltaLeft))
                        rowCell(scoreCellText(item.deltaRight))
                    }
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private func cardView(_ card: Card, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.rank.rawValue).font(.headline).bold()
            Text(card.suit.symbol).font(.subheadline)
            Spacer()
        }
        .foregroundStyle(card.isRed ? Color.red : Color.black)
        .padding(6)
        .frame(width: handCardWidth, height: 78, alignment: .topLeading)
        .background(selected ? Color(red: 0.84, green: 0.89, blue: 1.0) : Color.white)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5), lineWidth: 1))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
    }

    private func cardIndex(at point: CGPoint, count: Int, cardWidth: CGFloat, step: CGFloat) -> Int? {
        guard count > 0 else { return nil }
        let minY: CGFloat = 0
        let maxY: CGFloat = 96
        guard point.y >= minY, point.y <= maxY else { return nil }

        let adjustedX = max(0, point.x)
        let estimated = Int(round(adjustedX / max(step, 1)))
        return min(max(0, estimated), count - 1)
    }

    private func startDragSelection() {
        guard !dragSelectingActive else { return }
        dragSelectingActive = true
        touchedCardIDs = []
        dragSelectionMode = nil
        store.beginManualSelection()
    }

    private func handleDragSelection(at point: CGPoint, count: Int, cardWidth: CGFloat, step: CGFloat) {
        guard dragSelectingActive else { return }
        guard let index = cardIndex(at: point, count: count, cardWidth: cardWidth, step: step) else { return }
        let card = store.handCards[index]
        if touchedCardIDs.contains(card.id) { return }
        touchedCardIDs.insert(card.id)

        if dragSelectionMode == nil {
            dragSelectionMode = store.selected.contains(card.id) ? .deselect : .select
        }
        store.applyDragSelection(card: card, selecting: dragSelectionMode == .select)
    }

    private func finishDragSelection() {
        guard dragSelectingActive else { return }
        dragSelectingActive = false
        dragSelectionMode = nil
        touchedCardIDs = []
        store.endManualSelection()
    }

    private func headerCell(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func rowCell(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private func scoreCellText(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(Color.blue.opacity(configuration.isPressed ? 0.7 : 0.9))
            .cornerRadius(10)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(Color.black.opacity(configuration.isPressed ? 0.25 : 0.35))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.25), lineWidth: 1))
            .cornerRadius(10)
    }
}

struct AdBreakView: View {
    @State private var secondsLeft = 3
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 14) {
                Text(L10n.text("ad_break_title"))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Text(L10n.text("ad_break_subtitle"))
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                Text(L10n.format("ad_break_wait_format", secondsLeft))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                Button(L10n.text("ad_break_close")) {
                    onClose()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(secondsLeft > 0)
                .opacity(secondsLeft > 0 ? 0.5 : 1)
                .frame(width: 180)
            }
            .padding(24)
        }
        .onAppear {
            secondsLeft = 3
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                if secondsLeft <= 0 {
                    timer.invalidate()
                } else {
                    secondsLeft -= 1
                }
            }
        }
    }
}
