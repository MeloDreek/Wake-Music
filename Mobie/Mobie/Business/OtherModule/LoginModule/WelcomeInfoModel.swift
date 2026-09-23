import UIKit
import KakaFoundation
import AppGroupKit

struct WelcomeInfoModel {
    enum Page: CaseIterable { case formats, connect, equalizer, fingerprint, premium }
    let page: Page
    var isPurchase: Bool { page == .premium }

    var title: String {
        switch page {
        case .formats: return "Support All Formats".localStr()
        case .connect: return "Connect Your Music".localStr()
        case .equalizer: return "EQ.Title".localStr()
        case .fingerprint: return "Audio Fingerprint".localStr()
        case .premium: return "Upgrade to Premium".localStr()
        }
    }
    var descStr: String {
        switch page {
        case .formats: return ""
        case .connect: return "Onboarding.Connect.Body".localStr()
        case .equalizer: return "Onboarding.Equalizer.Body".localStr()
        case .fingerprint: return "Onboarding.Fingerprint.Body".localStr()
        case .premium: return "Your ultimate music player. Play anytime, anywhere, and enjoy total listening freedom!".localStr()
        }
    }
    var iconName: String {
        switch page {
        case .formats: return "onboarding_formats"
        case .connect: return "onboarding_connect"
        case .equalizer: return "onboarding_equalizer"
        case .fingerprint: return "onboarding_fingerprint"
        case .premium: return "vip_gift_crown"
        }
    }
    var backColor: UIColor {
        switch page {
        case .formats: return .rgb(29, 21, 61)
        case .connect: return .rgb(8, 39, 46)
        case .equalizer: return .rgb(45, 29, 23)
        case .fingerprint: return .rgb(48, 19, 42)
        case .premium: return .rgb(16, 18, 29)
        }
    }
    var glowColor: UIColor {
        switch page {
        case .formats: return .rgb(82, 56, 154)
        case .connect: return .rgb(15, 112, 121)
        case .equalizer: return .rgb(142, 75, 34)
        case .fingerprint: return .rgb(139, 47, 98)
        case .premium: return .rgb(80, 45, 71)
        }
    }
    static func welcomeDataArray() -> [WelcomeInfoModel] {
        let features = [Page.formats, .connect, .equalizer, .fingerprint]
#if Target_Mobie_Pro
        return features.map { WelcomeInfoModel(page: $0) }
#else
        return (UserInfoManager.shared.isVIP() ? features : features + [.premium])
            .map { WelcomeInfoModel(page: $0) }
#endif
    }
}

/// Calendar-aware: a month-long offer must not be advertised as a hard-coded 30 days.
enum WelcomeTrialDuration {
    static func days(value: Int, periods: Int, unit: Calendar.Component,
                     startingAt date: Date = Date()) -> Int? {
        let (count, overflow) = value.multipliedReportingOverflow(by: periods)
        guard !overflow, count > 0 else { return nil }
        if unit == .day { return count }
        if unit == .weekOfYear {
            let (days, overflow) = count.multipliedReportingOverflow(by: 7)
            return overflow ? nil : days
        }
        guard unit == .month || unit == .year else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: unit, value: count, to: start),
              let days = calendar.dateComponents([.day], from: start, to: end).day,
              days > 0 else { return nil }
        return days
    }
}
