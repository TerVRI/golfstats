import SwiftUI

struct CourseDiscussionsView: View {
    let course: Course
    @EnvironmentObject var authManager: AuthManager
    @State private var discussions: [CourseDiscussion] = []
    @State private var replies: [String: [DiscussionReply]] = [:]
    @State private var isLoading = true
    @State private var showNewDiscussion = false
    @State private var newDiscussionTitle = ""
    @State private var newDiscussionContent = ""
    @State private var replyingTo: String?
    @State private var replyContent = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // New Discussion Button
                    Button {
                        showNewDiscussion = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Ask a Question")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    if discussions.isEmpty && !isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "message")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No discussions yet")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Be the first to ask a question about this course!")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ForEach(discussions) { discussion in
                            DiscussionCard(
                                discussion: discussion,
                                replies: replies[discussion.id] ?? [],
                                onReply: { discussionId in
                                    replyingTo = discussionId
                                },
                                replyContent: $replyContent,
                                onSubmitReply: { discussionId, content in
                                    Task {
                                        await submitReply(discussionId: discussionId, content: content)
                                    }
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color("Background"))
            .navigationTitle("Discussions")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDiscussions()
            }
            .refreshable {
                await loadDiscussions()
            }
            .sheet(isPresented: $showNewDiscussion) {
                NewDiscussionSheet(
                    courseName: course.name,
                    title: $newDiscussionTitle,
                    content: $newDiscussionContent,
                    onSubmit: {
                        Task {
                            await createDiscussion()
                        }
                    },
                    onCancel: {
                        showNewDiscussion = false
                        newDiscussionTitle = ""
                        newDiscussionContent = ""
                        errorMessage = nil
                    }
                )
            }
            .onChange(of: showNewDiscussion) { _, isShowing in
                if !isShowing && !newDiscussionTitle.isEmpty {
                    // Sheet was dismissed - check if we need to show error
                    if errorMessage == nil {
                        // Clear fields if no error (successful submission)
                        newDiscussionTitle = ""
                        newDiscussionContent = ""
                    }
                }
            }
        }
    }
    
    private func loadDiscussions() async {
        isLoading = true
        errorMessage = nil
        
        do {
            discussions = try await DataService.shared.fetchCourseDiscussions(
                courseId: course.id,
                authHeaders: authManager.authHeaders
            )
            
            // Load replies for each discussion
            for discussion in discussions {
                do {
                    let discussionReplies = try await DataService.shared.fetchDiscussionReplies(
                        discussionId: discussion.id,
                        authHeaders: authManager.authHeaders
                    )
                    replies[discussion.id] = discussionReplies
                } catch {
                    // Continue if replies fail to load
                }
            }
        } catch {
            errorMessage = "Failed to load discussions: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func createDiscussion() async {
        guard let user = authManager.currentUser else {
            errorMessage = "Please sign in to create a discussion"
            return
        }
        guard !newDiscussionTitle.isEmpty && !newDiscussionContent.isEmpty else {
            errorMessage = "Please enter both a title and content"
            return
        }
        
        errorMessage = nil
        
        do {
            try await DataService.shared.createCourseDiscussion(
                courseId: course.id,
                userId: user.id,
                authHeaders: authManager.authHeaders,
                title: newDiscussionTitle,
                content: newDiscussionContent
            )
            // Small delay to ensure database is updated
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            showNewDiscussion = false
            newDiscussionTitle = ""
            newDiscussionContent = ""
            await loadDiscussions()
        } catch {
            print("Error creating discussion: \(error)")
            errorMessage = "Failed to create discussion: \(error.localizedDescription)"
            // Keep the sheet open so user can see the error and retry
        }
    }
    
    private func submitReply(discussionId: String, content: String) async {
        guard let user = authManager.currentUser else { return }
        guard !content.isEmpty else { return }
        
        do {
            try await DataService.shared.replyToDiscussion(
                discussionId: discussionId,
                userId: user.id,
                authHeaders: authManager.authHeaders,
                content: content
            )
            replyContent = ""
            replyingTo = nil
            await loadDiscussions()
        } catch {
            errorMessage = "Failed to submit reply: \(error.localizedDescription)"
        }
    }
}

struct DiscussionCard: View {
    let discussion: CourseDiscussion
    let replies: [DiscussionReply]
    let onReply: (String) -> Void
    @Binding var replyContent: String
    let onSubmitReply: (String, String) -> Void
    
    @State private var isExpanded = false
    @State private var showReplyField = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Discussion Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(discussion.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(formatDate(discussion.createdAt))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if let author = discussion.authorName {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            // Discussion Content
            Text(discussion.content)
                .font(.subheadline)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            // Reply Count
            if !replies.isEmpty {
                Button {
                    isExpanded.toggle()
                } label: {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            // Replies
            if isExpanded {
                ForEach(replies) { reply in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let author = reply.authorName {
                                Text(author)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            Text(formatDate(reply.createdAt))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Text(reply.content)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 16)
                    .padding(.vertical, 4)
                }
            }
            
            // Reply Button
            Button {
                showReplyField.toggle()
            } label: {
                HStack {
                    Image(systemName: "arrowshape.turn.up.left")
                    Text("Reply")
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            // Reply Field
            if showReplyField {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Write a reply...", text: $replyContent, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color("BackgroundTertiary"))
                        .cornerRadius(8)
                        .lineLimit(3...6)
                    
                    HStack {
                        Button("Cancel") {
                            showReplyField = false
                            replyContent = ""
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Button("Submit") {
                            onSubmitReply(discussion.id, replyContent)
                            showReplyField = false
                        }
                        .foregroundColor(.green)
                        .disabled(replyContent.isEmpty)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(12)
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

struct NewDiscussionSheet: View {
    let courseName: String
    @Binding var title: String
    @Binding var content: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Course") {
                    Text(courseName)
                        .foregroundColor(.gray)
                }
                
                Section("Question") {
                    TextField("Title", text: $title)
                    TextField("Your question...", text: $content, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("Ask a Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        onSubmit()
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
        }
    }
}

#Preview {
    CourseDiscussionsView(
        course: Course(
            id: "1",
            name: "Pebble Beach",
            city: "Pebble Beach",
            state: "CA",
            country: "USA",
            address: nil,
            phone: nil,
            website: nil,
            courseRating: 75.5,
            slopeRating: 145,
            par: 72,
            holes: 18,
            latitude: 36.5725,
            longitude: -121.9486,
            avgRating: 4.8,
            reviewCount: 150,
            holeData: nil,
            updatedAt: nil,
            createdAt: nil
        )
    )
    .environmentObject(AuthManager())
    .preferredColorScheme(.dark)
}
