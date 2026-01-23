import SwiftUI

// MARK: - Expandable Card

/// A card that expands/collapses to show more or less content
struct ExpandableCard<Header: View, Content: View>: View {
    let header: Header
    let content: Content
    
    @State private var isExpanded = false
    var initiallyExpanded: Bool = false
    var animationDuration: Double = 0.25
    
    init(
        initiallyExpanded: Bool = false,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.initiallyExpanded = initiallyExpanded
        self.header = header()
        self.content = content()
        _isExpanded = State(initialValue: initiallyExpanded)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: { toggleExpanded() }) {
                HStack {
                    header
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content (expandable)
            if isExpanded {
                Divider()
                    .padding(.vertical, 8)
                
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }
    
    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isExpanded.toggle()
        }
    }
}

/// Preset expandable card for stats
struct StatsExpandableCard: View {
    let title: String
    let mainValue: String
    let mainLabel: String
    let details: [(label: String, value: String)]
    var color: Color = .green
    
    var body: some View {
        ExpandableCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(mainValue)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(color)
                        
                        Text(mainLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } content: {
            VStack(spacing: 12) {
                ForEach(details, id: \.label) { detail in
                    HStack {
                        Text(detail.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(detail.value)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

// MARK: - Pull-Up Drawer

/// A pull-up drawer component with snap points
struct PullUpDrawer<Content: View>: View {
    @Binding var state: DrawerSnapPoint
    let content: Content
    let snapPoints: [DrawerSnapPoint]
    var backgroundColor: Color = Color(.systemBackground)
    var handleColor: Color = .secondary
    
    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false
    
    init(
        state: Binding<DrawerSnapPoint>,
        snapPoints: [DrawerSnapPoint] = [.collapsed, .half, .expanded],
        backgroundColor: Color = Color(.systemBackground),
        @ViewBuilder content: () -> Content
    ) {
        self._state = state
        self.snapPoints = snapPoints
        self.backgroundColor = backgroundColor
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            let currentHeight = height(for: state, in: geometry) + dragOffset
            
            VStack(spacing: 0) {
                // Handle
                VStack(spacing: 8) {
                    Capsule()
                        .fill(handleColor.opacity(0.5))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .gesture(dragGesture(in: geometry))
                
                // Content
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: max(0, currentHeight))
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
        }
    }
    
    private func height(for state: DrawerSnapPoint, in geometry: GeometryProxy) -> CGFloat {
        switch state {
        case .collapsed:
            return geometry.size.height * 0.12
        case .quarter:
            return geometry.size.height * 0.25
        case .half:
            return geometry.size.height * 0.5
        case .threeQuarter:
            return geometry.size.height * 0.75
        case .expanded:
            return geometry.size.height * 0.92
        case .custom(let fraction):
            return geometry.size.height * fraction
        }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in
                state = true
            }
            .onChanged { value in
                dragOffset = -value.translation.height
            }
            .onEnded { value in
                let predictedEnd = -value.predictedEndTranslation.height
                let currentHeight = height(for: state, in: geometry)
                let targetHeight = currentHeight + predictedEnd
                
                // Find nearest snap point
                let newState = snapPoints.min(by: {
                    abs(height(for: $0, in: geometry) - targetHeight) <
                    abs(height(for: $1, in: geometry) - targetHeight)
                }) ?? state
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    state = newState
                    dragOffset = 0
                }
            }
    }
}

enum DrawerSnapPoint: Equatable {
    case collapsed
    case quarter
    case half
    case threeQuarter
    case expanded
    case custom(CGFloat)
}

// MARK: - Swipe Actions Row

/// A row with swipe actions (like iOS Mail app)
struct SwipeActionsRow<Content: View>: View {
    let content: Content
    var leadingActions: [SwipeAction] = []
    var trailingActions: [SwipeAction] = []
    var threshold: CGFloat = 80
    
    @State private var offset: CGFloat = 0
    @State private var activeAction: SwipeAction?
    @GestureState private var isDragging = false
    
    init(
        leadingActions: [SwipeAction] = [],
        trailingActions: [SwipeAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            // Leading actions background
            HStack(spacing: 0) {
                ForEach(leadingActions) { action in
                    actionButton(action, leading: true)
                }
                Spacer()
            }
            
            // Trailing actions background
            HStack(spacing: 0) {
                Spacer()
                ForEach(trailingActions.reversed()) { action in
                    actionButton(action, leading: false)
                }
            }
            
            // Main content
            content
                .background(Color(.systemBackground))
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                            let maxLeading = CGFloat(leadingActions.count) * threshold
                            let maxTrailing = CGFloat(trailingActions.count) * threshold
                            
                            let translation = value.translation.width
                            
                            if translation > 0 && !leadingActions.isEmpty {
                                offset = min(translation, maxLeading)
                            } else if translation < 0 && !trailingActions.isEmpty {
                                offset = max(translation, -maxTrailing)
                            }
                        }
                        .onEnded { value in
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if abs(offset) > threshold / 2 || abs(velocity) > 100 {
                                    // Snap to action
                                    if offset > 0 {
                                        offset = CGFloat(leadingActions.count) * threshold
                                    } else {
                                        offset = -CGFloat(trailingActions.count) * threshold
                                    }
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }
    
    @ViewBuilder
    private func actionButton(_ action: SwipeAction, leading: Bool) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                offset = 0
            }
            action.action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.title3)
                if let title = action.title {
                    Text(title)
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .frame(width: threshold, height: 60)
            .background(action.color)
        }
    }
}

struct SwipeAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String?
    let color: Color
    let action: () -> Void
    
    static func delete(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(icon: "trash.fill", title: "Delete", color: .red, action: action)
    }
    
    static func share(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(icon: "square.and.arrow.up", title: "Share", color: .blue, action: action)
    }
    
    static func edit(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(icon: "pencil", title: "Edit", color: .orange, action: action)
    }
    
    static func favorite(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(icon: "heart.fill", title: "Favorite", color: .pink, action: action)
    }
    
    static func note(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(icon: "note.text", title: "Note", color: .purple, action: action)
    }
}

// MARK: - Long Press Context Menu

/// A view that shows a context menu on long press with haptic feedback
struct LongPressContextMenu<Content: View, MenuContent: View>: View {
    let content: Content
    let menuContent: MenuContent
    
    @State private var isPressed = false
    
    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder menuContent: () -> MenuContent
    ) {
        self.content = content()
        self.menuContent = menuContent()
    }
    
    var body: some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contextMenu {
                menuContent
            }
            .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                withAnimation {
                    isPressed = pressing
                }
                if pressing {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }, perform: { })
    }
}

