//
//  DTHTMLAttributedStringBuilder.m
//  DTCoreText
//
//  Created by Oliver Drobnik on 21.01.12.
//  Copyright (c) 2012 Drobnik.com. All rights reserved.
//

#import "DTHTMLAttributedStringBuilder.h"

#import "DTCoreTextConstants.h"
#import "DTCSSStylesheet.h"
#import "DTCoreTextFontDescriptor.h"
#import "DTCoreTextParagraphStyle.h"

#import "DTColor+HTML.h"
#import "DTImage+HTML.h"

#import "NSString+HTML.h"
#import "NSString+CSS.h"
#import "NSMutableString+HTML.h"


@interface DTHTMLAttributedStringBuilder ()

- (void)_registerTagStartHandlers;
- (void)_registerTagEndHandlers;

@end


@implementation DTHTMLAttributedStringBuilder
{
	NSData *_data;
	NSDictionary *_options;
	
	// settings for parsing
	CGFloat textScale;
	DTColor *defaultLinkColor;
	DTCSSStylesheet *_globalStyleSheet;
	NSURL *baseURL;
	DTCoreTextFontDescriptor *defaultFontDescriptor;
	DTCoreTextParagraphStyle *defaultParagraphStyle;
	
	// parsing state, accessed from inside blocks
	NSMutableAttributedString *tmpString;
	NSMutableString *_currentTagContents;
	
	DTHTMLElement *currentTag;
	BOOL needsListItemStart;
	BOOL needsNewLineBefore;
	BOOL outputHasNewline;
	BOOL currentTagIsEmpty; // YES for each opened tag, NO for anything flushed including hr, br, img -> adds an extra NL for <p></p>
	
	// GCD
	dispatch_queue_t _stringAssemblyQueue;
	dispatch_group_t _stringAssemblyGroup;
	dispatch_queue_t _stringParsingQueue;
	dispatch_group_t _stringParsingGroup;
	
	// lookup table for blocks that deal with begin and end tags
	NSMutableDictionary *_tagStartHandlers;
	NSMutableDictionary *_tagEndHandlers;
	
	DTHTMLAttributedStringBuilderWillFlushCallback _willFlushCallback;
}

- (id)initWithHTML:(NSData *)data options:(NSDictionary *)options documentAttributes:(NSDictionary **)dict
{
	self = [super init];
	if (self)
	{
		_data = data;
		_options = options;
		
		// documentAttributes ignored for now
		
		// register default handlers
		[self _registerTagStartHandlers];
		[self _registerTagEndHandlers];
		
		//GCD setup
		_stringAssemblyQueue = dispatch_queue_create("DTHTMLAttributedStringBuilder", 0);
		_stringAssemblyGroup = dispatch_group_create();
		_stringParsingQueue = dispatch_queue_create("DTHTMLAttributedStringBuilderParser", 0);
		_stringParsingGroup = dispatch_group_create();
	}
	
	return self;	
}

- (void)dealloc 
{
	dispatch_release(_stringAssemblyQueue);
	dispatch_release(_stringAssemblyGroup);
	dispatch_release(_stringParsingQueue);
	dispatch_release(_stringParsingGroup);
}

