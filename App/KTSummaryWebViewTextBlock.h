//
//  KTSummaryWebViewTextBlock.h
//  Marvel
//
//  Created by Mike on 04/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVHTMLTextBlock.h"


@interface KTSummaryWebViewTextBlock : SVHTMLTextBlock
{
    unsigned    myTruncateCharacters;
}

// Accessors
- (unsigned)truncateCharacters;
- (void)setTruncateCharacters:(unsigned)truncation;

- (NSString *)innerEditingHTML;

@end