import Foundation
import MLCSwift
import UIKit

enum MessageRole {
    case user
    case assistant
}

extension MessageRole {
    var isUser: Bool { self == .user }
}

struct MessageData: Hashable {
    let id = UUID()
    var role: MessageRole
    var message: String
}

enum ChatModelState {
    case generating
    case resetting
    case reloading
    case terminating
    case ready
    case failed
    case pendingImageUpload
    case processingImage
}

final class ChatState: ObservableObject {
    @Published var displayMessages = [MessageData]()
    @Published var infoText = ""
    @Published var displayName = ""
    @Published var legacyUseImage = true
    @Published private(set) var currentState: ChatModelState = .ready {
        didSet {
            print("ModelChatState changed from \(oldValue) to \(currentState)")
        }
    }

    private let modelChatStateLock = NSLock()
    private let engine = MLCEngine()
    private var historyMessages = [ChatCompletionMessage]()
    private var streamingText = ""
    private var modelLib = ""
    private var modelPath = ""
    var modelID = ""

    private var isSaving = false
    private var needsSaving = true
    var isLoadedChat = false // Made public to be checked by views

    init() {
    }

    var isInterruptible: Bool {
        return currentState == .ready
        || currentState == .generating
        || currentState == .failed
        || currentState == .pendingImageUpload
    }

    var isChattable: Bool {
        return currentState == .ready
    }

    var isUploadable: Bool {
        return currentState == .pendingImageUpload
    }

    var isResettable: Bool {
        return currentState == .ready
        || currentState == .generating
    }

