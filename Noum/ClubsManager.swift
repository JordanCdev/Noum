import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(MapKit)
import MapKit
#endif

// MARK: - Speaking Club Model

struct SpeakingClub: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var clubDescription: String
    var meetingDay: MeetingDay?
    var meetingTime: String?
    var location: String
    var latitude: Double?
    var longitude: Double?
    var memberCount: Int?
    var isToastmasters: Bool
    var websiteURL: String?
    var phoneNumber: String?

    enum MeetingDay: String, Codable, CaseIterable, Identifiable, Sendable {
        case monday, tuesday, wednesday, thursday, friday, saturday, sunday

        var id: String { rawValue }

        var label: String {
            rawValue.capitalized
        }

        var shortLabel: String {
            String(rawValue.prefix(3)).capitalized
        }
    }

    var meetingLabel: String? {
        guard let day = meetingDay, let time = meetingTime else { return nil }
        return "\(day.label)s at \(time)"
    }

    /// Compute distance from a reference coordinate
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let lat = latitude, let lon = longitude else { return nil }
        let clubLocation = CLLocation(latitude: lat, longitude: lon)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return clubLocation.distance(from: userLocation)
    }

    /// Human-readable distance label
    func distanceLabel(from coordinate: CLLocationCoordinate2D) -> String? {
        guard let meters = distance(from: coordinate) else { return nil }
        if meters < 1000 {
            return "\(Int(meters))m away"
        } else {
            let km = meters / 1000
            return String(format: "%.1f km away", km)
        }
    }
}

struct ClubsAccountDataSnapshot: Codable, Equatable, Sendable {
    let savedClubs: [SpeakingClub]
}

// MARK: - Location Manager (wraps CLLocationManager for async access)

#if canImport(CoreLocation)
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var locationError: String?

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestLocationOnce() async -> CLLocationCoordinate2D? {
        // Return cached location if recent
        if let current = currentLocation { return current }

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait briefly for authorization
            try? await Task.sleep(for: .milliseconds(500))
        }

        let currentStatus = manager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            locationError = "Location access not granted"
            return nil
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            let coordinate = locations.first?.coordinate
            currentLocation = coordinate
            locationError = nil
            continuation?.resume(returning: coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = error.localizedDescription
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}
#endif

// MARK: - Clubs Manager

#if canImport(SwiftUI)

@MainActor
final class ClubsManager: ObservableObject {
    static let shared = ClubsManager()

    @Published private(set) var nearbyClubs: [SpeakingClub] = []
    @Published private(set) var savedClubs: [SpeakingClub] = []
    @Published var isLoading = false
    @Published var searchQuery = ""
    @Published var lastSearchArea: String?
    @Published var searchError: String?

    private let savedKey = "NoumSavedClubs"
    private let locationService = LocationService.shared

    private init() {
        savedClubs = Self.loadSaved(accountID: Self.persistedAccountID)
    }

    // MARK: - Save / Unsave

    func saveClub(_ club: SpeakingClub) {
        guard !savedClubs.contains(where: { $0.id == club.id }) else { return }
        savedClubs.insert(club, at: 0)
        persistSaved()
    }

    func unsaveClub(id: UUID) {
        savedClubs.removeAll { $0.id == id }
        persistSaved()
    }

    func isClubSaved(_ club: SpeakingClub) -> Bool {
        savedClubs.contains(where: { $0.id == club.id })
    }

    // MARK: - Search by Current Location

    func searchNearby() async {
        isLoading = true
        searchError = nil

        guard let coordinate = await locationService.requestLocationOnce() else {
            isLoading = false
            searchError = locationService.locationError ?? "Could not determine location"
            return
        }

        await searchClubs(near: coordinate, label: "Current Location")
    }

    // MARK: - Search by Manual Query

    func searchByArea(_ query: String) async {
        guard !query.isEmpty else { return }
        isLoading = true
        searchError = nil

        // Geocode the area name to a coordinate
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            if let coordinate = placemarks.first?.location?.coordinate {
                await searchClubs(near: coordinate, label: query)
            } else {
                isLoading = false
                searchError = "Could not find location '\(query)'"
            }
        } catch {
            isLoading = false
            searchError = "Search failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Core Search (MapKit Local Search)

    private func searchClubs(near coordinate: CLLocationCoordinate2D, label: String) async {
        let searchTerms = ["Toastmasters", "speaking club", "public speaking", "debate club"]
        var allResults: [SpeakingClub] = []
        var seenNames: Set<String> = []

        for term in searchTerms {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = term
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 25000,
                longitudinalMeters: 25000
            )

            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()

                for item in response.mapItems {
                    let name = item.name ?? "Unknown Club"
                    // Deduplicate by name
                    guard !seenNames.contains(name.lowercased()) else { continue }
                    seenNames.insert(name.lowercased())

                    let isToastmasters = name.localizedCaseInsensitiveContains("toastmasters") ||
                                         name.localizedCaseInsensitiveContains("toast masters")

                    let club = SpeakingClub(
                        id: UUID(),
                        name: name,
                        clubDescription: buildDescription(for: item, isToastmasters: isToastmasters),
                        location: formatAddress(item),
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude,
                        isToastmasters: isToastmasters,
                        websiteURL: item.url?.absoluteString,
                        phoneNumber: item.phoneNumber
                    )
                    allResults.append(club)
                }
            } catch {
                // Continue with other search terms
            }
        }

