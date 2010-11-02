//
//  SVMediaPlugIn.m
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"

#import "SVGraphicFactory.h"
#import "SVMediaGraphic.h"
#import "SVMediaRecord.h"
#import "KSWebLocation+SVWebLocation.h"

#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "NSError+Karelia.h"


@implementation SVMediaPlugIn

#pragma mark Properties

- (SVMedia *)media;
{
    return [[[self container] media] media];
}
+ (NSSet *)keyPathsForValuesAffectingMedia;
{
    return [NSSet setWithObject:@"container.media.media"];
}

- (NSURL *)externalSourceURL; { return [[self container] externalSourceURL]; }

- (void)didSetSource; { }

+ (NSArray *)allowedFileTypes; { return nil; }

#pragma mark Poster Frame

- (SVMediaRecord *)posterFrame; { return [[self container] posterFrame]; }
+ (NSSet *)keyPathsForValuesAffectingPosterFrame;
{
    return [NSSet setWithObject:@"container.posterFrame"];
}

- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;
{
    return (posterFrame == nil);
}

- (void)setPosterFrameWithMedia:(SVMedia *)media;   // nil removes poster frame
{
    SVMediaRecord *record = nil;
    if (media)
    {
        record = [SVMediaRecord mediaRecordWithMedia:media
                                          entityName:@"PosterFrame"
                      insertIntoManagedObjectContext:[self.container managedObjectContext]];
    }
    
	[self replaceMedia:record forKeyPath:@"container.posterFrame"];
}

#pragma mark Media Conversion

- (BOOL)validateTypeToPublish:(NSString *)type; { return YES; }

#pragma mark Metrics

+ (BOOL)isExplicitlySized; { return YES; }

- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // SVGraphic.width is optional. For media graphics it becomes compulsary unless using external URL
    BOOL result = (*height != nil || (![self media] && [self externalSourceURL]));
    
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"height is a mandatory property"];
    }
    
    return result;
}

- (BOOL)isConstrainProportionsEditable; { return YES; }

- (NSNumber *)naturalWidth; { return [[self container] naturalWidth]; }

- (NSNumber *)naturalHeight; { return [[self container] naturalHeight]; }

- (void)setNaturalWidth:(NSNumber *)width height:(NSNumber *)height;
{
    SVMediaGraphic *graphic = [self container];
    [graphic setNaturalWidth:width];
    [graphic setNaturalHeight:height];
    
    NSUInteger oldWidth = [self width];
    [graphic makeOriginalSize];
    
    if (width && height)
    {
        [graphic setConstrainProportions:YES];
    }
    
    if (oldWidth && [self width] > oldWidth) [self setWidth:oldWidth];
}

- (CGSize)originalSize;
{
    CGSize result = CGSizeZero;
    
    NSNumber *naturalWidth = self.naturalWidth;
    NSNumber *naturalHeight = self.naturalHeight;
    
    // Try to get cached natural size first
    if (nil != naturalWidth && nil != naturalHeight)
    {
        result = CGSizeMake([naturalWidth floatValue], [naturalHeight floatValue]);
    }
    else	// ask the media for it, and cache it.
    {
        SVMedia *media = [self media];
        if (media)
        {
            result = [media originalSize];
            [self setNaturalWidth:[NSNumber numberWithFloat:result.width]
                           height:[NSNumber numberWithFloat:result.height]];
        }
    }
    
    
    return result;
}

/*  There shouldn't be any need to call this method directly. Instead, it should only be called internally from -[SVMediaGraphic makeOriginalSize]
 */
- (void)makeOriginalSize;
{
    CGSize size = [self originalSize];
    if (!CGSizeEqualToSize(size, CGSizeZero))
    {
        [self setWidth:size.width];
        [self setHeight:size.height];
    }
}

#pragma mark SVEnclosure

- (NSURL *)downloadedURL;   // where it currently resides on disk
{
	NSURL *mediaURL = nil;
	SVMedia *media = [self media];
	
    if (media)
    {
		mediaURL = [media fileURL];
	}
	else
	{
		mediaURL = [self externalSourceURL];
	}
	return mediaURL;
}

- (long long)length;
{
	long long result = 0;
	SVMedia *media = [self media];
	
    if (media)
    {
		NSData *mediaData = [media mediaData];
		result = [mediaData length];
	}
	return result;
}

- (NSString *)MIMEType;
{
	NSString *type = [(id)[self media] typeOfFile];
    if (!type)
    {
        type = [NSString UTIForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    }
    
    NSString *result = (type ? [NSString MIMETypeForUTI:type] : nil);
	return result;
}

- (NSURL *)URL; { return [self externalSourceURL]; }

#pragma mark HTML

- (BOOL)shouldWriteHTMLInline; { return NO; }
- (BOOL)canWriteHTMLInline; { return NO; }
- (id <SVMedia>)thumbnailMedia; { return [self media]; }

- (id)imageRepresentation;
{
    id <SVMedia> media = [self thumbnailMedia];
    id result = [media mediaData];
    if (!result) result = [media mediaURL];
    
    return result;
}

- (NSString *)imageRepresentationType;
{
    // Default to Quick Look. Subclasses can get better
    return ([[self thumbnailMedia] mediaData] ? nil : IKImageBrowserQuickLookPathRepresentationType);
}


#pragma mark Inspector

- (id)valueForUndefinedKey:(NSString *)key; { return NSNotApplicableMarker; }

#pragma mark Pasteboard

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    NSArray *result = [SVGraphicFactory graphicPasteboardTypes]; // want to read by UTI ideally
    result = [result arrayByAddingObjectsFromArray:[KSWebLocation webLocationPasteboardTypes]];
    return result;
}

@end