// MARK: - Floating Action Button

/// A floating action button that can expand to show multiple actions
struct FloatingActionButton<Content: View>: View {
    let icon: String
    let color: Color
    let actions: [FABAction]
    var expandDirection: FABExpandDirection = .up
    
    @State private var isExpanded = false
    
    init(
        icon: String,
        color: Color = .green,
        expandDirection: FABExpandDirection = .up,
        @ViewBuilder actions: () -> Content
    ) where Content == EmptyView {
        self.icon = icon
        self.color = color
        self.expandDirection = expandDirection
        self.actions = []
    }
    
    init(
        icon: String,
        color: Color = .green,
        expandDirection: FABExpandDirection = .up,
        actions: [FABAction]
    ) where Content == EmptyView {
        self.icon = icon
        self.color = color
        self.expandDirection = expandDirection
        self.actions = actions
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if expandDirection == .up && isExpanded {
                expandedActions
            }
            
            // Main FAB
            Button(action: { toggleExpanded() }) {
                Image(systemName: isExpanded ? "xmark" : icon)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 56, height: 56)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.3), radius: 8, y: 4)
            }
            
            if expandDirection == .down && isExpanded {
                expandedActions
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }
    
    @ViewBuilder
    private var expandedActions: some View {
        VStack(spacing: 12) {
            ForEach(actions) { action in
                Button(action: {
                    withAnimation { isExpanded = false }
                    action.action()
                }) {
                    HStack(spacing: 8) {
                        if let title = action.title {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        
                        Image(systemName: action.icon)
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(action.color)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded.toggle()
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

struct FABAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String?
    let color: Color
    let action: () -> Void
}

enum FABExpandDirection {
    case up
    case down
}

// MARK: - Segmented Picker Card

/// A card with segmented control for switching between views
struct SegmentedCard<Content: View>: View {
    let segments: [String]
    @Binding var selectedIndex: Int
    let content: (Int) -> Content
    
    var body: some View {
        VStack(spacing: 16) {
            // Segmented control
            Picker("", selection: $selectedIndex) {
                ForEach(0..<segments.count, id: \.self) { index in
                    Text(segments[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            
            // Content
            content(selectedIndex)
                .animation(.easeInOut(duration: 0.2), value: selectedIndex)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Peek & Pop Card

/// A card that shows a preview on hover/press
struct PeekCard<Content: View, Preview: View>: View {
    let content: Content
    let preview: Preview
    
    @State private var showPreview = false
    
    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview
    ) {
        self.content = content()
        self.preview = preview()
    }
    
    var body: some View {
        content
            .onLongPressGesture(minimumDuration: 0.3, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPreview = pressing
                }
            }, perform: { })
            .popover(isPresented: $showPreview) {
                preview
                    .presentationCompactAdaptation(.popover)
            }
    }
}

// MARK: - Preview

#Preview("UI Components") {
    ScrollView {
        VStack(spacing: 20) {
            // Expandable Card
            StatsExpandableCard(
                title: "Strokes Gained",
                mainValue: "+0.8",
                mainLabel: "Total",
                details: [
                    ("Driving", "+0.3"),
                    ("Approach", "-0.2"),
                    ("Short Game", "+0.4"),
                    ("Putting", "+0.3")
                ]
            )
            
            // Swipe Actions Row
            SwipeActionsRow(
                leadingActions: [.favorite { }],
                trailingActions: [.delete { }, .share { }]
            ) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Round at Pebble Beach")
                            .font(.headline)
                        Text("Score: 78 (+6)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            // Segmented Card
            SegmentedCard(
                segments: ["Simple", "Advanced"],
                selectedIndex: .constant(0)
            ) { index in
                if index == 0 {
                    Text("Simple stats view")
                } else {
                    Text("Advanced analytics")
                }
            }
            
            Spacer(minLength: 100)
        }
        .padding()
    }
}
