import Foundation
import CryptoKit

struct StoredChat: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let messages: [StoredMessage]
    var title: String
    let messageHash: String? // Made optional for backward compatibility
    let modelName: String // Made optional for backward compatibility

    struct StoredMessage: Codable {
        let role: String // "user" or "assistant"
        let message: String
    }
}

class ChatStorage: ObservableObject {
    @Published var savedChats: [StoredChat] = []
    @Published private(set) var currentChatId: UUID?

    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var chatDirectoryURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SavedChats", isDirectory: true)
    }

    init() {
        createDirectoryIfNeeded()
        loadSavedChats()
    }

    func saveChat(messages: [MessageData], isNewChat: Bool = false, currentModelName: String) -> Bool {
        guard !messages.isEmpty else { return false }

        let storedMessages = messages.map { message in
            StoredChat.StoredMessage(
                role: message.role.isUser ? "user" : "assistant",
                message: message.message
            )
        }

        // Use first user message as title, or fallback
        let title = messages.first { $0.role.isUser }?.message.prefix(50) ?? "New Chat"
        let messagesHash = createMessagesHash(messages)

        if !isNewChat, let currentId = currentChatId,
           let existingIndex = savedChats.firstIndex(where: { $0.id == currentId }) {
            print("Updating existing Chat")
            // Update existing chat
            let updatedChat = StoredChat(
                id: currentId,
                timestamp: Date(),
                messages: storedMessages,
                title: String(title),
                messageHash: messagesHash,
                modelName: currentModelName
            )

            do {
                let currentMessagesHash = savedChats[existingIndex].messageHash
                if currentMessagesHash == messagesHash {
                    return false
                }
                let data = try encoder.encode(updatedChat)
                let fileURL = chatDirectoryURL.appendingPathComponent("\(currentId.uuidString).json")
                try data.write(to: fileURL)
                savedChats[existingIndex] = updatedChat
                savedChats.sort { $0.timestamp > $1.timestamp }
                return true
            } catch {
                print("Failed to update chat: \(error)")
                return false
            }
        } else {
            // Create new chat
            let newId = UUID()
            let chat = StoredChat(
                id: newId,
                timestamp: Date(),
                messages: storedMessages,
                title: String(title),
                messageHash: messagesHash,
                modelName: currentModelName
            )

            do {
                let data = try encoder.encode(chat)
                let fileURL = chatDirectoryURL.appendingPathComponent("\(chat.id.uuidString).json")
                try data.write(to: fileURL)
                savedChats.append(chat)
                currentChatId = newId
                savedChats.sort { $0.timestamp > $1.timestamp }
                return true
            } catch {
                print("Failed to save new chat: \(error)")
                return false
            }
        }
    }

    func startNewChat() {
        currentChatId = nil
    }

    func setCurrent(chatId: UUID) {
        currentChatId = chatId
    }


    func deleteChat(_ index: IndexSet) -> Bool {
        do {
            let chat = savedChats[index.first!]
            let fileURL = chatDirectoryURL.appendingPathComponent("\(chat.id.uuidString).json")
            try fileManager.removeItem(at: fileURL)
            savedChats.removeAll(where: { $0.id == chat.id })
            return true
        } catch {
            print("Failed to delete chat: \(error)")
            return false
        }
    }

    func deleteAllChats() -> Bool {
        do {
            try fileManager.removeItem(at: chatDirectoryURL)

            // Clear in-memory chats
            savedChats.removeAll()
            currentChatId = nil
            createDirectoryIfNeeded()
            return true
        } catch {
            print("Failed to delete all chats: \(error)")
            return false
        }
    }

    private func createMessagesHash(_ messages: [MessageData]) -> String {
        // Create a string that combines all messages in a predictable way
        let messageString = messages.map { "\($0.role.isUser ? "user" : "assistant"):\($0.message)" }.joined(separator: "|")

        // Create SHA256 hash
        let messageData = messageString.data(using: .utf8)!
        let hash = SHA256.hash(data: messageData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: chatDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: chatDirectoryURL, withIntermediateDirectories: true)
            } catch {
                print("Failed to create directory: \(error)")
            }
        }
    }

    private func loadSavedChats() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: chatDirectoryURL,
                includingPropertiesForKeys: nil
            )
            savedChats = try fileURLs.compactMap { url in
                guard url.pathExtension == "json" else { return nil }
                let data = try Data(contentsOf: url)
                let chat = try decoder.decode(StoredChat.self, from: data)
                return chat
            }.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Failed to load chats: \(error)")
        }
    }
}
