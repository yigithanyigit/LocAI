import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @Binding var showModelView: Bool

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 30) {
                Spacer()

                Image(systemName: "message.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.blue)

                Text("Welcome to MLCChat")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(alignment: .leading, spacing: 20) {
                    FeatureRow(icon: "bolt.fill", title: "Fast", description: "Optimized for mobile performance")
                    FeatureRow(icon: "lock.fill", title: "Private", description: "All processing happens on device")
                    FeatureRow(icon: "cpu.fill", title: "Efficient", description: "Optimized for mobile hardware")
                }
                .padding(.horizontal)

                Button(action: {
                    hasSeenOnboarding = true
                    showModelView = true
                    dismiss()
                }) {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 20)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.title2)
                .frame(width: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(showModelView: .constant(false))
    }
}
