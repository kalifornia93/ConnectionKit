//
//  SVPagesTreeController.m
//  Sandvox
//
//  Created by Mike on 10/01/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPagesTreeController.h"

#import "SVApplicationController.h"
#import "SVArticle.h"
#import "SVAttributedHTML.h"
#import "SVDownloadSiteItem.h"
#import "KTElementPlugInWrapper.h"
#import "SVLinkManager.h"
#import "SVMediaGraphic.h"
#import "KTPage+Paths.h"
#import "SVPageTemplate.h"
#import "SVRichText.h"
#import "SVSidebarPageletsController.h"
#import "KTSite.h"
#import "SVTextAttachment.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSIndexPath+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"

#import "KSStringXMLEntityEscaping.h"
#import "KSURLUtilities.h"


@interface SVPageProxy : NSObject
{
@private
    SVSiteItem  *_page;
    
    NSMutableArray      *_childNodes;
    SVPagesController   *_childPagesController;
    BOOL                _syncingChildren;
}

+ (SVPageProxy *)proxyForTargetPage:(SVSiteItem *)page;

@end


#pragma mark -


@interface SVPagesTreeController ()
@property(nonatomic, retain, readwrite) SVPageTemplate *pageTemplate;
@property(nonatomic, copy, readwrite) NSURL *objectURL;
- (id)newObjectDestinedForCollection:(KTPage *)collection;
- (void)configurePageAsCollection:(KTPage *)collection;
@end


#pragma mark -


@implementation SVPagesTreeController

#pragma mark Init & Dealloc

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    self = [super initWithCoder:aDecoder];
    
    [self setParentKeyPath:@"parentPage"];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageProxyWillChange:) name:@"SVPageProxyWillChange" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageProxyDidChange:) name:@"SVPageProxyDidChange" object:nil];
    
    return self;
}

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SVPageProxyWillChange" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SVPageProxyDidChange" object:nil];
    
    [_template release];
    [_URL release];
    
    [super dealloc];
}

#pragma mark Core Data Support

@synthesize pageTemplate = _template;
- (void)setEntityNameWithPageTemplate:(SVPageTemplate *)pageTemplate;
{
    [self setEntityName:@"Page"];
    [self setPageTemplate:pageTemplate];
}

@synthesize objectURL = _URL;
- (void)setEntityTypeWithURL:(NSURL *)URL external:(BOOL)external;
{
    [self setEntityName:(external ? @"ExternalLink" : @"File")];
    [self setObjectURL:URL];
}

- (void)setEntityName:(NSString *)entityName;
{
    [self setObjectURL:nil];
    [self setPageTemplate:nil];
    
    [super setEntityName:entityName];
}

- (NSString *)childrenKeyPathForNode:(NSTreeNode *)node;
{
    // Override the default to return a sorted array via our page proxy instead
    NSString *result = [super childrenKeyPathForNode:node];
    
    // The tree controller might have been dumb and replaced our proxy objects with real pages
    id object = [node representedObject];
    if (object && ![object isKindOfClass:[SVPageProxy class]])
    {
        return result;
    }
         
    if (result) result = @"childNodes";
    return result;
}

#pragma mark Inserting Objects

- (void)add:(id)sender;
{
    [self commitEditingWithDelegate:self
                  didCommitSelector:@selector(controller:didCommitBeforeAdding:contextInfo:)
                        contextInfo:NO];
}

- (void)controller:(SVPagesController *)controller didCommitBeforeAdding:(BOOL)didCommit contextInfo:(BOOL)asChild;
{
    if (didCommit)
    {
        if ([[self entityName] isEqualToString:@"ExternalLink"] && ![self objectURL])
        {
            // Guess URL before continuing
            SVLink *link = [[SVLinkManager sharedLinkManager] guessLink];
            if ([link URLString]) [self setObjectURL:[NSURL URLWithString:[link URLString]]];
        }
        
        
        // Figure out the predecessor (which page to inherit properties from)
        KTPage *selectedPage = [[self selectedNode] representedObject];
        if (asChild)
        {
            id page = [self newObjectDestinedForCollection:selectedPage];
            [self addChildObject:page];
            [page release];
        }
        else
        {
            id page = [self newObjectDestinedForCollection:[selectedPage parentPage]];
            [self addObject:page];
            [page release];
        }
    }
    else
    {
        NSBeep();
    }
}

