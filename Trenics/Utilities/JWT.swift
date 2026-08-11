import Foundation
import CryptoKit

enum JWTError: Error, LocalizedError {
    case invalidKey
    case signingFailed

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Could not parse the .p8 private key. Make sure you pasted the full contents, including the BEGIN/END PRIVATE KEY lines."
        case .signingFailed: return "Failed to sign the JWT."
        }
    }
}

/// Builds a short-lived ES256 JSON Web Token as required by the App Store Connect API.
/// See: https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
enum AppStoreConnectJWT {
    static func generate(issuerId: String, keyId: String, privateKeyPEM: String) throws -> String {
        let header: [String: Any] = ["alg": "ES256", "kid": keyId, "typ": "JWT"]
        let now = Int(Date().timeIntervalSince1970)
        let payload: [String: Any] = [
            "iss": issuerId,
            "iat": now,
            "exp": now + 19 * 60, // Apple caps tokens at 20 minutes
            "aud": "appstoreconnect-v1"
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let signingInput = "\(base64URLEncode(headerData)).\(base64URLEncode(payloadData))"

        guard let privateKey = try? P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM) else {
            throw JWTError.invalidKey
        }
        guard let signingData = signingInput.data(using: .utf8) else {
            throw JWTError.signingFailed
        }

        let signature = try privateKey.signature(for: signingData)
        return "\(signingInput).\(base64URLEncode(signature.rawRepresentation))"
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
