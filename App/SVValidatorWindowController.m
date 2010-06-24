//
//  SVHTMLValidatorController.m
//  Sandvox
//
//  Created by Dan Wood on 2/16/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVValidatorWindowController.h"
#import "KSProgressPanel.h"
#import "NSString+Karelia.h"
#import "KSSilencingConfirmSheet.h"


@implementation SVValidatorWindowController


- (void) validateSource:(NSString *)pageSource charset:(NSString *)charset docTypeString:(NSString *)docTypeString windowForSheet:(NSWindow *)aWindow;
{
#if DEBUG
	// pageSource = [@"fjsklfjdslkjfld <b><bererej>" stringByAppendingString:pageSource];		// TESTING -- FORCE INVALID MARKUP
#endif
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	NSString *pathHeaders = [NSTemporaryDirectory() stringByAppendingPathComponent:@"headers.txt"];

	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"--max-time 6 -F uploaded_file=@%@ -F ss=1 -F verbose=1 --dump-header %@ http://validator.w3.org/check", path, pathHeaders];
	NSArray *args = [argString componentsSeparatedByString:@" "];
	
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/curl"];
	[task setArguments:args];
	
	[[NSFileManager defaultManager] createFileAtPath:pathOut contents:[NSData data] attributes:nil];
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathOut];
	[task setStandardOutput:fileHandle];
	