- (void)addChild:(id)sender;
{
    if (![self canAddChild]) return;
    
    [self commitEditingWithDelegate:self
                  didCommitSelector:@selector(controller:didCommitBeforeAdding:contextInfo:)
                        contextInfo:(void *)YES];
}

/*  After adding, resort to accomodate automatically sorted collections
 */
- (void)didAddObjectsByInsertingIntoNode:(NSTreeNode *)parentNode;
{
    KTPage *collection = [parentNode representedObject];
    
    if ([[collection collectionSortOrder] boolValue])
    {
        SVPagesController *controller = [[parentNode representedObject] valueForKey:@"childPagesController"];
        [controller rearrangeObjects];
    }
}
- (void)didAddObjectsByInsertingAtArrangedObjectIndexPath:(NSIndexPath *)path;
{
    // Rearrange if automatically sorted
    NSIndexPath *parentPath = [path indexPathByRemovingLastIndex];
    NSTreeNode *parentNode = [[self arrangedObjects] descendantNodeAtIndexPath:parentPath];
    [self didAddObjectsByInsertingIntoNode:parentNode];
}

- (void)addObject:(id)object;
{
    /* Reimplement so we have control over the path
     */
    
    // Insert
    NSIndexPath *path = [self indexPathForAddingObjects];
    [self insertObject:object atArrangedObjectIndexPath:path];
    
    // Rearrange if automatically sorted
    [self didAddObjectsByInsertingAtArrangedObjectIndexPath:path];
}

- (void)addObjects:(NSArray *)objects;  // like NSArrayController
{
    NSIndexPath *path = [[self selectionIndexPath] indexPathByIncrementingLastIndex];
    [self insertObjects:objects atArrangedObjectIndexPath:path];
    [self didAddObjectsByInsertingAtArrangedObjectIndexPath:path];
}

- (void)addChildObject:(id)object;  // NSTreeController doesn't provide this, so we do. Like -addObject:
{
    NSIndexPath *parentPath = [self selectionIndexPath];
    NSTreeNode *parentNode = [[self arrangedObjects] descendantNodeAtIndexPath:parentPath];
    
    NSIndexPath *path = [parentPath indexPathByAddingIndex:[[parentNode childNodes] count]];
    [self insertObject:object atArrangedObjectIndexPath:path];
    
    [self didAddObjectsByInsertingAtArrangedObjectIndexPath:path];
}

- (void)insertObjects:(NSArray *)objects atArrangedObjectIndexPath:(NSIndexPath *)startingIndexPath;
{
    NSIndexPath *aPath = startingIndexPath;
    NSMutableArray *paths = [[NSMutableArray alloc] initWithCapacity:[objects count]];
    
    for (id anObject in objects)
    {
        [paths addObject:aPath];
        aPath = [aPath indexPathByIncrementingLastIndex];
    }
    
    [self insertObjects:objects atArrangedObjectIndexPaths:paths];
    [paths release];
}

- (void)insertObject:(id)object atArrangedObjectIndexPath:(NSIndexPath *)indexPath;
{
    // Actually insert proxy for the page
    SVPageProxy *proxy = [SVPageProxy proxyForTargetPage:object];
    [super insertObject:proxy atArrangedObjectIndexPath:indexPath];
    
    
    // Include in site menu if appropriate
    KTPage *collection = (KTPage *)[object parentPage];
    if ([collection isRootPage] && [[collection childItems] count] < 7)
    {
        [object setIncludeInSiteMenu:[NSNumber numberWithBool:YES]];
    }
    
    
    [[NSNotificationCenter defaultCenter] postNotificationName:SVPagesControllerDidInsertObjectNotification object:self];
}

- (BOOL)canAddChild;
{
    // The selection must be a collection
    // For reasons I can't fathom, NSTreeController's implementation always returns NO, so have to write our own.
    return ![[self selectedNode] isLeaf];
}

- (NSIndexPath *)indexPathForAddingObjects;
{
    return [[self lastSelectionIndexPath] indexPathByIncrementingLastIndex];
}

#pragma mark Grouping

