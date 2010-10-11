//
//  SVBannerPickerController.m
//  Sandvox
//
//  Created by Mike on 23/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBannerPickerController.h"

#import "KTMaster.h"

#import "KSInspectorViewController.h"


@implementation SVBannerPickerController

#pragma mark Banner Type

- (NSNumber *)fillType;
{
    NSNumber *result = [super fillType];
    
    // Ugly hack, but it works. Pretend design-supplied is selected when design doesn't support it
    if (![self canChooseBannerType])
    {
        result = nil;
    }
    
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingFillType;
{
    return [NSSet setWithObject:@"canChooseBannerType"];
}

@synthesize canChooseBannerType = _canChooseBannerType;
- (void)setNilValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"canChooseBannerType"])
    {
        [self setCanChooseBannerType:NO];
    }
    else
    {
        [super setNilValueForKey:key];
    }
}

- (BOOL)setFileWithURL:(NSURL *)URL;
{
    KTMaster *master = [[oInspectorViewController inspectedObjectsController]
                        valueForKeyPath:@"selection.master"];
    
    [master setBannerWithContentsOfURL:URL];
    
    return YES;
}

@end
