import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var notifications: [Notification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var unreadCount: Int = 0
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if notifications.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bell")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No notifications yet")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("You'll see notifications here when someone confirms your course contributions or mentions you.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        if unreadCount > 0 {
                            Section {
                                Button {
                                    Task {
                                        await markAllAsRead()
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Mark all as read")
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        
                        ForEach(notifications) { notification in
                            NotificationRow(notification: notification) {
                                Task {
                                    await markAsRead(notification.id)
                                }
                            }
                            .listRowBackground(
                                notification.isRead
                                    ? Color("BackgroundSecondary")
                                    : Color("BackgroundSecondary").opacity(0.5)
                            )
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color("Background"))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(unreadCount)")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }
    
    private func loadNotifications() async {
        guard let user = authManager.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            notifications = try await DataService.shared.fetchNotifications(
                userId: user.id,
                authHeaders: authManager.authHeaders
            )
            unreadCount = notifications.filter { !$0.isRead }.count
        } catch {
            errorMessage = "Failed to load notifications: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func markAsRead(_ id: String) async {
        do {
            try await DataService.shared.markNotificationAsRead(
                notificationId: id,
                authHeaders: authManager.authHeaders
            )
            if let index = notifications.firstIndex(where: { $0.id == id }) {
                notifications[index] = Notification(
                    id: notifications[index].id,
                    userId: notifications[index].userId,
                    type: notifications[index].type,
                    title: notifications[index].title,
                    message: notifications[index].message,
                    courseId: notifications[index].courseId,
                    contributionId: notifications[index].contributionId,
                    relatedUserId: notifications[index].relatedUserId,
                    isRead: true,
                    readAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: notifications[index].createdAt
                )
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            errorMessage = "Failed to mark as read: \(error.localizedDescription)"
        }
    }
    
    private func markAllAsRead() async {
        guard let user = authManager.currentUser else { return }
        
        do {
            try await DataService.shared.markAllNotificationsAsRead(
                userId: user.id,
                authHeaders: authManager.authHeaders
            )
            notifications = notifications.map { notification in
                Notification(
                    id: notification.id,
                    userId: notification.userId,
                    type: notification.type,
                    title: notification.title,
                    message: notification.message,
                    courseId: notification.courseId,
                    contributionId: notification.contributionId,
                    relatedUserId: notification.relatedUserId,
                    isRead: true,
                    readAt: ISO8601DateFormatter().string(from: Date()),
                    createdAt: notification.createdAt
                )
            }
            unreadCount = 0
        } catch {
            errorMessage = "Failed to mark all as read: \(error.localizedDescription)"
        }
    }
}

struct NotificationRow: View {
    let notification: Notification
    let onMarkRead: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: iconForType(notification.type))
                .foregroundColor(colorForType(notification.type))
                .font(.title3)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if !notification.isRead {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                    
                    Spacer()
                    
                    Text(formatDate(notification.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text(notification.message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            
            if !notification.isRead {
                Button {
                    onMarkRead()
                } label: {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "course_confirmed", "course_verified":
            return "checkmark.circle.fill"
        case "contribution_approved":
            return "star.fill"
        case "contribution_rejected":
            return "xmark.circle.fill"
        case "thank_you_received":
            return "heart.fill"
        case "question_asked":
            return "questionmark.circle.fill"
        case "milestone_reached":
            return "trophy.fill"
        default:
            return "bell.fill"
        }
    }
    
    private func colorForType(_ type: String) -> Color {
        switch type {
        case "course_confirmed", "course_verified", "contribution_approved":
            return .green
        case "contribution_rejected":
            return .red
        case "thank_you_received":
            return .pink
        case "question_asked":
            return .blue
        case "milestone_reached":
            return .yellow
        default:
            return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            return dateFormatter.string(from: date)
        }
    }
}

#Preview {
    NotificationsView()
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
