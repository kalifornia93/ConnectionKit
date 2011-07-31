//
//  NSTemplateParser.h
//  Sandvox
//
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#import <Cocoa/Cocoa.h>
#import "KSWriter.h"
#import "NSString+Karelia.h"    // for ComparisonType


@class KTHTMLParserMasterCache;


@interface SVTemplateParser : NSObject <KSWriter>
{
  @private
	NSString				*myID;
	NSString				*myTemplate;
	id						myComponent;
	KTHTMLParserMasterCache	*myCache;
	SVTemplateParser		*myParentParser;	// Weak ref
	
    id <KSWriter> _writer;  // weak ref, only used mid-parse
	NSMutableDictionary	*myOverriddenKeys;
	
	NSUInteger  _ifFunctionDepth;
    NSUInteger  _foreachFunctionDepth;
	BOOL		_lastCharacterWrittenWasNewline;
}

- (id)initWithTemplate:(NSString *)templateString component:(id)parsedComponent;
- (id)initWithOutputWriter:(id <KSWriter>)output;

// Accessors
- (NSString *)parserID;
- (NSString *)template;
- (id)component;

// KVC Overrides
- (NSSet *)overriddenKeys;
- (void)overrideKey:(NSString *)key withValue:(id)override;
- (void)removeOverrideForKey:(NSString *)key;

// Child parsers
- (id)parentParser;
- (id)newChildParserWithTemplate:(NSString *)templateString component:(id)component;


#pragma mark Parsing

+ (BOOL)parseTemplate:(NSString *)aTemplate
            component:(id)component
        writeToStream:(id <KSWriter>)context;

- (BOOL)parseWithOutputWriter:(id <KSWriter>)context;
- (BOOL)prepareToParse;

- (void)willWriteKeyPath;

- (id)parseValue:(NSString *)inString;
- (NSString *)componentLocalizedString:(NSString *)tag;
- (NSString *)componentTargetLocalizedString:(NSString *)tag;
- (NSString *)mainBundleLocalizedString:(NSString *)tag;


#pragma mark If function

- (BOOL)compareLeft:(NSString *)left
              right:(NSString *)right
     comparisonType:(ComparisonType)comparisonType;

- (BOOL)compareIfStatement:(ComparisonType)comparisonType
                 leftValue:(id)leftValue
                rightValue:(id)rightValue;

- (BOOL)isNotEmpty:(id)aValue;


#pragma mark Foreach loops
- (BOOL)evaluateForeachLoopWithArray:(NSArray *)components
                     iterationsCount:(NSUInteger)specifiedNumberIterations
                             keyPath:(NSString *)keyPath
                              scaner:(NSScanner *)inScanner;
- (BOOL)doForeachIterationWithObject:(id)object
    template:(NSString *)stuffToRepeat
    keyPath:(NSString *)keyPath;


#pragma mark Support

@property(nonatomic, retain, readonly) KTHTMLParserMasterCache *cache;
- (void)didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object;
+ (NSDictionary *)parametersDictionaryWithString:(NSString *)parametersString;


@end


@interface NSObject (KTTemplateParserAdditions)
- (NSString *)templateParserStringValue;
@end
