//
//  Accountviews.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI
import StoreKit

// MARK: - Shared list of alert toggles (used by Follow Setup and Alerts & Profile)
struct AlertToggleList: View {
    @EnvironmentObject var account: AccountViewModel
    let kinds: [AlertKind]
    var body: some View {
        Divided {
            ForEach(kinds) { k in
                SettingToggle(title: k.info.title, subtitle: k.info.subtitle, isOn: account.binding(for: k))
                    .disabled(!k.clientAvailable || (k == .surge && !EntitlementService.shared.isPro))
                    .opacity(k.clientAvailable && (k != .surge || EntitlementService.shared.isPro) ? 1 : 0.55)
                if k != kinds.last { Divider().overlay(AppColors.border) }
            }
        }
    }
}

// MARK: - Alerts & Profile
struct AlertsProfileView: View {
    @EnvironmentObject var account: AccountViewModel
    @EnvironmentObject var app: AppViewModel
    @State private var editingProfile = false
    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 14) {
                    Card(highlight: true) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Excitement threshold").font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.text)
                            Text("Only get pinged when the momentum engine says a match is worth looking up from your desk.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                            HStack(spacing: 12) { ThresholdSlider(value: $account.threshold); Text(account.thresholdText).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(AppColors.lime) }
                            HStack { Mono(text: "Everything", size: 7); Spacer(); Mono(text: "Only the good stuff", size: 7); Spacer(); Mono(text: "Finals only", size: 7) }
                        }
                    }
                    AlertToggleList(kinds: AlertKind.allCases)
                }
                VStack(spacing: 14) {
                    Card { VStack(spacing: 8) {
                        Text(account.initials).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.lime).frame(width: 50, height: 50).background(Circle().fill(Color.white.opacity(0.08)))
                        Text(account.name).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.text)
                        Mono(text: L10n.text("%@ · %lld teams followed", account.planName, account.teamsFollowed), size: 7)
                        PillButton(title: "Go Pro") { app.open(.pro) }
                        Button("Edit profile") { editingProfile = true }.buttonStyle(.plain).font(.system(size: 9)).foregroundColor(AppColors.muted)
                    }.frame(maxWidth: .infinity) }
                    Card { VStack(spacing: 12) {
                        HStack { Mono(text: "This week", size: 7); Spacer() }
                        ForEach(account.usage) { r in
                            HStack { Text(LocalizedStringKey(r.label)).font(.system(size: 10)).foregroundColor(AppColors.text.opacity(0.8)); Spacer()
                                Text(r.value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(AppColors.text) }
                        }
                    } }
                }.frame(width: 230)
            }.padding(20)
        }
        .task { UsageMetricsService.shared.refresh(); await NotificationService.shared.refreshStatus(); await NotificationService.shared.refreshDeliveredMetrics() }
        .sheet(isPresented: $editingProfile) { ProfileEditorView().environmentObject(account) }
    }
}

