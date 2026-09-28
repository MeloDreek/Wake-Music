import Foundation

@main
enum WebAuthorizationRegression {
    static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            count += 1
        }
        let redirect = "https://example.invalid/oauth/115/callback"
        let state = "random-state-123"
        let request = Drive115WebOAuth.authorizationURL(clientID: "app-test", redirectURI: redirect, state: state)!
        let query = URLComponents(url: request, resolvingAgainstBaseURL: false)!.queryItems!
        check(request.scheme == "https" && request.host == "passportapi.115.com", "Use the official HTTPS authorization host")
        check(request.path == "/open/authorize", "Authorization endpoint")
        check(query.first { $0.name == "redirect_uri" }?.value == redirect, "Round-trip encoded redirect_uri")
        check(query.first { $0.name == "state" }?.value == state, "State retained")
        check(query.first { $0.name == "response_type" }?.value == "code", "Code grant")
        check(!query.contains { $0.name == "client_secret" }, "Never put the client secret in a web URL")
        for bad in ["http://example.invalid/callback", "app://callback", "invalid"] {
            check(Drive115WebOAuth.authorizationURL(clientID: "app", redirectURI: bad, state: state) == nil, "Reject invalid redirect configuration")
        }
        check(Drive115WebOAuth.authorizationURL(clientID: "", redirectURI: redirect, state: state) == nil, "Require app id")
        check(Drive115WebOAuth.authorizationURL(clientID: "app", redirectURI: redirect, state: "") == nil, "Require random state")
        let valid = URL(string: redirect + "?code=abc%2B123&state=" + state)!
        check(Drive115WebOAuth.authorizationCode(valid, redirectURI: redirect, expectedState: state) == "abc+123", "Decode valid code once")
        check(Drive115WebOAuth.isCallbackHost(valid, redirectURI: redirect), "Intercept callback host")
        for bad in [
            "https://evil.invalid/oauth/115/callback?code=x&state=\(state)",
            "https://example.invalid.evil.invalid/oauth/115/callback?code=x&state=\(state)",
            "http://example.invalid/oauth/115/callback?code=x&state=\(state)",
            "https://example.invalid:444/oauth/115/callback?code=x&state=\(state)",
            "https://example.invalid/wrong?code=x&state=\(state)",
            redirect + "?code=x&state=wrong", redirect + "?code=x",
            redirect + "?state=\(state)", redirect + "?code=&state=\(state)",
            redirect + "?code=%20%20&state=\(state)",
            redirect + "?code=x&code=y&state=\(state)",
            redirect + "?code=x&state=\(state)&state=\(state)",
            redirect + "?code=x&state=\(state)&error=denied",
            redirect + "?code=x&state=\(state)#fragment",
            "https://name:password@example.invalid/oauth/115/callback?code=x&state=\(state)"
        ] {
            check(Drive115WebOAuth.authorizationCode(URL(string: bad)!, redirectURI: redirect, expectedState: state) == nil, "Reject malformed/spoofed callback: \(bad)")
        }
        check(Drive115WebOAuth.authorizationCode(valid, redirectURI: redirect, expectedState: "") == nil, "No code after state consumption")
        check(Drive115WebOAuth.isCallbackHost(URL(string: "https://example.invalid/wrong?code=x")!, redirectURI: redirect), "Cancel malformed callbacks before requesting company's server")
        check(!Drive115WebOAuth.isCallbackHost(URL(string: "https://example.invalid.evil.invalid/")!, redirectURI: redirect), "No host suffix matching")
        let domainError = #"{"state":0,"code":40140131,"data":{},"message":"redirect_uri\u975e\u6cd5\u57df\u540d","error":"redirect_uri\u975e\u6cd5\u57df\u540d","errno":40140131}"#
        check(Drive115WebOAuth.isRedirectDomainFailure(domainError, pageURL: request), "Recognize actual escaped 115 domain response")
        check(Drive115WebOAuth.isRedirectDomainFailure(#"{"state":false,"errno":"40140131"}"#, pageURL: request), "Boolean failure state and string errno")
        for body in [
            #"{"state":0,"code":40140133,"message":"client_secret invalid"}"#,
            #"{"state":0,"code":40140131,"errno":40140133}"#,
            #"{"state":1,"code":40140131}"#,
            #"{"state":0,"code":40140131.5}"#,
            #"{"state":0,"code":0,"message":"redirect_uri"}"#,
            #"{"state":0,"message":"redirect_uri非法域名"}"#,
            #"{"code":40140131}"#, "redirect_uri非法域名", "<html>40140131</html>", "[]", "null", "",
            domainError + String(repeating: " ", count: 65536)
        ] {
            check(!Drive115WebOAuth.isRedirectDomainFailure(body, pageURL: request), "Do not misclassify other errors, HTML or invalid payloads")
        }
        for url in ["https://passportapi.115.com.evil.invalid/open/authorize",
                    "https://evil.invalid/open/authorize", "http://passportapi.115.com/open/authorize",
                    "https://passportapi.115.com:444/open/authorize", "https://passportapi.115.com/open/authCodeToToken",
                    "https://user@passportapi.115.com/open/authorize"] {
            check(!Drive115WebOAuth.isRedirectDomainFailure(domainError, pageURL: URL(string: url)!), "Only inspect the official HTTPS authorization page")
        }
        print("\(count) 115 web authorization checks passed")
    }
}
