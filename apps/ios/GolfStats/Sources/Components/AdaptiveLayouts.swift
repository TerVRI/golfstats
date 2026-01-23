import SwiftUI

// MARK: - Size Class Environment

/// Helper to detect current device size class
struct DeviceLayout {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

// MARK: - Adaptive Container

/// Container that adapts layout based on horizontal size class
struct AdaptiveContainer<Compact: View, Regular: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let compact: Compact
    let regular: Regular
    
    init(@ViewBuilder compact: () -> Compact, @ViewBuilder regular: () -> Regular) {
        self.compact = compact()
        self.regular = regular()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            regular
        } else {
            compact
        }
    }
}

// MARK: - Adaptive Grid

/// Grid that adjusts columns based on size class
struct AdaptiveGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let compactColumns: Int
    let regularColumns: Int
    let spacing: CGFloat
    let content: Content
    
    init(
        compactColumns: Int = 2,
        regularColumns: Int = 4,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.compactColumns = compactColumns
        self.regularColumns = regularColumns
        self.spacing = spacing
        self.content = content()
    }
    
    var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? regularColumns : compactColumns
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: spacing) {
            content
        }
    }
}

// MARK: - Adaptive Split View

/// Split view for iPad, stack for iPhone
struct AdaptiveSplitView<Sidebar: View, Detail: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let sidebar: Sidebar
    let detail: Detail
    let sidebarWidth: CGFloat
    
    init(
        sidebarWidth: CGFloat = 320,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebarWidth = sidebarWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: sidebarWidth)
                
                Divider()
                
                detail
                    .frame(maxWidth: .infinity)
            }
        } else {
            // On compact, just show detail (sidebar via navigation)
            detail
        }
    }
}

// MARK: - Adaptive Navigation Split View (iOS 16+)

@available(iOS 16.0, *)
struct AdaptiveNavigationSplit<Sidebar: View, Content: View, Detail: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let sidebar: Sidebar
    let content: Content
    let detail: Detail
    
    init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder content: () -> Content,
        @ViewBuilder detail: () -> Detail
    ) {
        self.sidebar = sidebar()
        self.content = content()
        self.detail = detail()
    }
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            content
        } detail: {
            detail
        }
    }
}

// MARK: - Adaptive Spacing

struct AdaptiveSpacing {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var small: CGFloat { horizontalSizeClass == .regular ? 12 : 8 }
    var medium: CGFloat { horizontalSizeClass == .regular ? 20 : 12 }
    var large: CGFloat { horizontalSizeClass == .regular ? 32 : 16 }
    var extraLarge: CGFloat { horizontalSizeClass == .regular ? 48 : 24 }
}

// MARK: - View Modifiers

extension View {
    /// Apply different padding based on size class
    func adaptivePadding(_ edges: Edge.Set = .all) -> some View {
        modifier(AdaptivePaddingModifier(edges: edges))
    }
    
    /// Apply maximum width constraint for readability on large screens
    func readableWidth(maxWidth: CGFloat = 700) -> some View {
        frame(maxWidth: maxWidth)
    }
    
    /// Conditionally apply modifier for iPad only
    func iPadOnly<M: ViewModifier>(_ modifier: M) -> some View {
        self.modifier(IPadOnlyModifier(modifier: modifier))
    }
}

struct AdaptivePaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let edges: Edge.Set
    
    func body(content: Content) -> some View {
        let padding: CGFloat = horizontalSizeClass == .regular ? 24 : 16
        content.padding(edges, padding)
    }
}

struct IPadOnlyModifier<M: ViewModifier>: ViewModifier {
    let modifier: M
    
    func body(content: Content) -> some View {
        if DeviceLayout.isIPad {
            content.modifier(modifier)
        } else {
            content
        }
    }
}

// MARK: - Adaptive Font Sizes

extension Font {
    static func adaptiveTitle(_ sizeClass: UserInterfaceSizeClass?) -> Font {
        sizeClass == .regular ? .largeTitle : .title
    }
    
