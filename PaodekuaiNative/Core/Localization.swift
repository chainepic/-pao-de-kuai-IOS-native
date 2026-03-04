import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans = "zh-Hans"
    case en = "en"

    static let storageKey = "paodekuai.native.language"

    var id: String { rawValue }
    var speechCode: String {
        switch self {
        case .zhHans: return "zh-CN"
        case .en: return "en-US"
        }
    }

    var displayName: String {
        switch self {
        case .zhHans: return "中文"
        case .en: return "English"
        }
    }
}

enum L10n {
    private static let zhHans: [String: String] = [
        "app_title": "湖南跑得快（单机）",
        "hand_no_format": "第%d手",
        "player_me": "我方",
        "player_left": "上家",
        "player_right": "下家",
        "score_me_format": "我方 %d",
        "score_left_format": "上家 %d",
        "score_right_format": "下家 %d",
        "remaining_cards_format": "剩余 %d 张",
        "table_pile": "桌面牌堆",
        "recent_play_format": "最近出牌：%@",
        "my_hand": "我的手牌",
        "selected_count_format": "已选 %d",
        "play": "出牌",
        "next_hand": "下一手",
        "pass": "过牌",
        "new_game": "新对局",
        "rules": "规则",
        "language": "语言",
        "round_result": "本手结算",
        "round_history": "结算历史",
        "round_history_empty": "暂无结算记录",
        "round_col_hand": "手数",
        "round_col_me": "我方",
        "round_col_left": "上家",
        "round_col_right": "下家",
        "round_result_line_format": "第%d手 %@：我方%+d 上家%+d 下家%+d",
        "hint_tap_new_game": "点击“新对局”开始",
        "hint_new_round_first_format": "新一手开始，%@先手",
        "hint_first_lead_no_pass": "先手不能过牌",
        "hint_must_beat_no_pass": "有大必出，不能过牌",
        "hint_must_beat_cycle_format": "有大必出，已为你选择第%d/%d组可出牌",
        "hint_drag_select_ready": "长按后可拖动批量选牌",
        "hint_first_turn_need_3s": "首手必须包含黑桃3",
        "hint_cannot_beat_top": "不能压过桌面牌",
        "hint_played_cards_format": "%@出牌：%@",
        "hint_two_pass_reset_format": "两家过牌，%@重新领出",
        "hint_player_pass_format": "%@过牌",
        "voice_player_cannot_beat_format": "%@要不起",
        "hint_round_finish_format": "本手结束：%@获胜",
        "hint_restored_local_state": "已恢复本地进度",
        "hint_action_ready": "请选择要出的牌",
        "hint_waiting_player_format": "等待%@出牌",
        "hint_bomb_must_play": "炸弹必出已开启，请先出炸弹",
        "confirm_new_game_title": "开始新对局？",
        "confirm_new_game_message": "当前对局进度会被覆盖。",
        "confirm": "确认",
        "cancel": "取消",
        "rules_page_title": "完整游戏规则",
        "rules_deck_title": "1. 牌组与发牌",
        "rules_deck_body": "使用湖南跑得快 48 张牌（去掉红桃2、方块2、梅花2、方块A），三家各 16 张。",
        "rules_turn_title": "2. 出牌顺序",
        "rules_turn_body": "第一手必须包含黑桃3；之后由上手出牌者的下家接牌。两家都过牌后，最后出牌者重新领出。",
        "rules_play_title": "3. 合法牌型",
        "rules_play_body": "支持：单张、对子、顺子、连对、三带二、飞机带翅膀、炸弹。",
        "rules_compare_title": "4. 牌型比较",
        "rules_compare_body": "同牌型且同张数才可比较主牌大小；炸弹可压非炸弹，炸弹之间比较点数。",
        "rules_must_title": "5. 过牌限制",
        "rules_must_body": "若你手中存在可压过当前桌面牌的牌，则不可选择“过牌”。",
        "rules_score_title": "6. 计分规则",
        "rules_score_body": "每手结束后，赢家获得两家罚分之和。输家罚分：剩1张及以下记0，剩15张记15，剩16张记30，其余按剩余张数计。",
        "rules_setting_title": "7. 牌局设置",
        "rules_setting_body": "可配置三带一、三不带、炸弹必出（明炸）以及常见规则预设。",
        "rules_preset": "规则预设",
        "rules_preset_hunanClassic": "湖南常规",
        "rules_preset_relaxed": "宽松模式",
        "rules_preset_bombPriority": "炸弹优先",
        "rules_preset_custom": "自定义",
        "rules_allow_triple_with_one": "允许三带一",
        "rules_allow_triple_without_wing": "允许三不带",
        "rules_bomb_must_play": "炸弹必出（明炸）",
        "ad_countdown_format": "免费模式：再玩%d手后看广告",
        "remove_ads_price": "去广告 $4.99",
        "restore_purchase": "恢复购买",
        "purchase_error_product_not_found": "未找到内购商品，请检查 App Store Connect 配置",
        "purchase_error_unverified": "购买校验失败，请稍后重试",
        "purchase_error_unknown": "购买失败，请稍后重试",
        "purchase_pending": "购买处理中，请稍后确认",
        "restore_nothing": "未找到可恢复的购买记录",
        "ad_break_title": "广告时间",
        "ad_break_subtitle": "免费用户每 10 手展示一次广告",
        "ad_break_wait_format": "可关闭倒计时：%d 秒",
        "ad_break_close": "关闭广告",
        "invalid_no_selection": "未选择牌",
        "invalid_shape": "牌型不合法",
        "voice_pair_prefix": "对",
        "voice_bomb_suffix": "炸弹",
        "voice_straight": "顺子",
        "voice_triple": "三张",
        "voice_triple_with_one": "三带一",
        "voice_triple_with_two": "三带二",
        "voice_airplane_with_wings": "飞机带牌",
        "voice_consecutive_pairs": "连对",
        "voice_rank_a": "尖",
        "voice_rank_t": "十",
        "voice_rank_2": "十",
        "voice_rank_j": "勾",
        "voice_rank_q": "圈",
        "speech_bomb_item_format": "%@有效炸弹%d个",
        "speech_bomb_prefix_format": "。%@",
        "speech_round_finish_format": "%@先跑完。%@剩%d张，%@剩%d张%@。%@%+d分，%@%+d分，%@%+d分。"
    ]

