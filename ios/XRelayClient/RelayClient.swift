import Foundation

final class RelayClient {
    static let shared = RelayClient()

    var baseURL: URL {
        get { UserDefaults.standard.url(forKey: "relayURL") ?? URL(string: "http://localhost:3000")! }
        set { UserDefaults.standard.set(newValue, forKey: "relayURL") }
    }

    var profileName: String? {
        get { UserDefaults.standard.string(forKey: "profileName") }
        set { UserDefaults.standard.set(newValue, forKey: "profileName") }
    }

    private let session: URLSession
    private var catalog: [String: [[String: Any]]]?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        session = URLSession(configuration: configuration)
    }

    func getTimeline(completion: @escaping (Result<[TimelinePost], Error>) -> Void) {
        request(operation: "HomeTimeline", variables: nil) { result in
            completion(result.map { Self.posts(from: $0) })
        }
    }

    func search(_ query: String, completion: @escaping (Result<[TimelinePost], Error>) -> Void) {
        request(operation: "SearchTimeline", variables: [
            "rawQuery": query,
            "count": 20,
            "querySource": "typed_query",
            "product": "Top"
        ]) { result in
            completion(result.map { Self.posts(from: $0) })
        }
    }

    func post(text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let operation = catalog?["CreateTweet"]?.first(where: {
            ($0["method"] as? String) == "POST" && $0["data"] != nil
        }) else {
            loadCatalog { [weak self] result in
                switch result {
                case .success:
                    self?.post(text: text, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }

        var body = operation["data"] as? [String: Any] ?? [:]
        var variables = body["variables"] as? [String: Any] ?? [:]
        variables["tweet_text"] = text
        variables["reply"] = NSNull()
        variables["media"] = [
            "media_entities": [],
            "possibly_sensitive": false
        ]
        body["variables"] = variables
        execute(method: "POST", path: operation["path"] as? String ?? "", query: [:], body: body) { result in
            completion(result.map { _ in () })
        }
    }

    private func request(
        operation name: String,
        variables: [String: Any]?,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        if catalog == nil {
            loadCatalog { [weak self] result in
                switch result {
                case .success:
                    self?.request(operation: name, variables: variables, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }

        guard let template = catalog?[name]?.first(where: {
            ($0["method"] as? String ?? "GET") == "GET" && $0["params"] != nil
        }) ?? catalog?[name]?.first,
              let path = template["path"] as? String else {
            completion(.failure(APIError.missingOperation(name)))
            return
        }

        var query = template["params"] as? [String: Any] ?? [:]
        if let variables = variables {
            query["variables"] = jsonString(variables)
        }
        execute(method: template["method"] as? String ?? "GET", path: path, query: query, body: nil, completion: completion)
    }

    private func loadCatalog(completion: @escaping (Result<Void, Error>) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("requests.ndjson"))
        request.httpMethod = "GET"
        addProfileHeader(to: &request)
        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data, let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                DispatchQueue.main.async { completion(.failure(APIError.invalidResponse)) }
                return
            }
            do {
                var operations: [String: [[String: Any]]] = [:]
                for line in String(data: data, encoding: .utf8)?.split(separator: "\n") ?? [] {
                    guard let lineData = line.data(using: .utf8),
                          let object = try JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          let path = object["path"] as? String else { continue }
                    let operationName = path.split(separator: "/").last.map(String.init) ?? path
                    operations[operationName, default: []].append(object)
                }
                self?.catalog = operations
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func execute(
        method: String,
        path: String,
        query: [String: Any],
        body: [String: Any]?,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        let relayPath = path.hasPrefix("/i/api/") ? path : "/i/api\(path)"
        guard let url = URL(string: relayPath, relativeTo: baseURL) else {
            completion(.failure(APIError.invalidURL))
            return
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = query.compactMap { key, value in
            guard let value = value as? String else { return nil }
            return URLQueryItem(name: key, value: value)
        }
        guard let finalURL = components?.url else {
            completion(.failure(APIError.invalidURL))
            return
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addProfileHeader(to: &request)
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(APIError.invalidResponse)) }
                return
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                DispatchQueue.main.async { completion(.failure(APIError.server(message))) }
                return
            }
            do {
                let object = try JSONSerialization.jsonObject(with: data)
                DispatchQueue.main.async { completion(.success(object)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func addProfileHeader(to request: inout URLRequest) {
        if let profileName = profileName, !profileName.isEmpty {
            request.setValue(profileName, forHTTPHeaderField: "x-profile-name")
        }
    }

    private func jsonString(_ object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    private static func posts(from object: Any) -> [TimelinePost] {
        var posts: [TimelinePost] = []
        collectPosts(from: object, into: &posts)
        var seen = Set<String>()
        return posts.filter { seen.insert($0.id).inserted }
    }

    private static func collectPosts(from object: Any, into posts: inout [TimelinePost]) {
        if let dictionary = object as? [String: Any] {
            if let legacy = dictionary["legacy"] as? [String: Any],
               let id = legacy["id_str"] as? String ?? dictionary["rest_id"] as? String,
               let text = legacy["full_text"] as? String {
                let user = (dictionary["core"] as? [String: Any])?["user_results"] as? [String: Any]
                let userResult = user?["result"] as? [String: Any]
                let userLegacy = userResult?["legacy"] as? [String: Any]
                let name = userLegacy?["name"] as? String ?? "Xユーザー"
                let handle = userLegacy?["screen_name"] as? String ?? ""
                let avatar = userLegacy?["profile_image_url_https"] as? String
                posts.append(TimelinePost(id: id, name: name, handle: handle, text: text, avatarURL: avatar.flatMap(URL.init)))
            }
            for value in dictionary.values {
                collectPosts(from: value, into: &posts)
            }
        } else if let array = object as? [Any] {
            for value in array {
                collectPosts(from: value, into: &posts)
            }
        }
    }
}
