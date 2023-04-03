import SwiftUI
import OpenAI

struct ContentView: View {
    @State
    private var isShowingSettings = false
    
    @StateObject
    private var settings = ObservableSettings()
    
    var body: some View {
        NavigationView {
            MessagesView()
            .edgesIgnoringSafeArea(.all)
            .navigationTitle(settings.model.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {
                    isShowingSettings.toggle()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            isShowingSettings = !settings.isKeyValid
        }
        .task {
            do {
                let (_, response) = try await settings.fetchModels()
                if ((response as? HTTPURLResponse)?.statusCode ?? 500) > 399 {
                    isShowingSettings = true
                }
            } catch {
                isShowingSettings = true
            }
        }
        .environmentObject(settings)
    }
}