private struct ProfileEditorView: View {
    @EnvironmentObject var account: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile").font(.title2.bold())
            TextField("Display name", text: $draft).textFieldStyle(.roundedBorder)
            Text("Stored only on this Mac and used for your profile label.").font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save") { let value = draft.trimmingCharacters(in: .whitespacesAndNewlines); if !value.isEmpty { account.name = value }; dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(24).frame(width: 380).onAppear { draft = account.name }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject var account: AccountViewModel
    @EnvironmentObject var app: AppViewModel
    @ObservedObject private var store = StoreKitService.shared
    @Environment(\.requestReview) private var requestReview
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !account.isPro { HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlock the full Tempo read").font(.system(size: 14, weight: .bold)).foregroundColor(AppColors.text)
                        Text("Unlimited AI requests, followed teams, and momentum-surge alerts.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                    }
                    Spacer()
                    PillButton(title: account.isPro ? "Tempo Pro active" : "View plans") { app.open(.pro) }.frame(width: 150)
                }.padding(18).background(LinearGradient(colors: [AppColors.lime.opacity(0.12), AppColors.card], startPoint: .trailing, endPoint: .leading))
                    .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.lime.opacity(0.35)))
                }
                Mono(text: "General", size: 8)
                Divided {
                    toggleRow("DK", "Dark appearance", "Tempo is designed dark; light mode is high-contrast only", $account.darkAppearance)
                    toggleRow("DN", "Compact rows", "Fit roughly four more matches per screen", $account.compactRows)
                    toggleRow("AP", "Autoplay highlights", "Play the next clip automatically in the player", $account.autoplayHighlights)
                    toggleRow("MB", "Menu-bar live score", "Keep one followed match in the macOS menu bar", $account.menuBarScore)
                    languageRow
                    kickoffRow
                    if !account.isPro { actionRow("RS", "Restore purchases", "Recover an existing App Store subscription", store.isLoading ? "Restoring…" : account.planName) { Task { await store.restore() } } }
                }
                Mono(text: "Others", size: 8)
                Divided {
                    ShareLink(item: "Football Live — live scores and grounded football analysis") { actionLabel("SH", "Share Tempo", "Send the app to a friend") }.buttonStyle(.plain)
                    Button { requestReview() } label: { actionLabel("RT", "Rate on the App Store", "Open the system App Store review prompt") }.buttonStyle(.plain)
                    if let url = APIConfiguration.termsURL { legalRow("TU", "Terms of Use", url) }
                    if let url = APIConfiguration.privacyURL { legalRow("PP", "Privacy Policy", url) }
                }
                if let message = store.message { Text(message).font(.system(size: 10)).foregroundColor(AppColors.muted) }
            }.padding(20)
        }
    }
    private func actionLabel(_ code: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 12) { badge(code); VStack(alignment: .leading, spacing: 3) { Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.text); Text(LocalizedStringKey(subtitle)).font(.system(size: 10)).foregroundColor(AppColors.muted) }; Spacer(); Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(AppColors.muted) }.padding(.vertical, 11).padding(.horizontal, 14)
    }

    func badge(_ c: String) -> some View {
        Text(c).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(AppColors.lime)
            .frame(width: 26, height: 26).background(AppColors.lime.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 5))
    }
    func toggleRow(_ code: String, _ title: String, _ sub: String, _ b: Binding<Bool>) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) { badge(code).padding(.leading, 14); SettingToggle(title: title, subtitle: sub, isOn: b) }
            Divider().overlay(AppColors.border)
        }
    }
    func valueRow(_ r: SettingRow) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                badge(r.code)
                VStack(alignment: .leading, spacing: 3) { Text(LocalizedStringKey(r.title)).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.text); Text(LocalizedStringKey(r.subtitle)).font(.system(size: 10)).foregroundColor(AppColors.muted) }
                Spacer()
                Text(r.value).font(.system(size: 10, design: .monospaced)).foregroundColor(AppColors.muted)
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(AppColors.muted)
            }.padding(.vertical, 11).padding(.horizontal, 14)
            Divider().overlay(AppColors.border)
        }
    }
    private var languageRow: some View {
        HStack(spacing: 12) {
            badge("LG")
            VStack(alignment: .leading, spacing: 3) { Text("Language").font(.system(size: 12, weight: .medium)); Text("Interface and AI commentary language").font(.system(size: 10)).foregroundColor(AppColors.muted) }
            Spacer()
            Picker("Language", selection: $account.languageCode) { ForEach(account.supportedLanguages) { language in Text(language.name).tag(language.id) } }.labelsHidden().frame(width: 190)
        }.padding(.vertical, 8).padding(.horizontal, 14)
    }
    private var kickoffRow: some View {
        HStack(spacing: 12) {
            badge("TZ")
            VStack(alignment: .leading, spacing: 3) { Text("Kickoff times").font(.system(size: 12, weight: .medium)); Text("Choose local time or UTC").font(.system(size: 10)).foregroundColor(AppColors.muted) }
            Spacer()
            Picker("Kickoff times", selection: $account.kickoffTimeMode) { Text("Local · \(account.kickoffTimeDescription)").tag("local"); Text("UTC").tag("utc") }.labelsHidden().frame(width: 170)
        }.padding(.vertical, 8).padding(.horizontal, 14)
    }
    private func actionRow(_ code: String, _ title: String, _ subtitle: String, _ value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack(spacing: 12) { badge(code); VStack(alignment: .leading, spacing: 3) { Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.text); Text(LocalizedStringKey(subtitle)).font(.system(size: 10)).foregroundColor(AppColors.muted) }; Spacer(); Text(LocalizedStringKey(value)).font(.system(size: 10, design: .monospaced)).foregroundColor(AppColors.muted); Image(systemName: "chevron.right").font(.system(size: 8)).foregroundColor(AppColors.muted) }.padding(.vertical, 11).padding(.horizontal, 14) }.buttonStyle(.plain)
    }
    private func legalRow(_ code: String, _ title: String, _ url: URL) -> some View {
        Link(destination: url) { HStack(spacing: 12) { badge(code); Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .medium)).foregroundColor(AppColors.text); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundColor(AppColors.muted) }.padding(.vertical, 11).padding(.horizontal, 14) }
    }
}

struct APIKeySettingsView: View {
#if DEBUG
    @StateObject private var vm = APIKeySettingsViewModel()
#endif
    var body: some View {
#if DEBUG
        Divided {
            keyRow(title: "GOAL API", subtitle: "Live football data", placeholder: "Paste a rotated GOAL API key", text: $vm.goalInput, connected: vm.hasGoalKey, save: vm.saveGoal, remove: vm.removeGoal)
            Divider().overlay(AppColors.border)
            keyRow(title: "Gemini API", subtitle: "Grounded AI explanations", placeholder: "Paste a Gemini API key", text: $vm.geminiInput, connected: vm.hasGeminiKey, save: vm.saveGemini, remove: vm.removeGemini)
            if let message = vm.message {
                Text(message).font(.system(size: 10)).foregroundColor(message.contains("saved") ? AppColors.lime : AppColors.muted).padding(14)
            }
        }
#else
        Card {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill").foregroundColor(AppColors.lime)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Secure API service").font(.system(size: 12, weight: .medium))
                    Text(APIConfiguration.backendBaseURL == nil ? "Production service is not configured." : "Football and AI requests are routed through the Tempo backend.")
                        .font(.system(size: 10)).foregroundColor(APIConfiguration.backendBaseURL == nil ? AppColors.red : AppColors.muted)
                }
            }
        }
