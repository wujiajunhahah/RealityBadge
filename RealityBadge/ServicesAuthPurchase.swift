import Foundation

// MARK: - Auth Service (placeholder)
protocol RBAuthService {
    var userID: String? { get }
    func signIn(completion: @escaping (Result<String, Error>) -> Void)
    func signOut()
}

final class RBNoopAuthService: RBAuthService {
    private(set) var userID: String? = nil
    func signIn(completion: @escaping (Result<String, Error>) -> Void) {
        let id = UUID().uuidString
        self.userID = id
        completion(.success(id))
    }
    func signOut() { self.userID = nil }
}

// MARK: - Purchase / Entitlements (placeholder)
struct RBEntitlements: Codable {
    var hasPro: Bool = false
    var unlockedPacks: [String] = []
}

protocol RBPurchaseService {
    var entitlements: RBEntitlements { get }
    func purchase(productID: String, completion: @escaping (Result<Void, Error>) -> Void)
    func restore(completion: @escaping (Result<RBEntitlements, Error>) -> Void)
}

final class RBNoopPurchaseService: RBPurchaseService {
    private(set) var entitlements = RBEntitlements()
    func purchase(productID: String, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func restore(completion: @escaping (Result<RBEntitlements, Error>) -> Void) { completion(.success(entitlements)) }
}