- (void)groupAsCollection:(id)sender;
{
    // New collection
    SVPageTemplate *template = [[SVPageTemplate alloc]
                                initWithCollectionPreset:[NSDictionary dictionary]];
    
    [self setEntityNameWithPageTemplate:template];
    [template release];
    
    NSIndexPath *path = [self indexPathForAddingObjects];
    
    KTPage *parent = [self parentPageOfObjectAtIndexPath:path];
    if (!parent)
    {
        // Selection is probably home page!
        NSBeep();
        return;
    }
    KTPage *group = [self newObjectDestinedForCollection:parent];
    
    
    // Insert
    NSArray *selection = [[self selectedNodes] retain]; // inserting may change selection so grab now
    [self insertObject:group atArrangedObjectIndexPath:path];
    [group release];
    
    
    // Move selection into it
    [self moveNodes:selection toIndexPath:[path indexPathByAddingIndex:0]];
    [selection release];
}

- (BOOL)canGroupAsCollection;
{
    // Can group if root isn't selected
    return ![[self selectionIndexPaths] containsObject:[NSIndexPath indexPathWithIndex:0]];
}

#pragma mark New Objects

- (id)newObject
{
    // NSTreeController seems to be unable to cope with entity mode by default, so do the insert ourselves
    id result = [NSEntityDescription insertNewObjectForEntityForName:[self entityName]
                                              inManagedObjectContext:[self managedObjectContext]];
    
    return [result retain];
}

- (id)newObjectWithPredecessor:(KTPage *)predecessor followTemplate:(BOOL)followTemplate;
{
    id result = [self newObject];
    
    if ([[self entityName] isEqualToString:@"Page"])
    {
        // Match the basic page properties up to the selection
        [result setMaster:[predecessor master]];
        
        if (predecessor)
        {
            [result setShowSidebar:[predecessor showSidebar]];
            [result setAllowComments:[predecessor allowComments]];
            [result setIncludeTimestamp:[predecessor includeTimestamp]];
        }
        
        
        if (followTemplate)
        {
            SVPageTemplate *template = [self pageTemplate];
            [result setMasterIdentifier:[[self pageTemplate] identifier]];
            
            
            // Make the page into a collection if it was requested
            if ([[[self pageTemplate] pageProperties] boolForKey:@"isCollection"]) 
            {
                [self configurePageAsCollection:result];
            }
            else
            {
                [result setValuesForKeysWithDictionary:[[self pageTemplate] pageProperties]];
            }
            
            
            // Initial graphic for the page
            if ([template graphicFactory])
            {
                SVGraphic *initialGraphic = [[template graphicFactory] insertNewGraphicInManagedObjectContext:[self managedObjectContext]];
                [initialGraphic setWasCreatedByTemplate:YES];
                
                NSAttributedString *graphicHTML = [NSAttributedString attributedHTMLStringWithGraphic:initialGraphic];
                [[initialGraphic textAttachment] setPlacement:[NSNumber numberWithInt:SVGraphicPlacementInline]];
                [initialGraphic awakeFromNew];
                
                SVRichText *article = [result article];
                NSMutableAttributedString *html = [[article attributedHTMLString] mutableCopy];
                [html appendAttributedString:graphicHTML];
                [article setAttributedHTMLString:html];
                [html release];
                
                [initialGraphic didAddToPage:result];
            }
        }
    }
    else if ([[self entityName] isEqualToString:@"ExternalLink"])
    {
        [result setURL:[self objectURL]];
    }
    else if ([[self entityName] isEqualToString:@"File"])
    {
        // Import specified file if possible
        SVMediaRecord *record = nil;
        if ([self objectURL])
        {
            record = [SVMediaRecord mediaByReferencingURL:[self objectURL] entityName:@"FileMedia" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];
        }
        if (!record)
        {
			NSString *boilerplateText = NSLocalizedString(@"This can be replaced with any HTML you want.", @"placeholder string");
            
			NSString *boilerplateFormat = // Minimal, clean, but empty
			@"<!DOCTYPE html>\n<html>\n<head>\n<meta charset='UTF-8' />\n<title></title>\n</head>\n<body>\n\n%@\n\n</body>\n</html>\n";
			NSString *boilerplateHTML = [NSString stringWithFormat:boilerplateFormat, [boilerplateText stringByEscapingHTMLEntities]];
			NSData *data = [boilerplateHTML dataUsingEncoding:NSUTF8StringEncoding];
			
			SVMedia *media = [[SVMedia alloc]
							  initWithData:data
							  URL:[NSURL URLWithString:@"x-sandvox-fake-url:///emptystring.html"]];
			
			[media setPreferredFilename:@"Untitled.html"];
			
			record = [SVMediaRecord mediaRecordWithMedia:media
											  entityName:@"FileMedia"
						  insertIntoManagedObjectContext:[self managedObjectContext]];
			[media release];
        }
        
        [(SVDownloadSiteItem *)result setMedia:record];
    }
    
    return result;
}

