import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)

enum SpeakOffConnectionCopy {
    static let unlinkedFriendsNotice = "Speak-offs are available with friends whose Noum accounts are linked. Saved contacts remain available for practice planning until linked invites are available."
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

private extension AsyncChallenge.Reaction {
    var symbolName: String {
        switch self {
        case .fire: return "sparkles"
        case .clap: return "hands.clap.fill"
        case .strong: return "bolt.fill"
        case .mindBlown: return "lightbulb.fill"
        case .trophy: return "checkmark.seal.fill"
        case .heart: return "heart.fill"
        }
    }

    var accessibilityName: String {
        switch self {
        case .fire: return "Standout"
        case .clap: return "Well delivered"
        case .strong: return "Strong"
        case .mindBlown: return "Fresh idea"
        case .trophy: return "Polished"
        case .heart: return "Warm"
        }
    }
}

@available(iOS 17.0, *)
struct AsyncChallengeDetailSheet: View {
    let challenge: AsyncChallenge
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Prompt")
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(AppColor.brandBlue)

                            Text(challenge.prompt)
                                .font(Typography.cardTitle)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.lg)
                        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: 1)
                        )

                        if challenge.bothHavePlayed {
                            VStack(spacing: Spacing.md) {
                                Group {
                                    if dynamicTypeSize.isAccessibilitySize {
                                        VStack(spacing: Spacing.sm) {
                                            comparisonScoreCards
                                        }
                                    } else {
                                        HStack(spacing: Spacing.sm) {
                                            comparisonScoreCards
                                        }
                                    }
                                }

                                VStack(spacing: Spacing.sm) {
                                    Text("Send a reaction")
                                        .font(Typography.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: Spacing.xs) {
                                        ForEach(AsyncChallenge.Reaction.allCases) { reaction in
                                            Button {
                                                challenges.addReaction(challengeID: challenge.id, reaction: reaction)
                                            } label: {
                                                Image(systemName: reaction.symbolName)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundStyle(AppColor.brandBlue)
                                                    .frame(width: 44, height: 44)
                                                    .background(AppColor.brandBlue.opacity(0.08), in: Circle())
                                            }
                                            .accessibilityLabel(reaction.accessibilityName)
                                        }
                                    }
                                }
                            }
                        } else {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "clock")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AppColor.brandBlue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Waiting for both reps")
                                        .font(Typography.headline)
                                        .foregroundStyle(.primary)
                                    Text("Results appear after both speakers complete the prompt.")
                                        .font(Typography.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(Spacing.md)
                            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.caption2)
                            Text("Expires \(challenge.expiresAt, style: .relative)")
                                .font(Typography.caption)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    .padding(Spacing.screenH)
                }
            }
            .navigationTitle("Speak-off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("speakOff.detail")
    }

    private func scoreCard(name: String, score: Int, duration: TimeInterval?, reaction: AsyncChallenge.Reaction?) -> some View {
        VStack(spacing: 10) {
            Text(String(name.prefix(1)).uppercased())
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 44, height: 44)
                .background(AppColor.brandBlue.opacity(0.12), in: Circle())

            Text(name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Text("\(score)")
                .font(Typography.figtreeNumeric(size: 32, weight: .bold, relativeTo: .title))
                .foregroundStyle(AppColor.brandBlue)

            if let dur = duration {
                Text(String(format: "%d:%02d", Int(dur) / 60, Int(dur) % 60))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let reaction {
                Image(systemName: reaction.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityLabel(reaction.accessibilityName)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var comparisonScoreCards: some View {
        scoreCard(
            name: challenge.creatorName,
            score: challenge.creatorScore ?? 0,
            duration: challenge.creatorDuration,
            reaction: challenge.opponentReaction
        )
        Image(systemName: "arrow.left.arrow.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel("Compared with")
        scoreCard(
            name: challenge.opponentName,
            score: challenge.opponentScore ?? 0,
            duration: challenge.opponentDuration,
            reaction: challenge.creatorReaction
        )
    }
}

@available(iOS 17.0, *)
struct ChallengePickFriendSheet: View {
    @ObservedObject var friends: FriendsManager
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var createdChallenge: AsyncChallenge?
    @State private var speakOffNavPath = NavigationPath()

    private var linkedFriends: [NoumFriend] {
        SpeakOffFriendEligibility.linkedFriends(from: friends.friends)
    }

    var body: some View {
        NavigationStack(path: $speakOffNavPath) {
            Group {
                if let challenge = createdChallenge {
                    VStack(spacing: Spacing.lg) {
                        Spacer()

                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 44, weight: .semibold))
                                .foregroundStyle(AppColor.brandBlue)
                            Text("Speak-off ready")
                                .font(Typography.cardTitle)
                            Text("Practice the same prompt, then compare the evidence.")
                                .font(Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Your prompt")
                                .font(Typography.caption.weight(.semibold))
                                .foregroundStyle(AppColor.brandBlue)
                            Text(challenge.prompt)
                                .font(Typography.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.lg)
                        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                                .stroke(AppColor.brandBlue.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.screenH)

                        Text("With \(challenge.opponentName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            speakOffNavPath.append(AppDestination.timedPractice)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mic.fill")
                                    .font(.headline)
                                Text("Start rep")
                                    .font(.headline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppColor.brandBlue, in: Capsule())
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, Spacing.screenH)
                        .accessibilityIdentifier("speakOff.start")

                        Button("Not now") { dismiss() }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)
                    }
                    .background(AppColor.screenBackground.ignoresSafeArea())
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
                            EmptyStateView(
                                symbol: "person.2.slash",
                                title: "No connected partners yet",
                                body: "Speak-offs become available when a friend's Noum account is connected.",
                                tint: AppColor.brandBlue
                            )
                            .padding(.vertical, Spacing.lg)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(linkedFriends) { friend in
                                Button {
                                    guard let opponentAccountID = friend.accountID else { return }
                                    let challenge = challenges.createAsyncChallenge(
                                        opponentID: friend.id,
                                        opponentName: friend.displayName,
                                        opponentAccountID: opponentAccountID
                                    )
                                    withAnimation(reduceMotion ? nil : .standardSpring) {
                                        createdChallenge = challenge
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(AppColor.brandBlue.opacity(0.12))
                                                .frame(width: 40, height: 40)

                                            Text(friend.initials)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(AppColor.brandBlue)
                                        }

                                        Text(friend.displayName)
                                            .font(.subheadline.weight(.medium))

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .accessibilityIdentifier("speakOff.friend.\(friend.id.uuidString)")
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(AppColor.screenBackground)
                    .navigationTitle("Choose a partner")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("speakOff.pickFriend")
    }
}

@available(iOS 17.0, *)
struct AddFriendSheet: View {
    @ObservedObject var friends: FriendsManager
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var friendName = ""
    @State private var didAdd = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppColor.brandBlue.opacity(0.12))
                        .frame(width: 64, height: 64)

                    if friendName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(AppColor.brandBlue)
                    } else {
                        Text(String(friendName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                            .font(Typography.cardTitle)
                            .foregroundStyle(AppColor.brandBlue)
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Save a practice contact")
                        .font(Typography.cardTitle)
                    Text("Keep a name for planning future reps. Shared scores require a connected Noum account.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Friend's name", text: $friendName)
                    .font(.body)
                    .padding(16)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal, Spacing.screenH)
                    .focused($nameFieldFocused)
                    .submitLabel(.done)
                    .onSubmit { addFriend() }

                if didAdd {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Contact saved")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: addFriend) {
                    Text("Save contact")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            friendName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AppColor.tagBackground
                                : AppColor.brandBlue,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            friendName.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.secondary
                                : Color.white
                        )
                }
                .disabled(friendName.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, Spacing.screenH)
                .padding(.bottom, 16)
                .accessibilityIdentifier("friends.add.save")
            }
            .background(AppColor.screenBackground.ignoresSafeArea())
            .navigationTitle("New contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { nameFieldFocused = true }
        }
        .accessibilityIdentifier("friends.add.sheet")
    }

    private func addFriend() {
        let trimmed = friendName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        friends.addFriend(name: trimmed, method: .manual)
        withAnimation(reduceMotion ? nil : .standardSpring) {
            didAdd = true
        }
        friendName = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

#endif
