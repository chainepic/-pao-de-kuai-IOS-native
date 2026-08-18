import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var store: GameStore
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack {
                rulesBackgroundColor
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("", selection: $selectedTab) {
                        Text(L10n.text("tab_rules")).tag(0)
                        Text(L10n.text("tab_settings")).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, horizontalSizeClass == .regular ? 32 : 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: horizontalSizeClass == .regular ? 720 : .infinity)
                    
                    Divider()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            if selectedTab == 0 {
                                rulesAndStrategyPanel
                            } else {
                                settingsPanel
                                aboutPanel
                            }
                        }
                        .padding(.vertical, 32)
                        .padding(.horizontal, horizontalSizeClass == .regular ? 40 : 24)
                        .frame(maxWidth: horizontalSizeClass == .regular ? 760 : .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle(L10n.text("rules_page_title"))
            .toolbar {
                ToolbarItem {
                    Button(L10n.text("confirm")) {
                        dismiss()
                    }
                    .font(.body.bold())
                }
            }
        }
    }

    // MARK: - Rules & Strategy (Typography Focused)
    private var rulesAndStrategyPanel: some View {
        VStack(alignment: .leading, spacing: 40) {
            
            // Basic Rules Section
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.text("rules_page_title"))
                    .font(.system(.title, design: .serif, weight: .bold))
                
                typographyRow(titleKey: "rules_deck_title", bodyKey: "rules_deck_body")
                typographyRow(titleKey: "rules_turn_title", bodyKey: "rules_turn_body")
                typographyRow(titleKey: "rules_play_title", bodyKey: "rules_play_body")
                typographyRow(titleKey: "rules_compare_title", bodyKey: "rules_compare_body")
                typographyRow(titleKey: "rules_must_title", bodyKey: "rules_must_body")
                typographyRow(titleKey: "rules_score_title", bodyKey: "rules_score_body")
            }
            
            Divider()
            
            // Strategy & Tips Section
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.text("strategy_title"))
                    .font(.system(.title, design: .serif, weight: .bold))
                
                typographyRow(titleKey: "strategy_1_title", bodyKey: "strategy_1_body")
                typographyRow(titleKey: "strategy_2_title", bodyKey: "strategy_2_body")
                typographyRow(titleKey: "strategy_3_title", bodyKey: "strategy_3_body")
                typographyRow(titleKey: "strategy_4_title", bodyKey: "strategy_4_body")
            }
        }
    }
    
    private func typographyRow(titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(titleKey))
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(L10n.text(bodyKey))
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(6)
        }
    }

    // MARK: - Settings Panel
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("rules_setting_title"))
                .font(.title2.bold())
            
            Text(L10n.text("rules_setting_body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                HStack {
                    Text(L10n.text("rules_preset"))
                        .foregroundStyle(.primary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { store.ruleConfig.preset },
                        set: { store.setRulePreset($0) }
                    )) {
                        ForEach(RulePreset.allCases) { preset in
                            Text(presetTitle(preset)).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 16)
                
                Divider()

                Toggle(L10n.text("rules_allow_triple_with_one"), isOn: Binding(
                    get: { store.ruleConfig.allowTripleWithOne },
                    set: { store.setAllowTripleWithOne($0) }
                ))
                .padding(.vertical, 16)

                Divider()

                Toggle(L10n.text("rules_allow_triple_without_wing"), isOn: Binding(
                    get: { store.ruleConfig.allowTripleWithoutWing },
                    set: { store.setAllowTripleWithoutWing($0) }
                ))
                .padding(.vertical, 16)

                Divider()

                Toggle(L10n.text("rules_bomb_must_play"), isOn: Binding(
                    get: { store.ruleConfig.bombMustPlay },
                    set: { store.setBombMustPlay($0) }
                ))
                .padding(.vertical, 16)
            }
        }
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.text("about_title"))
                .font(.title2.bold())
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 0) {
                if let url = URL(string: L10n.text("privacy_policy_url")) {
                    Link(destination: url) {
                        HStack {
                            Text(L10n.text("privacy_policy_title"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.bold())
                                .foregroundStyle(tertiaryLabelColor)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    private func presetTitle(_ preset: RulePreset) -> String {
        L10n.text("rules_preset_\(preset.rawValue)")
    }

    private var rulesBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    private var tertiaryLabelColor: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(uiColor: .tertiaryLabel)
        #endif
    }
}
