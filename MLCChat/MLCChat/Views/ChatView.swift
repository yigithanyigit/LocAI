import GameController
import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var chatState: ChatState
    @EnvironmentObject private var chatStorage: ChatStorage
    @Environment(\.scenePhase) var scenePhase
    @State private var inputMessage: String = ""
    @FocusState private var inputIsFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Namespace private var messagesBottomID
    @State private var selectedModel: ModelState?
    @State private var showModelSelect = false
    @State private var showChatHistory = false
    @State private var hasInitialSave = false
    @State private var showSendAlert = false
    @State private var shouldScrollToBottom = true

    // vision-related properties
    @State private var showActionSheet: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var imageConfirmed: Bool = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var image: UIImage?

    var modelButtonLabel: some View {
        HStack(spacing: 6) {
            if chatState.modelID.isEmpty {
                Image(systemName: "cube.box")
                Text("Select a Model")
            } else {
                Image(systemName: "cube.box.fill")
                Text(chatState.displayName)
                if chatState.isChattable {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 14))
                }
            }
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(chatState.modelID.isEmpty ? .blue : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
        .id(chatState.modelID)
    }

    var body: some View {
        VStack {
            modelInfoView
            messagesView
            uploadImageView
            messageInputView
        }
        .navigationBarTitle(
            "Chat",
            displayMode: .inline
        )
        .navigationBarBackButtonHidden()
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                self.chatState.requestSwitchToBackground()
            }
        }
        .onChange(of: chatState.displayMessages) { messages in
            // Only save chat when it's modified through interaction
            // not when loaded from history
            if !messages.isEmpty && hasInitialSave && !chatState.isLoadedChat {
                chatState.saveCurrentChat(to: chatStorage)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    showChatHistory = true
                } label: {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 18))
                        .foregroundColor(chatState.isInterruptible ? .blue : .gray)
                }
                .buttonStyle(.borderless)
                .disabled(!chatState.isInterruptible)
            }
            ToolbarItemGroup(placement: .principal) {
                Button {
                    showModelSelect = true
                } label: {
                    modelButtonLabel
                }
                .buttonStyle(.plain)
                .disabled(!chatState.isInterruptible)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        image = nil
                        imageConfirmed = false
                        hasInitialSave = false
                        chatState.requestResetChat(chatStorage: chatStorage)
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(chatState.isResettable ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!chatState.isResettable)
            }
        }
        .sheet(isPresented: $showModelSelect) {
            ModelSelectView(selectedModel: $selectedModel)
                .onDisappear {
                    if let model = selectedModel {
                        model.startChat(chatState: chatState, chatStorage: chatStorage)
                        selectedModel = nil
                    }
                }
        }
        .sheet(isPresented: $showChatHistory) {
            ChatHistoryView(showModelSelect: $showModelSelect)
                .onDisappear {
                    // Reset scroll flag when returning from history
                    shouldScrollToBottom = false
                    // Schedule a state reset after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        shouldScrollToBottom = true
                    }
                }
        }
        .onAppear {
            // Initialize chat state
            hasInitialSave = false
            shouldScrollToBottom = true

            // Start new chat if needed
            if chatState.displayMessages.isEmpty {
                chatStorage.startNewChat()
            } else {
                // Only save if this is a new chat, not loaded from history
                if !chatState.isLoadedChat {
                    chatState.saveCurrentChat(to: chatStorage, isNewChat: true)
                }
                hasInitialSave = true

                // Ensure we're at the bottom of existing chat
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shouldScrollToBottom = true
                }
            }
        }
    }
}

// ChatView extensions
extension ChatView {
    fileprivate var modelInfoView: some View {
        HStack(spacing: 8) {
            if !chatState.modelID.isEmpty && !chatState.isChattable {
                ProgressView()
                    .scaleEffect(0.8)
            }
            Text(chatState.infoText)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .animation(.easeInOut, value: chatState.infoText)
        }
        .padding(.vertical, 8)
    }

