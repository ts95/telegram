//
//  SelectUsersTableView.m
//  Messenger for Telegram
//
//  Created by keepcoder on 21.05.14.
//  Copyright (c) 2014 keepcoder. All rights reserved.
//

#import "SelectUsersTableView.h"
#import "NSString+Extended.h"
#import "TMSearchTextField.h"
#import "TGSearchRowView.h"
#import "SelectChatItem.h"
#import "SelectChatRowView.h"

@interface SelectUsersTableView ()<TMSearchTextFieldDelegate>
@property (nonatomic,strong) NSMutableArray *items;
@property (nonatomic,strong) TGSearchRowView *searchView;
@property (nonatomic,strong) TGSearchRowItem *searchItem;
@property (nonatomic,strong) RPCRequest *request;
@end

@implementation SelectUsersTableView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _selectLimit = 1;
        _type = SelectTableTypeUser;
    }
    return self;
}

static NSCache *cacheItems;

+(void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cacheItems = [[NSCache alloc] init];
    });
}



-(void)readyContacts {
    
    _type = SelectTableTypeUser;
    
    NSArray *contacts = [[NewContactsManager sharedManager] all];
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    contacts = [contacts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT(self.user_id IN %@ AND (self.user.flags & 1 << 16) == 0)",self.exceptions]];
    
    
    
    
    [contacts enumerateObjectsUsingBlock:^(TLContact *obj, NSUInteger idx, BOOL *stop) {
        
        SelectUserItem *item = [[SelectUserItem alloc] initWithObject:obj.user];
        item.isSelected = [_selectedItems indexOfObject:@(obj.user.n_id)] != NSNotFound;
        [items addObject:item];
        
        if(items.count == 30)
            *stop = YES;
    }];
    
    
    [items filterUsingPredicate:[NSPredicate predicateWithFormat:@"self.user.n_id != %d",[UsersManager currentUserId]]];
    
    
    
    self.tm_delegate = self;
    
    [self removeAllItems:NO];
    
    self.items = items;
    
    self.searchItem = [[TGSearchRowItem alloc] init];
    
    self.searchView = [[TGSearchRowView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(self.bounds), 50)];
    
    [self insert:self.searchItem atIndex:0 tableRedraw:NO];
    
    [self insert:self.items startIndex:1 tableRedraw:NO];
    
    
    [self reloadData];
    
    if(contacts.count > 30)
        dispatch_after_seconds(0.3, ^{
            [self insertOther:[contacts subarrayWithRange:NSMakeRange(30, contacts.count - 30)]];
        });
    
}


-(void)readyChats {
    
    
    _type = SelectTableTypeChats;
    
    NSArray *chats = [[[DialogsManager sharedManager] all] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.type == %d",DialogTypeChat]];
    
    
    NSMutableArray *items = [[NSMutableArray alloc] init];
    
    [chats enumerateObjectsUsingBlock:^(TL_conversation * obj, NSUInteger idx, BOOL *stop) {
        
        [items addObject:[[SelectChatItem alloc] initWithObject:obj.chat]];
        
    }];
    
    
    self.tm_delegate = self;
    
    [self removeAllItems:NO];
    
    self.items = items;
    
    self.searchItem = [[TGSearchRowItem alloc] init];
    
    self.searchView = [[TGSearchRowView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(self.bounds), 50)];
    
    [self insert:self.searchItem atIndex:0 tableRedraw:NO];
    
    [self insert:self.items startIndex:1 tableRedraw:NO];
    
    
    [self reloadData];
    
}

-(void)insertOther:(NSArray *)other {
    
    [ASQueue dispatchOnMainQueue:^{
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        [other enumerateObjectsUsingBlock:^(TL_contact *obj, NSUInteger idx, BOOL *stop) {
            
             SelectUserItem *item = [[SelectUserItem alloc] initWithObject:obj.user];
             item.isSelected = [_selectedItems indexOfObject:@(obj.user_id)] != NSNotFound;
             [items addObject:item];
            
        }];
        
        [[ASQueue mainQueue] dispatchOnQueue:^{
            [self.items addObjectsFromArray:items];
            [self insert:items startIndex:self.count tableRedraw:NO];
            [self reloadData];
        }];
    }];
    
    
}

- (void)setSelectLimit:(NSUInteger)selectLimit {
    self->_selectLimit = selectLimit;
    NSUInteger count = self.count;
    
    NSArray *copy;
    
    if(self.list.count > 0) {
        if([self.list[0] isKindOfClass:[TGSearchRowItem class]]) {
            copy = [self.list subarrayWithRange:NSMakeRange(1, self.list.count-1)];
        } else {
            copy = [self.list copy];
        }
    } else {
        copy = [self.list copy];
    }
    
    
    for (SelectUserItem *item in copy) {
        item.isSelected = NO;
    }
    
    [self cancelSelection];
    
    for(int i = 1; i < count; i++) {
        SelectUserRowView *cell = (SelectUserRowView *)[self viewAtColumn:0 row:i makeIfNecessary:NO];;
        [cell needUpdateSelectType];
    }
}

- (void)setExceptions:(NSArray *)exceptions {
    self->_exceptions = exceptions;
    
    if(self.list) {
        for (NSNumber *exception in exceptions) {
            
            NSArray *copy;
            
            if(self.list.count > 0) {
                if([self.list[0] isKindOfClass:[TGSearchRowItem class]]) {
                   copy = [self.list subarrayWithRange:NSMakeRange(1, self.list.count-1)];
                } else {
                    copy = [self.list copy];
                }
            } else {
                copy = [self.list copy];
            }
            
            [copy enumerateObjectsUsingBlock:^(SelectUserItem * obj, NSUInteger idx, BOOL *stop) {
                if(obj.user.n_id == [exception intValue]) {
                    [self removeItem:obj];
                    [self.items removeObject:obj];
                    *stop = YES;
                }
            }];
        }
    }
    
}

- (BOOL) selectionWillChange:(NSInteger)row item:(SelectUserItem *) item {
    return self.selectLimit == 0;
}

- (void)selectionDidChange:(NSInteger)row item:(SelectUserItem *)item {
    
    [self.selectDelegate selectTableDidChangedItem:item];
    
    if(self.multipleCallback != nil) {
        self.multipleCallback(@[item.user]);
    }
    
}


-(BOOL)isSelectable:(NSInteger)row item:(TMRowItem *)item {
    return YES;
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.count;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return YES;
}


-(BOOL)canSelectItem {
    return self.selectLimit > self.selectedItems.count || self.selectLimit == 0;
}

-(NSArray *)selectedItems {
    NSMutableArray *selected = [[NSMutableArray alloc] init];
    for (SelectUserItem *item in self.items) {
        if(item.isSelected) {
            [selected addObject:item];
        }
    }
    
    return selected;
}



- (CGFloat) rowHeight:(NSUInteger)row item:(TMRowItem *)item {
    return row == 0 ? 50 : 50;
}


- (TMRowView *)viewForRow:(NSUInteger)row item:(TMRowItem *)item {
    
    Class itemClass = [item isKindOfClass:[SelectUserItem class]] ? [SelectUserRowView class] : [SelectChatRowView class] ;
    
    return row == 0 ? self.searchView : [self cacheViewForClass:itemClass identifier:NSStringFromClass(itemClass) withSize:NSMakeSize(NSWidth(self.frame), 50)];
}

-(void)searchFieldTextChange:(NSString *)searchString {
    if(_type == SelectTableTypeUser)
        [self searchUsers:searchString];
    else
        if(_type == SelectTableTypeChats)
            [self searchChats:searchString];
}


-(void)searchChats:(NSString *)searchString {
    
    NSArray *sorted = self.items;
    
    
    if(searchString.length > 0) {
        sorted = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SelectChatItem *evaluatedObject, NSDictionary *bindings) {
            
            return [evaluatedObject.chat.title searchInStringByWordsSeparated:searchString];
            
        }]];
    }
    
    
    NSRange range = NSMakeRange(1, self.list.count-1);
    
    NSArray *list = [self.list subarrayWithRange:range];
    
    [list enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeItem:obj tableRedraw:NO];
    }];
    
    [self removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] withAnimation:self.defaultAnimation];
    
    
    [self insert:sorted startIndex:1 tableRedraw:YES];
    
}

