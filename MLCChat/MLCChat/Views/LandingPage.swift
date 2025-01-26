import SwiftUI

struct LandingPage: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding = false
    @State private var showModelSelect = false
    @State private var selectedModel: ModelState?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var chatStorage: ChatStorage
    @EnvironmentObject private var chatState: ChatState

    var body: some View {
        NavigationView {
            Group {
                if hasSeenOnboarding {
                    ChatView()
                } else {
                    VStack {
                        Text("MLCChat")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #else
        .navigationViewStyle(.automatic)
        .frame(minWidth: 800, minHeight: 600)
        #endif
        // Show onboarding for first-time users
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding && !showModelSelect },
            set: { showOnboarding = $0 }
        )) {
            OnboardingView(showModelView: $showModelSelect)
        }
        // Show model selection after onboarding or when needed
        .sheet(isPresented: $showModelSelect) {
            ModelSelectView(selectedModel: $selectedModel)
                .onDisappear {
                    if selectedModel != nil {
                        hasSeenOnboarding = true
                        showModelSelect = false
                    }
                }
        }
    }
}

#Preview {
    LandingPage()
}
