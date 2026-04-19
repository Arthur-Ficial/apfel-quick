import SwiftUI

struct WelcomeOverlayView: View {
    @Bindable var viewModel: QuickViewModel
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.38, green: 0.13, blue: 0.66),
                                     Color(red: 0.24, green: 0.07, blue: 0.44)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing))
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)

                Text("Welcome to apfel-quick")
                    .font(.system(size: 22, weight: .bold))

                Text("Press Option+Space anywhere to ask anything. The answer streams in and copies to your clipboard automatically. Everything runs on your Mac - no internet needed.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    featureBullet("airplane", "Works completely offline")
                    featureBullet("lock.shield", "Nothing leaves your Mac")
                    featureBullet("bolt", "Instant — no sign-up, no account")
                }
                .padding(.top, 4)

                Divider().padding(.top, 6)

                Toggle(isOn: $viewModel.settings.checkForUpdatesOnLaunch) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check for updates on launch")
                            .font(.system(size: 13, weight: .medium))
                        Text("We'll quietly check GitHub for new releases.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            .padding(32)

            Divider()

            Button("Get Started") {
                viewModel.settings.save()
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(20)
        }
        .frame(width: 460)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .preferredColorScheme(.light)
    }

    private func featureBullet(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}
