import Foundation
import WidgetKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var apiKey: String = KeychainHelper.load() ?? ""
    @Published var snapshot: DashboardSnapshot? = SharedCache.load()
    @Published var isLoading = false
    @Published var statusMessage: String?
    @Published var statusIsError = false

    var hasSavedKey: Bool {
        !(KeychainHelper.load() ?? "").isEmpty
    }

    func saveKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            statusMessage = "Enter an Admin API key first."
            statusIsError = true
            return
        }
        KeychainHelper.save(trimmed)
        statusMessage = "Key saved to Keychain."
        statusIsError = false
        Task { await refresh() }
    }

    func clearKey() {
        KeychainHelper.delete()
        apiKey = ""
        snapshot = nil
        statusMessage = "Key removed."
        statusIsError = false
        WidgetCenter.shared.reloadAllTimelines()
    }

    func refresh() async {
        guard let key = KeychainHelper.load(), !key.isEmpty else {
            statusMessage = "No Admin API key saved yet."
            statusIsError = true
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = AnthropicAdminClient(apiKey: key)
            let result = try await client.fetchSnapshot()
            snapshot = result
            SharedCache.save(result)
            statusMessage = "Updated \(result.generatedAt.formatted(date: .omitted, time: .shortened))."
            statusIsError = false
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            statusMessage = error.localizedDescription
            statusIsError = true
        }
    }
}
