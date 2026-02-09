import SwiftUI
import UniformTypeIdentifiers

// MARK: - Minimal Model Types

enum GameState {
    case startScreen
    case inRound
    case finished
}

enum ItemType: String, CaseIterable {
    case pancakes = "Pancakes"
    case croissant = "Croissant"
    case cupcakes = "Cupcakes"

    var requiredIngredient: DraggableToken { .batter }
    var requiredStation: StationType {
        switch self {
        case .pancakes: return .pan
        case .croissant, .cupcakes: return .oven
        }
    }

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
        switch self {
        case .pancakes: return "birthday.cake.fill"
        case .croissant: return "moon.stars.fill" // placeholder
        case .cupcakes: return "cup.and.saucer.fill" // placeholder
        }
    }

    var stationPlaceholderIcon: String {
        switch self {
        case .pancakes: return "square.fill" // pan placeholder
        case .croissant, .cupcakes: return "oven.fill" // might not exist; fallback handled
        }
    }
}

enum DraggableToken: String, CaseIterable, Equatable {
    case batter
    case pancakes
    case croissant
    case cupcakes
}

enum StationType {
    case pan
    case oven
}

enum StationState: Equatable {
    case empty
    case cooking
    case finished(DraggableToken)
}

struct Player {
    var name: String = "Player"
    var money: Int = 0
}

struct Customer: Identifiable {
    let id = UUID()
    var order: ItemType
    var hasBeenServed: Bool = false
}

// MARK: - Main View

struct ContentView: View {

    @State private var gameState: GameState = .startScreen
    @State private var player = Player()

    // Option B: Queue of customers
    @State private var customers: [Customer] = []
    @State private var currentCustomerIndex: Int = 0

    @State private var stationState: StationState = .empty
    @State private var showPaidBanner: Bool = false
    @State private var lastPayout: Int = 0

    private var currentCustomer: Customer? {
        guard customers.indices.contains(currentCustomerIndex) else { return nil }
        return customers[currentCustomerIndex]
    }

    private var currentOrder: ItemType? {
        currentCustomer?.order
    }

    private var isCurrentCustomerServed: Bool {
        currentCustomer?.hasBeenServed ?? false
    }

    private var canDragBatter: Bool {
        guard gameState == .inRound, let order = currentOrder else { return false }
        return stationState == .empty && !isCurrentCustomerServed && order.requiredIngredient == .batter
    }

    private var canDragFinishedItem: Bool {
        guard gameState == .inRound, let order = currentOrder else { return false }
        if case .finished(let token) = stationState {
            return token == order.finishedToken && !isCurrentCustomerServed
        }
        return false
    }

