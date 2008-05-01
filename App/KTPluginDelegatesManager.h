//
//  KTPluginDelegatesManager.h
//  Marvel
//
//  Created by Mike on 08/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class KTAbstractElement, KTAbstractPluginDelegate;

@interface KTPluginDelegatesManager : NSObject
{
	NSMutableDictionary		*myPluginDelegates;
}

- (KTAbstractPluginDelegate *)delegateForPlugin:(KTAbstractElement *)plugin;

@end