#ifndef DEBUG
	// Non-debug builds should throw away stderr
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
	
	// Put up a progress panel. Alas, there is no cancel button.  How can we allow escape to cancel this?
	
    KSProgressPanel *progressPanel = [[KSProgressPanel alloc] init];
	[progressPanel setMessageText:NSLocalizedString(@"Fetching results…", @"Title of progress dialog")];
	[progressPanel setInformativeText:nil];
	[progressPanel setIndeterminate:YES];
	[progressPanel beginSheetModalForWindow:aWindow];

	[task launch];
	
	// Ideally I'd let some events come through like modal events.  Not sure if I want to start up a modal run loop?
	while ([task isRunning])
	{
		[NSThread sleepUntilDate:[NSDate distantPast]];
	}
	
	[progressPanel endSheet];
    [progressPanel release];

	int status = [task terminationStatus];
	
	if (0 == status)
	{		
		// Scrape page to get status, to show success or failure.
		NSString *resultingPageString = [[[NSString alloc] initWithContentsOfFile:pathOut
																		 encoding:NSUTF8StringEncoding
																			error:nil] autorelease];
		
		// TODO: continue case 27254, parse headers.txt file instead of scraping.
		NSError *error;
		NSString *headers = [NSString stringWithContentsOfFile:pathHeaders encoding:NSUTF8StringEncoding error:&error];
		NSDictionary *headerDict = [headers parseHTTPHeaders];

		int numErrors = [[headerDict objectForKey:@"X-W3C-Validator-Errors"] intValue];
		int numWarnings = [[headerDict objectForKey:@"X-W3C-Validator-Warnings"] intValue];
		BOOL isValid = [[headerDict objectForKey:@"X-W3C-Validator-Status"] isEqualToString:@"Valid"];	// Valid, Invalid, Abort
		NSString *explanation = NSLocalizedString(@"(none provided)", "indicator that not explanation was provided to HTML validation success");	// needs to be scraped
		
		if (nil != resultingPageString)
		{
			NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
			if (NSNotFound != foundValidRange.location)
			{
				explanation = [resultingPageString substringWithRange:foundValidRange];
			}
		}
		
		if (isValid)	// no need to show HTML, just announce that it's OK
		{
			NSRunInformationalAlertPanelRelativeToWindow(
				NSLocalizedString(@"Congratulations!  The HTML is valid.",@"Title of results alert"),
				NSLocalizedString(@"The validator returned the following status message:\n\n%@",@""),
				nil,nil,nil, aWindow, explanation);
		}
		else
		{
			// show window
			NSString *errorCountString = nil;
			NSString *warningCountString = nil;
			switch (numErrors)
			{
				case 0: errorCountString = NSLocalizedString(@"No errors", @""); break;
				case 1: errorCountString = NSLocalizedString(@"1 error", @""); break;
				default: errorCountString = [NSString stringWithFormat:NSLocalizedString(@"%d errors", @"<count> errors"), numErrors]; break;
			}
			switch (numWarnings)
			{
				case 0: warningCountString = NSLocalizedString(@"No warnings", @""); break;
				case 1: warningCountString = NSLocalizedString(@"1 warning", @""); break;
				default: warningCountString = [NSString stringWithFormat:NSLocalizedString(@"%d warnings", @"<count> warnings"), numWarnings]; break;
			}
			
			[[self window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"Validator Results: %@, %@", "HTML Validator Window Title. Followed by <count> errors, <count> warnings"), errorCountString, warningCountString]];
			[[self window] setFrameAutosaveName:@"ValidatorWindow"];
			[self showWindow:nil];
			
			WebPreferences *newPrefs = [[[WebPreferences alloc] initWithIdentifier:@"validator"] autorelease];
			[newPrefs setUserStyleSheetEnabled:YES];
			NSString *cssPath = [[NSBundle mainBundle] pathForResource:@"validator" ofType:@"css"];
			[newPrefs setUserStyleSheetLocation:[NSURL fileURLWithPath:cssPath]];
			[oWebView setPreferences:newPrefs];
			
			// Insert our own message
			NSString *headline = NSLocalizedString(@"Explanation and Impact", @"Header, shown above Explanation Text for validator output");
			NSString *explanation1Fmt = NSLocalizedString(
@"When the W3C validator detects errors, this means that either the raw HTML that you have entered yourself, or possibly the HTML generated by Sandvox, is not properly formatted (for the specified HTML style, %@).", @"Explanation Text for validator output");
			NSString *explanation1 = [NSString stringWithFormat:explanation1Fmt, docTypeString];
			NSString *explanation2 = NSLocalizedString(
														  @"In many cases your page will render just fine in most browsers — most large companies have HTML that does not pass validation on their pages — but in some cases this will explain why your page does look right.", @"Explanation Text for validator output");
			NSString *explanation3 = NSLocalizedString(
														  @"If you are experiencing problems with how your website displays on certain browsers, you should fix any error messages in the HTML elements that you put onto your page (including code injection), or adjust the HTML style specified for this page to be a less restrictive syntax.", @"Explanation Text for validator output");
		
			NSString *appIconPath = [[NSBundle mainBundle] pathForImageResource:@"AppIcon"];
			NSURL *appIconURL = [NSURL fileURLWithPath:appIconPath];
			
			// WORK-AROUND ... can't load file:// when I have baseURL set, which I need for links to "#" sections to work!
			appIconURL = [NSURL URLWithString:@"http://www.karelia.com/images/SandvoxAppIcon128.png"];
			
			NSString *replacementString = [NSString stringWithFormat:@"</h2>\n<h3>%@</h3>\n<div id='appicon'><img src='%@' width='64' height='64' alt='' /></div>\n<div id='explain-impact'>\n<p>%@</p>\n<p>%@</p>\n<p>%@</p>\n</div>\n",
										   [headline stringByEscapingHTMLEntities],
										   [appIconURL absoluteString],
										   [explanation1 stringByEscapingHTMLEntities],
										   [explanation2 stringByEscapingHTMLEntities],
										   [explanation3 stringByEscapingHTMLEntities]];
			
			resultingPageString = [resultingPageString stringByReplacing:@"</h2>" with:replacementString];
			
			[[oWebView mainFrame] loadHTMLString:resultingPageString
										 baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
			
		}
	}
	else	// Don't show window; show alert sheet attached to document
	{
		[KSSilencingConfirmSheet
		 alertWithWindow:aWindow
		 silencingKey:@"shutUpValidateError"
		 title:NSLocalizedString(@"Unable to Validate",@"Title of alert")
		 format:NSLocalizedString(@"Unable to contact validator.w3.org to perform the validation.", @"error message")];
	}

}






@end
