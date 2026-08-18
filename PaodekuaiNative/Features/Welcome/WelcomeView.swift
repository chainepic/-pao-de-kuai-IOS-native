import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var store: GameStore
    @State private var animateGradients = false
    @State private var contentVisible = false

    var body: some View {
        ZStack {
            WelcomeBackdrop(animate: animateGradients)

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 22) {
                    WelcomeCardFan()
                        .scaleEffect(contentVisible ? 1 : 0.88)
                        .opacity(contentVisible ? 1 : 0)

                    Text(L10n.text("welcome_title"))
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, Color(red: 0.96, green: 0.82, blue: 0.48)], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 8)

                    Text(L10n.text("welcome_subtitle"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .offset(y: contentVisible ? 0 : 18)

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                        store.showWelcomeScreen = false
                    }
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title2)
                        Text(L10n.text("welcome_start_game"))
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(GameTheme.actionGradient)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
                    .shadow(color: GameTheme.accentBottom.opacity(0.45), radius: 18, x: 0, y: 10)
                }
                .buttonStyle(WelcomeButtonStyle())
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 24)
            }
        }
        .onAppear {
            animateGradients = true
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.12)) {
                contentVisible = true
            }
        }
    }
}

private struct WelcomeBackdrop: View {
    let animate: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: animate
                    ? [Color(red: 0.04, green: 0.28, blue: 0.18), Color(red: 0.01, green: 0.08, blue: 0.05)]
                    : [Color(red: 0.08, green: 0.42, blue: 0.26), Color(red: 0.03, green: 0.16, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [.yellow.opacity(0.24), .clear], center: animate ? .topTrailing : .topLeading, startRadius: 20, endRadius: 420)
            RadialGradient(colors: [.red.opacity(0.2), .clear], center: animate ? .bottomLeading : .bottomTrailing, startRadius: 40, endRadius: 360)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true), value: animate)
    }
}

private struct WelcomeCardFan: View {
    var body: some View {
        ZStack {
            welcomeCard(rank: "A", suit: "♠", color: .black)
                .rotationEffect(.degrees(-16))
                .offset(x: -44, y: 12)
            welcomeCard(rank: "K", suit: "♥", color: .red)
                .rotationEffect(.degrees(0))
                .offset(y: -4)
            welcomeCard(rank: "Q", suit: "♣", color: .black)
                .rotationEffect(.degrees(16))
                .offset(x: 44, y: 12)
        }
        .frame(width: 180, height: 128)
        .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
    }

    private func welcomeCard(rank: String, suit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rank)
                .font(.title2.bold())
            Text(suit)
                .font(.title3.bold())
            Spacer()
        }
        .foregroundStyle(color)
        .padding(10)
        .frame(width: 76, height: 104, alignment: .topLeading)
        .background(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.91, blue: 0.84)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(.white.opacity(0.7), lineWidth: 1))
    }
}

private struct WelcomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
