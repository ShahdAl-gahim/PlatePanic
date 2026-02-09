import SwiftUI
import UniformTypeIdentifiers

// MARK: - Minimal Model Types

enum GameState: Equatable {
    case startScreen
    case inLevel
    case levelComplete
    case gameOver
}

enum ItemType: String, CaseIterable, Equatable {
    case pancakes = "Pancakes"
    case croissant = "Croissant"
    case cupcakes = "Cupcakes"

    var cookTimeSeconds: TimeInterval {
        switch self {
        case .pancakes: return 1.2
        case .croissant: return 1.6
        case .cupcakes: return 1.8
        }
    }

    var payout: Int {
        switch self {
        case .pancakes: return 10
        case .croissant: return 14
        case .cupcakes: return 16
        }
    }

    var finishedToken: DraggableToken {
        switch self {
        case .pancakes: return .pancakes
        case .croissant: return .croissant
        case .cupcakes: return .cupcakes
        }
    }

    var finishedIcon: String {
        // Placeholder SF Symbols — swap to your real assets later
        switch self {
        case .pancakes: return "birthday.cake.fill"
        case .croissant: return "moon.stars.fill"
        case .cupcakes: return "cup.and.saucer.fill"
        }
    }
}

enum DraggableToken: String, CaseIterable, Equatable {
    case batter
    case pancakes
    case croissant
    case cupcakes
}

enum StationState: Equatable {
    case empty
    case cooking
    case finished(DraggableToken)
}

struct Player {
    var name: String = "Player"
    var money: Int = 0
    var level: Int = 1
}

struct Customer: Identifiable, Equatable {
    let id = UUID()
    var order: ItemType
    var hasBeenServed: Bool = false
}

// MARK: - Main View

struct ContentView: View {

    @State private var gameState: GameState = .startScreen
    @State private var player = Player()

    // Level queue
    @State private var customers: [Customer] = []
    @State private var currentCustomerIndex: Int = 0

    @State private var stationState: StationState = .empty

    // UI feedback
    @State private var showPaidBanner: Bool = false
    @State private var lastPayout: Int = 0

    // MARK: - Derived

    private var currentCustomer: Customer? {
        guard customers.indices.contains(currentCustomerIndex) else { return nil }
        return customers[currentCustomerIndex]
    }

    private var currentOrder: ItemType? { currentCustomer?.order }
    private var isCurrentCustomerServed: Bool { currentCustomer?.hasBeenServed ?? false }

    private var canDragBatter: Bool {
        gameState == .inLevel && stationState == .empty && !isCurrentCustomerServed
    }

    private var canDragFinishedItem: Bool {
        guard gameState == .inLevel, let order = currentOrder else { return false }
        if case .finished(let token) = stationState {
            return token == order.finishedToken && !isCurrentCustomerServed
        }
        return false
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 18) {
            HeaderView(
                money: player.money,
                level: player.level,
                progressText: progressText,
                showQuit: gameState == .inLevel || gameState == .levelComplete,
                onQuit: quitToStart
            )

            Group {
                switch gameState {
                case .startScreen:
                    StartScreenView(
                        onStart: startNewGame
                    )

                case .inLevel:
                    RoundView(
                        orderName: currentOrder?.rawValue ?? "—",
                        stationTitle: stationTitle,
                        stationSubtitle: stationSubtitle,
                        stationSystemImage: stationSystemImage,
                        customerServed: isCurrentCustomerServed,
                        showPaidBanner: showPaidBanner,
                        paidText: "Paid $\(lastPayout) ✅",
                        canDragBatter: canDragBatter,
                        canDragFinishedItem: canDragFinishedItem,
                        finishedItemName: currentOrder?.rawValue ?? "Item",
                        finishedItemIcon: currentOrder?.finishedIcon ?? "birthday.cake.fill",
                        finishedToken: currentOrder?.finishedToken ?? .pancakes,
                        onDropBatterOnStation: handleDropBatterOnStation,
                        onDropFinishedOnCustomer: handleDropFinishedOnCustomer
                    )

                case .levelComplete:
                    LevelCompleteView(
                        level: player.level,
                        totalMoney: player.money,
                        onNextLevel: advanceToNextLevel,
                        onQuit: quitToStart
                    )

                case .gameOver:
                    // Not used right now, but kept for easy future expansion.
                    FinishedView(totalMoney: player.money, onBackToStart: quitToStart)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.default, value: gameState)
        .animation(.default, value: stationState)
        .animation(.default, value: showPaidBanner)
    }

    // MARK: - Header Helpers

    private var progressText: String {
        guard gameState == .inLevel else { return "" }
        let current = min(currentCustomerIndex + 1, max(customers.count, 1))
        return "Customer \(current) / \(max(customers.count, 1))"
    }

    // MARK: - Station UI Strings

    private var stationTitle: String {
        switch stationState {
        case .empty: return "Station"
        case .cooking: return "Cooking…"
        case .finished: return "Ready"
        }
    }

    private var stationSubtitle: String {
        guard let order = currentOrder else { return "" }
        switch stationState {
        case .empty: return "Drop Batter Here"
        case .cooking: return "Wait for it…"
        case .finished: return "Drag \(order.rawValue) to Customer"
        }
    }

    private var stationSystemImage: String {
        guard let order = currentOrder else { return "square.fill" }
        switch stationState {
        case .empty:
            return "square.fill" // placeholder station
        case .cooking:
            return "flame.fill"
        case .finished:
            return order.finishedIcon
        }
    }

    // MARK: - Game / Level Flow

    private func startNewGame() {
        player.money = 0
        player.level = 1
        startLevel(level: player.level)
        gameState = .inLevel
    }

    private func startLevel(level: Int) {
        // Level N has N random customers
        customers = (0..<max(level, 1)).map { _ in
            Customer(order: ItemType.allCases.randomElement() ?? .pancakes)
        }
        currentCustomerIndex = 0
        stationState = .empty
        showPaidBanner = false
        lastPayout = 0
    }

    private func advanceToNextLevel() {
        player.level += 1
        startLevel(level: player.level)
        gameState = .inLevel
    }

    private func completeLevel() {
        // Show a simple level complete screen
        gameState = .levelComplete
    }

    private func quitToStart() {
        // Quit at any time
        gameState = .startScreen
        customers = []
        currentCustomerIndex = 0
        stationState = .empty
        showPaidBanner = false
        lastPayout = 0
        // Keep it simple: quitting resets progression to start screen.
        // (If you want “continue where you left off” later, we can keep player.level.)
    }

    // MARK: - Drop Handlers

    private func handleDropBatterOnStation() {
        guard gameState == .inLevel,
              stationState == .empty,
              let order = currentOrder,
              !isCurrentCustomerServed else { return }

        stationState = .cooking

        DispatchQueue.main.asyncAfter(deadline: .now() + order.cookTimeSeconds) {
            // Don’t finish cooking if we quit / moved states
            if gameState == .inLevel && stationState == .cooking {
                stationState = .finished(order.finishedToken)
            }
        }
    }

    private func handleDropFinishedOnCustomer() {
        guard gameState == .inLevel,
              let order = currentOrder else { return }

        guard case .finished(let token) = stationState, token == order.finishedToken else { return }
        guard !isCurrentCustomerServed else { return }

        // Serve current customer
        customers[currentCustomerIndex].hasBeenServed = true

        // Pay
        lastPayout = order.payout
        player.money += order.payout

        // Small feedback then advance
        showPaidBanner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showPaidBanner = false
            advanceToNextCustomerOrCompleteLevel()
        }
    }

