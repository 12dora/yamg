import Foundation
import SwiftUI

enum LocalizationKey: String {
    case appTitle = "app.title"
    case dashboardTitle = "section.dashboard.title"
    case dashboardSubtitle = "section.dashboard.subtitle"
    case applicationsTitle = "section.applications.title"
    case applicationsSubtitle = "section.applications.subtitle"
    case storageTitle = "section.storage.title"
    case storageSubtitle = "section.storage.subtitle"
    case logsTitle = "section.logs.title"
    case logsSubtitle = "section.logs.subtitle"
    case preferencesTitle = "section.preferences.title"
    case preferencesSubtitle = "section.preferences.subtitle"
    case onboardingTitle = "onboarding.title"
    case onboardingSubtitle = "onboarding.subtitle"
    case onboardingCLIStatus = "onboarding.cli.status"
    case onboardingConfigStatus = "onboarding.config.status"
    case refresh = "action.refresh"
    case applicationsCount = "applications.count %lld"
    case applicationsEmpty = "applications.empty"
    case applicationsFailed = "applications.failed"
    case applicationDetailConfigurationFiles = "application.detail.configuration_files"

    var localizedStringKey: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }
}