#endif
    }
#if DEBUG
    private func keyRow(title: String, subtitle: String, placeholder: String, text: Binding<String>, connected: Bool, save: @escaping () -> Void, remove: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 12, weight: .medium)); Text(subtitle).font(.system(size: 10)).foregroundColor(AppColors.muted) }
                Spacer()
                Text(connected ? "CONNECTED" : "NOT CONFIGURED").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(connected ? AppColors.lime : AppColors.muted)
            }
            HStack(spacing: 8) {
                SecureField(placeholder, text: text).textFieldStyle(.plain).font(.system(size: 10)).padding(9).background(AppColors.bg).clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.border))
                Button("Save") { save() }.buttonStyle(.borderedProminent).tint(AppColors.lime).foregroundColor(.black).disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if connected { Button("Remove", role: .destructive) { remove() }.buttonStyle(.borderless).font(.system(size: 10)) }
            }
            Text("Stored in macOS Keychain. The saved value is never displayed or logged.").font(.system(size: 9)).foregroundColor(AppColors.muted)
        }.padding(14)
    }
#endif
}

// MARK: - Tempo Pro
struct TempoProView: View {
    @EnvironmentObject var account: AccountViewModel
    @ObservedObject private var store = StoreKitService.shared
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Mono(text: "Tempo Pro", size: 9, color: AppColors.lime).padding(.top, 20)
                Text("See the game move\nbefore it happens.").font(.system(size: 30, weight: .bold)).multilineTextAlignment(.center).foregroundColor(AppColors.text)
                Text("The momentum engine and AI co-commentator run on every match, in every league you follow.")
                    .font(.system(size: 11)).foregroundColor(AppColors.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
                if account.isPro {
                    Card(highlight: true) { VStack(spacing: 10) { Image(systemName: "checkmark.seal.fill").font(.system(size: 28)).foregroundColor(AppColors.lime); Text("Tempo Pro is active").font(.title2.bold()); Text("Your implemented Pro features are unlocked on this Mac.").foregroundColor(AppColors.muted) } }.frame(maxWidth: 420)
                } else {
                    HStack(alignment: .top, spacing: 16) { ForEach(account.plans) { SubscriptionPlanCard(plan: $0) } }.frame(maxWidth: 620).padding(.top, 10)
                }
                if let message = store.message { Text(message).font(.system(size: 9, design: .monospaced)).foregroundColor(AppColors.muted) }
                if !account.isPro { Mono(text: "Subscriptions are billed and managed by the App Store.", size: 7).padding(.top, 6) }
            }.frame(maxWidth: .infinity).padding(20)
        }
    }
}

struct SubscriptionPlanCard: View {
    let plan: PlanInfo
    @ObservedObject private var store = StoreKitService.shared
    private var productID: String? { plan.id == "monthly" ? StoreKitService.monthlyID : plan.id == "annual" ? StoreKitService.annualID : nil }
    private var product: Product? { productID.flatMap(store.product) }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(plan.name)).font(.system(size: 11, weight: .medium)).foregroundColor(AppColors.text.opacity(0.85))
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(product?.displayPrice ?? plan.price).font(.system(size: 26, weight: .bold)).foregroundColor(AppColors.text)
                Text(plan.unit).font(.system(size: 10)).foregroundColor(AppColors.muted)
            }
            Mono(text: plan.note, size: 7, color: Color(hex: plan.noteColorHex))
            Divider().overlay(AppColors.border)
            ForEach(plan.features, id: \.self) { f in
                HStack(spacing: 8) { Circle().fill(AppColors.lime).frame(width: 4, height: 4); Text(LocalizedStringKey(f)).font(.system(size: 10)).foregroundColor(AppColors.text.opacity(0.85)) }
            }
            Spacer(minLength: 10)
            PillButton(title: store.purchasedIDs.contains(productID ?? "") ? "Current plan" : product == nil && plan.id != "free" ? "Unavailable" : plan.button, filled: plan.isFeatured) {
                if let product { Task { await store.purchase(product) } }
            }.disabled(plan.id == "free" || product == nil || store.purchasedIDs.contains(productID ?? ""))
        }
        .padding(16).frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(plan.isFeatured ? AppColors.lime.opacity(0.06) : AppColors.card).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(plan.isFeatured ? AppColors.lime : AppColors.border, lineWidth: plan.isFeatured ? 1.5 : 1))
    }
}