- (void)configurePageAsCollection:(KTPage *)collection;
{
    //  Create a collection. Populate according to the index plug-in (-representedObject) if applicable.
    
    
    NSDictionary *presetDict = [[self pageTemplate] pageProperties];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	KTElementPlugInWrapper *plugInWrapper = identifier ? [KTElementPlugInWrapper pluginWithIdentifier:identifier] : nil;
	
    NSBundle *indexBundle = [plugInWrapper bundle];
    
    
    // Create the basic collection. collectionMaxSyndicatedPagesCount should have already been set
    [collection setBool:YES forKey:@"isCollection"]; // Duh!
    
    
    // Now re-set title of page to be the appropriate untitled name
    NSString *englishPresetTitle = [presetDict objectForKey:@"SVMasterPageTitle"];
    if (englishPresetTitle)
    {
        NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
        
        [collection setTitle:presetTitle];
    }
    
    
    // Other settings
    NSDictionary *pageSettings = [presetDict objectForKey:@"SVPageProperties"];
    [collection setValuesForKeysWithDictionary:pageSettings];
    
    
    // Generate a first child page if desired
    NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"SVIndexFirstPageProperties.pluginIdentifier"];
    if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
    {
        NSMutableDictionary *firstChildProperties =
        [NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"SVIndexFirstPageProperties"]];
        [firstChildProperties removeObjectForKey:@"pluginIdentifier"];
        
        // Create first child
        KTPage *firstChild = [self newObjectWithPredecessor:collection followTemplate:NO];
        
        // Insert at right place.
        [[SVPagesController controllerWithPagesInCollection:collection] addObject:firstChild];
        [firstChild release];
        
        // Initial properties
        NSEnumerator *propertiesEnumerator = [firstChildProperties keyEnumerator];
        NSString *aKey;
        while (aKey = [propertiesEnumerator nextObject])
        {
            id aProperty = [firstChildProperties objectForKey:aKey];
            if ([aProperty isKindOfClass:[NSString class]])
            {
                aProperty = [indexBundle localizedStringForKey:aProperty value:nil table:@"InfoPlist"];
            }
            
            if ([aKey isEqualToString:@"richTextHTML"]) // special case
            {
                [[firstChild article] setString:aProperty attachments:nil];
            }
            else
            {
                [firstChild setValue:aProperty forKeyPath:aKey];
            }
        }
    }
    
    
    // Any collection with an RSS feed should have an RSS Badge.
    if ([pageSettings boolForKey:@"collectionSyndicationType"])
    {
        // Give weblogs special introductory text
        if ([[presetDict objectForKey:@"KTPresetIndexBundleIdentifier"] isEqualToString:@"sandvox.GeneralIndex"])
        {
            NSString *intro = NSLocalizedString(@"<p>This is a new weblog. You can replace this text with an introduction to your blog, or just delete it if you wish. To add an entry to the weblog, add a new page using the \\U201CPages\\U201D button in the toolbar. For more information on blogging with Sandvox, please have a look through our <a href=\"help:Blogging_with_Sandvox\">help guide</a>.</p>",
                                                "Introductory text for Weblogs");
            
            [[collection article] setString:intro attachments:nil];
        }
    }
}

- (id)newObjectDestinedForCollection:(KTPage *)collection;
{
    // Figure out the predecessor (which page to inherit properties from)
    if (![collection isCollection]) collection = [collection parentPage];
    OBASSERT(collection || ![[self content] count]);    // it's acceptable to have no parent when creating first page
    
    
    KTPage *predecessor = collection;
    NSArray *children = [collection childrenWithSorting:SVCollectionSortByDateCreated
                                              ascending:NO
                                                inIndex:NO];
    
    for (SVSiteItem *aChild in children)
    {
        if ([aChild isKindOfClass:[KTPage class]])
        {
            predecessor = (KTPage *)aChild;
            break;
        }
    }
    
    return [self newObjectWithPredecessor:predecessor followTemplate:YES];
}

#pragma mark Moving Objects