    fileprivate var messagesView: some View {
        ScrollViewReader { scrollViewProxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    let messageCount = chatState.displayMessages.count
                    let hasSystemMessage =
                        messageCount > 0
                        && chatState.displayMessages[0].role
                            == MessageRole.assistant
                    let startIndex = hasSystemMessage ? 1 : 0

                    if messageCount == 0 {
                        Text("Start a conversation")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }

                    // display the system message
                    if hasSystemMessage {
                        MessageView(
                            role: chatState.displayMessages[0].role,
                            message: chatState.displayMessages[0].message,
                            isMarkdownSupported: false
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // display image
                    if let image, imageConfirmed {
                        ImageView(image: image)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // display conversations
                    ForEach(
                        chatState.displayMessages[startIndex...],
                        id: \.id
                    ) { message in
                        MessageView(
                            role: message.role,
                            message: message.message
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(messagesBottomID)
                }
                .padding(.top, 8)
            }
            .onChange(of: chatState.displayMessages) { newMessages in
                guard shouldScrollToBottom else { return }

                if hasInitialSave {
                    withAnimation(.spring(response: 0.3)) {
                        scrollViewProxy.scrollTo(messagesBottomID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    fileprivate var uploadImageView: some View {
        // TODO: Implement vision-related features
        if chatState.legacyUseImage && !imageConfirmed && false {
            if image == nil {
                Button {
                    showActionSheet = true
                } label: {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("Upload picture to chat")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    )
                }
                .actionSheet(isPresented: $showActionSheet) {
                    ActionSheet(
                        title: Text("Choose from"),
                        buttons: [
                            .default(Text("Photo Library")) {
                                showImagePicker = true
                                imageSourceType = .photoLibrary
                            },
                            .default(Text("Camera")) {
                                showImagePicker = true
                                imageSourceType = .camera
                            },
                            .cancel(),
                        ])
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker(
                        image: $image,
                        showImagePicker: $showImagePicker,
                        imageSourceType: imageSourceType)
                }
                .disabled(!chatState.isChattable)
                // Show enabled only in chattable state
                .opacity(chatState.isChattable ? 1 : 0.5)
            } else {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 300, maxHeight: 300)
                            .cornerRadius(12)
                            .shadow(radius: 3)

                        HStack(spacing: 20) {
                            Button {
                                withAnimation {
                                    self.image = nil
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Undo")
                                }
                                .foregroundColor(.red)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                                )
                            }

                            Button {
                                withAnimation {
                                    imageConfirmed = true
                                    if let currentImage = image as? UIImage {
                                        chatState.handleImage(image: currentImage)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "checkmark")
                                    Text("Submit")
                                }
                                .foregroundColor(.green)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
                .padding()
                .transition(.opacity)
            }
        }
    }

    fileprivate var messageInputView: some View {
        VStack {
            Divider()
            HStack(spacing: 12) {
                TextField("Type your message...", text: $inputMessage, axis: .vertical)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .frame(minHeight: CGFloat(40))
                    .focused($inputIsFocused)
                    .onSubmit {
                        let isKeyboardConnected = GCKeyboard.coalesced != nil
                        if isKeyboardConnected {
                            send()
                        }
                    }

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(chatState.isChattable && !inputMessage.isEmpty ? .blue : .gray)
                }
                .disabled(!(chatState.isChattable && inputMessage != ""))
                .alert("No model selected, please select a model from top of the page.", isPresented: $showSendAlert) {
                    Button("OK") {
                        showModelSelect = false
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: -2)
        )
    }

    fileprivate func send() {
        if chatState.modelID.isEmpty {
            showSendAlert = true
            return
        }

        inputIsFocused = false

        // Send both text and image if available
        if imageConfirmed, let currentImage = image {
            chatState.requestGenerate(prompt: inputMessage, image: currentImage)
            // Clear image state after sending
            withAnimation {
                image = nil
                imageConfirmed = false
            }
        } else {
            chatState.requestGenerate(prompt: inputMessage)
        }

        inputMessage = ""

        // First message triggers new chat creation
        if !hasInitialSave {
            hasInitialSave = true
            chatState.saveCurrentChat(to: chatStorage, isNewChat: true)
        }
    }
}
