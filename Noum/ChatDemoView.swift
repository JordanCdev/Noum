// ChatDemoView.swift
// Minimal demo UI to exercise AINPCChatService streaming

import SwiftUI

struct ChatDemoView: View {
    @StateObject private var chat = AINPCChatService()
    @State private var input: String = "Hello! Give me a one-sentence pep talk."
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 12) {
            Text("AI Chat Demo")
                .font(.title3.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                Text(chat.streamedText.isEmpty ? "(No reply yet)" : chat.streamedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxHeight: 240)

            HStack(spacing: 10) {
                TextField("Type your message", text: $input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)

                Button {
                    Task {
                        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        isSending = true
                        await chat.sendStreaming(input)
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Send")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
        .padding()
        .navigationTitle("Chat Demo")
    }
}

#Preview {
    ChatDemoView()
}
