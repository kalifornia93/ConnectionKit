//
//  KTExportEngine.h
//  Marvel
//
//  Created by Mike on 12/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


/*  KTPublishingEngine is an abstract class that provides the general publishing functionality.
 *  It has 2 concrete subclasses, both of which publish to the local file system:
 *
 *      A)  KTExportEngine provides support for simply exporting an entire site.
 *
 *      B)  KTLocalPublishingEngine adds support for staleness management and pinging a server etc.
 *          after publishing is complete. KTLocalPublishingEngine has further subclasses to support
 *          remote publishing.
 */


#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>


extern NSString *KTPublishingEngineErrorDomain;
enum {
	KTPublishingEngineErrorAuthenticationFailed,
	KTPublishingEngineErrorNoCredentialForAuthentication,
	KTPublishingEngineNothingToPublish,
};

typedef enum {
    KTPublishingEngineStatusNotStarted,
    KTPublishingEngineStatusParsing,        // Pages are being parsed one-by-one
    KTPublishingEngineStatusLoadingMedia,   // Parsing has finished, but there is still media to load
    KTPublishingEngineStatusUploading,      // All content has been generated, just waiting for queued uploads now
    KTPublishingEngineStatusFinished,
} KTPublishingEngineStatus;


@class KTDocumentInfo, KTAbstractPage, KTMediaFileUpload, KTHTMLTextBlock, KSSimpleURLConnection;
@protocol KTPublishingEngineDelegate;


@interface KTPublishingEngine : NSObject
{
@private
    KTDocumentInfo	*_documentInfo;
    NSString        *_documentRootPath;
    NSString        *_subfolderPath;    // nil if there is no subfolder
    
    KTPublishingEngineStatus            _status;
    id <KTPublishingEngineDelegate>     _delegate;
    
	id <CKConnection>	_connection;
    CKTransferRecord    *_rootTransferRecord;
    CKTransferRecord    *_baseTransferRecord;
    
    NSMutableSet            *_uploadedMedia;
    NSMutableArray          *_pendingMediaUploads;
    KSSimpleURLConnection   *_currentPendingMediaConnection;
    
    NSMutableSet        *_resourceFiles;
    NSMutableDictionary *_graphicalTextBlocks;
}

- (id)initWithSite:(KTDocumentInfo *)site
  documentRootPath:(NSString *)docRoot
     subfolderPath:(NSString *)subfolder;

// Delegate
- (id <KTPublishingEngineDelegate>)delegate;
- (void)setDelegate:(id <KTPublishingEngineDelegate>)delegate;

// Accessors
- (KTDocumentInfo *)site;
- (NSString *)documentRootPath;
- (NSString *)subfolderPath;
- (NSString *)baseRemotePath;

// Control
- (void)start;
- (void)cancel;
- (KTPublishingEngineStatus)status;

// Tranfer records
- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;

@end



@protocol KTPublishingEngineDelegate
- (void)publishingEngine:(KTPublishingEngine *)engine didBeginUploadToPath:(NSString *)remotePath;
- (void)publishingEngineDidFinishGeneratingContent:(KTPublishingEngine *)engine;
- (void)publishingEngineDidUpdateProgress:(KTPublishingEngine *)engine;

- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine;
- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error;
@end


@interface KTPublishingEngine (SubclassSupport)

// Control
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error;

// Connection
- (id <CKConnection>)connection;
- (void)setConnection:(id <CKConnection>)connection;
- (void)createConnection;

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;

// Pages
- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTAbstractPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;

// Media
- (NSSet *)uploadedMedia;
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media;

// Design
- (void)uploadDesignIfNeeded;

- (void)addGraphicalTextBlock:(KTHTMLTextBlock *)textBlock;
- (CKTransferRecord *)uploadMainCSSIfNeeded;
- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData digest:(NSData **)outDigest;

// Resources
- (NSSet *)resourceFiles;
- (void)uploadResourceFiles;

@end

