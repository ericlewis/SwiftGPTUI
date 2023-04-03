import SwiftUI
import OpenAI

struct ParameterView<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
    let title: LocalizedStringKey
    let bounds: ClosedRange<Value>
    
    @Binding
    var value: Value
    
    var body: some View {
        Text(title).badge(Text(Double(value), format: .number))
        Slider(value: $value, in: bounds, step: 0.1)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(\.managedObjectContext)
    private var viewContext
    
    @State
    private var isShowingResetConversationConfirmation = false
        
    @EnvironmentObject
    private var settings: ObservableSettings

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        TextField("API Key", text: settings.$apiKey)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                        Image(systemName: settings.isKeyValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(settings.isKeyValid ? .green : .red)
                    }
                } footer: {
                    Text("**API key is required.** It is stored locally and is used only and directly with OpenAI. You can sign up for a developer account [here](https://platform.openai.com) in order to create a key.")
                }
                .disabled(false)
                Section("Settings") {
                    TextField("System prompt", text: settings.$systemPrompt, axis: .vertical)
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
                            value: settings.$temperature
                        )
                        ParameterView(
                            title: "Top P",
                            bounds: 0...1,
                            value: settings.$topP
                        )
                        ParameterView(
                            title: "Frequency penalty",
                            bounds: -2...2,
                            value: settings.$frequencyPenalty
                        )
                        ParameterView(
                            title: "Presence penalty",
                            bounds: -2...2,
                            value: settings.$presencePenalty
                        )
                    } label: {
                        Text("Parameters")
                            .bold()
                    }
                }
                .disabled(!settings.isKeyValid)

                Section {
                    Button("Reset Conversation", role: .destructive) {
                        isShowingResetConversationConfirmation.toggle()
                    }
                    .bold()
                }
                .disabled(!settings.isKeyValid)

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
    }
}

extension SettingsView {
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
