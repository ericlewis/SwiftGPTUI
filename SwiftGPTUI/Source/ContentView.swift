import SwiftUI
import OpenAI

struct ContentView: View {
    @State
    private var isShowingSettings = false
    
    @AppStorage("OPENAI_KEY")
    private var apiKey = ""
    
    @AppStorage("OPENAI_MODEL")
    private var model = Model.gpt3_5Turbo
    
    @AppStorage("OPENAI_SYSTEM_PROMPT")
    private var systemPrompt = ""
    
    var isKeyValid: Bool {
        do {
            let regex = try NSRegularExpression(pattern: "sk-\\w{20}T3BlbkFJ\\w{20}", options: [])
            let matches = regex.matches(in: apiKey, options: [], range: NSRange(location: 0, length: apiKey.utf16.count))
            return !matches.isEmpty
        } catch {
            return false
        }
    }
    
    var body: some View {
        NavigationView {
            MessagesView(apiKey: $apiKey, model: $model, systemPrompt: $systemPrompt)
                .edgesIgnoringSafeArea(.all)
                .navigationTitle(model.uppercased())
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    Button {
                        isShowingSettings.toggle()
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView(systemPrompt: $systemPrompt, apiKey: $apiKey, model: $model)
                }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            isShowingSettings = !isKeyValid
        }
    }
}
