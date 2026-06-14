import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Premium, step-driven onboarding that walks the user through enabling the Keygram
/// keyboard. It always reflects the steps that are *still* left: adding the keyboard,
/// allowing Full Access (with the reason it is needed), and activating the keyboard.
struct OnboardingView: View {
    var status: KeyboardSetupStatus
    var refresh: () -> Void
    var onComplete: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var demoText = ""
    @State private var didCelebrate = false
    @FocusState private var demoFieldFocused: Bool

    private let pollTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    static let brand = Color(red: 246.0 / 255.0, green: 207.0 / 255.0, blue: 47.0 / 255.0)

    private var step: OnboardingStep { status.currentStep }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header

                Spacer(minLength: 12)

                if didCelebrate {
                    SuccessView(brand: Self.brand)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    stepContent
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer(minLength: 12)

                if !didCelebrate {
                    footer
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: step)
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: didCelebrate)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onChange(of: status) { _, newValue in
            if newValue.isComplete { celebrateAndFinish() }
        }
        .onReceive(pollTimer) { _ in
            // While on the activation step the user is typing with Keygram inside the
            // app, which is when the extension records Full Access. Poll to catch it.
            if step == .activate { refresh() }
        }
        .onAppear {
            refresh()
            if status.isComplete { celebrateAndFinish() }
        }
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Self.brand.opacity(0.16),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                KeygramMark(size: 34)
                Text("Keygram")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
            }

            StepProgressBar(currentIndex: step.index, total: OnboardingStep.totalCount, brand: Self.brand)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .addKeyboard:
            OnboardingStepCard(
                illustration: { AddKeyboardIllustration(brand: Self.brand) },
                eyebrow: "Step 1 of 3",
                title: "Add the Keygram keyboard",
                message: "Keygram lives right inside your keyboard. Add it once and you can switch to it in any app."
            )
        case .allowFullAccess:
            OnboardingStepCard(
                illustration: { FullAccessIllustration(brand: Self.brand) },
                eyebrow: "Step 2 of 3",
                title: "Allow Full Access",
                message: "Keygram needs Full Access to learn the words and corrections you actually use — that’s what powers personalized autocorrect and autocomplete. Please enable it when asked. Everything stays on this device.",
                footnote: "Private by design — no typing ever leaves your phone."
            )
        case .activate:
            ActivateStepCard(brand: Self.brand, demoText: $demoText, demoFieldFocused: $demoFieldFocused)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 14) {
            switch step {
            case .addKeyboard:
                PrimaryButton(title: "Open Keyboard Settings", brand: Self.brand) {
                    openKeyboardSettings()
                }
                HintLabel(text: "Settings ▸ Keyboards ▸ Add New Keyboard ▸ Keygram")
            case .allowFullAccess:
                PrimaryButton(title: "Allow Full Access", brand: Self.brand) {
                    openKeyboardSettings()
                }
                HintLabel(text: "Settings ▸ Keygram ▸ turn on Allow Full Access")
            case .activate:
                PrimaryButton(title: "Try Keygram now", brand: Self.brand) {
                    demoFieldFocused = true
                }
                HintLabel(text: "Tap the field, hold 🌐 and choose Keygram, then type a word")
            }
        }
    }

    // MARK: - Actions

    private func openKeyboardSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func celebrateAndFinish() {
        guard !didCelebrate else { return }
        demoFieldFocused = false
        withAnimation { didCelebrate = true }
        KeyboardSetupStatus.hasCompletedOnboarding = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            onComplete()
        }
    }
}

// MARK: - Step card

private struct OnboardingStepCard<Illustration: View>: View {
    @ViewBuilder var illustration: () -> Illustration
    var eyebrow: String
    var title: String
    var message: String
    var footnote: String?

    var body: some View {
        VStack(spacing: 28) {
            illustration()
                .frame(height: 200)

            VStack(spacing: 12) {
                Text(eyebrow)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                if let footnote {
                    Label(footnote, systemImage: "lock.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }
}

private struct ActivateStepCard: View {
    var brand: Color
    @Binding var demoText: String
    var demoFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 26) {
            GlobeSwitchIllustration(brand: brand)
                .frame(height: 180)

            VStack(spacing: 12) {
                Text("Step 3 of 3")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text("Switch to Keygram")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("Tap below, switch to the Keygram keyboard and type a word. The moment it’s live, you’re all set.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            TextField("Type here to test Keygram…", text: $demoText)
                .focused(demoFieldFocused)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(brand.opacity(0.6), lineWidth: 1.5)
                        )
                )
        }
    }
}

// MARK: - Reusable pieces

private struct StepProgressBar: View {
    var currentIndex: Int
    var total: Int
    var brand: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? brand : Color(.systemGray4))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct PrimaryButton: View {
    var title: String
    var brand: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(brand)
                        .shadow(color: brand.opacity(0.45), radius: 12, y: 6)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HintLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

private struct SuccessView: View {
    var brand: Color
    @State private var animate = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(brand.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .scaleEffect(animate ? 1 : 0.5)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(brand)
                    .scaleEffect(animate ? 1 : 0.4)
            }

            VStack(spacing: 8) {
                Text("You’re all set")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Keygram is now learning your style to personalize every word.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(animate ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { animate = true }
        }
    }
}

private struct KeygramMark: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: "AppIcon~ios-marketing", withExtension: "png"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(OnboardingView.brand)
                    .overlay(Image(systemName: "keyboard.fill").foregroundStyle(.black))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

// MARK: - Illustrations

private struct AddKeyboardIllustration: View {
    var brand: Color
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 230, height: 150)
                .overlay(
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 7) {
                                ForEach(0..<(row == 2 ? 5 : 8), id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray4))
                                        .frame(width: 18, height: 22)
                                }
                            }
                        }
                    }
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 6)

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white, brand)
                .offset(x: 92, y: -64)
                .scaleEffect(pulse ? 1.08 : 0.94)
                .shadow(color: brand.opacity(0.5), radius: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct FullAccessIllustration: View {
    var brand: Color
    @State private var on = false

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(brand.opacity(0.16))
                    .frame(width: 120, height: 120)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(brand)
            }

            HStack {
                Text("Allow Full Access")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule()
                        .fill(on ? brand : Color(.systemGray4))
                        .frame(width: 52, height: 31)
                    Circle()
                        .fill(.white)
                        .frame(width: 27, height: 27)
                        .padding(2)
                        .shadow(radius: 1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .frame(width: 230)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.4).repeatForever(autoreverses: true)) {
                on = true
            }
        }
    }
}

private struct GlobeSwitchIllustration: View {
    var brand: Color
    @State private var bounce = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .frame(width: 230, height: 120)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 6)

            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(brand)
                    .scaleEffect(bounce ? 1.12 : 0.92)
                Text("Keygram")
                    .font(.headline.weight(.bold))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(brand.opacity(0.18))
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { bounce = true }
        }
    }
}