- (void)searchUsers:(NSString *)searchString {

    __block NSArray *sorted = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.user.n_id != %d",[UsersManager currentUserId]]];
    
    
    if(searchString.length > 0) {
        
        
        if([searchString hasPrefix:@"@"])
            searchString = [searchString substringFromIndex:1];
        
        sorted = [sorted filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SelectUserItem *evaluatedObject, NSDictionary *bindings) {
            
            return [[evaluatedObject.user fullName] searchInStringByWordsSeparated:searchString];
            
        }]];
    }
    
    
    
    
    NSRange range = NSMakeRange(1, self.list.count-1);
    
    NSArray *list = [self.list subarrayWithRange:range];
    
    [list enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self removeItem:obj tableRedraw:NO];
    }];
    
    [self removeRowsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:range] withAnimation:self.defaultAnimation];
    
    
    [self insert:sorted startIndex:1 tableRedraw:YES];
    
    
    [_request cancelRequest];
   
    dispatch_after_seconds(0.2, ^{
        [self remoteSearchByUserName:searchString];
    });
    
}


-(void)remoteSearchByUserName:(NSString *)userName {
    
    if(userName.length > 4) {
        _request = [RPCRequest sendRequest:[TLAPI_contacts_search createWithQ:userName limit:100] successHandler:^(RPCRequest *request, TL_contacts_found *response) {
                        
            NSMutableArray *converted = [[NSMutableArray alloc] init];
            
            
            NSMutableArray *ids = [[NSMutableArray alloc] init];
            
            [_items enumerateObjectsUsingBlock:^(SelectUserItem *obj, NSUInteger idx, BOOL *stop) {
                [ids addObject:@(obj.user.n_id)];
            }];
            
            NSArray *filtred = [response.users filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT(self.n_id IN %@)",ids]];
            
            [filtred enumerateObjectsUsingBlock:^(TLUser *obj, NSUInteger idx, BOOL *stop) {
                
                [obj rebuildNames];
                
               // if([obj isKindOfClass:[TL_userContact class]]) {
                
                SelectUserItem *item = [[SelectUserItem alloc] initWithObject:obj];
                item.isSearchUser = YES;
                [converted addObject:item];
              //  }
                
            }];
            
            if(converted.count > 0) {
                [self.items insertObjects:converted atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, converted.count)]];
                
                [self insert:converted startIndex:self.count tableRedraw:YES];
            }
            
            
        } errorHandler:^(RPCRequest *request, RpcError *error) {
            
            
        }];
    }
   
}


-(BOOL)isGroupRow:(NSUInteger)row item:(TMRowItem *)item {
    return NO;
}


- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    // Drawing code here.
}

@end
