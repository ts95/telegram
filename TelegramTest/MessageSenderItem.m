//
//  MessageSendItem.m
//  Messenger for Telegram
//
//  Created by keepcoder on 17.03.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "MessageSenderItem.h"
#import "TLPeer+Extensions.h"
#import "MessageTableItem.h"
@interface MessageSenderItem ()
@property (nonatomic,assign) BOOL noWebpage;
@end

@implementation MessageSenderItem


-(id)initWithMessage:(NSString *)message forConversation:(TL_conversation *)conversation noWebpage:(BOOL)noWebpage {
    
    if(self = [super initWithConversation:conversation]) {
        
        self.message = [MessageSender createOutMessage:message media:[TL_messageMediaEmpty create] conversation:conversation];
        
        if(noWebpage)
            self.message.media = [TL_messageMediaWebPage createWithWebpage:[TL_webPageEmpty createWithN_id:0]];
        
        [self.message save:YES];
    
    }

    return self;
}

-(id)initWithMessage:(NSString *)message forConversation:(TL_conversation *)conversation {
    if(self = [self initWithMessage:message forConversation:conversation noWebpage:YES]) {
        
    }
    
    return self;
}


-(SendingQueueType)sendingQueue {
    return SendingQueueMessage;
}

-(void)performRequest {
    
    id request;
    
    if(self.conversation.type != DialogTypeBroadcast) {
        
        int flags = self.message.reply_to_msg_id != 0 ? 1 : 0;
        
        flags|=[self.message.media.webpage isKindOfClass:[TL_webPageEmpty class]] ? 2 : 0;
        
        
        request = [TLAPI_messages_sendMessage createWithFlags:flags peer:[self.conversation inputPeer] reply_to_msg_id:self.message.reply_to_msg_id message:[self.message message] random_id:[self.message randomId] reply_markup:[TL_replyKeyboardMarkup createWithFlags:0 rows:[@[]mutableCopy]]];
    } else {
        
        TL_broadcast *broadcast = self.conversation.broadcast;
        
        request = [TLAPI_messages_sendBroadcast createWithContacts:[broadcast inputContacts] random_id:[broadcast generateRandomIds] message:self.message.message media:[TL_inputMediaEmpty create]];
    }
    
    self.rpc_request = [RPCRequest sendRequest:request successHandler:^(RPCRequest *request, TL_messages_sentMessage * response) {
        
        
        if(self.conversation.type != DialogTypeBroadcast)  {
            
            self.message.n_id = response.n_id;
            self.message.date = response.date;
            self.message.media = response.media;
            
            
        }
        
        self.message.dstate = DeliveryStateNormal;
        
        [self.message save:YES];
        
        self.state = MessageSendingStateSent;
        
        if([self.message.media isKindOfClass:[TL_messageMediaWebPage class]])
        {
            [Notification perform:UPDATE_WEB_PAGE_ITEMS data:@{KEY_MESSAGE_ID_LIST:@[@(self.message.n_id)]}];
        }

        
    } errorHandler:^(RPCRequest *request, RpcError *error) {
        self.state = MessageSendingStateError;
    }];
    
}



-(void)resend {
    
}

@end
