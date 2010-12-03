//
//  SVMediaDOMController.m
//  Sandvox
//
//  Created by Mike on 18/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaDOMController.h"

#import "SVPasteboardItemInternal.h"
#import "SVTextAttachment.h"

#import "NSColor+Karelia.h"


@implementation SVMediaDOMController

#pragma mark Properties

// TODO: proper logic for this:
- (BOOL)isMediaPlaceholder;
{
    // Don't accept drops on inline images
    BOOL result = YES;
    
    SVPlugInGraphic *graphic = [self representedObject];
    if ([graphic textAttachment] && ![[[graphic textAttachment] causesWrap] boolValue])
    {
        result = NO;
    }
    
    return result;
}

#pragma mark Selection

- (BOOL)allowsDirectAccessToWebViewWhenSelected;
{
    // Generally, no. EXCEPT for inline, non-wrap-causing images
    BOOL result = NO;
    
    SVMediaGraphic *image = [self representedObject];
    if ([image shouldWriteHTMLInline])
    {
        result = YES;
    }
    
    return result;
}

#pragma mark Resize

- (NSSize)minSize;
{
    // Remove the 200px width restriction
    NSSize result = [super minSize];
    result.width = result.height;
    return result;
}

#pragma mark Drag & Drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    if ([self isMediaPlaceholder])
    {
        _drawAsDropTarget = YES;
        [self setNeedsDisplay];
        return NSDragOperationCopy;
    }
    
    return NSDragOperationNone;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender;
{
    [self setNeedsDisplay];
    _drawAsDropTarget = NO;
    
    return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSPasteboard *pboard = [sender draggingPasteboard];
    
    NSString *type = [pboard availableTypeFromArray:[SVMediaPlugIn readableTypesForPasteboard:pboard]];
    if (type)
    {
        [[self representedObject] awakeFromPasteboardItems:[pboard sv_pasteboardItems]];
        return YES;
    }
    
    return NO;
}

- (NSArray *)registeredDraggedTypes;
{
    return [SVMediaPlugIn readableTypesForPasteboard:
            [NSPasteboard pasteboardWithName:NSDragPboard]];
}

#pragma mark Drawing

- (NSRect)dropTargetRect;
{
    NSRect result = [[self HTMLElement] boundingBox];
    
    // Movies draw using Core Animation so sit above any custom drawing of our own. Workaround by outsetting the rect
    NSString *tagName = [[self HTMLElement] tagName];
    if ([tagName isEqualToString:@"VIDEO"] || [tagName isEqualToString:@"OBJECT"])
    {
        result = NSInsetRect(result, -2.0f, -2.0f);
    }
    
    return result;
}

- (NSRect)drawingRect;
{
    NSRect result = [super drawingRect];
    
    if (_drawAsDropTarget)
    {
        result = NSUnionRect(result, [self dropTargetRect]);
    }
    
    return result;
}

- (void)drawRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    [super drawRect:dirtyRect inView:view];
    
    // Draw outline
    if (_drawAsDropTarget)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self dropTargetRect], 2.0f);
    }
}

- (void)updateToReflectSelection;
{
    // Do nothing!!
}

@end


#pragma mark -


@implementation SVMediaGraphicDOMController

- (void)dealloc
{
    [_imageDOMController release];
    [super dealloc];
}

#pragma mark Controller

@synthesize imageDOMController = _imageDOMController;

#pragma mark DOM

- (void)setHTMLElement:(DOMHTMLElement *)element;
{
    // Is this a change due to being orphaned while editing? If so, pass down to image controller too. #83312
    if ([self HTMLElement] == [[self imageDOMController] HTMLElement])
    {
        [[self imageDOMController] setHTMLElement:element];
    }
    
    [super setHTMLElement:element];
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document;
{
    // Hook up image controller first
    SVMediaDOMController *imageController = [self imageDOMController];
    if (![imageController isHTMLElementCreated])
    {
        [imageController loadHTMLElementFromDocument:document];
    }
    
    [super loadHTMLElementFromDocument:document];
    
    // If it failed that's because the image is chromeless, so adopt its element
    if (![self isHTMLElementCreated])
    {
        [self setHTMLElement:[imageController HTMLElement]];
    }
}

#pragma mark Update

- (void)updateSize;
{
    if ([[self selectableTopLevelDescendants] count] > 1)	// #93182
    {
        [super updateSize];
    }
    else
    {
        [self didUpdateWithSelector:_cmd];   // fake it
    }
}

#pragma mark Resizing

- (NSSize)constrainSize:(NSSize)size handle:(SVGraphicHandle)handle snapToFit:(BOOL)snapToFit;
{
    size = [super constrainSize:size handle:handle snapToFit:snapToFit];
    
    
    if (snapToFit)
    {
        // Snap to original size if you are very close to it
        BOOL resizingWidth = (handle == kSVGraphicUpperLeftHandle ||
                              handle == kSVGraphicMiddleLeftHandle ||
                              handle == kSVGraphicLowerLeftHandle ||
                              handle == kSVGraphicUpperRightHandle ||
                              handle == kSVGraphicMiddleRightHandle ||
                              handle == kSVGraphicLowerRightHandle);
        
        BOOL resizingHeight = (handle == kSVGraphicUpperLeftHandle ||
                               handle == kSVGraphicUpperMiddleHandle ||
                               handle == kSVGraphicUpperRightHandle ||
                               handle == kSVGraphicLowerLeftHandle ||
                               handle == kSVGraphicLowerMiddleHandle ||
                               handle == kSVGraphicLowerRightHandle);
        
        SVMediaPlugIn *plugIn = [(SVMediaGraphic *)[self representedObject] plugIn];
        NSNumber *naturalWidth = [plugIn naturalWidth];
        NSNumber *naturalHeight = [plugIn naturalHeight];
         
        
        // Snap if we are near the original size.
        if (naturalWidth && naturalHeight)
        {
            int snap = MIN([naturalWidth floatValue]/4, 10);	// snap to smaller of 25% image width or 10 pixels
            if (resizingWidth && ( abs(size.width - [naturalWidth floatValue]) < snap) )
            {
                size.width = [naturalWidth floatValue];
            }
            if (resizingHeight && ( abs(size.height - [naturalHeight floatValue]) < snap) )
            {
                size.height = [naturalHeight floatValue];
            }
        }
    }
    
    
    return size;
}

@end


#pragma mark -


@implementation SVMediaGraphic (SVDOMController)

- (SVDOMController *)newDOMController;
{
    //Class class = ([self isPagelet] ? [SVImagePageletDOMController class] : [SVImageDOMController class]);
    return [[SVMediaGraphicDOMController alloc] initWithRepresentedObject:self];
}

- (SVDOMController *)newBodyDOMController;
{
    return [[SVMediaDOMController alloc] initWithRepresentedObject:self];
}

@end
