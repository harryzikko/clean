import Foundation
import CryptoKit

public final class PINCodeService: @unchecked Sendable {
    public static let shared = PINCodeService()
    
    private let pinStorageKey = "com.cleanspace.vault.pin_hash"
    private let useFaceIDKey = "com.cleanspace.vault.use_faceid"
    
    private init() {}
    
    public var isPINConfigured: Bool {
        UserDefaults.standard.string(forKey: pinStorageKey) != nil
    }
    
    public var isFaceIDEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: useFaceIDKey) }
        set { UserDefaults.standard.set(newValue, forKey: useFaceIDKey) }
    }
    
    public func setPIN(_ pin: String) -> Bool {
        guard pin.count == 4, pin.allSatisfy({ $0.isNumber }) else { return false }
        let hash = hashPIN(pin)
        UserDefaults.standard.set(hash, forKey: pinStorageKey)
        return true
    }
    
    public func verifyPIN(_ pin: String) -> Bool {
        guard let savedHash = UserDefaults.standard.string(forKey: pinStorageKey) else {
            return false
        }
        return hashPIN(pin) == savedHash
    }
    
    public func resetPIN() {
        UserDefaults.standard.removeObject(forKey: pinStorageKey)
        UserDefaults.standard.removeObject(forKey: useFaceIDKey)
    }
    
    private func hashPIN(_ pin: String) -> String {
        let inputData = Data(pin.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
