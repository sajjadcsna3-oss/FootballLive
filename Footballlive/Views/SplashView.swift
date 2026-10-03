import SwiftUI

/// The launch artwork is drawn rather than stretched from a bitmap so the
/// one-pixel pitch markings stay sharp at every supported window size.
struct SplashView: View {
    @State private var displayedProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1280, proxy.size.height / 800)

            ZStack {
                Color(red: 7 / 255, green: 9 / 255, blue: 12 / 255)

                RadialGradient(
                    colors: [Color(red: 17 / 255, green: 29 / 255, blue: 8 / 255).opacity(0.55), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 310 * scale
                )

                PitchPattern()
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)

                splashContent(scale: scale)

                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .font(.system(size: 7 * scale, design: .monospaced))
                    .tracking(1.1 * scale)
                    .foregroundStyle(Color.white.opacity(0.16))
                    .position(x: proxy.size.width / 2, y: proxy.size.height - 29 * scale)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Football Live. Warming up momentum engine.")
        .onAppear {
            withAnimation(.easeOut(duration: 1.65)) {
                displayedProgress = 0.64
            }
        }
    }

    private func splashContent(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            Image("SplashFootballIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 146 * scale, height: 130 * scale)
                .padding(.bottom, 18 * scale)

            Image("Football Live")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 264 * scale, height: 24 * scale)

            Text("S C O R E S   ·   A I   A N A L Y S I S")
                .font(.system(size: 7 * scale, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .padding(.top, 14 * scale)

            Text("See the game move before it happens.")
                .font(.system(size: 13 * scale))
                .foregroundStyle(Color.white.opacity(0.58))
                .padding(.top, 24 * scale)

            VStack(spacing: 10 * scale) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.055))
                        Capsule()
                            .fill(AppColors.lime)
                            .frame(width: proxy.size.width * displayedProgress)
                    }
                }
                .frame(height: 4 * scale)

                HStack {
                    Text("Warming up momentum engine")
                    Spacer()
                    Text("LIVE DATA").foregroundStyle(AppColors.lime)
                }
                .font(.system(size: 7 * scale, design: .monospaced))
                .tracking(1 * scale)
                .foregroundStyle(Color.white.opacity(0.36))
            }
            .frame(width: 266 * scale)
            .padding(.top, 40 * scale)
        }
        .offset(y: -3 * scale)
    }
}

private struct PitchPattern: Shape {
    func path(in rect: CGRect) -> Path {
        let reference = CGSize(width: 1280, height: 800)
        let sx = rect.width / reference.width
        let sy = rect.height / reference.height
        let scale = min(sx, sy)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let penaltyWidth = 177 * sx
        let penaltyHeight = 390 * sy
        let goalWidth = 68 * sx
        let goalHeight = 178 * sy

        var path = Path()

        // Outer boundary and halfway line.
        path.addRect(rect.insetBy(dx: 1, dy: 1))
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))

        // Centre circle from the reference layout.
        let circleDiameter = 374 * scale
        path.addEllipse(in: CGRect(
            x: center.x - circleDiameter / 2,
            y: center.y - circleDiameter / 2,
            width: circleDiameter,
            height: circleDiameter
        ))

        // The penalty and six-yard boxes continue beyond the left/right crop,
        // exactly like the wide pitch shown in the supplied design.
        path.addRect(CGRect(
            x: rect.minX,
            y: center.y - penaltyHeight / 2,
            width: penaltyWidth,
            height: penaltyHeight
        ))
        path.addRect(CGRect(
            x: rect.maxX - penaltyWidth,
            y: center.y - penaltyHeight / 2,
            width: penaltyWidth,
            height: penaltyHeight
        ))
        path.addRect(CGRect(
            x: rect.minX,
            y: center.y - goalHeight / 2,
            width: goalWidth,
            height: goalHeight
        ))
        path.addRect(CGRect(
            x: rect.maxX - goalWidth,
            y: center.y - goalHeight / 2,
            width: goalWidth,
            height: goalHeight
        ))

        return path
    }
}