        // Sort by distance from the search center
        allResults.sort { club1, club2 in
            let d1 = club1.distance(from: coordinate) ?? .greatestFiniteMagnitude
            let d2 = club2.distance(from: coordinate) ?? .greatestFiniteMagnitude
            return d1 < d2
        }

        nearbyClubs = allResults
        lastSearchArea = label
        isLoading = false

        if allResults.isEmpty {
            searchError = "No speaking clubs found near \(label)"
        }
    }

    private func buildDescription(for item: MKMapItem, isToastmasters: Bool) -> String {
        if isToastmasters {
            return "Toastmasters International club. Visit to join a meeting and practice speaking in a supportive environment."
        }
        if let category = item.pointOfInterestCategory?.rawValue {
            return "A \(category.replacingOccurrences(of: "MKPOICategory", with: "").lowercased()) offering speaking and communication events."
        }
        return "A local venue for speaking practice and communication development."
    }

    private func formatAddress(_ item: MKMapItem) -> String {
        let placemark = item.placemark
        let components = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.locality,
            placemark.administrativeArea
        ].compactMap { $0 }
        return components.isEmpty ? "Address unavailable" : components.joined(separator: " ")
    }

    // MARK: - Next Meeting

    var nextMeeting: SpeakingClub? {
        let today = Calendar.current.component(.weekday, from: Date())

        let sorted = savedClubs.filter { $0.meetingDay != nil }.sorted { club1, club2 in
            daysUntilMeeting(club1, fromWeekday: today) <
            daysUntilMeeting(club2, fromWeekday: today)
        }

        return sorted.first
    }

    private func daysUntilMeeting(_ club: SpeakingClub, fromWeekday today: Int) -> Int {
        guard let day = club.meetingDay else { return 999 }
        let targetDay = SpeakingClub.MeetingDay.allCases.firstIndex(of: day)! + 2 // Sunday = 1
        let adjusted = targetDay > 7 ? targetDay - 7 : targetDay
        let diff = adjusted - today
        return diff >= 0 ? diff : diff + 7
    }

    // MARK: - Persistence

    private func persistSaved() {
        guard let data = try? JSONEncoder().encode(savedClubs) else { return }
        UserDefaults.standard.set(data, forKey: Self.accountKey(
            base: savedKey,
            accountID: Self.persistedAccountID
        ))
    }

    private static var persistedAccountID: String {
        KeychainHelper.load(key: "NoumAccountID") ?? "guest"
    }

    nonisolated static func accountKey(base: String, accountID: String) -> String {
        "\(base).\(accountID)"
    }

    private static func loadSaved(accountID: String) -> [SpeakingClub] {
        let key = accountKey(base: "NoumSavedClubs", accountID: accountID)
        if accountID != "guest",
           UserDefaults.standard.data(forKey: key) == nil,
           let legacy = UserDefaults.standard.data(forKey: "NoumSavedClubs") {
            UserDefaults.standard.set(legacy, forKey: key)
            UserDefaults.standard.removeObject(forKey: "NoumSavedClubs")
        }
        guard let data = UserDefaults.standard.data(forKey: key),
              let clubs = try? JSONDecoder().decode([SpeakingClub].self, from: data) else {
            return []
        }
        return clubs
    }

    func reloadForCurrentAccount() {
        savedClubs = Self.loadSaved(accountID: Self.persistedAccountID)
        nearbyClubs = []
        searchQuery = ""
        lastSearchArea = nil
        searchError = nil
    }

    func endSession() {
        savedClubs = []
        nearbyClubs = []
        searchQuery = ""
        lastSearchArea = nil
        searchError = nil
        isLoading = false
    }

    func exportSnapshot(for accountID: String) -> ClubsAccountDataSnapshot {
        ClubsAccountDataSnapshot(savedClubs: Self.loadSaved(accountID: accountID))
    }

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: Self.accountKey(
            base: savedKey,
            accountID: accountID
        ))
        if Self.persistedAccountID == accountID {
            endSession()
        }
    }
}

#endif