    func handleImage(image: UIImage) {
        switchToProcessingImage()
        // Format image data for specific LLM models
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            let base64String = imageData.base64EncodedString()
            // Use the LLM-specific format for images (this might need adjustment based on your model)
            let imagePrompt = "<vision>base64=\(base64String)</vision>"

            DispatchQueue.main.async {
                self.legacyUseImage = false
                self.requestGenerate(prompt: "What's in this image?", image: image)
            }
        } else {
            processImageError()
        }
    }

    func processImageError() {
        DispatchQueue.main.async {
            self.infoText = "Failed to process image"
            self.legacyUseImage = true
            self.switchToFailed()

            // Reset back to ready state after showing error
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.infoText = ""
                self.switchToReady()
            }
        }
    }

    func saveCurrentChat(to chatStorage: ChatStorage, isNewChat: Bool = false) {
        // Don't save if this is a loaded chat and hasn't been modified
        guard !isSaving && !displayMessages.isEmpty && !isLoadedChat else { return }

        isSaving = true
        _ = chatStorage.saveChat(messages: displayMessages, isNewChat: isNewChat, currentModelName: self.modelID)
        needsSaving = false
        isSaving = false
    }

    func requestResetChat(chatStorage: ChatStorage) {
        assert(isResettable)

        // Only save if this isn't a loaded chat
        if !isLoadedChat {
            saveCurrentChat(to: chatStorage)
        }
        isLoadedChat = false
        needsSaving = true

        // Ensure engine is properly cleaned up
        Task {
            await engine.unload()
            await mainResetChat()

            // If we have a model, reload it
            if !modelID.isEmpty {
                await engine.reload(modelPath: modelPath, modelLib: modelLib)
            }

            DispatchQueue.main.async {
                self.switchToReady()
            }
        }
    }

    func requestSwitchToBackground() {
        if (currentState == .generating) {
            self.requestResetChat(chatStorage: ChatStorage()) // TODO: Fix this temporary usage
        }
    }

    func requestTerminateChat(chatStorage: ChatStorage, callback: @escaping () -> Void) {
        assert(isInterruptible)
        if !isLoadedChat {
            saveCurrentChat(to: chatStorage)
        }

        interruptChat(prologue: {
            switchToTerminating()
        }, epilogue: { [weak self] in
            self?.mainTerminateChat(callback: callback)
        })
    }

    func requestReloadChat(modelID: String, modelLib: String, modelPath: String, estimatedVRAMReq: Int, displayName: String, chatStorage: ChatStorage?) {
        print("Requesting reload chat for model: \(modelID)")
        if (isCurrentModel(modelID: modelID)) {
            print("Already current model, returning")
            return
        }
        assert(isInterruptible)
        if let chatStorage = chatStorage, !isLoadedChat {
            saveCurrentChat(to: chatStorage)
            print("Chat Saved")
        }

        interruptChat(prologue: {
            print("Switching to reloading state")
            switchToReloading()
        }, epilogue: { [weak self] in
            print("Starting main reload chat")
            self?.mainReloadChat(modelID: modelID,
                               modelLib: modelLib,
                               modelPath: modelPath,
                               estimatedVRAMReq: estimatedVRAMReq,
                               displayName: displayName)
        })
    }

    func requestGenerate(prompt: String, image: UIImage? = nil) {
        assert(isChattable)
        switchToGenerating()

        var fullPrompt = prompt
        if let image = image {
            // Convert image to base64
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let base64String = imageData.base64EncodedString()
                // Format for vision models
                fullPrompt = "<vision>base64=\(base64String)</vision>\n\n\(prompt.isEmpty ? "What's in this image?" : prompt)"
            }
        }

        appendMessage(role: .user, message: fullPrompt)
        appendMessage(role: .assistant, message: "")
        needsSaving = true
        isLoadedChat = false // New interaction means this is no longer just a loaded chat

        Task {
            self.historyMessages.append(
                ChatCompletionMessage(role: .user, content: fullPrompt)
            )
            var finishReasonLength = false
            var finalUsageTextLabel = ""

            for await res in await engine.chat.completions.create(
                messages: self.historyMessages,
                stream_options: StreamOptions(include_usage: true)
            ) {
                for choice in res.choices {
                    if let content = choice.delta.content {
                        self.streamingText += content.asText()
                    }
                    if let finish_reason = choice.finish_reason {
                        if finish_reason == "length" {
                            finishReasonLength = true
                        }
                    }
                }
                if let finalUsage = res.usage {
                    finalUsageTextLabel = finalUsage.extra?.asTextLabel() ?? ""
                }
                if currentState != .generating {
                    break
                }

                var updateText = self.streamingText
                if finishReasonLength {
                    updateText += " [output truncated due to context length limit...]"
                }

                let newText = updateText
                DispatchQueue.main.async {
                    self.updateMessage(role: .assistant, message: newText)
                }
            }

            if !self.streamingText.isEmpty {
                self.historyMessages.append(
                    ChatCompletionMessage(role: .assistant, content: self.streamingText)
                )
                self.streamingText = ""
            } else {
                self.historyMessages.removeLast()
            }

            if (finishReasonLength) {
                let windowSize = self.historyMessages.count
                assert(windowSize % 2 == 0)
                let removeEnd = ((windowSize + 3) / 4) * 2
                self.historyMessages.removeSubrange(0..<removeEnd)
            }

            if currentState == .generating {
                let runtimStats = finalUsageTextLabel

                DispatchQueue.main.async {
                    self.infoText = runtimStats
                    self.legacyUseImage = true // Re-enable image upload for next message
                    self.switchToReady()
                }
            }
        }
    }

    func isCurrentModel(modelID: String) -> Bool {
        return self.modelID == modelID
    }

    func loadMessages(from chat: StoredChat) {
        clearHistory()
        displayMessages = chat.messages.map { message in
            let role: MessageRole = message.role == "user" ? .user : .assistant
            return MessageData(role: role, message: message.message)
        }
        historyMessages = chat.messages.map { message in
            ChatCompletionMessage(
                role: message.role == "user" ? .user : .assistant,
                content: message.message
            )
        }
        needsSaving = false
        isLoadedChat = true
    }

    func deloadModelFromChat() {
        self.mainDeloadModel()
    }
}

private extension ChatState {
    func setModelChatState(_ newModelChatState: ChatModelState) {
        modelChatStateLock.lock()
        defer { modelChatStateLock.unlock() }

        DispatchQueue.main.async {
            self.currentState = newModelChatState
        }
    }

