import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Contacts)
import Contacts
#endif
#if canImport(CoreImage)
import CoreImage.CIFilterBuiltins
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

#if canImport(SwiftUI)

// MARK: - QR Code Generator

private struct QRCodeGenerator {
    private static let sharedContext = CIContext()
    private static var cache: [String: UIImage] = [:]

    static func generate(from string: String, size: CGFloat = 200) -> UIImage? {
        let cacheKey = "\(string)_\(Int(size))"
        if let cached = cache[cacheKey] { return cached }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = sharedContext.createCGImage(scaled, from: scaled.extent) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache[cacheKey] = image
        return image
    }
}

// MARK: - Social Profile View

@available(iOS 17.0, *)
struct SocialProfileView: View {
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var friends = FriendsManager.shared
    @StateObject private var challenges = ChallengesManager.shared
    @State private var showInviteSheet = false
    @State private var showQRSheet = false
    @State private var showPaywall = false
    @State private var showContactsPicker = false
    @State private var showAddFriendManual = false

    @State private var contactsAccessDenied = false
    @State private var showScanner = false
    @State private var selectedAsyncChallenge: AsyncChallenge?
    @State private var showChallengePickFriend = false
    @Environment(\.openURL) private var openURL

    private let proColor = AppColor.pro

    private var displayName: String {
        authManager.currentAccountName ?? "Speaker"
    }

    private var userQRString: String {
        "noum://friend/\(authManager.currentAccountID ?? UUID().uuidString)"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                profileHeader
                statsRow
                asyncChallengesSection
                challengesSection
                friendsSection
                inviteSection
                discoverSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [AppColor.lightGradientStart, AppColor.lightGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showInviteSheet) { inviteView }
        .sheet(isPresented: $showQRSheet) { qrAddFriendView }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showContactsPicker) { contactsPickerView }
        .sheet(item: $selectedAsyncChallenge) { challenge in
            AsyncChallengeDetailSheet(challenge: challenge, challenges: challenges)
        }
        .sheet(isPresented: $showChallengePickFriend) {
            ChallengePickFriendSheet(friends: friends, challenges: challenges)
        }
        .sheet(isPresented: $showAddFriendManual) {
            AddFriendSheet(friends: friends, challenges: challenges)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.purple.opacity(0.2), radius: 16, y: 6)

                Text(String(displayName.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.title2.weight(.bold))

                    if premium.isPremium {
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(proColor, in: Capsule())
                    }
                }

