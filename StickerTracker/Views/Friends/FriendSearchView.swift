import SwiftUI

/// Username search for sending friend requests.
struct FriendSearchView: View {
    @Environment(FriendStore.self) private var friendStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FriendStore.Candidate] = []
    @State private var hasSearched = false
    @State private var sendingTo: Set<UUID> = []
    @State private var sentTo: Set<UUID> = []
    @State private var errorMessage: String?

    private enum CandidateStatus {
        case addable, sent, pending, friend
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(results) { candidate in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("@\(candidate.username)")
                                .fontWeight(.medium)
                            if !candidate.displayName.isEmpty {
                                Text(candidate.displayName)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        switch status(of: candidate) {
                        case .addable:
                            Button("Add") { send(candidate) }
                                .buttonStyle(.borderedProminent)
                                .disabled(sendingTo.contains(candidate.id))
                        case .sent, .pending:
                            Text("Pending")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        case .friend:
                            Label("Friends", systemImage: "checkmark")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .overlay {
                if results.isEmpty {
                    if hasSearched {
                        ContentUnavailableView.search(text: query)
                    } else {
                        ContentUnavailableView {
                            Label("Find Friends", systemImage: "magnifyingglass")
                        } description: {
                            Text("Search for a friend by their username.")
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Username")
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .task(id: query) {
                guard query.count >= 2 else {
                    results = []
                    hasSearched = false
                    return
                }
                // Debounce: typing cancels this task and restarts the clock.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                results = await friendStore.search(query)
                hasSearched = true
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Couldn't Send Request", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func status(of candidate: FriendStore.Candidate) -> CandidateStatus {
        if friendStore.friends.contains(where: { $0.id == candidate.id }) { return .friend }
        if sentTo.contains(candidate.id) { return .sent }
        if friendStore.outgoingRequests.contains(where: { $0.id == candidate.id })
            || friendStore.incomingRequests.contains(where: { $0.id == candidate.id }) { return .pending }
        return .addable
    }

    private func send(_ candidate: FriendStore.Candidate) {
        sendingTo.insert(candidate.id)
        Task {
            do {
                try await friendStore.sendRequest(toUsername: candidate.username)
                sentTo.insert(candidate.id)
            } catch {
                errorMessage = error.localizedDescription
            }
            sendingTo.remove(candidate.id)
        }
    }
}
