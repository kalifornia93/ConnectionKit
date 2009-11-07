//
//  SVInspectorWindowController.m
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspector.h"
#import "SVInspectorViewController.h"

#import "KSTabViewController.h"


@implementation SVInspector

+ (void)initialize
{
    [self exposeBinding:@"inspectedPagesController"];
}

@synthesize inspectedPagesController = _inspectedPagesController;
- (void)setInspectedPagesController:(NSObjectController *)controller
{
    [[[self inspectorTabsController] viewControllers] setValue:controller
                                                        forKey:@"inspectedPagesController"];
}

- (void)setInspectedWindow:(NSWindow *)window
{
    if ([self inspectedWindow])
    {
        [self unbind:@"inspectedPagesController"];
    }
    
    [super setInspectedWindow:window];
    
    if (window)
    {
        [self bind:@"inspectedPagesController"
          toObject:window
       withKeyPath:@"windowController.siteOutlineViewController.pagesController"
           options:nil];
    }
}

- (NSArray *)defaultInspectorViewControllers;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:3];
    
    
    // Document
    SVInspectorViewController *documentInspector = [[SVInspectorViewController alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [documentInspector setIcon:[NSImage imageNamed:@"emptyDoc"]];
    [documentInspector bind:@"inspectedDocument"
                   toObject:self
                withKeyPath:@"inspectedWindow.windowController.document"
                    options:nil];
    [documentInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:documentInspector atIndex:0];
    [documentInspector release];
    
    
    // Page
    SVInspectorViewController *pageInspector = [[SVInspectorViewController alloc] initWithNibName:@"PageInspector" bundle:nil];
    [pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [pageInspector setIcon:[NSImage imageNamed:@"toolbar_new_page"]];
    [pageInspector bind:@"inspectedDocument"
               toObject:self
            withKeyPath:@"inspectedWindow.windowController.document"
                options:nil];
    [pageInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:pageInspector atIndex:1];
    [pageInspector release];
    
    
    // Wrap
    SVInspectorViewController *wrapInspector = [[SVInspectorViewController alloc] initWithNibName:@"WrapInspector" bundle:nil];
    [wrapInspector setTitle:NSLocalizedString(@"Wrap", @"Wrap Inspector")];
    [wrapInspector setIcon:[NSImage imageNamed:@"unsorted"]];
    [wrapInspector bind:@"inspectedDocument"
               toObject:self
            withKeyPath:@"inspectedWindow.windowController.document"
                options:nil];
    [wrapInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:wrapInspector atIndex:2];
    [wrapInspector release];
    
    
    return result;
}

@end