    var body: some View {
        VStack(spacing: 18) {
            HeaderView(money: player.money, progressText: progressText)

            Group {
                switch gameState {
                case .startScreen:
                    StartScreenView(onStart: startNewGame)

                case .inRound:
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
                        finishedItemName: finishedItemName,
                        finishedItemIcon: finishedItemIcon,
                        onDropBatterOnStation: handleDropBatterOnStation,
                        onDropFinishedOnCustomer: handleDropFinishedOnCustomer
                    )

                case .finished:
                    FinishedView(totalMoney: player.money, onPlayAgain: resetToStart)
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.default, value: gameState)
        .animation(.default, value: stationState)
        .animation(.default, value: showPaidBanner)
    }

    // MARK: - Header

    private var progressText: String {
        if gameState == .inRound {
            let served = min(currentCustomerIndex, customers.count)
            return "Customer \(served + 1) / \(max(customers.count, 1))"
        }
        return ""
    }

    // MARK: - Station UI Strings

    private var stationTitle: String {
        switch stationState {
        case .empty: return stationTypeLabel
        case .cooking: return "Cooking…"
        case .finished: return "Ready"
        }
    }

    private var stationSubtitle: String {
        guard let order = currentOrder else { return "" }
        switch stationState {
        case .empty:
            return "Drop Batter Here"
        case .cooking:
            return "Wait for it…"
        case .finished:
            return "Drag \(order.rawValue) to Customer"
        }
    }

    private var stationTypeLabel: String {
        guard let order = currentOrder else { return "Station" }
        switch order.requiredStation {
        case .pan: return "Pan"
        case .oven: return "Oven"
        }
    }

    private var stationSystemImage: String {
        guard let order = currentOrder else { return "square.fill" }

        switch stationState {
        case .empty:
            // Use simple placeholders that exist on all platforms
            switch order.requiredStation {
            case .pan:
                return "square.fill" // placeholder pan
            case .oven:
                return "rectangle.fill" // placeholder oven
            }
        case .cooking:
            return "flame.fill"
        case .finished:
            return finishedItemIcon
        }
    }

    private var finishedItemName: String {
        currentOrder?.rawValue ?? "Item"
    }

    private var finishedItemIcon: String {
        guard let order = currentOrder else { return "birthday.cake.fill" }
        return order.finishedIcon
    }

    // MARK: - Game Lifecycle

    private func startNewGame() {
        // Create a simple queue: 2 customers with different orders
        // (Change these anytime)
        customers = [
            Customer(order: .pancakes),
            Customer(order: .croissant)
        ]
        currentCustomerIndex = 0
        stationState = .empty
        showPaidBanner = false
        lastPayout = 0

        // Reset player money for a new run (prototype)
        player.money = 0

        gameState = .inRound
    }

    private func resetToStart() {
        gameState = .startScreen
        customers = []
        currentCustomerIndex = 0
        stationState = .empty
        showPaidBanner = false
        lastPayout = 0
    }

    // MARK: - Drop Handlers

    private func handleDropBatterOnStation() {
        guard gameState == .inRound,
              stationState == .empty,
              let order = currentOrder,
              !isCurrentCustomerServed else { return }

        stationState = .cooking

        DispatchQueue.main.asyncAfter(deadline: .now() + order.cookTimeSeconds) {
            if gameState == .inRound, stationState == .cooking {
                stationState = .finished(order.finishedToken)
            }
        }
    }

    private func handleDropFinishedOnCustomer() {
        guard gameState == .inRound,
              let order = currentOrder else { return }

        // Must be holding the correct finished token in station
        guard case .finished(let token) = stationState, token == order.finishedToken else { return }
        guard !isCurrentCustomerServed else { return }

        // Mark served
        customers[currentCustomerIndex].hasBeenServed = true

        // Pay
        lastPayout = order.payout
        player.money += order.payout

        // Show small feedback then advance
        showPaidBanner = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showPaidBanner = false
            advanceToNextCustomerOrFinish()
        }
    }

    private func advanceToNextCustomerOrFinish() {
        // Reset station for next customer
        stationState = .empty

        let nextIndex = currentCustomerIndex + 1
        if nextIndex >= customers.count {
            gameState = .finished
        } else {
            currentCustomerIndex = nextIndex
            // stays inRound; UI updates to show next order
        }
    }
}

// MARK: - Subviews (same file)

private struct HeaderView: View {
    let money: Int
    let progressText: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PlatePanic (Prototype)")
                    .font(.headline)
                if !progressText.isEmpty {
                    Text(progressText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
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
    let totalMoney: Int
    let onPlayAgain: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Game Complete 🎉")
                .font(.title2)
                .bold()

            Text("Total earned: $\(totalMoney).")

            Button("Back to Start", action: onPlayAgain)
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

                // Ingredients / Items
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
                        token: tokenForFinishedName(finishedItemName)
                    )
                }
                .frame(maxWidth: .infinity)

                // Station
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

                // Customer
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
                            // We validate correctness via station state in ContentView;
                            // if user drops a finished item here, it will attempt serve.
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

    private func tokenForFinishedName(_ name: String) -> DraggableToken {
        // This keeps the view simple; ContentView already ensures which item is "ready".
        // The string comes from ItemType.rawValue, so map based on known names.
        switch name {
        case ItemType.pancakes.rawValue: return .pancakes
        case ItemType.croissant.rawValue: return .croissant
        case ItemType.cupcakes.rawValue: return .cupcakes
        default: return .pancakes
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

