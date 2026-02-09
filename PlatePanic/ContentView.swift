import SwiftUI
import UniformTypeIdentifiers

// MARK: - Game Types

enum GameState: Equatable {
    case startScreen
    case inLevel
    case levelComplete
    case levelFailed
}

enum ItemType: String, CaseIterable, Equatable {
    case pancakes = "Pancakes"
    case croissant = "Croissant"
    case cupcakes = "Cupcakes"

    // Different cooking times
    var cookTimeSeconds: TimeInterval {
        switch self {
        case .pancakes: return 1.2
        case .croissant: return 2.0
        case .cupcakes: return 2.2
        }
    }

    // Slower frustration (more patience) for longer items
    var patienceSeconds: TimeInterval {
        switch self {
        case .pancakes: return 9.0
        case .croissant: return 14.0
        case .cupcakes: return 15.0
        }
    }

    var payout: Int {
        switch self {
        case .pancakes: return 10
        case .croissant: return 14
        case .cupcakes: return 16
        }
    }

    var icon: String {
        // Placeholder SF Symbols — swap to your assets later
        switch self {
        case .pancakes: return "birthday.cake.fill"
        case .croissant: return "moon.stars.fill"
        case .cupcakes: return "cup.and.saucer.fill"
        }
    }

    var token: String {
        // for drag payload
        switch self {
        case .pancakes: return "pancakes"
        case .croissant: return "croissant"
        case .cupcakes: return "cupcakes"
        }
    }
}

enum StationState: Equatable {
    case empty
    case cooking(startedAt: Date)
    case ready
}

struct Player {
    var money: Int = 0
    var level: Int = 1
}

struct Customer: Identifiable, Equatable {
    let id: UUID = UUID()
    let order: ItemType
    let spawnedAt: Date

    var frustration: Double = 0.0      // 0.0 ... 1.0
    var isServed: Bool = false
    var station: StationState = .empty
}

// MARK: - Main View

struct ContentView: View {

    @State private var gameState: GameState = .startScreen
    @State private var player = Player()

    @State private var customers: [Customer] = []

    @State private var lastPayout: Int = 0
    @State private var showPaidBanner: Bool = false

    @State private var failMessage: String = ""

    // Tick for both frustration + cooking completion
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            HeaderView(
                money: player.money,
                level: player.level,
                state: gameState,
                onQuit: quitToStart
            )

