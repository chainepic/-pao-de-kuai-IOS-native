import SwiftUI

struct GameView: View {
    private enum DragSelectionMode {
        case select
        case deselect
    }

    @EnvironmentObject var store: GameStore
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.zhHans.rawValue
    @State private var showNewGameConfirm = false
    @State private var showRules = false
    @State private var dragSelectionMode: DragSelectionMode?
    @State private var touchedCardIDs: Set<String> = []
    @State private var dragSelectingActive = false
    @State private var tableGlow = false
    private let handCardWidth: CGFloat = 50
    private let handCardStep: CGFloat = 21

    var body: some View {
        ZStack {
            GameFeltBackground(glow: tableGlow)

            VStack(spacing: 8) {
                header
                opponents
                tablePile
                myHand
                actions
                hint
                roundHistory
            }
            .padding(.horizontal, 10)
            .padding(.top, 4)
            .padding(.bottom, 8)

            if let effect = store.specialPlayEffect {
                specialPlayEffectOverlay(effect)
                    .transition(.scale(scale: 0.65).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.62), value: store.specialPlayEffect?.id)
        .onAppear {
            tableGlow = true
            if ProcessInfo.processInfo.arguments.contains("-screenshot_page"),
               let pageIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshot_page"),
               ProcessInfo.processInfo.arguments.indices.contains(ProcessInfo.processInfo.arguments.index(after: pageIndex)),
               ProcessInfo.processInfo.arguments[ProcessInfo.processInfo.arguments.index(after: pageIndex)] == "rules" {
                showRules = true
            }
        }
        .sheet(isPresented: $showRules) {
            RulesView()
                .environmentObject(store)
        }
        .alert(L10n.text("confirm_new_game_title"), isPresented: $showNewGameConfirm) {
            Button(L10n.text("confirm"), role: .destructive) {
                store.newGame()
            }
            Button(L10n.text("cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("confirm_new_game_message"))
        }
        .onChange(of: languageRawValue) {
            store.refreshLocalizedHintForCurrentState()
        }
    }

    private func specialPlayEffectOverlay(_ effect: SpecialPlayEffect) -> some View {
        let isChinese = AppLanguage(rawValue: languageRawValue) != .en
        let title: String = {
            switch effect.kind {
            case .bomb:
                return isChinese ? "炸弹" : "BOMB"
            case .airplane:
                return isChinese ? "飞机" : "AIRPLANE"
            }
        }()
        let colors: [Color] = {
            switch effect.kind {
            case .bomb:
                return [.yellow.opacity(0.95), .orange.opacity(0.9), .red.opacity(0.9)]
            case .airplane:
                return [.cyan.opacity(0.95), .blue.opacity(0.88), .purple.opacity(0.82)]
            }
        }()

        return Text(title)
            .font(.system(size: 46, weight: .black, design: .rounded))
            .tracking(2)
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                ZStack {
                    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [.white.opacity(0.48), .clear], center: .topLeading, startRadius: 0, endRadius: 130)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.65), lineWidth: 2))
            .shadow(color: colors.last?.opacity(0.5) ?? .orange.opacity(0.5), radius: 24, x: 0, y: 10)
            .scaleEffect(1.04)
            .allowsHitTesting(false)
    }

