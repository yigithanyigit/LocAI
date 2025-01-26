import SwiftUI

struct ModelSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var chatState: ChatState
    @EnvironmentObject private var chatStorage: ChatStorage
    @Binding var selectedModel: ModelState?
    @State private var isRemoving = false

    var body: some View {
        NavigationView {
            List {
                ForEach(appState.models, id: \.modelConfig.modelID) { modelState in
                    if modelState.modelDownloadState == .finished {
                        Button(action: {
                            modelState.startChat(chatState: chatState)
                            selectedModel = modelState
                            dismiss()
                        }) {
                            ModelView(isRemoving: $isRemoving)
                                .environmentObject(modelState)
                                .environmentObject(chatState)
                        }
                    } else {
                        ModelView(isRemoving: $isRemoving)
                            .environmentObject(modelState)
                            .environmentObject(chatState)
                    }
                }
                if !chatState.modelID.isEmpty {
                    Button("Deload loaded model") {
                        chatState.deloadModelFromChat()

                    }
                }

            }
            .navigationTitle("Models")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isRemoving.toggle()
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #else
        .frame(minWidth: 400, minHeight: 500)
        .navigationViewStyle(.automatic)
        #endif
    }
}
