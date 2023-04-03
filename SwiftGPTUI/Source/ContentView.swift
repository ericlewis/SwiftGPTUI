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
    
    @AppStorage("OPENAI_TEMP")
    private var temperature = 0.7
    
    @AppStorage("OPENAI_TOP_P")
    private var topP = 1.0
    
    @AppStorage("OPENAI_FREQ_PEN")
    private var frequencyPenalty = 0.0
    
    @AppStorage("OPENAI_PRES_PEN")
    private var presencePenalty = 0.0
    
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
            MessagesView(
                apiKey: $apiKey,
                model: $model,
                systemPrompt: $systemPrompt,
                temperature: $temperature,
                topP: $topP,
                frequencyPenalty: $frequencyPenalty,
                presencePenalty: $presencePenalty
            )
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
                SettingsView(
                    temperature: $temperature,
                    topP: $topP,
                    frequencyPenalty: $frequencyPenalty,
                    presencePenalty: $presencePenalty,
                    systemPrompt: $systemPrompt,
                    apiKey: $apiKey,
                    model: $model
                )
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            isShowingSettings = !isKeyValid
        }
        .task {
            do {
                var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                let (_, response) = try await URLSession.shared.data(for: request)
                if ((response as? HTTPURLResponse)?.statusCode ?? 500) > 399 {
                    isShowingSettings = true
                }
            } catch {
                isShowingSettings = true
            }
        }
    }
}
