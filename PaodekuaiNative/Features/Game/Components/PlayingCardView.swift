import SwiftUI

struct PlayingCardView: View {
    let card: Card
    let selected: Bool
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: selected
                    ? [Color(red: 1.0, green: 0.96, blue: 0.78), Color(red: 0.82, green: 0.9, blue: 1.0)]
                    : [.white, Color(red: 0.95, green: 0.93, blue: 0.87)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(card.rank.rawValue).font(.headline).bold()
                Text(card.suit.symbol).font(.subheadline.weight(.semibold))
                Spacer()
                Text(card.suit.symbol)
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(0.28)
            }
            .padding(6)
        }
        .foregroundStyle(card.isRed ? Color.red : Color.black)
        .frame(width: width, height: 78, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(selected ? Color.orange.opacity(0.75) : Color.gray.opacity(0.35), lineWidth: selected ? 2 : 1))
        .shadow(color: selected ? Color.orange.opacity(0.28) : .black.opacity(0.2), radius: selected ? 8 : 3, x: 0, y: selected ? 5 : 2)
    }
}
