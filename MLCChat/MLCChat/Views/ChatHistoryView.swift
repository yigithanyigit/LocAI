import SwiftUI

// MARK: - Private Components
private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Chat History")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - History List Components
private struct HistoryList: View {
    let chats: [StoredChat]
    let currentChatId: UUID?
    let onSelect: (StoredChat) -> Void
    let onDelete: (IndexSet) -> Void

    // Nested but fileprivate to allow access within the struct
    fileprivate struct ChatItemView: View {
        let chat: StoredChat
        let isSelected: Bool
        let onSelect: () -> Void

        // Explicitly declare initializer as fileprivate
        fileprivate init(chat: StoredChat, isSelected: Bool, onSelect: @escaping () -> Void) {
            self.chat = chat
            self.isSelected = isSelected
            self.onSelect = onSelect
        }

        private var dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }()

        var body: some View {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: 12) {
                    // Chat icon with background
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
                            .frame(width: 40, height: 40)

                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .font(.system(size: 16))
                    }

                    // Chat details
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chat.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            Text(chat.modelName)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6))
                                )
                        }

                        HStack {
                            Text(dateFormatter.string(from: chat.timestamp))
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            Spacer()

                            Label("\(chat.messages.count)", systemImage: "message")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .listRowBackground(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
        }
    }

    var body: some View {
        List {
            ForEach(chats) { chat in
                ChatItemView(
                    chat: chat,
                    isSelected: chat.id == currentChatId,
                    onSelect: { onSelect(chat) }
                )
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Main View
public struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var chatState: ChatState
    @EnvironmentObject private var chatStorage: ChatStorage
    @Binding var showModelSelect: Bool

    @State private var showDeleteConfirmation = false
    @State private var selectedChat: StoredChat?

    public init(showModelSelect: Binding<Bool>) {
        self._showModelSelect = showModelSelect
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete All")
                }
                .foregroundColor(.red)
            }
            .disabled(chatStorage.savedChats.isEmpty)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .bold()
            }
        }
    }

    public var body: some View {
        NavigationView {
            Group {
                if chatStorage.savedChats.isEmpty {
                    EmptyHistoryView()
                } else {
                    HistoryList(
                        chats: chatStorage.savedChats,
                        currentChatId: chatStorage.currentChatId,
                        onSelect: selectChat,
                        onDelete: { _ = chatStorage.deleteChat($0) }
                    )
                }
            }
            .navigationTitle("Chat History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .alert("Are you sure?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    _ = chatStorage.deleteAllChats()
                    chatState.requestResetChat(chatStorage: chatStorage)
                    dismiss()
                }
            } message: {
                Text("This will delete all chat history.")
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onDisappear {
            // If there's a selected chat and model selection was shown
            // and then dismissed, load the chat
            if let chat = selectedChat, !showModelSelect {
                selectedChat = nil
                chatStorage.setCurrent(chatId: chat.id)
                chatState.loadMessages(from: chat)
            }
        }
    }

    private func selectChat(_ chat: StoredChat) {
        // Store the selected chat
        selectedChat = chat
        
        chatStorage.setCurrent(chatId: chat.id)
        chatState.loadMessages(from: chat)
        selectedChat = nil
        dismiss()
    }
}

// MARK: - Preview
struct ChatHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ChatHistoryView(showModelSelect: .constant(false))
    }
}
