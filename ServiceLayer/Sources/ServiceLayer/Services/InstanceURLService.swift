// Copyright © 2020 Metabolist. All rights reserved.

import CodableBloomFilter
import Combine
import Foundation
import HTTP
import Mastodon
import MastodonAPI

public enum InstanceURLError: Error {
  case instanceNotSupported
}

public struct InstanceURLService {
  private let session: URLSession

  public init(environment: AppEnvironment) {
    session = environment.session
  }
}

extension InstanceURLService {
  public func url(text: String) -> Result<URL, Error> {
    guard text.count >= Self.shortestPossibleURLLength else {
      return .failure(URLError(.badURL))
    }

    let url: URL

    if text.hasPrefix(Self.httpsPrefix), let prefixedURL = URL(string: text) {
      url = prefixedURL
    } else if let unprefixedURL = URL(string: Self.httpsPrefix.appending(text)) {
      url = unprefixedURL
    } else {
      return .failure(URLError(.badURL))
    }

    if isFiltered(url: url) {
      return .failure(InstanceURLError.instanceNotSupported)
    }

    return .success(url)
  }

  private func client(url: URL) throws -> MastodonAPIClient {
    try MastodonAPIClient(
      session: session,
      instanceURL: url,
      apiCapabilities: .unknown,
      accessToken: nil
    )
  }

  public func instance(url: URL) async throws -> Instance {
    try await client(url: url).request(InstanceEndpoint.instance)
  }

  public func instance(url: URL) -> AnyPublisher<Instance, Error> {
    Future {
      try await instance(url: url)
    }
    .eraseToAnyPublisher()
  }

  public func isPublicTimelineAvailable(url: URL) async throws -> Bool {
    _ = try await client(url: url).request(StatusesEndpoint.timelinesPublic(local: true))
    return true
  }

  public func isPublicTimelineAvailable(url: URL) -> AnyPublisher<Bool, Error> {
    Future {
      try await isPublicTimelineAvailable(url: url)
    }
    .eraseToAnyPublisher()
  }
}

extension InstanceURLService {
  fileprivate static let httpsPrefix = "https://"
  fileprivate static let shortestPossibleURLLength = 4

  private func isFiltered(url: URL) -> Bool {
    guard let host = url.host else { return true }

    let allHostComponents = host.components(separatedBy: ".")
    var hostComponents = [String]()

    for component in allHostComponents.reversed() {
      hostComponents.insert(component, at: 0)

    }

    return false
  }
}
