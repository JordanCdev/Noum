import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)

enum SpeakOffConnectionCopy {
    static let unlinkedFriendsNotice = "Scored speak-offs need linked Noum accounts on both sides. Manual friends stay local until linked invites are available."
}

enum SpeakOffFriendEligibility {
    static func linkedFriends(from friends: [NoumFriend]) -> [NoumFriend] {
        friends.filter(isLinked)
    }

    static func isLinked(_ friend: NoumFriend) -> Bool {
        guard let accountID = friend.accountID?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !accountID.isEmpty
    }
}

@available(iOS 17.0, *)
struct AsyncChallengeDetailSheet: View {
    let challenge: AsyncChallenge
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text("THE PROMPT")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(1.2)

                        Text(challenge.prompt)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(Color.teal.opacity(0.15), lineWidth: 1)
                    )

                    if challenge.bothHavePlayed {
                        HStack(spacing: 16) {
                            scoreCard(
                                name: challenge.creatorName,
                                score: challenge.creatorScore ?? 0,
                                duration: challenge.creatorDuration,
                                reaction: challenge.opponentReaction
                            )
                            Text("vs")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.secondary)
                            scoreCard(
                                name: challenge.opponentName,
                                score: challenge.opponentScore ?? 0,
                                duration: challenge.opponentDuration,
                                reaction: challenge.creatorReaction
                            )
                        }

                        VStack(spacing: 10) {
                            Text("React to their performance")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                ForEach(AsyncChallenge.Reaction.allCases) { reaction in
                                    Button {
                                        challenges.addReaction(challengeID: challenge.id, reaction: reaction)
                                    } label: {
                                        Text(reaction.rawValue)
                                            .font(.title2)
                                            .frame(width: 44, height: 44)
                                            .background(Color(.systemGray6), in: Circle())
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "hourglass")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Waiting for both players to complete the challenge.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 20)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("Expires \(challenge.expiresAt, style: .relative)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Speak-off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func scoreCard(name: String, score: Int, duration: TimeInterval?, reaction: AsyncChallenge.Reaction?) -> some View {
        VStack(spacing: 10) {
            Text(String(name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )

            Text(name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(score)")
                .font(Typography.figtreeNumeric(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(score >= 70 ? .green : score >= 50 ? .orange : .red)

            if let dur = duration {
                Text(String(format: "%d:%02d", Int(dur) / 60, Int(dur) % 60))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let reaction {
                Text(reaction.rawValue)
                    .font(.title3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}

@available(iOS 17.0, *)
struct ChallengePickFriendSheet: View {
    @ObservedObject var friends: FriendsManager
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @State private var createdChallenge: AsyncChallenge?
    @State private var speakOffNavPath = NavigationPath()

    private var linkedFriends: [NoumFriend] {
        SpeakOffFriendEligibility.linkedFriends(from: friends.friends)
    }

    var body: some View {
        NavigationStack(path: $speakOffNavPath) {
            Group {
                if let challenge = createdChallenge {
                    VStack(spacing: 28) {
                        Spacer()

                        VStack(spacing: 8) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.teal)
                            Text("Practice Speak-off created.")
                                .font(.title2.weight(.bold))
                        }

                        VStack(spacing: 12) {
                            Text("YOUR PROMPT")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .tracking(1.2)
                            Text(challenge.prompt)
                                .font(.title3.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                .stroke(Color.teal.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)

                        Text("vs \(challenge.opponentName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            speakOffNavPath.append(AppDestination.timedPractice)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .font(.headline)
                                Text("Start Speaking")
                                    .font(.headline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.teal, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 20)

                        Button("Do It Later") { dismiss() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    .navigationTitle("Speak-off")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { dismiss() }
                        }
                    }
                    .navigationDestination(for: AppDestination.self) { destination in
                        if case .timedPractice = destination {
                            TimedPracticeView(navigationPath: $speakOffNavPath)
                        }
                    }
                } else {
                    List {
                        if linkedFriends.isEmpty {
                            VStack(spacing: 12) {
                                Text("No linked friends yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("Scored speak-offs need a friend linked to a Noum account. Manual friends stay local for now.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(linkedFriends) { friend in
                                Button {
                                    guard let opponentAccountID = friend.accountID else { return }
                                    let challenge = challenges.createAsyncChallenge(
                                        opponentID: friend.id,
                                        opponentName: friend.displayName,
                                        opponentAccountID: opponentAccountID
                                    )
                                    withAnimation(.standardSpring) {
                                        createdChallenge = challenge
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                                )
                                                .frame(width: 40, height: 40)

                                            Text(friend.initials)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }

                                        Text(friend.displayName)
                                            .font(.subheadline.weight(.medium))

                                        Spacer()

                                        Image(systemName: "bolt.fill")
                                            .font(.caption)
                                            .foregroundStyle(.teal)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Challenge a Friend")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, *)
struct AddFriendSheet: View {
    @ObservedObject var friends: FriendsManager
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @State private var friendName = ""
    @State private var didAdd = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    if friendName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text(String(friendName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                            .font(Typography.bigStat)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Add a Practice Contact")
                        .font(.title3.weight(.bold))
                    Text("Save a name locally for practice planning. Scored speak-offs need linked Noum accounts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Friend's name", text: $friendName)
                    .font(.body)
                    .padding(16)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .padding(.horizontal, 20)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addFriend() }

                if didAdd {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Added.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: addFriend) {
                    Text("Save Contact")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            friendName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(.systemGray4)
                                : Color.blue,
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                .disabled(friendName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { nameFieldFocused = true }
        }
    }

    private func addFriend() {
        let trimmed = friendName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        friends.addFriend(name: trimmed, method: .manual)
        withAnimation(.standardSpring) {
            didAdd = true
        }
        friendName = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

#endif
