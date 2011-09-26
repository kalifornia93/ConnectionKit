//
//  SVDesignsController.m
//  Sandvox
//
//  Created by Dan Wood on 5/7/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDesignsController.h"

#import "KTDesign.h"
#import "KT.h"

#import "KSPlugInWrapper.h"


@implementation SVDesignsController

@synthesize rangesOfGroups = _rangesOfGroups;

- (id)init;
{
    // By default, list installed design plug-ins, sorted by name
    self = [self initWithContent:[KSPlugInWrapper pluginsWithFileExtension:kKTDesignExtension]];
        
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [self setSortDescriptors:[NSArray arrayWithObject:sort]];
    [sort release];
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    [super initWithCoder:aDecoder];
    
    // By default, list installed design plug-ins, sorted by name
    [self setContent:[KSPlugInWrapper pluginsWithFileExtension:kKTDesignExtension]];
    
    NSSortDescriptor *sort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES selector:@selector(localizedCaseInsensitiveCompare:)];
    [self setSortDescriptors:[NSArray arrayWithObject:sort]];
    [sort release];
    
    return self;
}

- (void)dealloc
{
	self.rangesOfGroups = nil;
	[super dealloc];
}

- (NSArray *)arrangeObjects:(NSArray *)objects;
{
    objects = [super arrangeObjects:objects];		// do the filtering
    
	NSArray *newRangesOfGroups;
	objects = [KTDesign reorganizeDesigns:objects familyRanges:&newRangesOfGroups];
	self.rangesOfGroups = newRangesOfGroups;
    
	return objects;
}

- (KTDesign *)designWithIdentifier:(NSString *)anIdentifier;
{
	KTDesign *result = nil;
	NSArray *designs = [self arrangedObjects];
	for (KTDesign *design in designs)
	{
		if ([[design identifier] isEqualToString:anIdentifier])
		{
			result = design;
			break;
		}
	}
	return result;
}

@end
