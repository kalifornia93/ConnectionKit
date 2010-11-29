//
//  SVPageProtocol.h
//  Sandvox
//
//  Created by Mike on 02/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVPlugIn.h"

typedef enum { kTruncateNone, kTruncateCharacters, kTruncateWords, kTruncateSentences, kTruncateParagraphs } SVIndexTruncationType;

@protocol SVPage <NSObject>

#pragma mark Content
- (NSString *)title;
- (void)writeSummary:(id <SVPlugInContext>)context truncation:(NSUInteger)maxCount truncationType:(SVIndexTruncationType)truncationType;


#pragma mark Properties
- (NSString *)language;
- (NSString *)timestampDescription;    // nil if page does't have/want timestamp


#pragma mark Thumbnail
// Return value is whether page had thumbnail to write
// Passing in dryRun as YES will inform you of presence of thumbnail without writing anything
- (BOOL)writeThumbnail:(id <SVPlugInContext>)context
              maxWidth:(NSUInteger)width
             maxHeight:(NSUInteger)height
        imageClassName:(NSString *)className
                dryRun:(BOOL)dryRun;


#pragma mark Children

// Most SVPage methods aren't KVO-compliant. Instead, observe all of -automaticRearrangementKeyPaths.
@property(nonatomic, readonly) BOOL isCollection;   // or is it enough to test if childPages is non-nil?
- (NSArray *)childPages; 
- (id <SVPage>)rootPage;

- (NSArray *)archivePages;


#pragma mark Navigation

@property(nonatomic, readonly) NSURL *feedURL;  // KVO-compliant

- (BOOL)shouldIncludeInIndexes;
- (BOOL)shouldIncludeInSiteMaps;


@end