                Text(profile.levelTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("\(profile.xp) XP")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if !premium.isPremium {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.caption)
                        Text("Upgrade to Pro")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(proColor, in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: "Sessions", value: "\(totalSessions)", icon: "mic.fill", tint: .blue)
            statCard(title: "Streak", value: "\(currentStreak)d", icon: "flame.fill", tint: .orange)
            statCard(title: "Friends", value: "\(friends.friendCount)", icon: "person.2.fill", tint: .green)
        }
    }

    private func statCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Async Challenges Section (Primary Social Feature)

    private var asyncChallengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Speak-offs")
                    .font(.headline)
                Spacer()
                Button {
                    if friends.friends.isEmpty {
                        showAddFriendManual = true
                    } else {
                        showChallengePickFriend = true
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Challenge")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.teal, in: Capsule())
                }
            }

            Text("Challenge a friend to the same prompt. Both speak, then compare scores.")
                .font(.caption)
                .foregroundStyle(.secondary)

            let active = challenges.activeAsyncChallenges
            if active.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    Image(systemName: "person.2.wave.2")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.4))

                    Text("No active speak-offs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Challenge a friend to see who delivers the best impromptu response to the same topic.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    Button {
                        if friends.friends.isEmpty {
                            showAddFriendManual = true
                        } else {
                            showChallengePickFriend = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.caption)
                            Text("Start a Speak-off")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.teal, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(active.prefix(5)) { challenge in
                    asyncChallengeRow(challenge)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func asyncChallengeRow(_ challenge: AsyncChallenge) -> some View {
        let userID = UUID(uuidString: authManager.currentAccountID ?? "") ?? UUID()
        let status = challenge.status(forUser: userID)
        let friendName = challenge.opponentName(forUser: userID)

        return Button {
            selectedAsyncChallenge = challenge
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.teal)
                    .frame(width: 36, height: 36)
                    .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("vs \(friendName)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(status.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(status.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(status.tint.opacity(0.1), in: Capsule())
                    }

                    Text(challenge.prompt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let result = challenge.result(forUser: userID) {
                        HStack(spacing: 4) {
                            Image(systemName: result.icon)
                                .font(.caption2)
                            Text(result.label)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(result == .won ? .green : result == .lost ? .orange : .secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Daily/Weekly Challenges Section

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Challenges")
                    .font(.headline)
                Spacer()
                if !challenges.completedChallenges.isEmpty {
                    Text("\(challenges.completedChallenges.count) done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            let active = challenges.activeChallenges.filter { !$0.isCompleted && !$0.isExpired }
            if active.isEmpty {
                Text("All caught up! New challenges will appear soon.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(active.prefix(4)) { challenge in
                    challengeRow(challenge)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func challengeRow(_ challenge: SpeakingChallenge2) -> some View {
        HStack(spacing: 14) {
            Image(systemName: challenge.category.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(challenge.category.tint)
                .frame(width: 36, height: 36)
                .background(challenge.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(challenge.title)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(challenge.progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(challenge.category.tint)
                }

                ProgressView(value: challenge.progress)
                    .tint(challenge.category.tint)

                HStack {
                    Text(challenge.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if challenge.daysRemaining > 0 {
                        Text("\(challenge.daysRemaining)d left")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - Friends Section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Friends")
                    .font(.headline)
                Spacer()
                Button {
                    showAddFriendManual = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Add")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1), in: Capsule())
                }
            }

            if friends.friends.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text("No friends yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text("Invite fellow speakers to practice together and challenge each other.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button {
                        showInviteSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "paperplane.fill")
                                .font(.caption)
                            Text("Invite Friends")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue, in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(friends.friends.prefix(8)) { friend in
                    friendRow(friend)
                }

                if friends.friendCount > 8 {
                    Text("+ \(friends.friendCount - 8) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    private func friendRow(_ friend: NoumFriend) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Text(friend.initials)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName)
                    .font(.subheadline.weight(.medium))
                Text("Added \(friend.addedAt, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Quick challenge button
            Button {
                challenges.createAsyncChallenge(opponentID: friend.id, opponentName: friend.displayName)
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                    .frame(width: 30, height: 30)
                    .background(Color.teal.opacity(0.1), in: Circle())
            }
        }
    }

    // MARK: - Invite Section

    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Grow Your Circle")
                .font(.headline)

            inviteRow(icon: "paperplane.fill", iconColor: .blue, title: "Share Invite Link", caption: "Send a link to anyone") {
                showInviteSheet = true
            }
            inviteRow(icon: "qrcode", iconColor: .purple, title: "QR Code", caption: "Scan to connect at events") {
                showQRSheet = true
            }
            inviteRow(icon: "person.crop.circle.badge.plus", iconColor: .green, title: "From Contacts", caption: "Find speakers you know") {
                requestContactsAccess()
            }
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .alert("Contacts Access", isPresented: $contactsAccessDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Noum needs access to your contacts to find people you know. Enable it in Settings.")
        }
    }

    private func inviteRow(icon: String, iconColor: Color, title: String, caption: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 36, height: 36)
                    .background(iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Discover Section (Toastmasters + Events)

    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Discover")
                .font(.headline)

            Text("Find local speaking opportunities to practice in person.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Toastmasters — official site link
            Button {
                if let url = URL(string: "https://www.toastmasters.org/find-a-club") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "person.3.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                        .frame(width: 36, height: 36)
                        .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find a Toastmasters Club")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("Search the official Toastmasters directory for clubs near you")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                }
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.vertical, 4)

            // Eventbrite — speaking events
            Button {
                if let url = URL(string: "https://www.eventbrite.com/d/online/public-speaking/") {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                        .frame(width: 36, height: 36)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Speaking Events on Eventbrite")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("Find public speaking events, workshops, and open mics")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Invite Sheet

    private var inviteView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Invite Friends to Noum")
                    .font(.title2.weight(.bold))

                Text("Share your invite link and practice speaking together. The more speakers in your circle, the better you all get.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    shareInviteLink()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.headline)
                        Text("Share Invite Link")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: Capsule())
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showInviteSheet = false }
                }
            }
        }
    }

    // MARK: - QR Add Friend Sheet

    private var qrAddFriendView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 220, height: 220)
                        .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)

                    if let qrImage = QRCodeGenerator.generate(from: userQRString, size: 180) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 180, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.small))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 72))
                                .foregroundStyle(.primary)
                            Text(displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("Scan to Connect")
                    .font(.title3.weight(.bold))

                Text("Show this code at speaking events. Others can scan it to add you as a friend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                HStack(spacing: 16) {
                    Button {
                        showScanner = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.subheadline)
                            Text("Scan Code")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                    }

                    Button {
                        shareQRCode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline)
                            Text("Share")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(Color(.systemGray5), in: Capsule())
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showQRSheet = false }
                }
            }
            .sheet(isPresented: $showScanner) {
                QRScannerView { scannedCode in
                    handleScannedQR(scannedCode)
                    showScanner = false
                }
            }
        }
    }

    // MARK: - Contacts Picker

    private var contactsPickerView: some View {
        NavigationStack {
            ContactsListView(onAdd: { name, phone in
                friends.addFriend(name: name, phoneNumber: phone, method: .contacts)
                challenges.recordSocialAction()
            })
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showContactsPicker = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private func requestContactsAccess() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    showContactsPicker = true
                } else {
                    contactsAccessDenied = true
                }
            }
        }
    }

    private func handleScannedQR(_ code: String) {
        if code.hasPrefix("noum://friend/") {
            let friendID = String(code.dropFirst("noum://friend/".count))
            friends.addFriend(name: "Speaker \(friendID.prefix(4))", method: .qrCode)
            challenges.recordSocialAction()
        }
    }

    private func shareQRCode() {
        guard let image = QRCodeGenerator.generate(from: userQRString, size: 400) else { return }
        let activityVC = UIActivityViewController(
            activityItems: [image, "Scan this QR code in Noum to add me as a speaking friend!"],
            applicationActivities: nil
        )
        presentActivity(activityVC)
    }

    private var totalSessions: Int {
        PracticeSessionStore.shared.sessions.count
    }

    private var currentStreak: Int {
        PracticeSession.calculateStreak(from: PracticeSessionStore.shared.sessions)
    }

    private func shareInviteLink() {
        let url = "https://noum.app/invite"
        let activityVC = UIActivityViewController(
            activityItems: ["Join me on Noum — a speaking practice app that makes you a better communicator.", URL(string: url)!],
            applicationActivities: nil
        )
        presentActivity(activityVC)
    }

    private func presentActivity(_ vc: UIActivityViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = windowScene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }
}

// MARK: - Async Challenge Detail Sheet

@available(iOS 17.0, *)
struct AsyncChallengeDetailSheet: View {
    let challenge: AsyncChallenge
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Prompt card
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

                    // Score comparison
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

                        // Reaction buttons
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

                    // Expires info
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
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

// MARK: - Challenge Pick Friend Sheet

@available(iOS 17.0, *)
struct ChallengePickFriendSheet: View {
    @ObservedObject var friends: FriendsManager
    @ObservedObject var challenges: ChallengesManager
    @Environment(\.dismiss) private var dismiss
    @State private var createdChallenge: AsyncChallenge?
    @State private var showPractice = false

    var body: some View {
        NavigationStack {
            Group {
                if let challenge = createdChallenge {
                    // Speak-off ready screen — user sees the prompt and starts
                    VStack(spacing: 28) {
                        Spacer()

                        VStack(spacing: 8) {
                            Image(systemName: "bolt.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.teal)
                            Text("Speak-off Created!")
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
                            showPractice = true
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
                    .navigationDestination(isPresented: $showPractice) {
                        TimedPracticeView(goHome: { dismiss() })
                    }
                } else {
                    List {
                        if friends.friends.isEmpty {
                            VStack(spacing: 12) {
                                Text("No friends yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text("Add a friend first, then come back to challenge them.")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(friends.friends) { friend in
                                Button {
                                    let challenge = challenges.createAsyncChallenge(opponentID: friend.id, opponentName: friend.displayName)
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

// MARK: - Add Friend Sheet

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
                // Avatar preview
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
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 20)

                VStack(spacing: 8) {
                    Text("Add a Speaking Friend")
                        .font(.title3.weight(.bold))
                    Text("Enter their name to add them to your speaking network.")
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
                        Text("Added!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                Button(action: addFriend) {
                    Text("Add Friend")
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
        challenges.recordSocialAction()
        withAnimation(.standardSpring) {
            didAdd = true
        }
        friendName = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

// MARK: - Contacts List View

@available(iOS 17.0, *)
private struct ContactsListView: View {
    var onAdd: (String, String?) -> Void

    @State private var contacts: [(name: String, phone: String?)] = []
    @State private var searchText = ""
    @State private var addedNames: Set<String> = []

    var filteredContacts: [(name: String, phone: String?)] {
        if searchText.isEmpty { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if contacts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading contacts...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredContacts, id: \.name) { contact in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.subheadline.weight(.medium))
                            if let phone = contact.phone {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if addedNames.contains(contact.name) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                onAdd(contact.name, contact.phone)
                                addedNames.insert(contact.name)
                            } label: {
                                Text("Add")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.blue, in: Capsule())
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search contacts")
        .navigationTitle("Contacts")
        .task {
            await loadContacts()
        }
    }

    private func loadContacts() async {
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName

        var results: [(name: String, phone: String?)] = []

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let phone = contact.phoneNumbers.first?.value.stringValue
                results.append((name: name, phone: phone))
            }
        } catch {
            // Contact enumeration failed
        }

        await MainActor.run {
            contacts = results
        }
    }
}

// MARK: - QR Scanner View

@available(iOS 17.0, *)
struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showFallback()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview
        captureSession = session

        let label = UILabel()
        label.text = "Point at a Noum QR code"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])

        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    private func showFallback() {
        let label = UILabel()
        label.text = "Camera not available"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(value)
    }
}

#endif
