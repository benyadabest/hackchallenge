import Foundation
import UIKit

enum APIError: LocalizedError, Identifiable {
    case http(status: Int, message: String?)
    case network
    case decoding
    case payloadTooLarge
    case rateLimited

    var id: String {
        switch self {
        case .http(let status, _): return "http_\(status)"
        case .network: return "network"
        case .decoding: return "decoding"
        case .payloadTooLarge: return "payloadTooLarge"
        case .rateLimited: return "rateLimited"
        }
    }

    var errorDescription: String? {
        switch self {
        case .http(let status, let message):
            return message ?? "Server error (\(status))"
        case .network:
            return "Network error. Check your connection and try again."
        case .decoding:
            return "Unexpected response from server."
        case .payloadTooLarge:
            return "Image is too large. Try a smaller photo."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        }
    }
}

@MainActor
final class APIService {
    static let shared = APIService()

    private let baseURL = URL(string: "http://localhost:3001")!

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    func fetchFeed(page: Int = 1, limit: Int = 20) async throws -> [ImagePost] {
        var components = URLComponents(url: baseURL.appendingPathComponent("feed"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        let (data, response) = try await perform(URLRequest(url: components.url!))
        try checkStatus(response, data: data)
        return try decode([ImagePost].self, from: data)
    }

    func findOrCreateUser(username: String) async throws -> User {
        let url = baseURL.appendingPathComponent("users/\(username)")
        let (data, response) = try await perform(URLRequest(url: url))
        try checkStatus(response, data: data)
        return try decode(User.self, from: data)
    }

    func fetchUserImages(userID: UUID, viewerID: UUID?, page: Int = 1, limit: Int = 30) async throws -> [ImagePost] {
        var components = URLComponents(url: baseURL.appendingPathComponent("users/\(userID.uuidString)/images"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let viewerID {
            items.append(URLQueryItem(name: "viewer_id", value: viewerID.uuidString))
        }
        components.queryItems = items
        let (data, response) = try await perform(URLRequest(url: components.url!))
        try checkStatus(response, data: data)
        return try decode([ImagePost].self, from: data)
    }

    func generate(userID: UUID, prompt: String, imageData: Data, mimeType: String, isPublic: Bool) async throws -> ImagePost {
        var request = URLRequest(url: baseURL.appendingPathComponent("generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": userID.uuidString,
            "prompt": prompt,
            "image_base64": imageData.base64EncodedString(),
            "mime_type": mimeType,
            "is_public": isPublic
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(request)
        try checkStatus(response, data: data)
        return try decode(ImagePost.self, from: data)
    }

    func deleteImage(id: UUID, userID: UUID) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("images/\(id.uuidString)"))
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_id": userID.uuidString]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(request)
        try checkStatus(response, data: data)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            print("[API] \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "nil")")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[API] Status: \(http.statusCode), Body: \(String(data: data.prefix(500), encoding: .utf8) ?? "nil")")
            }
            return (data, response)
        } catch {
            print("[API] Network error: \(error)")
            throw APIError.network
        }
    }

    private func checkStatus(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 413:
            throw APIError.payloadTooLarge
        case 429:
            throw APIError.rateLimited
        default:
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw APIError.http(status: http.statusCode, message: message)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}

extension UIImage {
    func encodedForUpload(maxEdge: CGFloat = 1024, quality: CGFloat = 0.8) -> (data: Data, mime: String)? {
        let size = self.size
        let scale = min(maxEdge / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }

        guard let jpeg = resized.jpegData(compressionQuality: quality) else { return nil }
        return (jpeg, "image/jpeg")
    }
}
