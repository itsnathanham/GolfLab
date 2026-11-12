import SwiftUI
import UIKit

/// Profile bag: open distance rows, grip to reorder, swipe to delete, compact stepper.
struct StockClubYardagesSection: View {
    @Binding var rows: [StockClubYardage]
    /// Set while a reorder or swipe is in progress so the profile scroll view stays still.
    @Binding var locksParentScroll: Bool
    var onChange: () -> Void

    @State private var reorder: ReorderDrag?
    @State private var reorderGeneration = 0
    @State private var openDeleteID: UUID?
    @State private var activeSwipeID: UUID?
    @State private var swipeDrag: CGFloat = 0
    /// Resets when the grip gesture ends or the scroll view cancels it, so the profile cannot stay locked.
    @GestureState private var gripActive = false

    private let rowHeight: CGFloat = 64
    private let gripWidth: CGFloat = 44
    private let deleteRevealWidth: CGFloat = 88

    private var availableClubs: [StockClub] {
        let used = Set(rows.map(\.club))
        return StockClub.allCases.filter { !used.contains($0) }
    }

    var body: some View {
        GLFormCard {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    GLFormFieldLabel(text: "Stock yardages")
                    Text("Total distance in yards.")
                        .font(.glFootnote)
                        .foregroundColor(.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 6)

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        clubRow(row, index: index)
                    }
                    if !availableClubs.isEmpty {
                        addClubRow
                    }
                }
                .padding(.horizontal, -GLCardMetrics.padding)
            }
        }
        .onDisappear {
            locksParentScroll = false
        }
        .onChange(of: gripActive) { _, active in
            guard !active else { return }
            // GestureState clears on cancel too, sometimes before onEnded. A newer grip increments the generation and this pass does nothing.
            let generation = reorderGeneration
            DispatchQueue.main.async {
                guard generation == reorderGeneration else { return }
                commitReorder()
            }
        }
    }

    private func clubRow(_ row: StockClubYardage, index: Int) -> some View {
        let dragged = reorder?.id == row.id
        return ZStack(alignment: .trailing) {
            deleteButton(for: row)

            HStack(spacing: 12) {
                grip(for: row, index: index)
                Text(row.club.displayName)
                    .font(.glBody)
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(horizontalSwipeCatcher(for: row.id))
                CompactYardageStepper(
                    yardage: Binding(
                        get: { row.yardage },
                        set: { newValue in
                            guard let newValue else { return }
                            updateYardage(id: row.id, yardage: newValue)
                        }
                    )
                )
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .frame(maxWidth: .infinity)
            .frame(height: rowHeight)
            .background(Color.cardBackground)
            .offset(x: swipeOffset(for: row.id))
        }
        .frame(height: rowHeight)
        .clipped()
        .zIndex(dragged ? 1 : 0)
        .offset(y: visualOffset(index: index))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Move up")) { shiftRow(id: row.id, by: -1) }
        .accessibilityAction(named: Text("Move down")) { shiftRow(id: row.id, by: 1) }
        .accessibilityAction(named: Text("Delete")) { deleteRow(id: row.id) }
    }

    private func deleteButton(for row: StockClubYardage) -> some View {
        Button {
            deleteRow(id: row.id)
        } label: {
            Text("Delete")
                .font(GLFonts.sans(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: deleteRevealWidth)
        .frame(maxHeight: .infinity)
        .background(Color(uiColor: .systemRed))
        .accessibilityLabel("Delete \(row.club.displayName)")
        .accessibilityHidden(openDeleteID != row.id)
    }

    private func grip(for row: StockClubYardage, index: Int) -> some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 22, weight: .bold))
            .foregroundColor(.textTertiary)
            .frame(width: gripWidth, height: rowHeight)
            .contentShape(Rectangle())
            .highPriorityGesture(reorderGesture(for: row.id, index: index))
            .accessibilityLabel("Reorder \(row.club.displayName)")
            .accessibilityAddTraits(.isButton)
    }

    private var addClubRow: some View {
        Menu {
            ForEach(availableClubs) { club in
                Button(club.displayName) {
                    addClub(club)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.accent)
                    .frame(width: gripWidth, height: 44)
                Text("Add club")
                    .font(.glBody)
                    .foregroundColor(.textSecondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, GLCardMetrics.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, rows.isEmpty ? 0 : 4)
        .accessibilityLabel("Add club")
    }

    // MARK: - Reorder

    private func reorderGesture(for id: UUID, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .updating($gripActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if reorder?.id != id {
                    closeSwipe()
                    reorderGeneration += 1
                    reorder = ReorderDrag(
                        id: id,
                        originIndex: index,
                        translation: 0,
                        lastProposed: index,
                        startY: value.startLocation.y
                    )
                    locksParentScroll = true
                }
                guard var drag = reorder, drag.id == id else { return }
                // Screen coordinates, so a neighbor sliding out from under the grip cannot jump the translation.
                drag.translation = value.location.y - drag.startY
                stepProposedIndex(&drag)
                reorder = drag
            }
            .onEnded { _ in
                commitReorder()
            }
    }

    /// Move one slot at a time, and only after the finger is most of the way into the next row.
    /// A fast drag still crosses several clubs, with one haptic each.
    private func stepProposedIndex(_ drag: inout ReorderDrag) {
        let position = CGFloat(drag.originIndex) + drag.translation / rowHeight
        let last = max(rows.count - 1, 0)
        var proposed = drag.lastProposed
        var crossed = 0
        while proposed < last, position >= CGFloat(proposed) + 0.65 {
            proposed += 1
            crossed += 1
        }
        while proposed > 0, position <= CGFloat(proposed) - 0.65 {
            proposed -= 1
            crossed += 1
        }
        guard crossed > 0 else { return }
        drag.lastProposed = proposed
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.prepare()
        for _ in 0..<crossed {
            haptic.impactOccurred()
        }
    }

    private func visualOffset(index: Int) -> CGFloat {
        guard let drag = reorder else { return 0 }
        let from = drag.originIndex
        let to = drag.lastProposed
        if index == from {
            return drag.translation
        }
        if from < to, index > from, index <= to {
            return -rowHeight
        }
        if to < from, index >= to, index < from {
            return rowHeight
        }
        return 0
    }

    private func commitReorder() {
        guard let drag = reorder else {
            if activeSwipeID == nil {
                locksParentScroll = false
            }
            return
        }
        let from = drag.originIndex
        let to = drag.lastProposed
        let didMove = rows.indices.contains(from) && from != to
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if didMove {
                rows.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
            reorder = nil
        }
        if didMove {
            onChange()
        }
        locksParentScroll = activeSwipeID != nil
    }

    private func shiftRow(id: UUID, by delta: Int) {
        guard let from = rows.firstIndex(where: { $0.id == id }) else { return }
        let to = min(max(0, from + delta), rows.count - 1)
        guard to != from else { return }
        rows.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Swipe to delete

    private func swipeOffset(for id: UUID) -> CGFloat {
        if activeSwipeID == id { return swipeDrag }
        if openDeleteID == id { return -deleteRevealWidth }
        return 0
    }

    /// Horizontal-only pan on the club name. A vertical move never begins, so the profile page can scroll.
    private func horizontalSwipeCatcher(for id: UUID) -> some View {
        HorizontalSwipeCatcher(
            onChanged: { translation in
                guard reorder == nil else { return }
                if activeSwipeID != id {
                    activeSwipeID = id
                    if openDeleteID != id {
                        openDeleteID = nil
                    }
                }
                locksParentScroll = true
                let base: CGFloat = openDeleteID == id ? -deleteRevealWidth : 0
                swipeDrag = min(0, max(-deleteRevealWidth - 12, base + translation))
            },
            onEnded: { translation, predicted in
                guard activeSwipeID == id else { return }
                let base: CGFloat = openDeleteID == id ? -deleteRevealWidth : 0
                finishSwipe(id: id, open: base + predicted < -deleteRevealWidth / 2 || base + translation < -deleteRevealWidth / 2)
            }
        )
    }

    private func finishSwipe(id: UUID, open: Bool) {
        guard activeSwipeID == id || openDeleteID == id else {
            locksParentScroll = reorder != nil
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            openDeleteID = open ? id : nil
            activeSwipeID = nil
            swipeDrag = 0
        }
        locksParentScroll = reorder != nil
    }

    private func closeSwipe() {
        openDeleteID = nil
        activeSwipeID = nil
        swipeDrag = 0
    }

    // MARK: - Mutations

    private func updateYardage(id: UUID, yardage: Int) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        rows[index].yardage = yardage
        onChange()
    }

    private func deleteRow(id: UUID) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            rows.remove(at: index)
            closeSwipe()
        }
        locksParentScroll = false
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func addClub(_ club: StockClub) {
        guard !rows.contains(where: { $0.club == club }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            rows.append(StockClubYardage(club: club, yardage: nil, displayOrder: rows.count))
        }
        onChange()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct ReorderDrag: Equatable {
    var id: UUID
    var originIndex: Int
    var translation: CGFloat
    var lastProposed: Int
    var startY: CGFloat
}

/// Same − / value / + control as `StepperField`, sized to sit beside a club name.
/// An unset distance reads as a dash. The first step moves off 100 yards.
private struct CompactYardageStepper: View {
    @Binding var yardage: Int?

    @State private var flashState: FlashState = .idle
    @State private var flashToken = 0

    private enum FlashState {
        case idle
        case minus
        case plus
    }

    private var minusEnabled: Bool {
        guard let yardage else { return true }
        return yardage > GLStockClubYardages.minYards
    }

    private var plusEnabled: Bool {
        guard let yardage else { return true }
        return yardage < GLStockClubYardages.maxYards
    }

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemName: "minus", side: .minus, enabled: minusEnabled) {
                apply(delta: -1, side: .minus)
            }
            Text(yardage.map { String($0) } ?? "—")
                .font(GLFonts.mono(size: 22, weight: .semibold))
                .foregroundColor(yardage == nil ? .textTertiary : .textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            stepButton(systemName: "plus", side: .plus, enabled: plusEnabled) {
                apply(delta: 1, side: .plus)
            }
        }
        .frame(width: 148, height: 52)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall))
        .overlay(
            RoundedRectangle(cornerRadius: GLCardMetrics.cornerRadiusSmall)
                .stroke(Color.borderDefault, lineWidth: GLCardMetrics.strokeWidth)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(yardage.map { "\($0) yards" } ?? "Yards not set")
    }

    private func apply(delta: Int, side: FlashState) {
        let baseline = yardage ?? GLStockClubYardages.defaultYardsWhenSetting
        yardage = GLStockClubYardages.clampYards(baseline + delta * GLStockClubYardages.step)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        flashToken += 1
        let token = flashToken
        flashState = side
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if flashToken == token {
                flashState = .idle
            }
        }
    }

    private func stepButton(
        systemName: String,
        side: FlashState,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let flashing = flashState == side
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(flashing ? .ctaOnAccent : (enabled ? .textPrimary : .textTertiary))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 52)
        .background(flashing ? Color.accent : Color.bgElevated)
        .animation(.easeOut(duration: 0.15), value: flashState)
        .disabled(!enabled)
        .accessibilityLabel(side == .minus ? "Decrease yards" : "Increase yards")
    }
}

/// Pan that begins only when the finger is clearly moving sideways.
/// A vertical drag fails this recognizer so the profile `ScrollView` can scroll.
private struct HorizontalSwipeCatcher: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ predicted: CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handle(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat, CGFloat) -> Void

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (CGFloat, CGFloat) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.25
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.y) >= abs(velocity.x)
        }

        @objc func handle(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view).x
            switch pan.state {
            case .changed:
                onChanged(translation)
            case .ended, .cancelled, .failed:
                let predicted = translation + pan.velocity(in: pan.view).x * 0.15
                onEnded(translation, predicted)
            default:
                break
            }
        }
    }
}
