import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    settingPanel
                    ruleSection("rules_deck_title", "rules_deck_body")
                    ruleSection("rules_turn_title", "rules_turn_body")
                    ruleSection("rules_play_title", "rules_play_body")
                    ruleSection("rules_compare_title", "rules_compare_body")
                    ruleSection("rules_must_title", "rules_must_body")
                    ruleSection("rules_score_title", "rules_score_body")
                }
                .padding(16)
            }
            .navigationTitle(L10n.text("rules_page_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.text("confirm")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func ruleSection(_ titleKey: String, _ bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.text(titleKey))
                .font(.headline)
                .foregroundStyle(.primary)
            Text(L10n.text(bodyKey))
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    private var settingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("rules_setting_title"))
                .font(.headline)
            Text(L10n.text("rules_setting_body"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker(L10n.text("rules_preset"), selection: Binding(
                get: { store.ruleConfig.preset },
                set: { store.setRulePreset($0) }
            )) {
                ForEach(RulePreset.allCases) { preset in
                    Text(presetTitle(preset)).tag(preset)
                }
            }
            .pickerStyle(.menu)

            Toggle(L10n.text("rules_allow_triple_with_one"), isOn: Binding(
                get: { store.ruleConfig.allowTripleWithOne },
                set: { store.setAllowTripleWithOne($0) }
            ))
            Toggle(L10n.text("rules_allow_triple_without_wing"), isOn: Binding(
                get: { store.ruleConfig.allowTripleWithoutWing },
                set: { store.setAllowTripleWithoutWing($0) }
            ))
            Toggle(L10n.text("rules_bomb_must_play"), isOn: Binding(
                get: { store.ruleConfig.bombMustPlay },
                set: { store.setBombMustPlay($0) }
            ))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(10)
    }

    private func presetTitle(_ preset: RulePreset) -> String {
        L10n.text("rules_preset_\(preset.rawValue)")
    }
}
