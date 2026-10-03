//
//  Theme.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI


// MARK: - Colors

extension Color {

    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)

        self.init(
            red: Double((value >> 16) & 255) / 255.0,
            green: Double((value >> 8) & 255) / 255.0,
            blue: Double(value & 255) / 255.0
        )
    }

    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            var value: UInt64 = 0; Scanner(string: hex).scanHexInt64(&value)
            return NSColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

enum AppColors {

    static let bg = Color(light: "F4F5F6", dark: "0B0C0E")
    static let sidebar = Color(light: "ECEEF0", dark: "0E1013")
    static let card = Color(light: "FFFFFF", dark: "121417")
    static let border = Color(light: "D7DADF", dark: "262A30")

    static let lime = Color(hex: "C4F135")
    static let blue = Color(hex: "3B6FE8")
    static let red = Color(hex: "FF4D4D")

    static let text = Color(light: "17191C", dark: "F2F3F5")
    static let muted = Color(light: "626872", dark: "7B8088")
}

struct RemoteBadge: View {
    let url: URL?
    let name: String
    var size: CGFloat = 24
    var body: some View {
        AsyncImage(url: APIConfiguration.allowsThirdPartyVisualAssets ? url : nil) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit().padding(size * 0.06)
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.08))
                    Text(String(name.prefix(2)).uppercased())
                        .font(.system(size: size * 0.30, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.lime)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel(name)
    }
}

struct ScreenStateView: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String = "exclamationmark.circle"
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 28)).foregroundColor(AppColors.lime)
            Text(LocalizedStringKey(title)).font(.system(size: 16, weight: .semibold)).foregroundColor(AppColors.text)
            if let subtitle { Text(LocalizedStringKey(subtitle)).font(.system(size: 11)).foregroundColor(AppColors.muted).multilineTextAlignment(.center).frame(maxWidth: 420) }
            if let retry { PillButton(title: "Retry", action: retry).fixedSize() }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(30)
    }
}

// MARK: - Small Reusable Pieces

struct Mono: View {

    let text: String
    var size: CGFloat = 9
    var color: Color = AppColors.muted

    var body: some View {
        Text(LocalizedStringKey(text))
            .textCase(.uppercase)
            .font(
                .system(
                    size: size,
                    design: .monospaced
                )
            )
            .tracking(1.2)
            .foregroundColor(color)
    }
}

// MARK: - Card

struct Card<Content: View>: View {

    var highlight: Bool = false
    var padding: CGFloat = 16

    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                highlight
                ? AppColors.lime.opacity(0.06)
                : AppColors.card
            )
            .clipShape(
                RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        highlight
                        ? AppColors.lime.opacity(0.35)
                        : AppColors.border
                    )
            )
    }
}

// MARK: - Pill Button

struct PillButton: View {

    let title: String
    var filled: Bool = true
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title))
                .font(
                    .system(
                        size: 12,
                        weight: .semibold
                    )
                )
                .foregroundColor(
                    filled
                    ? Color.black
                    : AppColors.text
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    filled
                    ? AppColors.lime
                    : Color.clear
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: 7)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            filled
                            ? Color.clear
                            : AppColors.border
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Lime Toggle

struct LimeToggle: ToggleStyle {

    func makeBody(configuration: Configuration) -> some View {

        Button {
            configuration.isOn.toggle()
        } label: {

            Capsule()
                .fill(
                    configuration.isOn
                    ? AppColors.lime
                    : Color.white.opacity(0.12)
                )
                .frame(
                    width: 36,
                    height: 20
                )
                .overlay {

                    Circle()
                        .fill(
                            configuration.isOn
                            ? Color.black
                            : AppColors.muted
                        )
                        .frame(
                            width: 14,
                            height: 14
                        )
                        .offset(
                            x: configuration.isOn
                            ? 8
                            : -8
                        )
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setting Toggle

struct SettingToggle: View {

    let title: String
    let subtitle: String

    @Binding var isOn: Bool

    var body: some View {

        HStack {

            VStack(
                alignment: .leading,
                spacing: 3
            ) {

                Text(LocalizedStringKey(title))
                    .font(
                        .system(
                            size: 12,
                            weight: .medium
                        )
                    )
                    .foregroundColor(AppColors.text)

                Text(LocalizedStringKey(subtitle))
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.muted)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(LimeToggle())
                .labelsHidden()
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 16)
    }
}

// MARK: - Divided Container

struct Divided<Content: View>: View {

    @ViewBuilder var content: () -> Content

    var body: some View {

        VStack(
            spacing: 0,
            content: content
        )
        .background(AppColors.card)
        .clipShape(
            RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border)
        )
    }
}

// MARK: - Team Colors

func teamColor(_ name: String) -> Color {

    let map: [String: String] = [
        "Arsenal": "D0161B",
        "Chelsea": "1D3C8F",
        "Man City": "6CABDD",
        "Newcastle": "E8E8E8",
        "Liverpool": "D0161B",
        "Tottenham": "1B2A5E",
        "Barcelona": "A50044",
        "Real Madrid": "EDEDED",
        "Sevilla": "D9232B",
        "Betis": "0BB363",
        "Everton": "1846B8",
        "West Ham": "7A263A",
        "Aston Villa": "95BFE5",
        "Brighton": "0057B8",
        "Bayern": "DC052D",
        "PSG": "1C3F94",
        "Warriors": "F5B400"
    ]

    return Color(
        hex: map[name] ?? "444B55"
    )
}

// MARK: - Team Dot

struct TeamDot: View {

    let name: String
    var size: CGFloat = 16

    var body: some View {

        Circle()
            .fill(teamColor(name))
            .frame(
                width: size,
                height: size
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.white.opacity(0.15)
                    )
            )
    }
}

// MARK: - Momentum Bar

struct MomentumBar: View {

    var value: Double

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 3
        ) {

            Mono(
                text: "Momentum",
                size: 7
            )

            GeometryReader { geometry in

                let safeValue = min(
                    max(value, 0.0),
                    1.0
                )

                let progressWidth =
                    geometry.size.width * CGFloat(safeValue)

                HStack(spacing: 0) {

                    Rectangle()
                        .fill(AppColors.lime)
                        .frame(
                            width: progressWidth
                        )

                    Rectangle()
                        .fill(AppColors.blue)
                }
                .clipShape(Capsule())
            }
            .frame(
                width: 105,
                height: 4
            )
        }
    }
}

// MARK: - Threshold Slider

struct ThresholdSlider: View {

    @Binding var value: Double

    // Expected range: 0...10

    var body: some View {

        GeometryReader { geometry in

            let safeValue = min(
                max(value, 0.0),
                10.0
            )

            let progress =
                CGFloat(safeValue / 10.0)

            let progressWidth =
                geometry.size.width * progress

            ZStack(alignment: .leading) {

                // Background Track
                Capsule()
                    .fill(
                        Color.white.opacity(0.08)
                    )
                    .frame(height: 4)

                // Progress Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.blue,
                                AppColors.lime
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: progressWidth,
                        height: 4
                    )

                // Slider Handle
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: 10,
                        height: 10
                    )
                    .offset(
                        x: progressWidth - 5
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in

                        guard geometry.size.width > 0 else {
                            return
                        }

                        let locationX = min(
                            max(drag.location.x, 0),
                            geometry.size.width
                        )

                        let percentage =
                            locationX / geometry.size.width

                        let newValue =
                            Double(percentage) * 10.0

                        value =
                            (newValue * 10.0).rounded() / 10.0
                    }
            )
        }
        .frame(height: 12)
    }
}