            Group {
                switch gameState {
                case .startScreen:
                    StartScreenView(onStart: startNewGame)

                case .inLevel:
                    levelView

                case .levelComplete:
                    LevelCompleteView(
                        level: player.level,
                        totalMoney: player.money,
                        onNext: advanceToNextLevel,
                        onQuit: quitToStart
                    )

                case .levelFailed:
                    LevelFailedView(
                        level: player.level,
                        message: failMessage,
                        onRetry: retryLevel,
                        onQuit: quitToStart
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .animation(.default, value: gameState)
        .animation(.default, value: customers)
        .animation(.default, value: showPaidBanner)
        .onReceive(tick) { _ in
            updateTick()
        }
    }

    // MARK: - In-Level UI

    private var levelView: some View {
        VStack(spacing: 12) {

            if showPaidBanner {
                Text("Paid $\(lastPayout) ✅")
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            }

            Text("Serve all customers before anyone hits 100% frustration.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(customers.indices, id: \.self) { idx in
                        CustomerRowView(
                            customer: customers[idx],
                            cookingProgress: cookingProgress(for: customers[idx]),
                            onDropBatter: { handleDropBatter(onCustomerIndex: idx) },
                            onDropFinished: { payload in handleDropFinished(payload: payload, onCustomerIndex: idx) }
                        )
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Game Flow

    private func startNewGame() {
        player.money = 0
        player.level = 1
        startLevel(level: player.level)
        gameState = .inLevel
    }

    private func startLevel(level: Int) {
        let now = Date()
        customers = (0..<max(level, 1)).map { _ in
            Customer(order: ItemType.allCases.randomElement() ?? .pancakes, spawnedAt: now)
        }
        lastPayout = 0
        showPaidBanner = false
        failMessage = ""
    }

    private func advanceToNextLevel() {
        player.level += 1
        startLevel(level: player.level)
        gameState = .inLevel
    }

    private func retryLevel() {
        startLevel(level: player.level)
        gameState = .inLevel
    }

    private func quitToStart() {
        gameState = .startScreen
        customers = []
        lastPayout = 0
        showPaidBanner = false
        failMessage = ""
    }

    // MARK: - Tick Updates (Frustration + Cooking)

    private func updateTick() {
        guard gameState == .inLevel else { return }
        guard !customers.isEmpty else { return }

        let now = Date()

        // Update everyone
        for i in customers.indices {
            if customers[i].isServed { continue }

            // Frustration increases while waiting (not served)
            let elapsed = now.timeIntervalSince(customers[i].spawnedAt)
            let patience = customers[i].order.patienceSeconds
            let frac = min(max(elapsed / patience, 0.0), 1.0)
            customers[i].frustration = frac

            // Fail condition
            if frac >= 1.0 {
                failLevel(reason: "\(customers[i].order.rawValue) took too long — customer left unhappy.")
                return
            }

            // Cooking completion per customer
            switch customers[i].station {
            case .empty:
                break
            case .ready:
                break
            case .cooking(let startedAt):
                let cookElapsed = now.timeIntervalSince(startedAt)
                if cookElapsed >= customers[i].order.cookTimeSeconds {
                    customers[i].station = .ready
                }
            }
        }

        // Complete if all served
        if customers.allSatisfy({ $0.isServed }) {
            gameState = .levelComplete
        }
    }

    private func failLevel(reason: String) {
        showPaidBanner = false
        failMessage = reason
        gameState = .levelFailed
    }

    // MARK: - Cooking Progress Helper

    private func cookingProgress(for customer: Customer) -> Double {
        switch customer.station {
        case .empty:
            return 0.0
        case .ready:
            return 1.0
        case .cooking(let startedAt):
            let elapsed = Date().timeIntervalSince(startedAt)
            let total = max(customer.order.cookTimeSeconds, 0.01)
            return min(max(elapsed / total, 0.0), 1.0)
        }
    }

    // MARK: - Drop Handlers

    private func handleDropBatter(onCustomerIndex idx: Int) {
        guard gameState == .inLevel else { return }
        guard customers.indices.contains(idx) else { return }
        guard !customers[idx].isServed else { return }

        // Only start if empty
        guard customers[idx].station == .empty else { return }

        customers[idx].station = .cooking(startedAt: Date())
    }

    // Finished item drag payload format:
    // "finished:<itemToken>:<customerUUID>"
    private func handleDropFinished(payload: String, onCustomerIndex idx: Int) {
        guard gameState == .inLevel else { return }
        guard customers.indices.contains(idx) else { return }
        guard !customers[idx].isServed else { return }

        // Must be ready
        guard customers[idx].station == .ready else { return }

        let parts = payload.split(separator: ":").map(String.init)
        guard parts.count == 3 else { return }
        guard parts[0] == "finished" else { return }

        let itemToken = parts[1]
        let customerIdString = parts[2]

        // Must match this customer row
        guard customerIdString == customers[idx].id.uuidString else { return }

        // Must match the order type
        guard itemToken == customers[idx].order.token else { return }

        // Serve
        customers[idx].isServed = true
        lastPayout = customers[idx].order.payout
        player.money += lastPayout

        // Optional: clear station after serving
        customers[idx].station = .empty

        showPaidBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showPaidBanner = false
        }
    }
}

// MARK: - UI Subviews (same file)

private struct HeaderView: View {
    let money: Int
    let level: Int
    let state: GameState
    let onQuit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PlatePanic (Prototype)")
                    .font(.headline)
                Text("Level \(level)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Money: $\(money)")
                .font(.subheadline)

            if state == .inLevel || state == .levelComplete || state == .levelFailed {
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

            Text("Level N spawns N customers at the same time.\nCook and serve in parallel.")
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
    let onNext: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Level \(level) Complete 🎉")
                .font(.title2)
                .bold()

            Text("Total money: $\(totalMoney)")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("Next Level", action: onNext)
                    .buttonStyle(.borderedProminent)

                Button("Quit", action: onQuit)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

private struct LevelFailedView: View {
    let level: Int
    let message: String
    let onRetry: () -> Void
    let onQuit: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Level \(level) Failed 😬")
                .font(.title2)
                .bold()

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Retry Level", action: onRetry)
                    .buttonStyle(.borderedProminent)

                Button("Quit", action: onQuit)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }
}

// One “list item” row that includes customer + cooking lane
private struct CustomerRowView: View {
    let customer: Customer
    let cookingProgress: Double

    let onDropBatter: () -> Void
    let onDropFinished: (String) -> Void

    private var canDragBatter: Bool {
        !customer.isServed && customer.station == .empty
    }

    private var canDragFinished: Bool {
        !customer.isServed && customer.station == .ready
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order: \(customer.order.rawValue)")
                        .font(.headline)
                    Text(customer.isServed ? "Served ✅" : "Waiting")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(customer.isServed ? "" : "\(Int(customer.frustration * 100))%")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Frustration
            ProgressView(value: customer.isServed ? 0 : customer.frustration)
                .opacity(customer.isServed ? 0.5 : 1.0)

            // Cooking lane
            HStack(spacing: 12) {

                // Batter draggable (per row)
                DraggableCard(
                    title: "Batter",
                    systemImage: "drop.fill",
                    enabled: canDragBatter,
                    dragPayload: "batter"
                )

                // Station drop zone
                DropZoneCard(
                    title: stationTitle,
                    systemImage: stationIcon,
                    subtitle: stationSubtitle,
                    isActive: !customer.isServed,
                    acceptsBatter: true,
                    onDropText: { text in
                        if text == "batter" { onDropBatter() }
                    }
                )

                // Finished item draggable (only when ready)
                DraggableCard(
                    title: customer.order.rawValue,
                    systemImage: customer.order.icon,
                    enabled: canDragFinished,
                    dragPayload: finishedPayload
                )

                // Customer drop zone (accept finished payload)
                DropZoneCard(
                    title: "Customer",
                    systemImage: "person.fill",
                    subtitle: customer.isServed ? "Done" : "Drop Here",
                    isActive: !customer.isServed,
                    acceptsBatter: false,
                    onDropText: { text in
                        onDropFinished(text)
                    }
                )
            }

            // Cooking progress (visual only)
            if !customer.isServed {
                if case .cooking = customer.station {
                    ProgressView(value: cookingProgress)
                        .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .opacity(customer.isServed ? 0.65 : 1.0)
    }

    private var finishedPayload: String {
        // "finished:<itemToken>:<customerUUID>"
        "finished:\(customer.order.token):\(customer.id.uuidString)"
    }

    private var stationTitle: String {
        switch customer.station {
        case .empty: return "Station"
        case .cooking: return "Cooking…"
        case .ready: return "Ready"
        }
    }

    private var stationSubtitle: String {
        switch customer.station {
        case .empty: return "Drop Batter"
        case .cooking: return "In progress"
        case .ready: return "Grab item"
        }
    }

    private var stationIcon: String {
        switch customer.station {
        case .empty: return "square.fill"
        case .cooking: return "flame.fill"
        case .ready: return customer.order.icon
        }
    }
}

private struct DraggableCard: View {
    let title: String
    let systemImage: String
    let enabled: Bool
    let dragPayload: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
            Text(title)
                .font(.footnote)
                .multilineTextAlignment(.center)
        }
        .frame(width: 92, height: 92)
        .padding(6)
        .background(enabled ? Color.blue.opacity(0.12) : Color.gray.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(enabled ? Color.blue.opacity(0.25) : Color.gray.opacity(0.25), lineWidth: 1)
        )
        .opacity(enabled ? 1.0 : 0.45)
        .onDrag {
            guard enabled else { return NSItemProvider() }
            return NSItemProvider(object: dragPayload as NSString)
        }
    }
}

private struct DropZoneCard: View {
    let title: String
    let systemImage: String
    let subtitle: String
    let isActive: Bool

    // if true, only accept "batter" quickly; else accept anything (we validate upstream)
    let acceptsBatter: Bool

    let onDropText: (String) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 28))
            Text(title)
                .font(.footnote)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 110, height: 92)
        .padding(6)
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
                guard let text = object else { return }
                if acceptsBatter {
                    // Fast path: only allow batter
                    if text == "batter" {
                        DispatchQueue.main.async { onDropText(text) }
                    }
                } else {
                    DispatchQueue.main.async { onDropText(text) }
                }
            }
            return true
        }

        return false
    }
}

