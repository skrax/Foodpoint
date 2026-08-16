import Foundation

/// Envelope returned by the search-a-licious text-search API, wrapping the
/// matching products. Internal — only `OpenFoodFactsService` needs this
/// shape. An empty `hits` array (zero matches) is a normal, successful
/// response, not an error condition.
struct SearchResponse: Decodable {
    let hits: [SearchedProduct]
}