- (BOOL)buildString
{
	// only with valid data
	if (![_data length])
	{
		return NO;
	}
	
 	// Specify the appropriate text encoding for the passed data, default is UTF8 
	NSString *textEncodingName = [_options objectForKey:NSTextEncodingNameDocumentOption];
	NSStringEncoding encoding = NSUTF8StringEncoding; // default
	
	if (textEncodingName)
	{
		CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((__bridge CFStringRef)textEncodingName);
		encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
	}
	
	// custom option to scale text
	textScale = [[_options objectForKey:NSTextSizeMultiplierDocumentOption] floatValue];
	if (!textScale)
	{
		textScale = 1.0f;
	}
	
	// use baseURL from options if present
	baseURL = [_options objectForKey:NSBaseURLDocumentOption];
	
	
	// Make it a string
	NSString *htmlString;
	
	if (encoding == NSUTF8StringEncoding)
	{
		// this method can fix malformed UTF8
		htmlString = [[NSString alloc] initWithPotentiallyMalformedUTF8Data:_data];
	}
	else
	{
		// use the specified encoding
		htmlString = [[NSString alloc] initWithData:_data encoding:encoding];
	}
	
	if (!htmlString)
	{
		return NO;
	}
	
	// the combined style sheet for entire document
	_globalStyleSheet = [DTCSSStylesheet defaultStyleSheet]; 
	
	// do we have a default style sheet passed as option?
	DTCSSStylesheet *defaultStylesheet = [_options objectForKey:DTDefaultStyleSheet];
	if (defaultStylesheet) 
	{
		// merge the default styles to the combined style sheet
		[_globalStyleSheet mergeStylesheet:defaultStylesheet];
	}
	
	// for performance we will return this mutable string
	tmpString = [[NSMutableAttributedString alloc] init];
	
	needsListItemStart = NO;
	needsNewLineBefore = NO;
	
	// we cannot skip any characters, NLs turn into spaces and multi-spaces get compressed to singles
	NSScanner *scanner = [NSScanner scannerWithString:htmlString];
	scanner.charactersToBeSkipped = nil;
	
	// base tag with font defaults
	defaultFontDescriptor = [[DTCoreTextFontDescriptor alloc] initWithFontAttributes:nil];
	defaultFontDescriptor.pointSize = 12.0f * textScale;
	
	NSString *defaultFontFamily = [_options objectForKey:DTDefaultFontFamily];
	if (defaultFontFamily)
	{
		defaultFontDescriptor.fontFamily = defaultFontFamily;
	}
	else
	{
		defaultFontDescriptor.fontFamily = @"Times New Roman";
	}
	
	defaultLinkColor = [_options objectForKey:DTDefaultLinkColor];
	
	if (defaultLinkColor)
	{
		if ([defaultLinkColor isKindOfClass:[NSString class]])
		{
			// convert from string to color
			defaultLinkColor = [DTColor colorWithHTMLName:(NSString *)defaultLinkColor];
		}
		
		// get hex code for t   he passed color
		NSString *colorHex = [defaultLinkColor htmlHexString];
		
		// overwrite the style
		NSString *styleBlock = [NSString stringWithFormat:@"a {color:#%@;}", colorHex];
		[_globalStyleSheet parseStyleBlock:styleBlock];
	}
	
	// default is to have A underlined
	NSNumber *linkDecorationDefault = [_options objectForKey:DTDefaultLinkDecoration];
	
	if (linkDecorationDefault)
	{
		if (![linkDecorationDefault boolValue])
		{
			// remove default decoration
			[_globalStyleSheet parseStyleBlock:@"a {text-decoration:none;}"];
		}
	}
	
	// default paragraph style
	defaultParagraphStyle = [DTCoreTextParagraphStyle defaultParagraphStyle];
	
	NSNumber *defaultLineHeightMultiplierNum = [_options objectForKey:DTDefaultLineHeightMultiplier];
	
	if (defaultLineHeightMultiplierNum)
	{
		CGFloat defaultLineHeightMultiplier = [defaultLineHeightMultiplierNum floatValue];
		defaultParagraphStyle.lineHeightMultiple = defaultLineHeightMultiplier;
	}
	
	NSNumber *defaultTextAlignmentNum = [_options objectForKey:DTDefaultTextAlignment];
	
	if (defaultTextAlignmentNum)
	{
		defaultParagraphStyle.textAlignment = (CTTextAlignment)[defaultTextAlignmentNum integerValue];
	}
	
	NSNumber *defaultFirstLineHeadIndent = [_options objectForKey:DTDefaultFirstLineHeadIndent];
	if (defaultFirstLineHeadIndent)
	{
		defaultParagraphStyle.firstLineIndent = [defaultFirstLineHeadIndent integerValue];
	}
	
	NSNumber *defaultHeadIndent = [_options objectForKey:DTDefaultHeadIndent];
	if (defaultHeadIndent)
	{
		defaultParagraphStyle.headIndent = [defaultHeadIndent integerValue];
	}
	
	NSNumber *defaultListIndent = [_options objectForKey:DTDefaultListIndent];
	if (defaultListIndent)
	{
		defaultParagraphStyle.listIndent = [defaultListIndent integerValue];
	}
	
	DTHTMLElement *defaultTag = [[DTHTMLElement alloc] init];
	defaultTag.fontDescriptor = defaultFontDescriptor;
	defaultTag.paragraphStyle = defaultParagraphStyle;
	defaultTag.textScale = textScale;
	
	id defaultColor = [_options objectForKey:DTDefaultTextColor];
	if (defaultColor)
	{
		if ([defaultColor isKindOfClass:[DTColor class]])
		{
			// already a DTColor
			defaultTag.textColor = defaultColor;
		}
		else
		{
			// need to convert first
			defaultTag.textColor = [DTColor colorWithHTMLName:defaultColor];
		}
	}
	
	
	currentTag = defaultTag; // our defaults are the root
	
	// create a parser
	DTHTMLParser *parser = [[DTHTMLParser alloc] initWithData:_data encoding:encoding];
	parser.delegate = (id)self;
	
	__block BOOL result;
	dispatch_group_async(_stringParsingGroup, _stringParsingQueue, ^{ result = [parser parse]; });
	
	// wait until all string assembly is complete
	dispatch_group_wait(_stringParsingGroup, DISPATCH_TIME_FOREVER);
	dispatch_group_wait(_stringAssemblyGroup, DISPATCH_TIME_FOREVER);
	
	return result;
}

