import Foundation
import Security

struct CredentialStore {
    static let serviceName = "com.pixelandpines.pixel-terminal"

    static func set(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecValueData: data
        ]
        // Try update first, then add
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    static func get(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: serviceName,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: – Token validation

actor TokenValidator {
    static func validateGitHub(token: String) async -> (valid: Bool, user: String?) {
        var req = URLRequest(url: URL(string: "https://api.github.com/user")!)
        req.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("PixelTerminal/0.2.1", forHTTPHeaderField: "User-Agent")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return (false, nil) }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            return (true, json?["login"] as? String)
        } catch {
            return (false, nil)
        }
    }

    static func validateVercel(token: String) async -> (valid: Bool, user: String?) {
        var req = URLRequest(url: URL(string: "https://api.vercel.com/v2/user")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return (false, nil) }
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let userObj = json?["user"] as? [String: Any]
            let name = userObj?["email"] as? String ?? userObj?["name"] as? String
            return (true, name)
        } catch {
            return (false, nil)
        }
    }
}