- (void)moveNode:(NSTreeNode *)node toIndexPath:(NSIndexPath *)indexPath;
{
    // Is this a drop into a collection with nowhere specific in mind?
    NSIndexPath *parentPath = [indexPath indexPathByRemovingLastIndex];
    NSTreeNode *parentNode = [[self arrangedObjects] descendantNodeAtIndexPath:parentPath];
    
    NSUInteger index = [indexPath indexAtPosition:([indexPath length] - 1)];
    if (index > [[parentNode childNodes] count])
    {
        index = [[parentNode childNodes] count];
        indexPath = [parentPath indexPathByAddingIndex:index];
    }
    
    [super moveNode:node toIndexPath:indexPath];
}

- (void)moveNodes:(NSArray *)nodes toIndexPath:(NSIndexPath *)startingIndexPath;
{
    // Is this a drop into a collection with nowhere specific in mind?
    NSIndexPath *parentPath = [startingIndexPath indexPathByRemovingLastIndex];
    NSTreeNode *parentNode = [[self arrangedObjects] descendantNodeAtIndexPath:parentPath];
    
    NSUInteger index = [startingIndexPath indexAtPosition:([startingIndexPath length] - 1)];
    if (index > [[parentNode childNodes] count])
    {
        index = [[parentNode childNodes] count];
        startingIndexPath = [parentPath indexPathByAddingIndex:index];
    }
    
    
    [super moveNodes:nodes toIndexPath:startingIndexPath];
    
    // If moved into an auto-sorted collection, will probably need to rearrange
    [self didAddObjectsByInsertingIntoNode:parentNode];
}

#pragma mark Leak Conversion

- (NSCellStateValue)selectedItemsAreCollections;
{
    NSNumber *state = [self valueForKeyPath:@"selection.isCollection"];
    NSCellStateValue result = (NSIsControllerMarker(state) ? NSMixedState : [state integerValue]);
    return result;
}

// YES if any of them have
- (BOOL)selectedItemsHaveBeenPublished;
{
    NSDate *published = [self valueForKeyPath:@"selection.datePublished"];
    return (published != nil);
}

- (NSString *)convertToCollectionControlTitle;
{
    NSString *result = ([self selectedItemsAreCollections] ?
                        NSLocalizedString(@"Convert to Single Page", "menu title") :
                        NSLocalizedString(@"Convert to Collection", "menu title"));
    
    if ([self selectedItemsHaveBeenPublished]) result = [result stringByAppendingString:NSLocalizedString(@"‚Ä¶", @"ellipses appended to command, meaning there will be confirmation alert.  Probably spaces before in French.")];
    
    return result;
}

- (void)setContent:(id)content;
{
    // Replace content with proxies
    if ([content isKindOfClass:[NSArray class]])
    {
        NSMutableArray *buffer = [NSMutableArray arrayWithCapacity:[content count]];
        for (SVSiteItem *anItem in content)
        {
            SVPageProxy *proxy = [SVPageProxy proxyForTargetPage:anItem];
            [buffer addObject:proxy];
        }
        content = buffer;
    }
    else if (content)
    {
        content = [SVPageProxy proxyForTargetPage:content];
    }
    
    [super setContent:content];
}

#pragma mark Removing Objects