    private var header: some View {
        VStack(spacing: 4) {
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

                VStack(spacing: 4) {
                    Menu {
                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                languageRawValue = language.rawValue
                            } label: {
                                HStack {
                                    Text(language.displayName)
                                    if languageRawValue == language.rawValue {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "globe")
                            .font(.headline.weight(.semibold))
                            .frame(width: 24, height: 22)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel(L10n.text("language"))

                    Button {
                        store.toggleVoiceEnabled()
                    } label: {
                        Image(systemName: store.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.headline.weight(.semibold))
                            .frame(width: 24, height: 22)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.isVoiceEnabled ? L10n.text("voice_on") : L10n.text("voice_off"))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 5)
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
        .background(
            LinearGradient(
                colors: active
                    ? [Color(red: 0.96, green: 0.54, blue: 0.18).opacity(0.55), Color(red: 0.7, green: 0.16, blue: 0.1).opacity(0.42)]
                    : [Color.black.opacity(0.22), Color.black.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(active ? Color.white.opacity(0.55) : Color.white.opacity(0.15), lineWidth: active ? 2 : 1)
        )
        .cornerRadius(10)
        .shadow(color: active ? Color.orange.opacity(0.24) : .clear, radius: 10, x: 0, y: 5)
        .scaleEffect(active ? 1.02 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: active)
    }

    private var tablePile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text("table_pile"))
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                if store.topCards.isEmpty {
                    Text(L10n.text("table_waiting"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 22)
                } else {
                    HStack(spacing: -28) {
                        ForEach(store.topCards) { card in
                            cardView(card, selected: false)
                                .transition(.scale(scale: 0.82).combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 80)
        }
        .padding(10)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: store.topCards.map(\.id))
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
                let availableWidth = max(proxy.size.width, cardWidth)
                let fittedStep = count > 1 ? (availableWidth - cardWidth) / CGFloat(count - 1) : handCardStep
                let step = max(15, min(handCardStep, fittedStep))

                ZStack(alignment: .topLeading) {
                    ForEach(Array(store.handCards.enumerated()), id: \.element.id) { index, card in
                        let isSelected = store.selected.contains(card.id)
                        cardView(card, selected: isSelected)
                            .offset(x: CGFloat(index) * step, y: isSelected ? -14 : 0)
                            .rotationEffect(.degrees(isSelected ? -1.5 : 0), anchor: .bottom)
                            .zIndex(Double(index))
                            .animation(.spring(response: 0.32, dampingFraction: 0.68), value: isSelected)
                            .onTapGesture {
                                store.beginManualSelection()
                                store.toggle(card)
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.vertical, 16)
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
    }

    private var actions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(store.gameFinished ? L10n.text("next_hand") : L10n.text("play")) {
                    if store.gameFinished {
                        store.startNextHand()
                    } else {
                        store.playSelected()
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                
                Button(L10n.text("pass")) { store.pass() }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            HStack(spacing: 8) {
                Button(L10n.text("declare_single")) { store.declareSingle() }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(!store.canDeclareSingle)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Button(L10n.text("new_game")) { showNewGameConfirm = true }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity)
                    Button(L10n.text("settings")) { showRules = true }
                        .buttonStyle(SecondaryActionButtonStyle())
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var hint: some View {
        Text(store.hint)
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
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
                ForEach(store.roundResults.suffix(7).reversed()) { item in
                    HStack(spacing: 0) {
                        rowCell("\(item.handNo)")
                        rowCell(scoreCellText(item.deltaMe, bombedCount: bombedCount(for: .me, item: item)))
                        rowCell(scoreCellText(item.deltaLeft, bombedCount: bombedCount(for: .left, item: item)))
                        rowCell(scoreCellText(item.deltaRight, bombedCount: bombedCount(for: .right, item: item)))
                    }
                }
            }
        }
        .padding(10)
        .background(.black.opacity(store.roundResults.isEmpty ? 0 : 0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(store.roundResults.isEmpty ? 0 : 0.12), lineWidth: 1))
    }

    private func cardView(_ card: Card, selected: Bool) -> some View {
        PlayingCardView(card: card, selected: selected, width: handCardWidth)
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

    private func scoreCellText(_ value: Int, bombedCount: Int = 0) -> String {
        let base = value >= 0 ? "+\(value)" : "\(value)"
        guard bombedCount > 0 else { return base }
        return base + " 💣"
    }

    private func bombedCount(for player: PlayerID, item: RoundResult) -> Int {
        switch player {
        case .me: return item.bombedMe
        case .left: return item.bombedLeft
        case .right: return item.bombedRight
        }
    }
}
