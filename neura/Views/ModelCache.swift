import Foundation
#if os(iOS)
import RealityKit

// MARK: - ModelCache

@MainActor
final class ModelCache {
    static let shared = ModelCache()

    private var cache: [String: Entity] = [:]
    private var loading: Set<String> = []

    func preload(_ modelName: String) {
        guard cache[modelName] == nil, !loading.contains(modelName) else { return }
        loading.insert(modelName)
        Task.detached(priority: .userInitiated) {
            guard let url = Bundle.main.url(forResource: modelName, withExtension: "usdz") else {
                await MainActor.run { self.loading.remove(modelName) }
                return
            }
            do {
                let entity = try Entity.load(contentsOf: url)
                await MainActor.run {
                    self.cache[modelName] = entity
                    self.loading.remove(modelName)
                }
            } catch {
                print("[ModelCache] failed to load \(modelName): \(error)")
                await MainActor.run { self.loading.remove(modelName) }
            }
        }
    }

    func get(_ modelName: String) -> Entity? {
        cache[modelName]?.clone(recursive: true)
    }

    func evict(_ modelName: String) {
        cache.removeValue(forKey: modelName)
    }

    func evictAll() {
        cache.removeAll()
    }
}
#endif
