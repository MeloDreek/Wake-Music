// Compile-only business error/localization signatures; not production behavior.
import Foundation

public enum KakaError: Error {
    case youhaveCanceled
    case tokenExpiredAuthAgain
    case custom(String)
}
public extension String {
    func localStr() -> String { self }
}
