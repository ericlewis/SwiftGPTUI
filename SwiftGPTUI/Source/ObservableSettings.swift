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
    
    var isKeyValid: Bool {
        do {
            let regex = try NSRegularExpression(pattern: "sk-\\w{20}T3BlbkFJ\\w{20}", options: [])
            let matches = regex.matches(in: apiKey, options: [], range: NSRange(location: 0, length: apiKey.utf16.count))
            return !matches.isEmpty
        } catch {
            return false
        }
    }
}
