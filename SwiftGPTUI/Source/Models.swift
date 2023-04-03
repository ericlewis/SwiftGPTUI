import Foundation
import MessageKit
import OpenAI

struct Sender: SenderType {
    public var senderId: String
    public var displayName: String
}

extension Message: MessageType {
    public var sender: SenderType {
        Sender(senderId: sentBy!, displayName: sentBy!)
    }
    
    public var messageId: String {
        get { messageIdInternal! }
        set { messageIdInternal = newValue }
    }
    
    public var sentDate: Date {
        get { sentDateInternal! }
        set { sentDateInternal = newValue }
    }
    
    public var kind: MessageKind {
        .text(text!)
    }
}

struct _Model: Decodable {
    struct _Container: Decodable {
        let data: [_Model]
    }
    
    let id: Model
}