- (NSAttributedString *)generatedAttributedString
{
	return tmpString;
}

#pragma mark GCD

- (void)_registerTagStartHandlers
{
	_tagStartHandlers = [[NSMutableDictionary alloc] init];
	
	void (^imgBlock)(void) = ^ 
	{
		// float causes the image to be its own block
		if (currentTag.floatStyle != DTHTMLElementFloatStyleNone)
		{
			currentTag.displayStyle = DTHTMLElementDisplayStyleBlock;
		}
		
		// hide contents of recognized tag
		currentTag.tagContentInvisible = YES;
		
		// make appropriate attachment
		DTTextAttachment *attachment = [DTTextAttachment textAttachmentWithElement:currentTag options:_options];
		
		// add it to tag
		currentTag.textAttachment = attachment;
		
		// to avoid much too much space before the image
		currentTag.paragraphStyle.lineHeightMultiple = 1;
		
		// specifiying line height interfers with correct positioning
		currentTag.paragraphStyle.minimumLineHeight = 0;
		currentTag.paragraphStyle.maximumLineHeight = 0;
		
		// caller gets opportunity to modify image tag before it is written
		if (_willFlushCallback)
		{
			_willFlushCallback(currentTag);
		}
		
		// maybe the image is forced to show as block, then we want a newline before and after
		if (currentTag.displayStyle == DTHTMLElementDisplayStyleBlock)
		{
			needsNewLineBefore = YES;
		}
		
		if (needsNewLineBefore)
		{
			if ([tmpString length] && !outputHasNewline)
			{
				[tmpString appendNakedString:@"\n"];
				outputHasNewline = YES;
			}
			
			needsNewLineBefore = NO;
		}
		
		// add it to output
		[tmpString appendAttributedString:[currentTag attributedString]];	
		outputHasNewline = NO;
		currentTagIsEmpty = NO;
		
//		if (currentTag.displayStyle == DTHTMLElementDisplayStyleBlock)
//		{
//			needsNewLineBefore = YES;
//		}
	};
	
	[_tagStartHandlers setObject:[imgBlock copy] forKey:@"img"];
	
	
	void (^blockquoteBlock)(void) = ^ 
	{
		currentTag.paragraphStyle.headIndent += 25.0 * textScale;
		currentTag.paragraphStyle.firstLineIndent = currentTag.paragraphStyle.headIndent;
		currentTag.paragraphStyle.paragraphSpacing = defaultFontDescriptor.pointSize;
	};
	
	[_tagStartHandlers setObject:[blockquoteBlock copy] forKey:@"blockquote"];
	
	
	void (^objectBlock)(void) = ^ 
	{
		// hide contents of recognized tag
		currentTag.tagContentInvisible = YES;
		
		// make appropriate attachment
		DTTextAttachment *attachment = [DTTextAttachment textAttachmentWithElement:currentTag options:_options];
		
		// add it to tag
		currentTag.textAttachment = attachment;
		
		// to avoid much too much space before the image
		currentTag.paragraphStyle.lineHeightMultiple = 1;
		
		// add it to output
		[tmpString appendAttributedString:[currentTag attributedString]];
		outputHasNewline = NO;
	};
	
	[_tagStartHandlers setObject:[objectBlock copy] forKey:@"object"];
	[_tagStartHandlers setObject:[objectBlock copy] forKey:@"video"];
	[_tagStartHandlers setObject:[objectBlock copy] forKey:@"iframe"];
	
	
	void (^aBlock)(void) = ^ 
	{
		if (currentTag.isColorInherited || !currentTag.textColor)
		{
			currentTag.textColor = defaultLinkColor;
			currentTag.isColorInherited = NO;
		}
		
		// remove line breaks and whitespace in links
		NSString *cleanString = [[currentTag attributeForKey:@"href"] stringByReplacingOccurrencesOfString:@"\n" withString:@""];
		cleanString = [cleanString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		NSURL *link = [NSURL URLWithString:cleanString];
		
		// deal with relative URL
		if (![link scheme])
		{
			if ([cleanString length])
			{
				link = [NSURL URLWithString:cleanString relativeToURL:baseURL];
				
				if (!link)
				{
					// NSURL did not like the link, so let's encode it
					cleanString = [cleanString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
					
					link = [NSURL URLWithString:cleanString relativeToURL:baseURL];
				}
			}
			else
			{
				link = baseURL;
			}
		}
		
		currentTag.link = link;
	};
	
	[_tagStartHandlers setObject:[aBlock copy] forKey:@"a"];
	
	
	void (^liBlock)(void) = ^ 
	{
		// have inherited the correct list counter from parent
		DTHTMLElement *counterElement = currentTag.parent;
		
		NSString *valueNum = [currentTag attributeForKey:@"value"];
		if (valueNum)
		{
			NSInteger value = [valueNum integerValue];
			counterElement.listCounter = value;
			currentTag.listCounter = value;
		}
		
		counterElement.listCounter++;
		
		needsListItemStart = YES;
		currentTag.paragraphStyle.paragraphSpacing = 0;
		currentTag.paragraphStyle.firstLineIndent = currentTag.paragraphStyle.headIndent;
		currentTag.paragraphStyle.headIndent += currentTag.paragraphStyle.listIndent;
		
		// first tab is to right-align bullet, numbering against
		CGFloat tabOffset = currentTag.paragraphStyle.headIndent - 5.0f*textScale;
		[currentTag.paragraphStyle addTabStopAtPosition:tabOffset alignment:kCTRightTextAlignment];
		
		// second tab is for the beginning of first line after bullet
		[currentTag.paragraphStyle addTabStopAtPosition:currentTag.paragraphStyle.headIndent alignment:	kCTLeftTextAlignment];			
	};
	
	[_tagStartHandlers setObject:[liBlock copy] forKey:@"li"];
	
	
	void (^olBlock)(void) = ^ 
	{
		NSString *valueNum = [currentTag attributeForKey:@"start"];
		if (valueNum)
		{
			NSInteger value = [valueNum integerValue];
			currentTag.listCounter = value;
		}
		else
		{
			currentTag.listCounter = 1;
		}
		
		needsNewLineBefore = YES;
	};
	
	[_tagStartHandlers setObject:[olBlock copy] forKey:@"ol"];
	
	
	void (^ulBlock)(void) = ^ 
	{
		needsNewLineBefore = YES;
		
		currentTag.listCounter = 0;
	};
	
	[_tagStartHandlers setObject:[ulBlock copy] forKey:@"ul"];
	
	
	void (^hrBlock)(void) = ^ 
	{
		// open block needs closing
		if (needsNewLineBefore)
		{
			if ([tmpString length] && !outputHasNewline)
			{
				[tmpString appendNakedString:@"\n"];
				outputHasNewline = YES;
			}
			
			needsNewLineBefore = NO;
		}
		
		currentTag.text = @"\n";
		
		NSMutableDictionary *styleDict = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"Dummy"];
		
		if (currentTag.backgroundColor)
		{
			[styleDict setObject:currentTag.backgroundColor forKey:@"BackgroundColor"];
		}
		[currentTag addAdditionalAttribute:styleDict forKey:@"DTHorizontalRuleStyle"];
		
		[tmpString appendAttributedString:[currentTag attributedString]];
		outputHasNewline = YES;
		currentTagIsEmpty = NO;
	};
	
	[_tagStartHandlers setObject:[hrBlock copy] forKey:@"hr"];
	
	
	void (^h1Block)(void) = ^ 
	{
			currentTag.headerLevel = 1;
	};
	[_tagStartHandlers setObject:[h1Block copy] forKey:@"h1"];

	
	void (^h2Block)(void) = ^ 
	{
		currentTag.headerLevel = 2;
	};
	[_tagStartHandlers setObject:[h2Block copy] forKey:@"h2"];

	
	void (^h3Block)(void) = ^ 
	{
		currentTag.headerLevel = 3;
	};
	[_tagStartHandlers setObject:[h3Block copy] forKey:@"h3"];
	
	
	void (^h4Block)(void) = ^ 
	{
		currentTag.headerLevel = 4;
	};
	[_tagStartHandlers setObject:[h4Block copy] forKey:@"h4"];

	
	void (^h5Block)(void) = ^ 
	{
		currentTag.headerLevel = 5;
	};
	[_tagStartHandlers setObject:[h5Block copy] forKey:@"h5"];
	
	
	void (^h6Block)(void) = ^ 
	{
		currentTag.headerLevel = 6;
	};
	[_tagStartHandlers setObject:[h6Block copy] forKey:@"h6"];

	
	void (^fontBlock)(void) = ^ 
	{
		NSInteger size = [[currentTag attributeForKey:@"size"] intValue];
		
		switch (size) 
		{
			case 1:
				currentTag.fontDescriptor.pointSize = textScale * 9.0f;
				break;
			case 2:
				currentTag.fontDescriptor.pointSize = textScale * 10.0f;
				break;
			case 4:
				currentTag.fontDescriptor.pointSize = textScale * 14.0f;
				break;
			case 5:
				currentTag.fontDescriptor.pointSize = textScale * 18.0f;
				break;
			case 6:
				currentTag.fontDescriptor.pointSize = textScale * 24.0f;
				break;
			case 7:
				currentTag.fontDescriptor.pointSize = textScale * 37.0f;
				break;	
			case 3:
			default:
				currentTag.fontDescriptor.pointSize = defaultFontDescriptor.pointSize;
				break;
		}
		
		NSString *face = [currentTag attributeForKey:@"face"];
		
		if (face)
		{
			currentTag.fontDescriptor.fontName = face;
			
			// face usually invalidates family
			currentTag.fontDescriptor.fontFamily = nil; 
		}
		
		NSString *color = [currentTag attributeForKey:@"color"];
		
		if (color)
		{
			currentTag.textColor = [DTColor colorWithHTMLName:color];       
		}
	};
	
	[_tagStartHandlers setObject:[fontBlock copy] forKey:@"font"];
	
	
	void (^pBlock)(void) = ^ 
	{
		currentTag.paragraphStyle.firstLineIndent = currentTag.paragraphStyle.headIndent + defaultParagraphStyle.firstLineIndent;
	};
	
	[_tagStartHandlers setObject:[pBlock copy] forKey:@"p"];
	
	
	void (^brBlock)(void) = ^ 
	{
		currentTag.text = UNICODE_LINE_FEED;
		
		// NOTE: cannot use flush because that removes the break
		[tmpString appendAttributedString:[currentTag attributedString]];
		outputHasNewline = NO;
		currentTagIsEmpty = NO;
	};
	
	[_tagStartHandlers setObject:[brBlock copy] forKey:@"br"];
}

- (void)_registerTagEndHandlers
{
	_tagEndHandlers = [[NSMutableDictionary alloc] init];
	
	void (^bodyBlock)(void) = ^ 
	{
		// if the last child was a block we need an extra \n
		if (needsNewLineBefore)
		{
			if ([tmpString length] && !outputHasNewline)
			{
				[tmpString appendString:@"\n"];
				outputHasNewline = YES;
			}
			
			needsNewLineBefore = NO;
		}
	};
	
	[_tagEndHandlers setObject:[bodyBlock copy] forKey:@"body"];
	
	
	void (^liBlock)(void) = ^ 
	{
		needsListItemStart = NO;
	};
	
	[_tagEndHandlers setObject:[liBlock copy] forKey:@"li"];
	

	void (^ulBlock)(void) = ^ 
	{
		if (currentTag.listDepth < 1)
		{
			// adjust spacing after last li to be the one defined for ol/ul
			NSRange effectiveRange;
			
			NSMutableDictionary *finalAttributes = [[tmpString attributesAtIndex:[tmpString length]-1 effectiveRange:&effectiveRange] mutableCopy];
			CTParagraphStyleRef style = (__bridge CTParagraphStyleRef)[finalAttributes objectForKey:(id)kCTParagraphStyleAttributeName];
			DTCoreTextParagraphStyle *paragraphStyle = [DTCoreTextParagraphStyle paragraphStyleWithCTParagraphStyle:style];
			
			if (paragraphStyle.paragraphSpacing != currentTag.paragraphStyle.paragraphSpacing)
			{
				paragraphStyle.paragraphSpacing = currentTag.paragraphStyle.paragraphSpacing;
			
				CTParagraphStyleRef newParagraphStyle = [paragraphStyle createCTParagraphStyle];
				[finalAttributes setObject:CFBridgingRelease(newParagraphStyle) forKey:(id)kCTParagraphStyleAttributeName];
			
				[tmpString setAttributes:finalAttributes range:effectiveRange];
			}
		}

	};
	
	[_tagEndHandlers setObject:[ulBlock copy] forKey:@"ul"];
	[_tagEndHandlers setObject:[ulBlock copy] forKey:@"ol"];
	
	void (^pBlock)(void) = ^ 
	{
		// we need to output something for <p></p>
		if (currentTagIsEmpty)
		{
			[tmpString appendString:@"\n"];
			outputHasNewline = NO;  // NO: otherwise a following needed NL is cancelled
		}
	};
	
	[_tagEndHandlers setObject:[pBlock copy] forKey:@"p"];
}

- (void)_handleTagContent:(NSString *)string
{
	NSAssert(dispatch_get_current_queue() == _stringAssemblyQueue, @"method called from invalid queue");
	
	if (!_currentTagContents)
	{
		_currentTagContents = [[NSMutableString alloc] initWithCapacity:1000];
	}
	
	[_currentTagContents appendString:string];
}


- (void)_flushCurrentTagContent:(NSString *)tagContent
{
	NSAssert(dispatch_get_current_queue() == _stringAssemblyQueue, @"method called from invalid queue");
	
	// trim newlines
	NSString *tagContents = tagContent;
	
	if (![tagContents length])
	{
		// nothing to do
		return;
	}
	
	if (currentTag.preserveNewlines)
	{
		[tagContent stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		
		tagContents = [tagContents stringByReplacingOccurrencesOfString:@"\n" withString:UNICODE_LINE_FEED];
	}
	else
	{
		tagContents = [tagContents stringByNormalizingWhitespace];
		
		if ([tagContents isEqualToString:@" "])
		{
			return;
		}
	}
	
	if (needsNewLineBefore)
	{
		if ([tagContents hasPrefix:@" "])
		{
			tagContents = [tagContents substringFromIndex:1];
		}
		
		if ([tmpString length])
		{
			if (!outputHasNewline)
			{
				[tmpString appendString:@"\n"];
				outputHasNewline = YES;
			}
		}
		
		needsNewLineBefore = NO;
	}
	else // might be a continuation of a paragraph, then we might need space before it
	{
		NSString *stringSoFar = [tmpString string];
		
		// prevent double spacing
		if ([stringSoFar hasSuffixCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] && [tagContents hasPrefix:@" "])
		{
			tagContents = [tagContents substringFromIndex:1];
		}
	}
	
	// if we start a list, then we wait until we have actual text
	if (needsListItemStart && [tagContents length] > 0 && ![tagContents isEqualToString:@" "])
	{
		NSAttributedString *prefixString = [currentTag prefixForListItem];
		
		if (prefixString)
		{
			[tmpString appendAttributedString:prefixString]; 
			outputHasNewline = NO;
		}
		
		needsListItemStart = NO;
	}
	
	// we don't want whitespace before first tag to turn into paragraphs
	if (!(currentTag.displayStyle == DTHTMLElementDisplayStyleNone) && !currentTag.tagContentInvisible)
	{
		currentTag.text = tagContents;
		
		if (_willFlushCallback)
		{
			_willFlushCallback(currentTag);
		}
		
		[tmpString appendAttributedString:[currentTag attributedString]];
		outputHasNewline = NO;
		
		// we've written something
		currentTagIsEmpty = NO;
	}	
	
	_currentTagContents = nil;
}

#pragma mark DTHTMLParser Delegate

- (void)parser:(DTHTMLParser *)parser didStartElement:(NSString *)elementName attributes:(NSDictionary *)attributeDict
{
	void (^tmpBlock)(void) = ^
	{
		DTHTMLElement *parent = currentTag;
		DTHTMLElement *nextTag = [currentTag copy];
		nextTag.tagName = elementName;
		nextTag.textScale = textScale;
		nextTag.attributes = attributeDict;
		[parent addChild:nextTag];
		
		// apply style from merged style sheet
		NSDictionary *mergedStyles = [_globalStyleSheet mergedStyleDictionaryForElement:nextTag];
		if (mergedStyles)
		{
			[nextTag applyStyleDictionary:mergedStyles];
		}

		// keep currentTag, might be used in flush
		if (_currentTagContents)
		{
			// remove whitespace suffix in current non-block item
			if (nextTag.displayStyle == DTHTMLElementDisplayStyleBlock)
			{
				if (currentTag.displayStyle != DTHTMLElementDisplayStyleBlock)
				{
					[_currentTagContents removeWhitespaceSuffix];
				}
			}

			[self _flushCurrentTagContent:_currentTagContents];
		}
		
		// keep track of something was flushed for this tag
		currentTagIsEmpty = YES;
		
		// switch to new tag
		currentTag = nextTag;
		
		if (currentTag.displayStyle == DTHTMLElementDisplayStyleNone)
		{
			// we don't care about the other stuff in META tags, but styles are inherited
			return;
		}
		
		if (currentTag.displayStyle == DTHTMLElementDisplayStyleBlock || currentTag.displayStyle == DTHTMLElementDisplayStyleListItem)
		{
			// make sure that we have a NL before text in this block
			needsNewLineBefore = YES;
		}
		
		// direction
		NSString *direction = [currentTag attributeForKey:@"dir"];
		
		if (direction)
		{
			NSString *lowerDirection = [direction lowercaseString];
			
			
			if ([lowerDirection isEqualToString:@"ltr"])
			{
				currentTag.paragraphStyle.writingDirection = kCTWritingDirectionLeftToRight;
			}
			else if ([lowerDirection isEqualToString:@"rtl"])
			{
				currentTag.paragraphStyle.writingDirection = kCTWritingDirectionRightToLeft;
			}
		}
		
		
//		// block items need a break before
//		if ([tmpString length])
//		{
//			if (!(currentTag.displayStyle == DTHTMLElementDisplayStyleInline) && !(currentTag.displayStyle == DTHTMLElementDisplayStyleNone) && !outputHasNewline)
//			{
//				[tmpString appendString:@"\n"];
//
//				outputHasNewline = YES;
//				needsNewLineBefore = NO;
//			}
//		}
		
		// find block to execute for this tag if any
		void (^tagBlock)(void) = [_tagStartHandlers objectForKey:elementName];
		
		if (tagBlock)
		{
			tagBlock();
		}
	};
	
	dispatch_group_async(_stringAssemblyGroup, _stringAssemblyQueue, tmpBlock);
}

- (void)parser:(DTHTMLParser *)parser didEndElement:(NSString *)elementName
{
	void (^tmpBlock)(void) = ^
	{
		if (_currentTagContents)
		{
			// trim off white space at end if block
			if (currentTag.displayStyle != DTHTMLElementDisplayStyleInline)
			{
				[_currentTagContents removeWhitespaceSuffix];
			}
			
			[self _flushCurrentTagContent:_currentTagContents];
		}
		
		// find block to execute for this tag if any
		void (^tagBlock)(void) = [_tagEndHandlers objectForKey:elementName];
		
		if (tagBlock)
		{
			tagBlock();
		}
		
		if (currentTag.displayStyle == DTHTMLElementDisplayStyleBlock)
		{
			needsNewLineBefore = YES;
		}
		
		// check if this tag is indeed closing the currently open one
		if ([elementName isEqualToString:currentTag.tagName])
		{
			DTHTMLElement *popChild = currentTag;
			currentTag = currentTag.parent;
			[currentTag removeChild:popChild];
		}
		else 
		{
			// Ignoring non-open tag
		}
	};
	
	dispatch_group_async(_stringAssemblyGroup, _stringAssemblyQueue, tmpBlock);
}

- (void)parser:(DTHTMLParser *)parser foundCharacters:(NSString *)string
{
	dispatch_group_async(_stringAssemblyGroup, _stringAssemblyQueue,^{
		[self _handleTagContent:string];	
	});
}

#pragma mark Properties

@synthesize willFlushCallback = _willFlushCallback;

@end
