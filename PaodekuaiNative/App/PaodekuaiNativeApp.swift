import SwiftUI

@main
struct PaodekuaiNativeApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var monetization = MonetizationStore()

    var body: some Scene {
        WindowGroup {
            if !store.showWelcomeScreen {
                GameView()
                    .environmentObject(store)
                    .environmentObject(monetization)
                    .onAppear {
                        store.bootstrap()
                    }
            } else {
                WelcomeView()
                    .environmentObject(store)
            }
        }
    }
}

struct WelcomeView: View {
    @EnvironmentObject var store: GameStore
    @State private var animateGradients = false

    var body: some View {
        ZStack {
            // Animated background
            LinearGradient(
                colors: animateGradients 
                    ? [Color(red: 0.05, green: 0.25, blue: 0.15), Color(red: 0.02, green: 0.1, blue: 0.05)]
                    : [Color(red: 0.08, green: 0.4, blue: 0.25), Color(red: 0.04, green: 0.2, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animateGradients)
            .onAppear {
                animateGradients = true
            }

            VStack(spacing: 50) {
                Spacer()

                // Logo/Title area
                VStack(spacing: 16) {
                    Image(systemName: "suit.spade.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Text("湖南跑得快")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 5, x: 0, y: 3)
                    
                    Text("原汁原味 · 经典玩法")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                // Buttons
                VStack(spacing: 24) {
                    Button(action: {
                        withAnimation(.spring()) {
                            store.showWelcomeScreen = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.title2)
                            Text("开始游戏")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(colors: [Color.blue.opacity(0.8), Color.blue.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}