    static func adaptiveHeadline(_ sizeClass: UserInterfaceSizeClass?) -> Font {
        sizeClass == .regular ? .title2 : .headline
    }
    
    static func adaptiveBody(_ sizeClass: UserInterfaceSizeClass?) -> Font {
        sizeClass == .regular ? .title3 : .body
    }
}

// MARK: - iPad Dashboard Layout

struct IPadDashboardLayout<Stats: View, Charts: View, Recent: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let stats: Stats
    let charts: Charts
    let recent: Recent
    
    init(
        @ViewBuilder stats: () -> Stats,
        @ViewBuilder charts: () -> Charts,
        @ViewBuilder recent: () -> Recent
    ) {
        self.stats = stats()
        self.charts = charts()
        self.recent = recent()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: 3-column layout
            HStack(alignment: .top, spacing: 20) {
                // Left column - Stats
                VStack(spacing: 16) {
                    stats
                }
                .frame(width: 280)
                
                // Center column - Charts (wider)
                VStack(spacing: 16) {
                    charts
                }
                .frame(maxWidth: .infinity)
                
                // Right column - Recent activity
                VStack(spacing: 16) {
                    recent
                }
                .frame(width: 320)
            }
            .padding()
        } else {
            // iPhone: Stacked layout
            VStack(spacing: 16) {
                stats
                charts
                recent
            }
            .padding()
        }
    }
}

// MARK: - iPad Round View Layout

struct IPadRoundLayout<Map: View, Scorecard: View, Details: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedTab: RoundTab = .map
    
    enum RoundTab {
        case map, scorecard, details
    }
    
    let map: Map
    let scorecard: Scorecard
    let details: Details
    
    init(
        @ViewBuilder map: () -> Map,
        @ViewBuilder scorecard: () -> Scorecard,
        @ViewBuilder details: () -> Details
    ) {
        self.map = map()
        self.scorecard = scorecard()
        self.details = details()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Side-by-side layout
            HStack(spacing: 0) {
                // Left: Full map
                map
                    .frame(maxWidth: .infinity)
                
                Divider()
                
                // Right: Scorecard + Details in tabs
                VStack(spacing: 0) {
                    // Tab picker
                    Picker("View", selection: $selectedTab) {
                        Text("Scorecard").tag(RoundTab.scorecard)
                        Text("Details").tag(RoundTab.details)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    Group {
                        switch selectedTab {
                        case .map:
                            EmptyView()
                        case .scorecard:
                            scorecard
                        case .details:
                            details
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(width: 400)
            }
        } else {
            // iPhone: Tab-based layout
            TabView {
                map
                    .tabItem { Label("Map", systemImage: "map") }
                
                scorecard
                    .tabItem { Label("Scorecard", systemImage: "list.number") }
                
                details
                    .tabItem { Label("Details", systemImage: "info.circle") }
            }
        }
    }
}

// MARK: - iPad Courses List Layout

struct IPadCoursesLayout<List: View, Detail: View>: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    let list: List
    let detail: Detail
    
    init(
        @ViewBuilder list: () -> List,
        @ViewBuilder detail: () -> Detail
    ) {
        self.list = list()
        self.detail = detail()
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: Master-Detail
            HStack(spacing: 0) {
                list
                    .frame(width: 350)
                
                Divider()
                
                detail
                    .frame(maxWidth: .infinity)
            }
        } else {
            // iPhone: Navigation stack
            list
        }
    }
}

// MARK: - Previews

#Preview("Adaptive Grid - iPhone") {
    AdaptiveGrid(compactColumns: 2, regularColumns: 4) {
        ForEach(0..<8) { i in
            RoundedRectangle(cornerRadius: 8)
                .fill(.blue.opacity(0.3))
                .frame(height: 100)
                .overlay(Text("\(i + 1)"))
        }
    }
    .padding()
}

#Preview("Adaptive Split - iPad") {
    AdaptiveSplitView {
        List {
            ForEach(0..<10) { i in
                Text("Item \(i)")
            }
        }
    } detail: {
        Text("Detail View")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }
}
