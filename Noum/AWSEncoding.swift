import Foundation

private let awsQueryAllowed: CharacterSet = {
    var set = CharacterSet()
    set.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    return set
}()

extension String {
    /// Percent-encode the string according to AWS SigV4 requirements.
    /// Only RFC 3986 unreserved characters are left unescaped.
    func awsPercentEncoded() -> String {
        addingPercentEncoding(withAllowedCharacters: awsQueryAllowed) ?? self
    }
}