    private static let en: [String: String] = [
        "app_title": "Hunan Paodekuai",
        "hand_no_format": "Hand %d",
        "player_me": "Me",
        "player_left": "Left",
        "player_right": "Right",
        "score_me_format": "Me %d",
        "score_left_format": "Left %d",
        "score_right_format": "Right %d",
        "remaining_cards_format": "%d cards left",
        "table_pile": "Table Pile",
        "recent_play_format": "Last play: %@",
        "my_hand": "My Hand",
        "selected_count_format": "Selected %d",
        "play": "Play",
        "next_hand": "Next Hand",
        "pass": "Pass",
        "new_game": "New Round",
        "rules": "Rules",
        "language": "Language",
        "round_result": "Round Result",
        "round_history": "Round History",
        "round_history_empty": "No round history yet",
        "round_col_hand": "Hand",
        "round_col_me": "Me",
        "round_col_left": "Left",
        "round_col_right": "Right",
        "round_result_line_format": "Hand %d %@: Me%+d Left%+d Right%+d",
        "hint_tap_new_game": "Tap \"New Round\" to start",
        "hint_new_round_first_format": "New hand started, %@ leads",
        "hint_first_lead_no_pass": "Leader cannot pass",
        "hint_must_beat_no_pass": "You must play if you can beat",
        "hint_must_beat_cycle_format": "You can beat. Selected option %d/%d",
        "hint_drag_select_ready": "Long-press then drag to batch select",
        "hint_first_turn_need_3s": "First play must include 3 of Spades",
        "hint_cannot_beat_top": "Cannot beat current top play",
        "hint_played_cards_format": "%@ played: %@",
        "hint_two_pass_reset_format": "Two players passed, %@ leads again",
        "hint_player_pass_format": "%@ passed",
        "voice_player_cannot_beat_format": "%@ passes",
        "hint_round_finish_format": "Round finished: %@ wins",
        "hint_restored_local_state": "Local progress restored",
        "hint_action_ready": "Choose cards to play",
        "hint_waiting_player_format": "Waiting for %@",
        "hint_bomb_must_play": "Bomb-must-play is on, play a bomb first",
        "confirm_new_game_title": "Start a new round?",
        "confirm_new_game_message": "Current round progress will be overwritten.",
        "confirm": "Confirm",
        "cancel": "Cancel",
        "rules_page_title": "Full Game Rules",
        "rules_deck_title": "1. Deck and Deal",
        "rules_deck_body": "Use 48 cards (remove 2H, 2D, 2C, AD). Three players each get 16 cards.",
        "rules_turn_title": "2. Turn Order",
        "rules_turn_body": "The first hand must include 3 of Spades. After that, turns continue in order. If two players pass, the last player who played leads again.",
        "rules_play_title": "3. Valid Plays",
        "rules_play_body": "Supported plays: single, pair, straight, consecutive pairs, triple-with-two, airplane-with-wings, bomb.",
        "rules_compare_title": "4. Comparison Rules",
        "rules_compare_body": "Only same type and same length can compare by rank. Bomb beats non-bomb. Bomb vs bomb compares rank.",
        "rules_must_title": "5. Pass Restriction",
        "rules_must_body": "If you have any valid play that can beat the current top play, passing is not allowed.",
        "rules_score_title": "6. Scoring",
        "rules_score_body": "At round end, winner gains the sum of both losers' penalties. Loser penalty: 0 for <=1 card left, 15 for 15 cards left, 30 for 16 cards left, otherwise equal to remaining card count.",
        "rules_setting_title": "7. Match Settings",
        "rules_setting_body": "You can configure triple-with-one, triple-only, bomb-must-play, and common presets.",
        "rules_preset": "Preset",
        "rules_preset_hunanClassic": "Hunan Classic",
        "rules_preset_relaxed": "Relaxed",
        "rules_preset_bombPriority": "Bomb Priority",
        "rules_preset_custom": "Custom",
        "rules_allow_triple_with_one": "Allow triple with one",
        "rules_allow_triple_without_wing": "Allow triple only",
        "rules_bomb_must_play": "Bomb must play",
        "ad_countdown_format": "Free mode: ad after %d more hands",
        "remove_ads_price": "No Ads $4.99",
        "restore_purchase": "Restore",
        "purchase_error_product_not_found": "IAP product not found. Check App Store Connect.",
        "purchase_error_unverified": "Purchase verification failed. Please retry.",
        "purchase_error_unknown": "Purchase failed. Please retry.",
        "purchase_pending": "Purchase is pending.",
        "restore_nothing": "No purchases to restore.",
        "ad_break_title": "Ad Break",
        "ad_break_subtitle": "Free users watch one ad every 10 hands",
        "ad_break_wait_format": "Close available in %d s",
        "ad_break_close": "Close",
        "invalid_no_selection": "No card selected",
        "invalid_shape": "Invalid card combination",
        "voice_pair_prefix": "Pair of ",
        "voice_bomb_suffix": " bomb",
        "voice_straight": "Straight",
        "voice_triple": "Triple",
        "voice_triple_with_one": "Triple with one",
        "voice_triple_with_two": "Triple with two",
        "voice_airplane_with_wings": "Airplane with wings",
        "voice_consecutive_pairs": "Consecutive pairs",
        "voice_rank_a": "Ace",
        "voice_rank_t": "ten",
        "voice_rank_2": "ten",
        "voice_rank_j": "Jack",
        "voice_rank_q": "Queen",
        "speech_bomb_item_format": "%@ has %d valid bombs",
        "speech_bomb_prefix_format": ". %@",
        "speech_round_finish_format": "%@ finishes first. %@ has %d cards left, %@ has %d cards left%@. Score this round: %@ %+d, %@ %+d, %@ %+d."
    ]

    static func currentLanguage() -> AppLanguage {
        let raw = UserDefaults.standard.string(forKey: AppLanguage.storageKey)
        return AppLanguage(rawValue: raw ?? "") ?? .zhHans
    }

    static func text(_ key: String, language: AppLanguage? = nil) -> String {
        let resolved = language ?? currentLanguage()
        let dict = resolved == .en ? en : zhHans
        return dict[key] ?? key
    }

    static func format(_ key: String, language: AppLanguage? = nil, _ args: CVarArg...) -> String {
        let resolved = language ?? currentLanguage()
        let locale = resolved == .en ? Locale(identifier: "en_US") : Locale(identifier: "zh_Hans_CN")
        return String(format: text(key, language: resolved), locale: locale, arguments: args)
    }
}
