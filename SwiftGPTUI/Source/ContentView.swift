import SwiftUI
import OpenAI

struct ContentView: View {
    @State
    private var isShowingSettings = false
    
    @State
    private var isShowingConversationSettings = false
    
    @State
    private var selection: Conversation?
    
    @StateObject
    private var settings = ObservableSettings()
    
    @Environment(\.managedObjectContext)
    private var viewContext
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.updatedAt, ascending: false)], animation: .default)
    private var conversations: FetchedResults<Conversation>
    
    func removeConversation(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            viewContext.delete(conversation)
        }
        try? viewContext.save()
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(conversations) { convo in
                    NavigationLink(value: convo) {
                        VStack(alignment: .leading) {
                            Text(convo.title ?? convo.conversationId ?? "Unknown")
                                .lineLimit(1)
                                .font(.headline)
                            Text(convo.updatedAt ?? .now, format: .relative(presentation: .named))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: removeConversation)
            }
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .toolbar {
                ToolbarItem(placement: .status) {
                    HStack {
                        Button {
                            isShowingSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        .buttonStyle(.bordered)
                        Button {
                            selection = Conversation(context: viewContext)
                            selection?.conversationId = UUID().uuidString
                            selection?.title = selection?.conversationId
                            selection?.updatedAt = .now
                            selection?.frequencyPenalty = settings.frequencyPenalty
                            selection?.presencePenalty = settings.frequencyPenalty
                            selection?.temperature = settings.temperature
                            selection?.topP = settings.topP
                            selection?.model = settings.model
                            selection?.systemPrompt = settings.systemPrompt
                            try? viewContext.save()
                        } label: {
                            Label("New Conversation", systemImage: "plus")
                        }
                    }
                    .bold()
                    .labelStyle(.titleAndIcon)
                    .buttonBorderShape(.capsule)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                ToolbarItem {
                    EditButton()
                }
            }
        } detail: {
            if let selection {
                MessagesView(conversation: $selection)
                    .edgesIgnoringSafeArea(.bottom)
                    .navigationTitle(selection.title ?? selection.conversationId ?? "Unknown")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem {
                            Button {
                                isShowingConversationSettings = true
                            } label: {
                                Label("Conversation Settings", systemImage: "info.circle")
                            }
                        }
                    }
                    .sheet(isPresented: $isShowingConversationSettings) {
                        ConversationSettingsView(conversation: selection)
                    }
                    .onAppear {
                        try? viewContext.save()
                    }
            } else {
                Text("Create a new conversation.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
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
