//
//  DTCSSStylesheet.m
//  CoreTextExtensions
//
//  Created by Oliver Drobnik on 9/5/11.
//  Copyright (c) 2011 Drobnik.com. All rights reserved.
//

#import "DTCSSStylesheet.h"
#import "DTCSSListStyle.h"

#import "DTHTMLElement.h"
#import "NSScanner+HTML.h"
#import "NSString+CSS.h"

#define DEFAULT_CSS         @"html{display:block;}head{display:none;}title{display:none;}style{display:none;}body{display:block;}article,aside,footer,header,hgroup,nav,section{display:block;}p{display:block;-webkit-margin-before:1em;-webkit-margin-after:1em;-webkit-margin-start:0;-webkit-margin-end:0;}ul,menu,dir{display:block;list-style-type:disc;-webkit-margin-before:1em;-webkit-margin-after:1em;-webkit-margin-start:0;-webkit-margin-end:0;-webkit-padding-start:40px;}li{display:list-item;}ol{display:block;list-style-type:decimal;-webkit-margin-before:1em;-webkit-margin-after:1em;-webkit-margin-start:0;-webkit-margin-end:0;-webkit-padding-start:40px;}code{font-family:Courier;}pre{font-family:Courier;}/* color:-webkit-link */a{color:#0000EE;text-decoration:underline;}center{text-align:center;display:block;}strong,b{font-weight:bolder;}i,em{font-style:italic;}u{text-decoration:underline;}big{font-size:bigger;}small{font-size:smaller;}sub{font-size:smaller;vertical-align:sub;}sup{font-size:smaller;vertical-align:super;}s,strike,del{text-decoration:line-through;}tt,code,kbd,samp{font-family:monospace;}pre,xmp,plaintext,listing{display:block;font-family:monospace;white-space:pre;margin-top:1em;margin-right:0;margin-bottom:1em;margin-left:0;}h1{display:block;font-size:2em;-webkit-margin-before:.67em;-webkit-margin-after:.67em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}h2{display:block;font-size:1.5em;-webkit-margin-before:.83em;-webkit-margin-after:.83em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}h3{display:block;font-size:1.17em;-webkit-margin-before:1em;-webkit-margin-after:1em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}h4{display:block;-webkit-margin-before:1.33em;-webkit-margin-after:1.33em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}h5{display:block;font-size:.83em;-webkit-margin-before:1.67em;-webkit-margin-after:1.67em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}h6{display:block;font-size:.67em;-webkit-margin-before:2.33em;-webkit-margin-after:2.33em;-webkit-margin-start:0;-webkit-margin-end:0;font-weight:bold;}div {display: block;}link {display: none;}meta {display: none;}script {display: none;}"

// external symbols generated via custom build rule and xxd
//extern unsigned char default_css[];
//extern unsigned int default_css_len;


@interface DTCSSStylesheet ()

@property (nonatomic, strong) NSMutableDictionary *styles;

@end


@implementation DTCSSStylesheet
{
	NSMutableDictionary *_styles;
	
}

+ (DTCSSStylesheet *)defaultStyleSheet
{
	NSString *cssString = DEFAULT_CSS;
	// get the data from the external symbol
	//NSData *data = [NSData dataWithBytes:default_css length:default_css_len];
	//NSString *cssString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	return [[DTCSSStylesheet alloc] initWithStyleBlock:cssString];
}

- (id)initWithStyleBlock:(NSString *)css
{
	self = [super init];
	
	if (self)
	{
		_styles	= [[NSMutableDictionary alloc] init];	
		
		[self parseStyleBlock:css];
	}
	
	return self;
}

- (id)initWithStylesheet:(DTCSSStylesheet *)stylesheet
{
	self = [super init];
	
	if (self)
	{
		[self mergeStylesheet:stylesheet];
	}
	
	return self;
}

- (NSString *)description
{
	return [_styles description];
}

