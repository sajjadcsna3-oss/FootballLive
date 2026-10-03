import SwiftUI

struct AIConsentNotice: View {
    @EnvironmentObject private var consent: AIConsentService

    var body: some View {
        Card(highlight: true) {
            VStack(alignment: .leading, spacing: 9) {
                Label("AI privacy", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColors.lime)
                Text("When you use an AI feature, your question and the displayed football context are sent through Football Live's service to Google Gemini for processing. AI responses can be incomplete or incorrect; verify important information against the match data.")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your profile name and locally saved preferences are not included in AI requests.")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.muted)
                HStack {
                    PillButton(title: "Allow AI processing") { consent.grant() }
                        .fixedSize()
                    if let url = APIConfiguration.privacyURL {
                        Link("Privacy Policy", destination: url)
                            .font(.system(size: 10))
                    }
                }
            }
        }
    }
}
