//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebTextArea.h"


@class SVBodyElement;
@protocol SVElementController <NSObject>
- (SVBodyElement *)bodyElement;
- (DOMHTMLElement *)HTMLElement;
@end


@class SVPageletBody;


@interface SVBodyTextArea : SVWebTextArea <DOMEventListener>
{
    NSArrayController   *_content;
    
    NSMutableArray  *_elementControllers;
    
    BOOL    _isUpdating;    
}

- (id)initWithHTMLElement:(DOMHTMLElement *)element content:(NSArrayController *)content;


#pragma mark Content
@property(nonatomic, retain, readonly) NSArrayController *content;
- (void)contentElementsDidChange;


#pragma mark Subcontrollers

- (void)addElementController:(id <SVElementController>)controller;
- (void)removeElementController:(id <SVElementController>)controller;

- (id <SVElementController>)makeAndAddControllerForBodyElement:(SVBodyElement *)element
                                                   HTMLElement:(DOMHTMLElement *)element;

- (id <SVElementController>)controllerForBodyElement:(SVBodyElement *)element;
- (id <SVElementController>)controllerForHTMLElement:(DOMHTMLElement *)element;


#pragma mark Updates

// Use these methods to temporarily suspend observation while updating model or view otherwise we get in an infinite loop
@property(nonatomic, readonly, getter=isUpdating) BOOL updating;
- (void)willUpdate;
- (void)didUpdate;

@end


#import "SVWebContentItem.h"
@interface SVWebContentItem (SVElementController) <SVElementController>
@end