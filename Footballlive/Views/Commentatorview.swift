import SwiftUI

struct CommentatorView: View {
    @EnvironmentObject var vm: CommentatorViewModel
    @EnvironmentObject var match: MatchCenterViewModel
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var aiConsent: AIConsentService
    var body: some View { VStack(spacing: 0) { ScrollViewReader { proxy in ScrollView { LazyVStack(spacing: 16) { if !aiConsent.hasConsent { AIConsentNotice() }; if vm.messages.isEmpty { ScreenStateView(title: "Ask about the selected match.", subtitle: match.fixture == nil ? "Select a live match first. AI answers may be incomplete or incorrect." : "Answers are generated from the match data shown in Match Center and may contain errors.", systemImage: "bubble.left.and.text.bubble.right") }; ForEach(vm.messages) { AIChatBubble(message: $0).id($0.id) }; if vm.isLoading { HStack(spacing: 8) { ProgressView().tint(AppColors.lime); Text("Generating response…") }.font(.system(size: 10)).foregroundColor(AppColors.muted) }; if let error = vm.errorMessage { Text(error).foregroundColor(AppColors.red).font(.system(size: 11)) } }.padding(24) }.onChange(of: vm.messages.count) { _, _ in if let id = vm.messages.last?.id { withAnimation { proxy.scrollTo(id, anchor: .bottom) } } } }; Divider().overlay(AppColors.border); composer }.background(AppColors.bg) }
    private var composer: some View { VStack(alignment: .leading, spacing: 10) { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(vm.chips, id: \.self) { chip in Button { send(chip) } label: { Text(chip).font(.system(size: 9)).foregroundColor(AppColors.muted).padding(.horizontal, 10).padding(.vertical, 5).overlay(Capsule().stroke(AppColors.border)) }.buttonStyle(.plain) } } }; HStack(alignment: .bottom) { TextEditor(text: $vm.input).font(.system(size: 11)).scrollContentBackground(.hidden).frame(minHeight: 36, maxHeight: 90); Button("Clear") { vm.clear() }.buttonStyle(.plain).foregroundColor(AppColors.muted); Button { send() } label: { Image(systemName: "arrow.up.right").foregroundColor(.black).frame(width: 26, height: 26).background(Circle().fill(AppColors.lime)) }.buttonStyle(.plain).disabled(vm.isLoading) }.padding(10).background(AppColors.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border)) }.padding(20) }
    private func send(_ suggested: String? = nil) {
        guard EntitlementService.shared.canUseAI else { app.openPremium(); return }
        guard aiConsent.hasConsent else { return }
        Task { await vm.send(suggested, fixture: match.fixture, statistics: match.statistics, events: match.events) }
    }
}
struct AIChatBubble: View { let message: ChatMessage; var body: some View { HStack { if message.isUser { Spacer() }; Text(message.text.joined(separator: "\n\n")).font(.system(size: 11)).foregroundColor(message.isUser ? .black : AppColors.text).padding(14).background(message.isUser ? AppColors.lime : AppColors.card).clipShape(RoundedRectangle(cornerRadius: 14)).frame(maxWidth: 620, alignment: message.isUser ? .trailing : .leading); if !message.isUser { Spacer() } } } }
