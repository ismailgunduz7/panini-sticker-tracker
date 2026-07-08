import SwiftUI

/// The Friends segment of the Trade tab: incoming/sent requests and the
/// friend list. Trade visibility per friend arrives in a later phase.
struct FriendsView: View {
    @Environment(AccountStore.self) private var account
    @Environment(FriendStore.self) private var friendStore
    @State private var showingSearch = false
    @State private var friendPendingRemoval: FriendStore.Friendship?

    var body: some View {
        Group {
            switch account.phase {
            case .signedIn:
                friendList
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .needsProfile:
                ContentUnavailableView {
                    Label("Finish Your Profile", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Pick a username in Settings so friends can find you.")
                }
            case .signedOut:
                ContentUnavailableView {
                    Label("Sign In to Add Friends", systemImage: "person.2")
                } description: {
                    Text("Sign in with Apple in Settings to add friends and see which stickers you can trade with each other.")
                }
            }
        }
        .toolbar {
            if account.profile != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSearch = true
                    } label: {
                        Label("Add Friend", systemImage: "person.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            FriendSearchView()
        }
        .task(id: account.profile?.id) {
            if account.profile != nil {
                await friendStore.refresh()
            }
        }
    }

    private var friendList: some View {
        List {
            if !friendStore.incomingRequests.isEmpty {
                Section("Friend Requests") {
                    ForEach(friendStore.incomingRequests) { request in
                        HStack {
                            nameLabel(request)
                            Spacer()
                            Button {
                                Task { await friendStore.accept(request.id) }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .accessibilityLabel("Accept")
                            Button {
                                Task { await friendStore.decline(request.id) }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Decline")
                        }
                        // Borderless keeps the two buttons individually
                        // tappable instead of the whole row firing both.
                        .buttonStyle(.borderless)
                    }
                }
            }

            if !friendStore.outgoingRequests.isEmpty {
                Section("Sent Requests") {
                    ForEach(friendStore.outgoingRequests) { request in
                        HStack {
                            nameLabel(request)
                            Spacer()
                            Text("Pending")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Cancel", role: .destructive) {
                                Task { await friendStore.remove(request.id) }
                            }
                        }
                    }
                }
            }

            Section("Friends") {
                if friendStore.friends.isEmpty {
                    Text(friendStore.hasLoaded
                         ? "No friends yet. Find one with the add button above."
                         : "Loading…")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(friendStore.friends) { friend in
                        nameLabel(friend)
                            .swipeActions {
                                Button("Remove", role: .destructive) {
                                    friendPendingRemoval = friend
                                }
                            }
                    }
                }
            }
        }
        .refreshable {
            await friendStore.refresh()
        }
        .confirmationDialog(
            Text("Remove @\(friendPendingRemoval?.username ?? "") from your friends? You can only reconnect with a new request."),
            isPresented: Binding(
                get: { friendPendingRemoval != nil },
                set: { if !$0 { friendPendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove Friend", role: .destructive) {
                if let friend = friendPendingRemoval {
                    Task { await friendStore.remove(friend.id) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func nameLabel(_ friendship: FriendStore.Friendship) -> some View {
        VStack(alignment: .leading) {
            Text("@\(friendship.username)")
                .fontWeight(.medium)
            if !friendship.displayName.isEmpty {
                Text(friendship.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