    private func advanceToNextCustomerOrCompleteLevel() {
        stationState = .empty

        let nextIndex = currentCustomerIndex + 1
        if nextIndex >= customers.count {
            completeLevel()
        } else {
            currentCustomerIndex = nextIndex
        }
    }
}

// MARK: - Subviews (same file)

private struct HeaderView: View {
    let money: Int
    let level: Int
    let progressText: String
    let showQuit: Bool
    let onQuit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PlatePanic (Prototype)")
                    .font(.headline)
                Text("Level \(level)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !progressText.isEmpty {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("Money: $\(money)")
                .font(.subheadline)

            if showQuit {
                Button("Quit") { onQuit() }
                    .buttonStyle(.bordered)
                    .padding(.leading, 8)
            }
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

            Text("Level 1: 1 customer • Level 2: 2 customers • Level 3: 3 customers…")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct LevelCompleteView: View {
    let level: Int
    let totalMoney: Int
    let onNextLevel: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Level \(level) Complete 🎉")
                .font(.title2)
                .bold()

            Text("Total money: $\(totalMoney)")
                .font(.body)

            HStack(spacing: 12) {
                Button("Next Level", action: onNextLevel)
                    .buttonStyle(.borderedProminent)

                Button("Quit", action: onQuit)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct FinishedView: View {
    let totalMoney: Int
    let onBackToStart: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Game Over")
                .font(.title2)
                .bold()

            Text("Total earned: $\(totalMoney).")

            Button("Back to Start", action: onBackToStart)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct RoundView: View {
    let orderName: String

    let stationTitle: String
    let stationSubtitle: String
    let stationSystemImage: String

    let customerServed: Bool

    let showPaidBanner: Bool
    let paidText: String

    let canDragBatter: Bool
    let canDragFinishedItem: Bool

    let finishedItemName: String
    let finishedItemIcon: String
    let finishedToken: DraggableToken

    let onDropBatterOnStation: () -> Void
    let onDropFinishedOnCustomer: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            OrderCard(orderName: orderName)

            if showPaidBanner {
                Text(paidText)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            }

            HStack(alignment: .top, spacing: 14) {

                // Items
                VStack(spacing: 10) {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DraggableCard(
                        title: "Batter",
                        systemImage: "drop.fill",
                        enabled: canDragBatter,
                        token: .batter
                    )

                    DraggableCard(
                        title: finishedItemName,
                        systemImage: finishedItemIcon,
                        enabled: canDragFinishedItem,
                        token: finishedToken
                    )
                }
                .frame(maxWidth: .infinity)

                // Station (drop batter here)
                VStack(spacing: 10) {
                    Text("Station")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DropZoneCard(
                        title: stationTitle,
                        systemImage: stationSystemImage,
                        subtitle: stationSubtitle,
                        isActive: true,
                        accepts: [.batter],
                        onAccept: { token in
                            if token == .batter { onDropBatterOnStation() }
                        }
                    )
                }
                .frame(maxWidth: .infinity)

                // Customer (drop finished item here)
                VStack(spacing: 10) {
                    Text("Customer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    DropZoneCard(
                        title: customerServed ? "Served ✅" : "Waiting",
                        systemImage: "person.fill",
                        subtitle: customerServed ? "Thanks!" : "Drop \(finishedItemName) Here",
                        isActive: !customerServed,
                        accepts: [.pancakes, .croissant, .cupcakes],
                        onAccept: { _ in
                            onDropFinishedOnCustomer()
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }

            Text("Goal: Drag Batter → Station, then finished item → Customer.")
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

