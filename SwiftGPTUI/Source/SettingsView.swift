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
    
    @State
    private var models = [Model.gpt3_5Turbo]
        
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
                Section("Settings") {
                    TextField("System prompt", text: settings.$systemPrompt, axis: .vertical)
                        .onSubmit {
                            dismiss()
                        }
                    
                    Picker(selection: settings.$model) {
                        ForEach(models, id: \.self) {
                            Text($0.uppercased()).tag($0)
                        }
                    } label: {
                        Text("Model")
                            .bold()
                    }
                    DisclosureGroup {
                        ParameterView(title: "Temperature", bounds: 0...1, value: settings.$temperature)
                        ParameterView(title: "Top P", bounds: 0...1, value: settings.$topP)
                        ParameterView(title: "Frequency penalty", bounds: -2...2, value: settings.$frequencyPenalty)
                        ParameterView(title: "Presence penalty", bounds: -2...2, value: settings.$presencePenalty)
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
            } message: {
                Text("Please confirm if you would like to reset your conversation history.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(!settings.isKeyValid)
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(!settings.isKeyValid)
        .task {
            do {
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                request.addValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
                let (data, _) = try await URLSession.shared.data(for: request)
                let result = try JSONDecoder().decode(_Model._Container.self, from: data)
                let models = result.data.filter { model in
                    [
                        Model.gpt3_5Turbo,
                        Model.gpt3_5Turbo0301,
                        Model.gpt4,
                        Model.gpt4_0134,
                        Model.gpt4_32k,
                        Model.gpt4_32k_0314
                    ].contains {
                        $0 == model.id
                    }
                }
                .map {
                    $0.id
                }
                self.models = models
            } catch {
                print(error)
            }
        }
    }
}
