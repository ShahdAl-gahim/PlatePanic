import SwiftUI
import UniformTypeIdentifiers

// MARK: - Minimal Model Types

enum GameState {
    case startScreen
    case inRound
    case finished
}

enum ItemType: String {
    case pancakes = "Pancakes"
}

enum DraggableToken: String {
    case batter
    case pancakes
}

enum PanState {
    case empty
    case hasBatter
    case finishedPancakes
}

struct Player {
    var name: String = "Player"
    var money: Int = 0
}

struct Customer {
    var order: ItemType = .pancakes
    var moneyToPay: Int = 10
    var hasBeenServed: Bool = false
}

// MARK: - Main View

struct ContentView: View {

    @State private var gameState: GameState = .startScreen
    @State private var player = Player()
    @State private var customer = Customer()
    @State private var panState: PanState = .empty

    private var canDragBatter: Bool { gameState == .inRound && panState == .empty && !customer.hasBeenServed }
    private var canDragPancakes: Bool { gameState == .inRound && panState == .finishedPancakes && !customer.hasBeenServed }

    var body: some View {
        VStack(spacing: 18) {
            HeaderView(money: player.money)

            Group {
                switch gameState {
                case .startScreen:
                    StartScreenView(onStart: startNewRound)

                case .inRound:
                    RoundView(
                        orderName: customer.order.rawValue,
                        canDragBatter: canDragBatter,
                        canDragPancakes: canDragPancakes,
                        panTitle: panTitle,
                        panSubtitle: panSubtitle,
                        panSystemImage: panSystemImage,
                        customerServed: customer.hasBeenServed,
                        onDropBatterOnPan: handleDropBatterOnPan,
                        onDropPancakesOnCustomer: handleDropPancakesOnCustomer
                    )

                case .finished:
                    FinishedView(earned: customer.moneyToPay, onPlayAgain: startNewRound)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.default, value: gameState)
        .animation(.default, value: panState)
    }

    // MARK: - Computed UI Strings

    private var panTitle: String {
        switch panState {
        case .empty: return "Empty"
        case .hasBatter: return "Cooking…"
        case .finishedPancakes: return "Pancakes Ready"
        }
    }

    private var panSubtitle: String {
        switch panState {
        case .empty: return "Drop Batter Here"
        case .hasBatter: return "Wait for it…"
        case .finishedPancakes: return "Drag Pancakes to Customer"
        }
    }

    private var panSystemImage: String {
        switch panState {
        case .empty:
            return "square.fill"          // placeholder pan
        case .hasBatter:
            return "flame.fill"           // cooking
        case .finishedPancakes:
            return "birthday.cake.fill"   // placeholder pancakes
        }
    }

    // MARK: - Game Logic

    private func startNewRound() {
        customer = Customer(order: .pancakes, moneyToPay: 10, hasBeenServed: false)
        panState = .empty
        gameState = .inRound
    }

    private func handleDropBatterOnPan() {
        guard gameState == .inRound, panState == .empty else { return }

        panState = .hasBatter

        // simple fake cook time
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if gameState == .inRound && panState == .hasBatter {
                panState = .finishedPancakes
            }
        }
    }

    private func handleDropPancakesOnCustomer() {
        guard gameState == .inRound,
              panState == .finishedPancakes,
              customer.hasBeenServed == false else { return }

        customer.hasBeenServed = true
        player.money += customer.moneyToPay
        gameState = .finished
    }
}

// MARK: - Subviews (still in same file)

private struct HeaderView: View {
    let money: Int

    var body: some View {
        HStack {
            Text("Prototype Cooking Game")
                .font(.headline)
            Spacer()
            Text("Money: $\(money)")
                .font(.subheadline)
        }
    }
}

private struct StartScreenView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Tap Start to begin.")
                .font(.title3)

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct FinishedView: View {
    let earned: Int
    let onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Round Complete 🎉")
                .font(.title2)
                .bold()

            Text("You earned $\(earned).")

            Button("Play Again", action: onPlayAgain)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct RoundView: View {
    let orderName: String
    let canDragBatter: Bool
    let canDragPancakes: Bool

    let panTitle: String
    let panSubtitle: String
    let panSystemImage: String

    let customerServed: Bool

    let onDropBatterOnPan: () -> Void
    let onDropPancakesOnCustomer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            OrderCard(orderName: orderName)

            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 10) {
                    Text("Ingredients")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DraggableCard(title: "Batter", systemImage: "drop.fill", enabled: canDragBatter, token: .batter)
                    DraggableCard(title: "Pancakes", systemImage: "birthday.cake.fill", enabled: canDragPancakes, token: .pancakes)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Pan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DropZoneCard(
                        title: panTitle,
                        systemImage: panSystemImage,
                        subtitle: panSubtitle,
                        isActive: true,
                        accepts: [.batter],
                        onAccept: { token in
                            if token == .batter { onDropBatterOnPan() }
                        }
                    )
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 10) {
                    Text("Customer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DropZoneCard(
                        title: customerServed ? "Served ✅" : "Waiting",
                        systemImage: "person.fill",
                        subtitle: customerServed ? "Thanks!" : "Drop Pancakes Here",
                        isActive: !customerServed,
                        accepts: [.pancakes],
                        onAccept: { token in
                            if token == .pancakes { onDropPancakesOnCustomer() }
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }

            Text("Goal: Drag Batter → Pan, then Pancakes → Customer.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
    }
}

private struct OrderCard: View {
    let orderName: String

    var body: some View {
        VStack(spacing: 8) {
            Text("Customer Order:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(orderName)
                .font(.title2)
                .bold()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct DraggableCard: View {
    let title: String
    let systemImage: String
    let enabled: Bool
    let token: DraggableToken

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
            Text(title)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: 110)
        .padding()
        .background(enabled ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(enabled ? Color.blue.opacity(0.25) : Color.gray.opacity(0.25), lineWidth: 1)
        )
        .opacity(enabled ? 1.0 : 0.45)
        .onDrag {
            guard enabled else { return NSItemProvider() }
            return NSItemProvider(object: token.rawValue as NSString)
        }
    }
}

private struct DropZoneCard: View {
    let title: String
    let systemImage: String
    let subtitle: String
    let isActive: Bool
    let accepts: [DraggableToken]
    let onAccept: (DraggableToken) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding()
        .background(isActive ? Color.green.opacity(0.10) : Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isActive ? Color.green.opacity(0.25) : Color.gray.opacity(0.25), lineWidth: 1)
        )
        .opacity(isActive ? 1.0 : 0.55)
        .onDrop(of: [UTType.text], isTargeted: nil, perform: handleDrop(providers:))
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard isActive else { return false }
        guard let provider = providers.first else { return false }

        if provider.canLoadObject(ofClass: String.self) {
            _ = provider.loadObject(ofClass: String.self) { object, _ in
                guard let str = object,
                      let token = DraggableToken(rawValue: str),
                      accepts.contains(token) else { return }

                DispatchQueue.main.async {
                    onAccept(token)
                }
            }
            return true
        }

        return false
    }

}

                  
