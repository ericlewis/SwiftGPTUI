import SwiftUI
import OpenAI

struct ConversationSettingsView: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(\.managedObjectContext)
    private var viewContext
    
    @State
    private var isShowingResetConversationConfirmation = false
    
    @State
    private var isShowingConfirmedParamReset = false
    
    @EnvironmentObject
    private var settings: ObservableSettings
    
    @ObservedObject
    var conversation: Conversation
    
    var body: some View {
        NavigationView {
            List {
                Section("Conversation Title") {
                    TextField(
                        "Conversation Title",
                        text: $conversation.title.toUnwrapped(defaultValue: "")
                    )
                }
                Section {
                    TextField(
                        "System prompt",
                        text: $conversation.systemPrompt.toUnwrapped(defaultValue: settings.systemPrompt),
                        axis: .vertical
                    )
                    .onSubmit {
                        dismiss()
                    }
                    if settings.isLoading {
                        HStack {
                            Text("Model")
                                .bold()
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Picker(selection: settings.$model) {
                            ForEach(settings.models, id: \.self) {
                                Text($0.uppercased()).tag($0)
                            }
                        } label: {
                            Text("Model")
                                .bold()
                        }
                    }
                    DisclosureGroup {
                        ParameterView(
                            title: "Temperature",
                            bounds: 0...1,
                            value: $conversation.temperature
                        )
                        ParameterView(
                            title: "Top P",
                            bounds: 0...1,
                            value: $conversation.topP
                        )
                        ParameterView(
                            title: "Frequency penalty",
                            bounds: -2...2,
                            value: $conversation.frequencyPenalty
                        )
                        ParameterView(
                            title: "Presence penalty",
                            bounds: -2...2,
                            value: $conversation.presencePenalty
                        )
                    } label: {
                        Text("Parameters")
                            .bold()
                    }
                }
                .disabled(!settings.isKeyValid)
                
                Section {
                    Button("Reset Parameters", role: .destructive) {
                        conversation.systemPrompt = settings.systemPrompt
                        conversation.temperature = settings.temperature
                        conversation.topP = settings.topP
                        conversation.frequencyPenalty = settings.frequencyPenalty
                        conversation.presencePenalty = settings.presencePenalty
                        isShowingConfirmedParamReset = true
                    }
                    .bold()
                    Button("Reset Conversation", role: .destructive) {
                        isShowingResetConversationConfirmation.toggle()
                    }
                    .bold()
                }
                .disabled(!settings.isKeyValid)
            }
            .alert("Parameters reset to defaults", isPresented: $isShowingConfirmedParamReset) {
                Button("Okay") {}
            }
            .alert("Reset Conversation", isPresented: $isShowingResetConversationConfirmation) {
                Button("Reset", role: .destructive) {
                    resetConversationHistory()
                }
            } message: {
                Text("Please confirm if you would like to reset your conversation history.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if settings.isLoading {
                        ProgressView()
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .disabled(!settings.isKeyValid)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(!settings.isKeyValid)
        .task { await settings.updateModels() }
        .onChange(of: settings.apiKey) { _ in
            if settings.isKeyValid {
                Task {
                    await settings.updateModels()
                }
            }
        }
        .onDisappear {
            try? viewContext.save()
        }
    }
}

extension ConversationSettingsView {
    func resetConversationHistory() {
        do {
            let fetchRequest = Message.fetchRequest()
            let items = try viewContext.fetch(fetchRequest)
            for item in items {
                viewContext.delete(item)
            }
            try viewContext.save()
            dismiss()
        } catch let error as NSError {
            print(error)
        }
    }
}

extension Binding {
    func toUnwrapped<T>(defaultValue: T) -> Binding<T> where Value == Optional<T>  {
        Binding<T>(get: { self.wrappedValue ?? defaultValue }, set: { self.wrappedValue = $0 })
    }
}
