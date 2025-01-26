//
//  MessageView.swift
//  MLCChat
//

import SwiftUI
import MarkdownUI

extension Theme {
    static let customGitHub = Theme.gitHub
        .text {
            BackgroundColor(nil)  // Change text block background
        }
        .code {
            BackgroundColor(Color(.systemGray6))  // Change code block background
        }
        .codeBlock { configuration in
            configuration.label
                .padding()
                .background(Color(.systemGray6))  // Change inline code background
                .cornerRadius(8)
        }
}

struct MessageView: View {
    // Helper function to process message content
    private static func processMessage(_ text: String) -> String {
        var result = text

        // Define token patterns and their formatters
        let tokens: [(start: String, end: String, icon: String, prefix: String)] = [
            ("<think>", "</think>", "🤔", "Thinking"),
            ("<tool>", "</tool>", "🛠️", "Using Tool"),
            ("<attempt_completion>", "</attempt_completion>", "✅", "Complete"),
            ("<execute_command>", "</execute_command>", "⚡", "Execute"),
            ("<replace_in_file>", "</replace_in_file>", "📝", "Edit File"),
            ("<read_file>", "</read_file>", "📖", "Read File"),
            ("<write_to_file>", "</write_to_file>", "💾", "Write File"),
            ("<search_files>", "</search_files>", "🔍", "Search")
        ]

        // Process each token type
        for (startTag, endTag, icon, prefix) in tokens {
            // Find all start tags
            var searchRange = result.startIndex..<result.endIndex
            while let startRange = result.range(of: startTag, range: searchRange) {
                // Find the corresponding end tag after this start tag
                let afterStart = startRange.upperBound
                let endRange = result.range(of: endTag, range: afterStart..<result.endIndex)

                // Extract content between tags
                let contentStart = startRange.upperBound
                let contentEnd = endRange?.lowerBound ?? result.endIndex
                let content = String(result[contentStart..<contentEnd])

                // Format the content with a modern design
                let processedContent = content
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .map { "> \($0)" }
                    .joined(separator: "\n")

                let formattedContent = """

                    ___
                    **\(icon) \(prefix)**

                    \(processedContent)
                    ___

                    """
                 
                // Replace the entire tag block (or just the start tag and content if no end tag)
                if let end = endRange {
                    result.replaceSubrange(startRange.lowerBound..<end.upperBound, with: formattedContent)
                } else {
                    result.replaceSubrange(startRange.lowerBound..<contentEnd, with: formattedContent)
                    break // Exit since we've reached an unclosed tag
                }

                // Update search range for next iteration
                searchRange = result.index(result.startIndex, offsetBy: formattedContent.count)..<result.endIndex
            }
        }

        return result
    }

    let role: MessageRole;
    let message: String
    let isMarkdownSupported: Bool

    @State private var showMarkdown: Bool

    init(role: MessageRole, message: String, isMarkdownSupported: Bool = true) {
        self.role = role
        self.isMarkdownSupported = isMarkdownSupported
        _showMarkdown = State(initialValue: isMarkdownSupported)
        self.message = Self.processMessage(message)
    }

    var body: some View {
        HStack {
            if role.isUser {
                Spacer()
            }

            HStack(alignment: .top, spacing: 8) {
                if !role.isUser {
                    // Assistant avatar
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "sparkles")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        )
                }

                VStack(alignment: role.isUser ? .trailing : .leading, spacing: 4) {
                    if !role.isUser && isMarkdownSupported {
                        Toggle(isOn: $showMarkdown) {
                            HStack(spacing: 4) {
                                Image(systemName: showMarkdown ? "text.word.spacing" : "text.alignleft")
                                    .font(.system(size: 12))
                                Text(showMarkdown ? "Markdown" : "Plain Text")
                                    .font(.system(size: 12))
                            }
                        }
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.blue)
                    }

                    // Message content
                    Group {
                        if showMarkdown {
                            Markdown(message)
                                .markdownTheme(.customGitHub)
                                .padding(12)
                                .foregroundColor(role.isUser ? .white : .primary)
                        } else {
                            Text(message)
                                .padding(12)
                                .foregroundColor(role.isUser ? .white : .primary)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(role.isUser ? Color.blue : Color(.systemGray6))
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                }

                if role.isUser {
                    // User avatar
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.8)

            if !role.isUser {
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .id(message)
    }
}

struct ImageView: View {
    let image: UIImage

    var body: some View {
        HStack {
            Spacer()
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .padding(12)
        }
        .padding()
        .listRowSeparator(.hidden)
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    MessageView(role: MessageRole.user, message: "How can I improve my code?")
                    // Example with incomplete tag
                    MessageView(role: MessageRole.assistant, message: """
                        Let me analyze your code.

                        <think>
                        Analyzing the code structure...
                        Looking for potential improvements...
                        // This tag is intentionally left open to demonstrate handling of incomplete tags
                        """)
                    // Example with complete tags
                    MessageView(role: MessageRole.assistant, message: """
                        Here's what I found:

                        <think>
                        First, reviewing the implementation
                        </think>

                        <read_file>
                        <path>src/main.swift</path>
                        </read_file>

                        Here are my suggestions...
                        """)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
