//
//  GlyphImageSource.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSource.h"
#import "GlyphImageSourceController.h"
#import "NSString+MacOSaiX.h"
#import <fcntl.h>
#import <sys/types.h>
#import <sys/uio.h>
#import <unistd.h>


static NSImage	*glyphSourceImage = nil;


@interface MacOSaiXGlyphImageSource (PrivateMethods)
- (void)calculateBoundingRectForGlyphs;
@end


@implementation MacOSaiXGlyphImageSource


+ (void)load
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	NSString	*imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"GlyphImageSource"];
	glyphSourceImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
	
		// Seed the random number generator
	srandom(time(NULL));
	
	[pool release];
}


+ (NSImage *)image
{
	return glyphSourceImage;
}


+ (Class)editorClass
{
	return [MacOSaiXGlyphImageSourceController class];
}


+ (Class)preferencesControllerClass
{
	return nil;
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (NSArray *)builtInColorListNames
{
	return [NSArray arrayWithObjects:@"All Colors",
									 @"Grayscale", 
									 @"Redscale", 
									 @"Greenscale", 
									 @"Bluescale", 
									 @"Sepia Tone",
									 nil];
}


+ (NSString *)standardNameForGlyph:(UInt16)glyphNum
{
	static NSArray	*glyphNames = nil;
	
	if (!glyphNames)
	{
		NSString	*plistPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Glyph Names" ofType:@"plist"];
		
		glyphNames = [[NSArray arrayWithContentsOfFile:plistPath] retain];
	}
	
	return (glyphNum < [glyphNames count] ? [glyphNames objectAtIndex:glyphNum] : nil);
}


- (id)init
{
	if (self = [super init])
	{
		focusWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000.0, -10000.0, 512.0, 512.0)
							   styleMask:NSBorderlessWindowMask
							 backing:NSBackingStoreBuffered defer:NO];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(focusWindowWillClose:) 
													 name:NSWindowWillCloseNotification 
												   object:focusWindow];
		focusWindowLock = [[NSLock alloc] init];
		
		fontNames = [[NSMutableArray array] retain];
		colorLists = [[NSMutableDictionary dictionary] retain];
		
		glyphsDict = [[NSMutableDictionary dictionary] retain];
	}
	
	return self;
}