- (void)uncompressShorthands:(NSMutableDictionary *)styles
{
	NSString *shortHand = [[styles objectForKey:@"list-style"] lowercaseString];
	
	if (shortHand)
	{
		[styles removeObjectForKey:@"list-style"];
		
		if ([shortHand isEqualToString:@"inherit"])
		{
			[styles setObject:@"inherit" forKey:@"list-style-type"];
			[styles setObject:@"inherit" forKey:@"list-style-position"];
			return;
		}
		
		NSArray *components = [shortHand componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
		
		BOOL typeWasSet = NO;
		BOOL positionWasSet = NO;
		
		DTCSSListStyleType listStyleType = DTCSSListStyleTypeNone;
		DTCSSListStylePosition listStylePosition = DTCSSListStylePositionInherit;
		
		for (NSString *oneComponent in components)
		{
			if ([oneComponent hasPrefix:@"url"])
			{
				// list-style-image
				NSScanner *scanner = [NSScanner scannerWithString:oneComponent];
				
				if ([scanner scanCSSURL:NULL])
				{
					[styles setObject:oneComponent forKey:@"list-style-image"];
					
					continue;
				}
			}
			
			if (!typeWasSet)
			{
				// check if valid type
				listStyleType = [DTCSSListStyle listStyleTypeFromString:oneComponent];
				
				if (listStyleType != DTCSSListStyleTypeInvalid)
				{
					[styles setObject:oneComponent forKey:@"list-style-type"];
					
					typeWasSet = YES;
					continue;
				}
			}
			
			if (!positionWasSet)
			{
				// check if valid position
				listStylePosition = [DTCSSListStyle listStylePositionFromString:oneComponent];
				
				if (listStylePosition != DTCSSListStylePositionInvalid)
				{
					[styles setObject:oneComponent forKey:@"list-style-position"];

					positionWasSet = YES;
					continue;
				}
			}
		}
		
		return;
	}
}

- (void)addStyleRule:(NSString *)rule withSelector:(NSString*)selectors
{
	NSArray *split = [selectors componentsSeparatedByString:@","];
	
	for (NSString *selector in split) 
	{
		NSString *cleanSelector = [selector stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		NSMutableDictionary *ruleDictionary = [[rule dictionaryOfCSSStyles] mutableCopy];

		// need to uncompress because otherwise we might get shorthands and non-shorthands together
		[self uncompressShorthands:ruleDictionary];
		
		NSDictionary *existingRulesForSelector = [self.styles objectForKey:cleanSelector];
		
		if (existingRulesForSelector) 
		{
			// substitute new rules over old ones
			NSMutableDictionary *tmpDict = [existingRulesForSelector mutableCopy];
			
			// append new rules
			[tmpDict addEntriesFromDictionary:ruleDictionary];

			// save it
			[self.styles setObject:tmpDict forKey:cleanSelector];
		}
		else 
		{
			[self.styles setObject:ruleDictionary forKey:cleanSelector];
		}
	}
}


// TODO: make parsing more robust, deal with comments properly
- (void)parseStyleBlock:(NSString*)css
{
	NSUInteger braceLevel = 0, braceMarker = 0;
	
	NSString* selector;
	
	NSInteger length = [css length];
	
	for (NSUInteger i = 0; i < length; i++) {
		
		unichar c = [css characterAtIndex:i];
		
		if (c == '/')
		{
			i++;
			// skip until closing /
			
			for (; i < length; i++)
			{
				if ([css characterAtIndex:i] == '/')
				{
					break;
				}
			}
			
			if (i < length)
			{
				braceMarker = i+1;
				continue;
			}
			else
			{
				// end of string
				return;
			}
		}
		
		
		// An opening brace! It could be the start of a new rule, or it could be a nested brace.
		if (c == '{') {
			
			// If we start a new rule...
			
			if (braceLevel == 0) 
			{
				// Grab the selector (we'll process it in a moment)
				selector = [css substringWithRange:NSMakeRange(braceMarker, i-braceMarker-1)];
				
				// And mark our position so we can grab the rule's CSS when it is closed
				braceMarker = i + 1;
			}
			
			// Increase the brace level.
			braceLevel += 1;
		}
		
		// A closing brace!
		else if (c == '}') 
		{
			// If we finished a rule...
			if (braceLevel == 1) 
			{
				NSString *rule = [css substringWithRange:NSMakeRange(braceMarker, i-braceMarker)];
				
				[self addStyleRule:rule withSelector: selector];
				
				braceMarker = i + 1;
			}
			
			braceLevel = MAX(braceLevel-1, 0);
		}
	}
}

- (NSDictionary *)mergedStyleDictionaryForElement:(DTHTMLElement *)element
{
	// We are going to combine all the relevant styles for this tag.
	// (Note that when styles are applied, the later styles take precedence,
	//  so the order in which we grab them matters!)

	NSMutableDictionary *tmpDict = [NSMutableDictionary dictionary];
	
	// Get based on element
	NSDictionary *byTagName = [self.styles objectForKey:element.tagName];
	
	if (byTagName) 
	{
		[tmpDict addEntriesFromDictionary:byTagName];
	}
	
    // Get based on class(es)
	NSString *classString = [element attributeForKey:@"class"];
	NSArray *classes = [classString componentsSeparatedByString:@" "];
	
	for (NSString *class in classes) 
	{
		NSString *classRule = [NSString stringWithFormat:@".%@", class];
		NSString *classAndTagRule = [NSString stringWithFormat:@"%@.%@", element.tagName, class];
		
		NSDictionary *byClass = [_styles objectForKey:classRule];
		NSDictionary *byClassAndName = [_styles objectForKey:classAndTagRule];
		
		if (byClass) 
		{
			[tmpDict addEntriesFromDictionary:byClass];
		}
		
		if (byClassAndName) 
		{
			[tmpDict addEntriesFromDictionary:byClassAndName];
		}
	}
	
	// Get based on id
	NSString *idRule = [NSString stringWithFormat:@"#%@", [element attributeForKey:@"id"]];
	NSDictionary *byID = [_styles objectForKey:idRule];
	
	if (byID) 
	{
		[tmpDict addEntriesFromDictionary:byID];
	}
	
	// Get tag's local style attribute
	NSString *styleString = [element attributeForKey:@"style"];
	
	if ([styleString length])
	{
		NSMutableDictionary *localStyles = [[styleString dictionaryOfCSSStyles] mutableCopy];
		
		// need to uncompress because otherwise we might get shorthands and non-shorthands together
		[self uncompressShorthands:localStyles];
	
		[tmpDict addEntriesFromDictionary:localStyles];
	}
	
	if ([tmpDict count])
	{
		return tmpDict;
	}
	else
	{
		return nil;
	}
}

- (void)mergeStylesheet:(DTCSSStylesheet *)stylesheet
{
	[self.styles addEntriesFromDictionary:stylesheet.styles];
}


#pragma mark Properties

- (NSMutableDictionary *)styles
{
	if (!_styles)
	{
		_styles = [[NSMutableDictionary alloc] init];
	}
	
	return _styles;
}

@synthesize styles = _styles;

@end
