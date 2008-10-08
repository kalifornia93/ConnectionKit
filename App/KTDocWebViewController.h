//
//  KTDocWebViewController.h
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


// myViewTypes
typedef enum {
	KTStandardWebView,
	KTWithoutStylesView,
	KTSourceCodeView,
	KTPreviewSourceCodeView,	// Unimplemented
	KTDOMSourceView,
	KTRSSView,					// Unimplemented
	KTRSSSourceView,
	KTHTMLValidationView
} KTWebViewViewType;


@class KTAbstractElement, KTPage, KTPagelet;
@class KTWebViewComponent;
@class KTHTMLTextBlock, KTWebViewUndoManagerProxy;
@class KTHTMLParser;
@class KTInlineImageElement;
@class CIFilter;
@class KTDocument;
@class KTDocWindowController;
@class KTAsyncOffscreenWebViewController;


@interface KTDocWebViewController : NSResponder
{
	IBOutlet WebView				*webView;
	IBOutlet NSTextView				*oSourceTextView;
	
	
	@private
	
    // View
	WebView					*myWebView;
    
    // Controller chain
	KTDocWindowController	*_windowController;
    KTDocument              *_document;
	
	DOMHTMLElement			*myElementWaitingForFragmentLoad;
	KTAsyncOffscreenWebViewController				*myAsyncOffscreenWebViewController;
	
	
	// Loading
    NSSet					*myPages;
    KTWebViewComponent		*myMainWebViewComponent;
    BOOL                    _needsReload;
	unsigned				myLoadingSuspensionCount;
	
	
	
	NSString	*mySavedPageletStyle;
	DOMHTMLElement					*mySelectedPageletHTMLElement;
	
	BOOL myWebViewIsLoading;
	
		
	WebScriptObject					*myWindowScriptObject;
	
	KTWebViewViewType	myViewType;
	
	// Animation
	NSWindow						*myAnimationCoverWindow;
	NSTimer							*myAnimationTimer;
	CIFilter						*myTransitionFilter;
	NSPoint							myAnimateStartingPoint;
	NSTimeInterval					myBaseTime;
	NSTimeInterval					myTotalAnimationTime;
	
	// Resources
	unsigned int myResourceCount;
	unsigned int myResourceCompletedCount;
	unsigned int myResourceFailedCount;
	
	
	// Editing
	KTHTMLTextBlock				*myTextEditingBlock;
	KTWebViewUndoManagerProxy	*myUndoManagerProxy;
	NSString					*myMidEditHTML;
	
	NSMutableDictionary	*myInlineImageNodes;
	NSMutableDictionary *myInlineImageElements;
}


#pragma mark View
- (WebView *)webView;
- (void)setWebView:(WebView *)webView;	// No-one should have to call this.


#pragma mark Controller chain
- (KTDocWindowController *)windowController;	// Weak reference
- (void)setWindowController:(KTDocWindowController *)windowController;	// Don't call this.

- (KTDocument *)document;   // Weak ref
- (void)setDocument:(KTDocument *)document;


#pragma mark Accessors
- (DOMHTMLElement *)elementWaitingForFragmentLoad;
- (void)setElementWaitingForFragmentLoad:(DOMHTMLElement *)anElementWaitingForFragmentLoad;
- (KTAsyncOffscreenWebViewController *)asyncOffscreenWebViewController;
- (void)setAsyncOffscreenWebViewController:(KTAsyncOffscreenWebViewController *)anAsyncOffscreenWebViewController;

- (NSTextView *)sourceCodeTextView;

- (NSString *)savedPageletStyle;
- (void)setSavedPageletStyle:(NSString *)aSavedPageletStyle;

- (DOMHTMLElement *)selectedPageletHTMLElement;
- (void)setSelectedPageletHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;

- (KTWebViewViewType)viewType;
- (void)setViewType:(KTWebViewViewType)aViewType;

- (NSWindow *)animationCoverWindow;
- (void)setAnimationCoverWindow:(NSWindow *)anAnimationCoverWindow;

- (NSTimer *)animationTimer;
- (void)setAnimationTimer:(NSTimer *)anAnimationTimer;

- (CIFilter *)transitionFilter;
- (void)setTransitionFilter:(CIFilter *)aTransitionFilter;

- (NSTimeInterval)baseTime;
- (void)setBaseTime:(NSTimeInterval)aBaseTime;

- (NSTimeInterval)totalAnimationTime;
- (void)setTotalAnimationTime:(NSTimeInterval)aTotalAnimationTime;

- (WebScriptObject *)windowScriptObject;
- (void)setWindowScriptObject:(WebScriptObject *)aWindowScriptObject;



// Updating
- (void)updateWebViewAnimated;

// Other
- (void)selectPagelet:(KTPagelet *)aPagelet;
- (void)setHilite:(BOOL)inHilite onHTMLElement:(DOMHTMLElement *)aSelectedPageletHTMLElement;

@end


#pragma mark -


@interface KTDocWebViewController (Refreshing)

- (NSSet *)pages;
- (void)setPages:(NSSet *)pages;
- (KTPage *)page;

// Content loading
- (BOOL)webViewNeedsReload;
- (void)setWebViewNeedsReload:(BOOL)flag;

- (void)suspendWebViewLoading;
- (void)resumeWebViewLoading;
- (BOOL)webViewLoadingIsSuspended;

- (void)reloadWebView;
- (void)reloadWebViewIfNeeded;

- (void)replaceWebViewComponent:(KTWebViewComponent *)oldComponent withComponent:(KTWebViewComponent *)newComponent;
- (void)spliceElement:(DOMHTMLElement *)loadedBody;	// Private

// Web View component hierarchy
- (KTWebViewComponent *)mainWebViewComponent;
- (void)setMainWebViewComponent:(KTWebViewComponent *)component;

@end


#pragma mark -


@interface KTDocWebViewController (Editing)

- (void)processEditableElementsFromElement:(DOMElement *)aDOMElement;

// Editing status
- (BOOL)webViewIsEditing;
- (KTHTMLTextBlock *)currentTextEditingBlock;
- (BOOL)commitEditing;

- (KTInlineImageElement *)inlineImageElementForNode:(DOMHTMLImageElement *)node
										  container:(KTAbstractElement *)container;

// Links
- (BOOL)validateCreateLinkItem:(id <NSValidatedUserInterfaceItem>)item title:(NSString **)title;

- (IBAction)pasteTextAsMarkup:(id)sender;


@end
