import SwiftUI
import OpenAI

class ObservableSettings: ObservableObject {
    @AppStorage("OPENAI_KEY")
    var apiKey = ""
    
    @AppStorage("OPENAI_MODEL")
    var model = Model.gpt3_5Turbo
    
    @AppStorage("OPENAI_SYSTEM_PROMPT")
    var systemPrompt = ""
    
    @AppStorage("OPENAI_TEMP")
    var temperature = 0.7
    
    @AppStorage("OPENAI_TOP_P")
    var topP = 1.0
    
    @AppStorage("OPENAI_FREQ_PEN")
    var frequencyPenalty = 0.0
    
    @AppStorage("OPENAI_PRES_PEN")
    var presencePenalty = 0.0
    
    @Published
    var models = [Model.gpt3_5Turbo]
    
    @Published
    var isLoading = false
    
    var isKeyValid: Bool {
        do {
            let regex = try NSRegularExpression(pattern: "sk-\\w{20}T3BlbkFJ\\w{20}", options: [])
            let matches = regex.matches(in: apiKey, options: [], range: NSRange(location: 0, length: apiKey.utf16.count))
            return !matches.isEmpty
        } catch {
            return false
        }
    }
    
    func fetchModels() async throws -> (Data, URLResponse) {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return try await URLSession.shared.data(for: request)
    }
    
    func updateModels() async {
        await MainActor.run { isLoading = true }
        do {
            let (data, _) = try await fetchModels()
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
            await MainActor.run {
                self.models = models
            }
        } catch {
            print(error)
        }
        await MainActor.run { isLoading = false }
    }
}
