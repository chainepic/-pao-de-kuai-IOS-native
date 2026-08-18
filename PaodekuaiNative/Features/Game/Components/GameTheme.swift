import SwiftUI

enum GameTheme {
    static let tableTop = Color(red: 0.03, green: 0.25, blue: 0.16)
    static let tableBottom = Color(red: 0.01, green: 0.11, blue: 0.08)
    static let accentTop = Color(red: 0.95, green: 0.5, blue: 0.18)
    static let accentBottom = Color(red: 0.74, green: 0.16, blue: 0.1)
    static let panel = Color.black.opacity(0.18)
    static let panelStrong = Color.black.opacity(0.35)
    static let panelStroke = Color.white.opacity(0.15)

    static var actionGradient: LinearGradient {
        LinearGradient(colors: [accentTop, accentBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct GameFeltBackground: View {
    let glow: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [GameTheme.tableTop, GameTheme.tableBottom], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.yellow.opacity(glow ? 0.18 : 0.08), .clear], center: .topTrailing, startRadius: 40, endRadius: 360)
            RadialGradient(colors: [.red.opacity(glow ? 0.16 : 0.06), .clear], center: .bottomLeading, startRadius: 30, endRadius: 320)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: glow)
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(GameTheme.actionGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
            .shadow(color: Color.orange.opacity(configuration.isPressed ? 0.16 : 0.28), radius: configuration.isPressed ? 4 : 9, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
            .background(GameTheme.panelStrong.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