- (NSString *)settingsAsXMLElement
{
	NSMutableString	*settings = [NSMutableString string];
	
	[settings appendString:@"<FONTS>\n"];
	NSEnumerator	*fontNameEnumerator = [fontNames objectEnumerator];
	NSString		*fontName = nil;
	while (fontName = [fontNameEnumerator nextObject])
		[settings appendFormat:@"\t<FONT NAME=\"%@\"/>\n", [fontName stringByEscapingXMLEntites]];
	[settings appendString:@"</FONTS>\n"];
	
	[settings appendString:@"<COLORS>\n"];
	NSEnumerator	*colorListClassEnumerator = [colorLists keyEnumerator];
	NSString		*colorListClass = nil;
	while (colorListClass = [colorListClassEnumerator nextObject])
	{
		NSEnumerator	*colorListNameEnumerator = [[colorLists objectForKey:colorListClass] objectEnumerator];
		NSString		*colorListName = nil;
		while (colorListName = [colorListNameEnumerator nextObject])
			[settings appendFormat:@"\t<COLOR_LIST CLASS=\"%@\" NAME=\"%@\"/>\n", 
								   [colorListClass stringByEscapingXMLEntites],
								   [colorListName stringByEscapingXMLEntites]];
	}
	[settings appendString:@"</COLORS>\n"];
	
	if ([letterPool length] > 0)
		[settings appendFormat:@"<LETTERS>%@</LETTERS>\n", [letterPool stringByEscapingXMLEntites]];
	
	[settings appendFormat:@"<COUNT CURRENT=\"%d\" LIMIT=\"%d\"/>\n", imageCount, imageCountLimit];
	
	return settings;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"COUNT"])
	{
		imageCount = [[[settingDict objectForKey:@"CURRENT"] description] intValue];
		imageCountLimit = [[[settingDict objectForKey:@"LIMIT"] description] intValue];
	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	NSString	*settingType = [childSettingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"FONT"])
		[self addFontWithName:[[[childSettingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites]];
	else if ([settingType isEqualToString:@"COLOR_LIST"])
		[self addColorList:[[[childSettingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites] 
				   ofClass:[[[childSettingDict objectForKey:@"CLASS"] description] stringByUnescapingXMLEntites]];
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
	
	if ([settingType isEqualToString:@"LETTERS"])
		[self setLetterPool:[[[settingDict objectForKey:kMacOSaiXImageSourceSettingText] description] stringByUnescapingXMLEntites]];
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXGlyphImageSource	*copy = [[MacOSaiXGlyphImageSource allocWithZone:zone] init];
	
	NSEnumerator	*fontNameEnumerator = [fontNames objectEnumerator];
	NSString		*fontName = nil;
	while (fontName = [fontNameEnumerator nextObject])
		[copy addFontWithName:fontName];
	
	NSEnumerator	*colorListClassEnumerator = [colorLists keyEnumerator];
	NSString		*colorListClass = nil;
	while (colorListClass = [colorListClassEnumerator nextObject])
	{
		NSEnumerator	*colorListNameEnumerator = [[colorLists objectForKey:colorListClass] objectEnumerator];
		NSString		*colorListName = nil;
		while (colorListName = [colorListNameEnumerator nextObject])
			[copy addColorList:colorListName ofClass:colorListClass];
	}
	[copy setAllowTransparentImages:allowTransparentImages];
	
	[copy setLetterPool:letterPool];
	
	[copy setImageCountLimit:imageCountLimit];
	
	return copy; 
}


- (NSImage *)image;
{
	return glyphSourceImage;
}


- (BOOL)hasMoreImages
{
	return (imageCountLimit == 0 || imageCount < imageCountLimit);
}


- (id)descriptor
{
    return @"Random glyphs";
}


- (NSColor *)randomColor
{
	float		red = 0.0,
				green = 0.0,
				blue = 0.0, 
				alpha = 0.0;
	NSString	*colorListClass = [[colorLists allKeys] objectAtIndex:(random() % [[colorLists allKeys] count])];
	NSArray		*colorClassLists = [colorLists objectForKey:colorListClass];
	NSString	*colorListName = [colorClassLists objectAtIndex:(random() % [colorClassLists count])];
	
	if ([colorListClass isEqualToString:@"Built-in"])
	{
		if ([colorListName isEqualToString:@"All Colors"])
		{
			red = (random() % 256) / 255.0;
			green = (random() % 256) / 255.0;
			blue = (random() % 256) / 255.0;
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
		else if ([colorListName isEqualToString:@"Grayscale"])
		{
			red = green = blue = (random() % 256) / 255.0;
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
		else if ([colorListName isEqualToString:@"Redscale"])
		{
			red = (random() % 256) / 255.0;
			green = blue = (red >= 1.0 / 255.0 ? (random() % (int)(red * 255.0)) / 255.0 : 0.0);
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
		else if ([colorListName isEqualToString:@"Greenscale"])
		{
			green = (random() % 256) / 255.0;
			red = blue = (green >= 1.0 / 255.0 ? (random() % (int)(green * 255.0)) / 255.0 : 0.0);
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
		else if ([colorListName isEqualToString:@"Bluescale"])
		{
			blue = (random() % 256) / 255.0;
			red = green = (blue >= 1.0 / 255.0 ? (random() % (int)(blue * 255.0)) / 255.0 : 0.0);
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
		else if ([colorListName isEqualToString:@"Sepia Tone"])
		{
				// Convert from HSV space: Hue = 50 degrees, Saturation = 35%, Value = random
			red = (random() % 256) / 255.0;
			green = red * (1.0 - (0.35 * (1.0 - 5.0 / 6.0)));
			blue = red * (1.0 - 0.35);
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
	}
	else if ([colorListClass isEqualToString:@"System-wide"])
	{
		NSColorList	*colorList = [NSColorList colorListNamed:colorListName];
		NSArray		*colorKeys = [colorList allKeys];
		
		if ([colorKeys count] > 0)
		{
			NSColor		*color = [colorList colorWithKey:[colorKeys objectAtIndex:(random() % [colorKeys count])]];
			
			red = [color redComponent];
			green = [color greenComponent];
			blue = [color blueComponent];
			alpha = [color alphaComponent];
		}
		else
		{
			red = (random() % 256) / 255.0;
			green = (random() % 256) / 255.0;
			blue = (random() % 256) / 255.0;
			alpha = (allowTransparentImages ? (random() % 256) / 255.0 : 1.0);
		}
	}
	
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}


- (NSArray *)glyphsForFont:(NSFont *)font
{
	NSString	*fontName = [font fontName];
	NSArray		*glyphNums = [glyphsDict objectForKey:fontName];
	
	if (!glyphNums)
	{
		NSLayoutManager	*layoutManager = [[NSLayoutManager alloc] init];
		NSDictionary	*attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
		NSTextStorage	*textStorage = [[NSTextStorage alloc] initWithString:[self letterPool] attributes:attributes];
		NSTextContainer	*textContainer = [[NSTextContainer alloc] init];
		
		[layoutManager setBackgroundLayoutEnabled:NO];
		[layoutManager addTextContainer:textContainer];
		[textStorage addLayoutManager:layoutManager];
		
		unsigned	glyphCount = [layoutManager numberOfGlyphs],
					glyphIndex;
		NSGlyph		glyphs[glyphCount];
		
		glyphNums = [NSMutableArray arrayWithCapacity:glyphCount];
		[layoutManager getGlyphs:glyphs range:NSMakeRange(0, glyphCount)];
		
		[textStorage removeLayoutManager:layoutManager];
		[layoutManager removeTextContainerAtIndex:[[layoutManager textContainers] indexOfObject:textContainer]];
		
		[textContainer release];
		[textStorage release];
		[layoutManager release];
		
		for (glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++)
			[(NSMutableArray *)glyphNums addObject:[NSNumber numberWithInt:glyphs[glyphIndex]]];
		
		[glyphsDict setObject:glyphNums forKey:fontName];
	}
	
	return glyphNums;
}


- (NSError *)nextImage:(NSImage **)image andIdentifier:(NSString **)identifier
{
	NSError	*error = nil;
	
	*image = nil;
	*identifier = nil;
	
	if ([fontNames count] > 0 && [colorLists count] > 0)
	{
		unsigned int	fontNum = random() % [fontNames count];
		NSFont			*font = [NSFont fontWithName:[fontNames objectAtIndex:fontNum] size:12.0];
		
		if (font)
		{
			NSGlyph			glyphNum;
			if ([self letterPool])
			{
				NSArray	*glyphNums = [self glyphsForFont:font];
				glyphNum = [[glyphNums objectAtIndex:random() % [glyphNums count]] intValue];
			}
			else
				glyphNum = random() % ([font numberOfGlyphs] - 1) + 1;
			
			NSBezierPath	*glyphPath = [NSBezierPath bezierPath];
			NSRect			glyphRect;
			
			[focusWindowLock lock];
				while (![[focusWindow contentView] lockFocusIfCanDraw])
					[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
				[glyphPath moveToPoint:NSZeroPoint];
				[glyphPath appendBezierPathWithGlyph:glyphNum inFont:font];
				glyphRect = [glyphPath bounds];
				[[focusWindow contentView] unlockFocus];
			[focusWindowLock unlock];

			if (glyphRect.size.width > 0.0 && glyphRect.size.height > 0.0)
			{
				NSColor		*foregroundColor = [self randomColor],
							*backgroundColor = [self randomColor];
				
					// Make sure the colors are a little different.
				while (fabs([foregroundColor redComponent] - [backgroundColor redComponent]) < 0.02 && 
					   fabs([foregroundColor greenComponent] - [backgroundColor greenComponent]) < 0.02 && 
					   fabs([foregroundColor blueComponent] - [backgroundColor blueComponent]) < 0.02)
				{
					foregroundColor = [self randomColor];
					backgroundColor = [self randomColor];
				}
				
				NSString	*tempIdentifier = [NSString stringWithFormat:
													@"%@\t%d %d %d %d %d %d %d %d %d", 
													[fontNames objectAtIndex:fontNum], glyphNum,
													(int)(255.0 * [foregroundColor redComponent]), 
													(int)(255.0 * [foregroundColor greenComponent]), 
													(int)(255.0 * [foregroundColor blueComponent]), 
													(int)(255.0 * [backgroundColor redComponent]), 
													(int)(255.0 * [backgroundColor greenComponent]), 
													(int)(255.0 * [backgroundColor blueComponent]), 
													(int)(255.0 * [foregroundColor alphaComponent]), 
													(int)(255.0 * [backgroundColor alphaComponent])];
				
				*image = [self imageForIdentifier:tempIdentifier];
				if (*image)
				{
					*identifier = tempIdentifier;
					imageCount++;
				}
			}
		}
	}
	
	return error;
}


- (BOOL)canReenumerateImages
{
	// TBD: return YES if a limited number of colors/fonts/letters are chosen?
	
	return NO;
}


- (BOOL)canRefetchImages
{
	// TBD: return NO if non-system font in use?
	
	return YES;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	// TODO: create a PDF rep instead of a bitmap
	
	NSImage	*image = nil;
	NSArray	*fontNameAndNumbers = [identifier componentsSeparatedByString:@"\t"];
	NSFont	*font = [NSFont fontWithName:[fontNameAndNumbers objectAtIndex:0] size:12.0];
	
	if (font)
	{
		NSArray				*numbers = [[fontNameAndNumbers objectAtIndex:1] componentsSeparatedByString:@" "];
		int					glyphNum = [[numbers objectAtIndex:0] intValue],
							foreRed = [[numbers objectAtIndex:1] intValue], 
							foreGreen = [[numbers objectAtIndex:2] intValue], 
							foreBlue = [[numbers objectAtIndex:3] intValue], 
							backRed = [[numbers objectAtIndex:4] intValue], 
							backGreen = [[numbers objectAtIndex:5] intValue], 
							backBlue = [[numbers objectAtIndex:6] intValue], 
							foreAlpha = ([numbers count] > 7 ? [[numbers objectAtIndex:7] intValue] : 255), 
							backAlpha = ([numbers count] > 8 ? [[numbers objectAtIndex:8] intValue] : 255);
		NSBezierPath		*glyphPath = [NSBezierPath bezierPath];
		NSRect				glyphRect, 
							destRect = NSZeroRect;
		NSAffineTransform	*transform = [NSAffineTransform transform];
		NSBitmapImageRep	*imageRep = nil;
		
		image = [[[NSImage alloc] initWithSize:glyphsBounds.size] autorelease];
		
			// Get the bounds of the glyph.
//		[focusWindowLock lock];
//			while (![[focusWindow contentView] lockFocusIfCanDraw])
//				[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
		[image lockFocus];
			[glyphPath moveToPoint:NSZeroPoint];
			[glyphPath appendBezierPathWithGlyph:glyphNum inFont:font];
			glyphRect = [glyphPath bounds];
		[image unlockFocus];
		[image removeRepresentation:[[image representations] lastObject]];
//			[[focusWindow contentView] unlockFocus];
//		[focusWindowLock unlock];
		
			// Make sure it's non-empty.
		if (glyphRect.size.width > 0 && glyphRect.size.height > 0)
		{
				// Scale up the glyph so that it's largest dimension is 128 pixels.
			if (glyphsBounds.size.width / glyphRect.size.width < glyphsBounds.size.height / glyphRect.size.height)
			{
				destRect.size.width = glyphsBounds.size.width;
				destRect.size.height = glyphsBounds.size.width / glyphRect.size.width * glyphRect.size.height;
				[transform translateXBy:0.0
									yBy:(glyphsBounds.size.height - destRect.size.height) / 2.0];
			}
			else
			{
				destRect.size.width = glyphsBounds.size.height / glyphRect.size.height * glyphRect.size.width;
				destRect.size.height = glyphsBounds.size.height;
				[transform translateXBy:(glyphsBounds.size.width - destRect.size.width) / 2.0
									yBy:0.0];
			}
			[transform scaleBy:destRect.size.width / glyphRect.size.width];
			[transform translateXBy:-glyphRect.origin.x yBy:-glyphRect.origin.y];
			[glyphPath transformUsingAffineTransform:transform];
			
//			[focusWindowLock lock];
//				while (![[focusWindow contentView] lockFocusIfCanDraw])
//					[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
			[image lockFocus];
					// start with a clear background
				[[NSColor clearColor] set];
				NSRectFill(glyphsBounds);
				
					// draw the background color
				[[NSColor colorWithCalibratedRed:backRed/255.0 green:backGreen/255.0 blue:backBlue/255.0 alpha:backAlpha/255.0] set];
				NSRectFillUsingOperation(glyphsBounds, NSCompositeSourceOver);
				
					// draw the glyph in the foreground color
				[[NSColor colorWithCalibratedRed:foreRed/255.0 green:foreGreen/255.0 blue:foreBlue/255.0 alpha:foreAlpha/255.0] set];
				[glyphPath fill];
				
					// grab the image
//				imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:glyphsBounds] autorelease];
//				
//				[[focusWindow contentView] unlockFocus];
//			[focusWindowLock unlock];
			[image unlockFocus];
			
			imageRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];

			if (imageRep)
				[image addRepresentation:imageRep];
			else
				image = nil;
		}
	}
	
	return image;
}


- (void)calculateBoundingRectForGlyphs
{
	NSEnumerator	*fontNameEnumerator = [fontNames objectEnumerator];
	NSString		*fontName = nil;
	
	glyphsBounds = NSZeroRect;
	
	while (fontName = [fontNameEnumerator nextObject])
	{
		NSFont			*font = [NSFont fontWithName:fontName size:12.0];
		
		if (font)
		{
			if ([self letterPool])
			{
				NSEnumerator	*glyphEnumerator = [[self glyphsForFont:font] objectEnumerator];
				NSNumber		*glyphNum = nil;
				
				while ((glyphNum = [glyphEnumerator nextObject]))
					glyphsBounds = NSUnionRect(glyphsBounds, [font boundingRectForGlyph:[glyphNum intValue]]);
			}
			else
				glyphsBounds = NSUnionRect(glyphsBounds, [font boundingRectForFont]);
		}
	}
	
	if (glyphsBounds.size.width != 0 && glyphsBounds.size.height != 0)
	{
		if (glyphsBounds.size.width > glyphsBounds.size.height)
		{
			glyphsBounds.size.height = round(512.0 / glyphsBounds.size.width * glyphsBounds.size.height);
			glyphsBounds.size.width = 512.0;
		}
		else
		{
			glyphsBounds.size.width = round(512.0 / glyphsBounds.size.height * glyphsBounds.size.width);
			glyphsBounds.size.height = 512.0;
		}
	}
	
	glyphsBounds = NSOffsetRect(glyphsBounds, -glyphsBounds.origin.x, -glyphsBounds.origin.y);
}


- (NSSize)glyphsSize
{
	return glyphsBounds.size;
}


#pragma mark Fonts


- (void)addFontWithName:(NSString *)fontName
{
	if (![fontNames containsObject:fontName])
	{
		[fontNames addObject:fontName];
		[self calculateBoundingRectForGlyphs];
	}
}


- (void)removeFontWithName:(NSString *)fontName
{
	if ([fontNames containsObject:fontName])
	{
		[fontNames removeObject:fontName];
		[glyphsDict removeObjectForKey:fontName];
		
		[self calculateBoundingRectForGlyphs];
	}
}


- (NSArray *)fontNames
{
	return [NSArray arrayWithArray:fontNames];
}


#pragma mark Colors


- (void)addColorList:(NSString *)listName ofClass:(NSString *)listClass
{
	NSMutableArray	*membersOfClass = [colorLists objectForKey:listClass];
	
	if (!membersOfClass)
	{
		membersOfClass = [NSMutableArray arrayWithObject:listName];
		[colorLists setObject:membersOfClass forKey:listClass];
	}
	else if (![membersOfClass containsObject:listName])
	{
		[membersOfClass addObject:listName];
		[membersOfClass sortUsingSelector:@selector(caseInsensitiveCompare:)];
	}
}


- (void)removeColorList:(NSString *)listName ofClass:(NSString *)listClass
{
	NSMutableArray	*membersOfClass = [colorLists objectForKey:listClass];
	
	if (membersOfClass)
	{
		[membersOfClass removeObject:listName];
		
		if ([membersOfClass count] == 0)
			[colorLists removeObjectForKey:listClass];
	}
}


- (NSArray *)colorListsOfClass:(NSString *)listClass
{
	return [NSArray arrayWithArray:[colorLists objectForKey:listClass]];
}


- (void)setAllowTransparentImages:(BOOL)flag
{
	allowTransparentImages = flag;
}


- (BOOL)allowTransparentImages
{
	return allowTransparentImages;
}


#pragma mark Letters


- (void)setLetterPool:(NSString *)pool
{
	[letterPool autorelease];
	letterPool = [pool copy];
	
	[glyphsDict removeAllObjects];
	
	[self calculateBoundingRectForGlyphs];
}


- (NSString *)letterPool
{
	return (letterPool ? [NSString stringWithString:letterPool] : nil);
}


- (void)setImageCountLimit:(unsigned long)limit
{
	imageCountLimit = limit;
}


- (unsigned long)imageCountLimit
{
	return imageCountLimit;
}


- (NSURL *)urlForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSURL *)contextURLForIdentifier:(NSString *)identifier
{
	return nil;
}	


- (NSString *)descriptionForIdentifier:(NSString *)identifier
{
	NSArray			*fontNameAndNumbers = [identifier componentsSeparatedByString:@"\t"];
	NSString		*fontName = [fontNameAndNumbers objectAtIndex:0], 
					*fontDisplayName = [[NSFont fontWithName:fontName size:0.0] displayName], 
					*glyphName = nil;
	UInt16			glyphNum = [[[[fontNameAndNumbers objectAtIndex:1] componentsSeparatedByString:@" "] objectAtIndex:0] intValue];
	ATSFontRef		fontRef = ATSFontFindFromPostScriptName((CFStringRef)fontName, kATSOptionFlagsDefault);
	
	if (fontRef)
	{
		// Pull the glyph name from the 'post' table in the font.  (<http://developer.apple.com/textfonts/TTRefMan/RM06/Chap6post.html>)
		
		ByteCount		bufferSize = 0;
		unsigned char	*buffer = nil;
		OSStatus		status = ATSFontGetTable(fontRef, 'post', 0, 0, NULL, &bufferSize);
		buffer = malloc(bufferSize);
		status = ATSFontGetTable(fontRef, 'post', 0, bufferSize, buffer, &bufferSize);
		
		unsigned char	postFormatBuffer[4], 
						postFormat1[4] = {0x0, 0x1, 0x0, 0x0}, 
						postFormat2[4] = {0x0, 0x2, 0x0, 0x0}, 
						postFormat3[4] = {0x0, 0x3, 0x0, 0x0}, 
						postFormat4[4] = {0x0, 0x4, 0x0, 0x0};
		memcpy(postFormatBuffer, buffer, 4);
		
		if (memcmp(postFormatBuffer, postFormat1, 4) == 0)
			glyphName = [[self class] standardNameForGlyph:glyphNum];
		else if (memcmp(postFormatBuffer, postFormat2, 4) == 0)
		{
			UInt16			glyphCount = *(buffer + 32) * 256 + *(buffer + 33), 
							glyphNameIndex = *(buffer + 34 + glyphNum * 2) * 256 + *(buffer + 34 + glyphNum * 2 + 1);
			
			if (glyphNameIndex < 258)
				glyphName = [[self class] standardNameForGlyph:glyphNameIndex];
			else
			{
				unsigned char	*glyphNamePtr = buffer + 34 + glyphCount * 2;
				UInt16			curIndex;
				
				glyphNameIndex -= 258;
				
				if (glyphNameIndex < glyphCount)
				{
					for (curIndex = 0; curIndex < glyphNameIndex; curIndex++)
					{
						unsigned char	nameLength = *glyphNamePtr;
						
						glyphNamePtr += nameLength + 1;
					}
					
					if (glyphNamePtr < buffer + bufferSize)
						glyphName = [[[NSString alloc] initWithData:[NSData dataWithBytes:glyphNamePtr + 1 length:*glyphNamePtr] encoding:NSASCIIStringEncoding] autorelease];
					else
					{
						#ifdef DEBUG
							NSLog(@"Name of glyph #%d beyond name table of %@", glyphNum, fontName);
						#endif
					}
				}
				else
				{
					#ifdef DEBUG
						NSLog(@"Glyph #%d outside of name table of %@", glyphNum, fontName);
					#endif
				}
			}
		}
		else if (memcmp(postFormatBuffer, postFormat3, 4) == 0)
		{
			// Format 3 does not specify any glyph names.
		}
		else if (memcmp(postFormatBuffer, postFormat4, 4) == 0)
		{
			#ifdef DEBUG
				//NSLog(@"Don't know what to do with 'post' format 4.0: %@", fontName);
			#endif
		}
		else
		{
			#ifdef DEBUG
				NSLog(@"unknown 'post' format");
			#endif
		}
		
		free(buffer);
	}
	
	// TBD: Use <http://partners.adobe.com/public/developer/en/opentype/aglfn13.txt> to lookup an even better name?
	
	if ([glyphName length] == 0)
		return [NSString stringWithFormat:@"%@ #%d", fontDisplayName, glyphNum];
	else
		return [NSString stringWithFormat:@"%@ #%d (%@)", fontDisplayName, glyphNum, glyphName];
}	


- (void)reset
{
	imageCount = 0;
}


- (void)focusWindowWillClose:(NSNotification *)notification
{
	focusWindow = nil;
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [fontNames release];
	[colorLists release];
	[letterPool release];
	[glyphsDict release];
	
    [focusWindow close];
    [focusWindowLock release];
	
    [super dealloc];
}

@end