- (void) remove:(id)sender;
{
    [super remove:sender];
    
    // Label undo menu
    NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
    if ([[self selectionIndexPaths] count] == 1)
    {
        if ([[[self selectedObjects] objectAtIndex:0] isCollection])
        {
            [undoManager setActionName:NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")];
        }
        else
        {
            [undoManager setActionName:NSLocalizedString(@"Delete Page", "Delete Page MenuItem")];
        }
    }
    else
    {
        [undoManager setActionName:NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")];
    }
}

- (void)removeObjectsAtArrangedObjectIndexPaths:(NSArray *)indexPaths;
{
    // The default implementation of this method tries to change the content of the controller after making the removal (as to why, I haven't the foggiest idea). Instead, remove from the tree directly ourselves.
    
    
    // Sort the index paths backwards so as we remove each one the remaining paths are not affected
    NSArray *descriptors = [NSSortDescriptor sortDescriptorArrayWithKey:@"self" ascending:NO];
    indexPaths = [indexPaths sortedArrayUsingDescriptors:descriptors];
    
    
    // Logically, none of those objects can be selected after
    [self removeSelectionIndexPaths:indexPaths];
    
    
    // Time for a new selection?
    NSTreeNode *nextSelectionNode = nil;
    if (![self selectionIndexPath])
    {
        NSIndexPath *removalPath = [indexPaths objectAtIndex:0];
        NSIndexPath *path = [removalPath indexPathByIncrementingLastIndex];
        
        while (!(nextSelectionNode = [[self arrangedObjects] descendantNodeAtIndexPath:path]) ||
               [indexPaths containsObject:path])
        {
            path = ([path lastIndex] > 0 ?
                    [path indexPathByDecrementingLastIndex] :
                    [path indexPathByRemovingLastIndex]);
        }
    }
    
    
    // Make the removals
    for (NSIndexPath *aPath in indexPaths)
    {
        NSTreeNode *node = [[self arrangedObjects] descendantNodeAtIndexPath:aPath];
        
        [node retain];
        [[[node parentNode] mutableChildNodes] removeObjectAtIndex:[aPath lastIndex]];
        
        // Delete. Pages have to be treated specially, but I forget quite why
        id page = [[node representedObject] self]; // self accounts for proxy
        if ([page isKindOfClass:[KTPage class]])
        {
            [[self managedObjectContext] deletePage:page];
        }
        else
        {
            [[self managedObjectContext] deleteObject:page];
        }
        
        [node release];
    }
    
    
    // Invalidate site menu cache since the deleted pages may well have been in it
    NSTreeNode *root = [[self arrangedObjects] descendantNodeAtIndexPath:[NSIndexPath indexPathWithIndex:0]];
    KTPage *rootPage = [root representedObject];
    [[rootPage site] invalidatePagesInSiteMenuCache];
    
    
    // Set the new selection
    if (nextSelectionNode)
    {
        NSIndexPath *path = [nextSelectionNode indexPath];
        [self setSelectionIndexPath:path];
    }
}

#pragma mark Selection

- (NSTreeNode *)selectedNode;
{
    NSIndexPath *path = [self selectionIndexPath];
    NSTreeNode *result = [[self arrangedObjects] descendantNodeAtIndexPath:path];
    return result;
}

- (NSIndexPath *)lastSelectionIndexPath;
{
    return [[self selectionIndexPaths] lastObject];
}

- (NSArray *)XselectedObjects;
{
    NSArray *result = [super selectedObjects];
    return [result valueForKey:@"representedObject"];
}

- (void)pageProxyWillChange:(NSNotification *)notification;
{
    // Try to restore the current selection if this change is the first of the current event
    NSTimeInterval timestamp = [[NSApp currentEvent] timestamp];
    if (timestamp != _selectionRestorationTimestamp || !_selectionToRestore)
    {
        [_selectionToRestore release]; _selectionToRestore = [[self selectedObjects] copy];
        _selectionRestorationTimestamp = timestamp;
    }
    
    // If all selected objects are removed, we'll have to fall back to selecting the nearest sibling/parent
    [_fallbackSelection release]; _fallbackSelection = [[self selectionIndexPath] copy];
}

- (void)pageProxyDidChange:(NSNotificationCenter *)notification;
{
    if (_selectionToRestore)
    {
        NSTimeInterval timestamp = [[NSApp currentEvent] timestamp];
        if (timestamp == _selectionRestorationTimestamp)
        {
            // Did it completely work?
            if ([self setSelectedObjects:_selectionToRestore] &&
                [[self selectionIndexPaths] count] == [_selectionToRestore count])
            {
                [_selectionToRestore release]; _selectionToRestore = nil;
            }
        }
    }
    
    
    // Avoid empty selection
    if (![self selectionIndexPath])
    {
        if (_fallbackSelection)
        {
            // Search for the best match to the original keypath
            NSIndexPath *path = _fallbackSelection;
            
            NSTreeNode *node;
            while (!(node = [[self arrangedObjects] descendantNodeAtIndexPath:path]))
            {
                path = ([path lastIndex] > 0 ?
                        [path indexPathByDecrementingLastIndex] :
                        [path indexPathByRemovingLastIndex]);
            }
            
            [self setSelectionIndexPath:path];
            [_fallbackSelection release]; _fallbackSelection = nil;
        }
    }
}

#pragma mark Queries

- (KTPage *)parentPageOfObjectAtIndexPath:(NSIndexPath *)indexPath;
{
    NSIndexPath *parentPath = [indexPath indexPathByRemovingLastIndex];
    KTPage *result = [[[self arrangedObjects] descendantNodeAtIndexPath:parentPath] representedObject];
    return result;
}

#pragma mark Pasteboard Support

- (BOOL)addObjectsFromPasteboard:(NSPasteboard *)pboard;
{
    return [self insertObjectsFromPasteboard:pboard
                   atArrangedObjectIndexPath:[[self lastSelectionIndexPath] indexPathByIncrementingLastIndex]];
}

- (BOOL)insertObjectsFromPasteboard:(NSPasteboard *)pboard atArrangedObjectIndexPath:(NSIndexPath *)startingIndexPath;
{
    NSIndexPath *collectionPath = [startingIndexPath indexPathByRemovingLastIndex];
    KTPage *collection = [[[self arrangedObjects] descendantNodeAtIndexPath:collectionPath] representedObject];
    SVPagesController *pagesController = [collection valueForKey:@"childPagesController"]; // slight hack!
    
    if ([[pboard types] containsObject:kKTPagesPboardType])
    {
        NSArray *plists = [pboard propertyListForType:kKTPagesPboardType];
        NSMutableArray *pages = [NSMutableArray arrayWithCapacity:[plists count]];
        
        for (id aPlist in plists)
        {
            SVSiteItem *item = [pagesController newObjectFromPropertyList:aPlist];
            
            if (item)   // might be nil due to invalid plist
            {
                [pages addObject:item];
                [item release];
            }
        }
        
        if ([pages count])
        {
            [self insertObjects:pages atArrangedObjectIndexPath:startingIndexPath];
            return YES;
        }
    }
    
    
    // Fallback to creating graphics/links from the pasteboard
    BOOL result = NO;
    
    NSArray *pages = [pagesController objectsWithContentFromPasteboard:pboard];
    if (pages)
    {
        [self insertObjects:pages atArrangedObjectIndexPath:startingIndexPath];
        result = YES;
    }
    
    
    return result;
}

#pragma mark KVC

/*	When the user customizes the filename, we want it to become fixed on their choice
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	[super setValue:value forKeyPath:keyPath];
	
	if ([keyPath isEqualToString:@"selection.fileName"])
	{
		[self setValue:[NSNumber numberWithBool:NO] forKeyPath:@"selection.shouldUpdateFileNameWhenTitleChanges"];
	}
}

@end


#pragma mark -


@implementation SVPageProxy

#pragma mark Init & Dealloc

- (id)initWithTargetPage:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    self = [self init];
    
    _page = [page retain];
    _page->_proxy = self;
    
    return self;
}

+ (SVPageProxy *)proxyForTargetPage:(SVSiteItem *)page;
{
    SVPageProxy *result = page->_proxy;
    if (!result)
    {
        result = [[[SVPageProxy alloc] initWithTargetPage:page] autorelease];
    }
    return result;
}

- (void)dealloc;
{
    [_childPagesController removeObserver:self forKeyPath:@"arrangedObjects"];
    
    _page->_proxy = nil;
    [_page release];
    
    [_childNodes release];
    [_childPagesController release];
    
    [super dealloc];
}

#pragma mark Target

- (SVSiteItem *)representedObject;
{
    return _page;
}

- (NSMethodSignature *) methodSignatureForSelector:(SEL)sel;
{
    return [_page methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation;
{
    [invocation invokeWithTarget:_page];
}

- (BOOL)respondsToSelector:(SEL)aSelector;
{
    BOOL result = [super respondsToSelector:aSelector];
    if (!result) result = [_page respondsToSelector:aSelector];
    return result;
}

- (id) self; { return _page; }

- (BOOL)isEqual:(id)object;
{
    // Swap the comparison round so if the other object is also a proxy comparison will *then* boil down to comparing the pages
    BOOL result = [object isEqual:_page];
    return result;
}

- (NSUInteger)hash; { return [_page hash]; }

#pragma mark Children

- (BOOL)isLeaf; { return ![_page isCollection]; }
+ (NSSet *)keyPathsForValuesAffectingIsLeaf; { return [NSSet setWithObject:@"representedObject.isCollection"]; }

- (NSArray *)childNodes;
{
    if (!_childNodes && ![self isLeaf])
    {
        // Create pages controller on-demand
        if (!_childPagesController)
        {
            _childPagesController = [[SVPagesController controllerWithPagesInCollection:_page] retain];
            
            [_childPagesController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:NULL];
        }
        
        
        // Build nodes to represent each child page
        NSArray *pages = [_childPagesController arrangedObjects];
        _childNodes = [[NSMutableArray alloc] initWithCapacity:[pages count]];
        
        for (SVSiteItem *aPage in pages)
        {
            SVPageProxy *proxy = [SVPageProxy proxyForTargetPage:aPage];
            [_childNodes addObject:proxy];
        }
    }
    
    return [[_childNodes copy] autorelease];
}

- (void)insertObject:(SVPageProxy *)proxy inChildNodesAtIndex:(NSUInteger)index;
{
    // Be sure self and pages controller aren't out of sync
    OBPRECONDITION([_childNodes isEqualToArray:[_childPagesController arrangedObjects]]);
    
    
    _syncingChildren = YES;
    @try
    {
        [_childPagesController insertObject:[proxy representedObject] atArrangedObjectIndex:index];
        [_childNodes insertObject:proxy atIndex:index];
    }
    @finally {
        _syncingChildren = NO;
    }
    
    
    OBPOSTCONDITION([_childNodes isEqualToArray:[_childPagesController arrangedObjects]]);
}

- (void)removeObjectFromChildNodesAtIndex:(NSUInteger)index;
{
    // Be sure self and pages controller aren't out of sync
    OBPRECONDITION([_childNodes isEqualToArray:[_childPagesController arrangedObjects]]);
    
    
    // Called by tree controller to remove an object. We'll pass on to pages controller to handle, and should bubble back up to us, modifying .childNodes
    
    _syncingChildren = YES;
    @try
    {
        [_childPagesController removeObjectAtArrangedObjectIndex:index];
        [_childNodes removeObjectAtIndex:index];
    }
    @finally
    {
        _syncingChildren = NO;
    }
    
    
    OBPOSTCONDITION([_childNodes isEqualToArray:[_childPagesController arrangedObjects]]);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    if (!_syncingChildren)
    {
		// Don't bother if nothing actually changed.
        // Yes this is a slight efficiency boost, but more importantly on Leopard I was seeing steps like so:
        //
        // 1. Tree controller starts observing
        // 2. Act of observing, faults in an object, firing a change notification
        // 3. SVPagesController sees that change and rearranges its content
        // 4. We observe that change and notify that .childNodes is changing
        // 5. Tree Controller sees that change, tries to respond and throws an exception because it's not ready yet!
        //
        // By ignoring the change when nothing really happened, everyone's happy
        //
		if ([_childNodes isEqualToArray:[object arrangedObjects]]) return;
		
        
        [self willChangeValueForKey:@"childNodes"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SVPageProxyWillChange" object:self];
        
        // Clear out child nodes and rebuild on-demand. If there's no observers, means doing no work now
        NSArray *oldChildren = _childNodes; _childNodes = nil;  // hang on to till after the change
        [self didChangeValueForKey:@"childNodes"];
        [oldChildren release];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SVPageProxyDidChange" object:self];
    }
}

#pragma mark KVC

- (id)valueForUndefinedKey:(NSString *)key;
{
    return [_page valueForKey:key];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key;
{
    [_page setValue:value forKey:key];
}

- (NSMutableArray *)XmutableArrayValueForKeyPath:(NSString *)keyPath
{
    return [_page mutableArrayValueForKeyPath:keyPath];
}

- (NSMutableArray *)XmutableArrayValueForKey:(NSString *)keyPath;
{
    return [_page mutableArrayValueForKey:keyPath];
}

- (NSMutableSet *)mutableSetValueForKeyPath:(NSString *)keyPath
{
    return [_page mutableSetValueForKeyPath:keyPath];
}

#pragma mark KVO

/*  Forward all KVO messages on to the page except those few properties that belong to self
 *  TODO: have a method that checks for known keys rather than repeating the same if statement
 *
 */
- (void)addObserver:(NSObject *)observer
         forKeyPath:(NSString *)keyPath
            options:(NSKeyValueObservingOptions)options
            context:(void *)context;
{
    if ([keyPath isEqualToString:@"childNodes"] || [keyPath isEqualToString:@"isLeaf"])
    {
        [super addObserver:observer forKeyPath:keyPath options:options context:context];
    }
    else
    {
        [_page addObserver:observer forKeyPath:keyPath options:options context:context];
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath;
{
    if ([keyPath isEqualToString:@"childNodes"] || [keyPath isEqualToString:@"isLeaf"])
    {
        [super removeObserver:observer forKeyPath:keyPath];
    }
    else
    {
        [_page removeObserver:observer forKeyPath:keyPath];
    }
}

@end