    func appendMessage(role: MessageRole, message: String) {
        displayMessages.append(MessageData(role: role, message: message))
        needsSaving = true
    }

    func updateMessage(role: MessageRole, message: String) {
        displayMessages[displayMessages.count - 1] = MessageData(role: role, message: message)
        needsSaving = true
    }

    func clearHistory() {
        displayMessages.removeAll()
        infoText = ""
        historyMessages.removeAll()
        streamingText = ""
        needsSaving = true
    }

    func switchToResetting() {
        setModelChatState(.resetting)
    }

    func switchToGenerating() {
        setModelChatState(.generating)
    }

    func switchToReloading() {
        setModelChatState(.reloading)
    }

    func switchToReady() {
        setModelChatState(.ready)
    }

    func switchToTerminating() {
        setModelChatState(.terminating)
    }

    func switchToFailed() {
        setModelChatState(.failed)
    }

    func switchToPendingImageUpload() {
        setModelChatState(.pendingImageUpload)
    }

    func switchToProcessingImage() {
        setModelChatState(.processingImage)
        DispatchQueue.main.async {
            // Keep image upload disabled during processing
            self.legacyUseImage = false
            // Give UI time to update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.switchToReady()
            }
        }
    }

    func interruptChat(prologue: () -> Void, epilogue: @escaping () -> Void) {
        assert(isInterruptible)
        if currentState == .ready
            || currentState == .failed
            || currentState == .pendingImageUpload {
            prologue()
            epilogue()
        } else if currentState == .generating {
            prologue()
            DispatchQueue.main.async {
                epilogue()
            }
        } else {
            assert(false)
        }
    }

    private func mainResetChat() async {
        await engine.reset()
        self.historyMessages = []
        self.streamingText = ""

        DispatchQueue.main.async {
            self.clearHistory()
        }
    }

    private func mainDeloadModel() {
        Task {
            await engine.unload()
            DispatchQueue.main.async {
                self.modelID = ""
                self.modelLib = ""
                self.modelPath = ""
                self.switchToReady()
            }
        }
    }

    func mainTerminateChat(callback: @escaping () -> Void) {
        Task {
            await engine.unload()
            DispatchQueue.main.async {
                self.clearHistory()
                self.modelID = ""
                self.modelLib = ""
                self.modelPath = ""
                self.displayName = ""
                // Only reset legacyUseImage when completely terminating chat
                self.legacyUseImage = true
                self.switchToReady()
                callback()
            }
        }
    }

    func mainReloadChat(modelID: String, modelLib: String, modelPath: String, estimatedVRAMReq: Int, displayName: String) {
        print("Starting mainReloadChat for model: \(modelID)")
        clearHistory()
        self.modelID = modelID
        self.modelLib = modelLib
        self.modelPath = modelPath
        self.displayName = displayName

        Task {
            print("Unloading engine")
            await engine.unload()

            let vRAM = os_proc_available_memory()
            if (vRAM < estimatedVRAMReq) {
                let requiredMemory = String(
                    format: "%.1fMB", Double(estimatedVRAMReq) / Double(1 << 20)
                )
                let errorMessage = (
                    "Sorry, the system cannot provide \(requiredMemory) VRAM as requested to the app, " +
                    "so we cannot initialize this model on this device."
                )
                DispatchQueue.main.async {
                    self.displayMessages.append(MessageData(role: MessageRole.assistant, message: errorMessage))
                    self.switchToFailed()
                }
                return
            }

            print("Reloading engine with new model")
            await engine.reload(
                modelPath: modelPath, modelLib: modelLib
            )

            print("Testing model with empty prompt")
            for await _ in await engine.chat.completions.create(
                messages: [ChatCompletionMessage(role: .user, content: "")],
                max_tokens: 1
            ) {}

            print("Model test complete, switching to ready state")
            DispatchQueue.main.async {
                self.switchToReady()
            }
        }
    }

}
