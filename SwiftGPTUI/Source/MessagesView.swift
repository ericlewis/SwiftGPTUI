import InputBarAccessoryView
import MessageKit
import SwiftUI
import CoreData
import OpenAI

final class MessageSwiftUIVC: MessagesViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        additionalBottomInset = 10
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        messagesCollectionView.scrollToLastItem(animated: true)
    }
}

struct MessagesView: UIViewControllerRepresentable {
    final class Coordinator {
        init(messages: FetchedResults<Message>, context: NSManagedObjectContext, vc: MessagesViewController) {
            self.messages = messages
            self.viewContext = context
            self.vc = vc
        }

        var vc: MessagesViewController
        var messages: FetchedResults<Message>
        var viewContext: NSManagedObjectContext
        var openAI = OpenAI(apiToken: "")
        var model: Model = Model.gpt3_5Turbo
        var systemPrompt: String?
        var temperature: Double = 0.7
        var topP: Double = 1
        var frequencyPenalty: Double = 0
        var presencePenalty: Double = 0
    }
    
    let messagesVC = MessageSwiftUIVC()
    
    @State
    private var initialized = false
    
    @Binding
    var apiKey: String
    
    @Binding
    var model: Model
    
    @Binding
    var systemPrompt: String
    
    @Binding
    var temperature: Double
    
    @Binding
    var topP: Double
    
    @Binding
    var frequencyPenalty: Double
    
    @Binding
    var presencePenalty: Double
    
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Message.sentDateInternal, ascending: true)], animation: .default)
    private var messages: FetchedResults<Message>
    
    @Environment(\.managedObjectContext)
    private var viewContext
    
    func makeUIViewController(context: Context) -> MessagesViewController {
        messagesVC.messagesCollectionView.messagesDisplayDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesLayoutDelegate = context.coordinator
        messagesVC.messagesCollectionView.messagesDataSource = context.coordinator
        messagesVC.messageInputBar.delegate = context.coordinator
        messagesVC.messageInputBar.inputTextView.placeholder = "Type a message"
        let layout = messagesVC.messagesCollectionView.collectionViewLayout as? MessagesCollectionViewFlowLayout
        layout?.setMessageOutgoingAvatarSize(.zero)
        layout?.setMessageIncomingAvatarSize(.zero)
        messagesVC.scrollsToLastItemOnKeyboardBeginsEditing = true // default false
        messagesVC.maintainPositionOnInputBarHeightChanged = true // default false
        messagesVC.showMessageTimestampOnSwipeLeft = true // default false
        return messagesVC
    }
    
    func updateUIViewController(_ uiViewController: MessagesViewController, context ctx: Context) {
        ctx.coordinator.systemPrompt = systemPrompt
        ctx.coordinator.frequencyPenalty = frequencyPenalty
        ctx.coordinator.presencePenalty = presencePenalty
        ctx.coordinator.temperature = temperature
        ctx.coordinator.topP = topP
        ctx.coordinator.openAI = OpenAI(apiToken: apiKey)
        ctx.coordinator.messages = messages
        uiViewController.messagesCollectionView.reloadData()
        scrollToBottom(uiViewController)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(messages: messages, context: viewContext, vc: messagesVC)
    }
    
    private func scrollToBottom(_ uiViewController: MessagesViewController) {
        DispatchQueue.main.async {
            uiViewController.messagesCollectionView.scrollToLastItem(animated: self.initialized)
            self.initialized = true
        }
    }
}

extension MessagesView.Coordinator: MessagesDataSource {
    var currentSender: SenderType {
        Sender(senderId: "user", displayName: "user")
    }
    
    func messageForItem(at indexPath: IndexPath, in _: MessagesCollectionView) -> MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(in _: MessagesCollectionView) -> Int {
        messages.count
    }
}

extension MessagesView.Coordinator: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        Task {
            do {
                // fire off the users message
                let message = Message(context: viewContext)
                message.messageId = UUID().uuidString
                message.sentDate = .now
                message.sentBy = currentSender.senderId
                message.text = text
                try viewContext.save()
                
                // indicate we are waiting for a response and reset input
                await vc.setTypingIndicatorViewHidden(false, animated: true)
                await MainActor.run { inputBar.inputTextView.text = "" }
                
                // assemble history and send to openai
                var history = messages.map { OpenAI.Chat(role: $0.sender.senderId, content: $0.text!) }
                
                // insert system prompt at beginning if need be
                if let systemPrompt, !systemPrompt.isEmpty {
                    history.insert(.init(role: "system", content: systemPrompt), at: 0)
                }
                
                // wala
                let query = OpenAI.ChatQuery(
                    model: model,
                    messages: history,
                    temperature: temperature,
                    topP: topP,
                    presencePenalty: presencePenalty,
                    frequencyPenalty: frequencyPenalty
                )
                let result = try await openAI.chats(query: query)
                
                // we are done typing
                await vc.setTypingIndicatorViewHidden(true, animated: true)
                
                // add result
                let choice = result.choices[0]
                let resultMessage = Message(context: viewContext)
                resultMessage.messageId = result.id
                resultMessage.sentDate = .now
                resultMessage.sentBy = choice.message.role
                resultMessage.text = choice.message.content
                try viewContext.save()
            } catch {
                print(error)
            }
        }
    }
}

extension MessagesView.Coordinator: MessagesLayoutDelegate, MessagesDisplayDelegate {}
