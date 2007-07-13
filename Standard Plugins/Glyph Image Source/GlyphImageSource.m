//
//  GlyphImageSource.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSourceController.h"

#import "GlyphImageSource.h"
#import "GlyphImageSourcePlugIn.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXGlyphImageSource


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


+ (id<MacOSaiXImageSource>)imageSourceForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)identifier
{
	return [[[self alloc] init] autorelease];
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


- (id)init
{
	if (self = [super init])
	{
		focusWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000.0, -10000.0, 256.0, 256.0)
							   styleMask:NSBorderlessWindowMask
							 backing:NSBackingStoreBuffered defer:NO];
		focusWindowLock = [[NSLock alloc] init];
		
		glyphsDict = [[NSMutableDictionary dictionary] retain];
		
		[self setColorListName:@"All Colors" ofClass:@"Built-in"];
	}
	
	return self;
}


- (BOOL)settingsAreValid
{
	return YES;
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	NSMutableDictionary	*settings = [NSDictionary dictionaryWithObjectsAndKeys:
										colorListName, @"Color List Name", 
										colorListClass, @"Color List Class", 
										letterPool, @"Letter Pool", 
										nil];
	
	if ([self fontsType] == allFonts)
		[settings setObject:[NSNumber numberWithBool:YES] forKey:@"Use All Fonts"];
	else if ([self fontsType] == fontCollection)
		[settings setObject:[self fontCollectionName] forKey:@"Font Collection Name"];
	else if ([self fontsType] == fontFamily)
		[settings setObject:[self fontFamilyName] forKey:@"Font Family Name"];
	
	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	if ([[settings objectForKey:@"Use All Fonts"] boolValue])
		[self useAllFonts];
	else if ([settings objectForKey:@"Font Collection Name"])
		[self setFontCollectionName:[settings objectForKey:@"Font Collection Name"]];
	else if ([settings objectForKey:@"Font Family Name"])
		[self setFontFamilyName:[settings objectForKey:@"Font Family Name"]];
	
	[self setColorListName:[settings objectForKey:@"Color List Name"] ofClass:[settings objectForKey:@"Color List Class"]];
	
	letterPool = [[settings objectForKey:@"Letter Pool"] retain];
	
	return YES;
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	NSString	*settingType = [childSettingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"FONT"])
	{
		NSString	*fontName = [[[childSettingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites];
		NSFont		*font = [NSFont fontWithName:fontName size:0.0];
		
		[self setFontFamilyName:[font familyName]];
	}
	else if ([settingType isEqualToString:@"COLOR_LIST"])
		[self setColorListName:[[[childSettingDict objectForKey:@"NAME"] description] stringByUnescapingXMLEntites] 
					   ofClass:[[[childSettingDict objectForKey:@"CLASS"] description] stringByUnescapingXMLEntites]];
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	NSString	*settingType = [settingDict objectForKey:@"Element Type"];
	
	if ([settingType isEqualToString:@"LETTERS"])
		[self setLetterPool:[[[settingDict objectForKey:@"Element Text"] description] stringByUnescapingXMLEntites]];
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXGlyphImageSource	*copy = [[MacOSaiXGlyphImageSource allocWithZone:zone] init];
	
	if ([self fontsType] == allFonts)
		[copy useAllFonts];
	else if ([self fontsType] == fontCollection)
		[copy setFontCollectionName:[self fontCollectionName]];
	else if ([self fontsType] == fontFamily)
		[copy setFontFamilyName:[self fontFamilyName]];
	
	[copy setColorListName:[self colorListName] ofClass:[self colorListClass]];
	[copy setLetterPool:letterPool];
	
	return copy; 
}


- (NSImage *)image;
{
	return [MacOSaiXGlyphImageSourcePlugIn image];
}


- (BOOL)hasMoreImages
{
	return YES;
}


- (NSNumber *)imageCount
{
	return nil;
}


- (id)briefDescription
{
    return NSLocalizedString(@"Random glyphs", @"");
}


- (BOOL)imagesShouldBeRemovedForLastChange
{
	return imagesShouldBeRemovedForLastChange;
}


- (void)reset
{
}


#pragma mark -
#pragma mark Settings


- (void)useAllFonts
{
	if (fontsType != allFonts)
	{
		fontsType = allFonts;
		
		[fontCollectionName release];
		fontCollectionName = nil;
		
		[fontFamilyName release];
		fontFamilyName = nil;
		
		[self reset];
	}
}


- (void)setFontCollectionName:(NSString *)collectionName
{
	if (fontsType != fontCollection)
	{
		fontsType = fontCollection;
		
		[fontCollectionName release];
		fontCollectionName = [collectionName copy];
		
		[fontFamilyName release];
		fontFamilyName = nil;
		
		imagesShouldBeRemovedForLastChange = YES;
		
		[self reset];
	}
}


- (NSString *)fontCollectionName
{
	return fontCollectionName;
}


- (void)setFontFamilyName:(NSString *)familyName;
{
	if (fontsType != fontFamily)
	{
		fontsType = fontFamily;
		
		[fontCollectionName release];
		fontCollectionName = nil;
		
		[fontFamilyName release];
		fontFamilyName = [familyName copy];
		
		imagesShouldBeRemovedForLastChange = YES;
		
		[self reset];
	}
}


- (NSString *)fontFamilyName
{
	return fontFamilyName;
}


- (MacOSaiXGlyphFontsType)fontsType
{
	return fontsType;
}


- (void)setAspectRatio:(NSNumber *)ratio
{
	if (ratio != aspectRatio || ![ratio isEqualTo:aspectRatio])
	{
		[aspectRatio release];
		aspectRatio = [ratio retain];
		
		imagesShouldBeRemovedForLastChange = YES;
		
		[self reset];
	}
}


- (NSNumber *)aspectRatio;
{
	return aspectRatio;
}


#pragma mark -


- (NSFont *)randomFont
{
	NSString	*fontName = nil;
	
	if ([self fontsType] == allFonts)
	{
		NSArray	*fontNames = [[NSFontManager sharedFontManager] availableFonts];
		
		fontName = [fontNames objectAtIndex:random() % [fontNames count]];
	}
	else if ([self fontsType] == fontCollection && [self fontCollectionName])
	{
		NSArray				*collectionDescriptors = [[NSFontManager sharedFontManager] fontDescriptorsInCollection:[self fontCollectionName]];
		NSFontDescriptor	*fontDescriptor = [collectionDescriptors objectAtIndex:random() % [collectionDescriptors count]];
		
		fontName = [[fontDescriptor fontAttributes] objectForKey:NSFontNameAttribute];
	}
	else if ([self fontsType] == fontFamily && [self fontFamilyName])
	{
		NSArray	*familyFonts = [[NSFontManager sharedFontManager] availableMembersOfFontFamily:[self fontFamilyName]];
		
		fontName = [[familyFonts objectAtIndex:random() % [familyFonts count]] objectAtIndex:0];
	}
	
	return (fontName ? [NSFont fontWithName:fontName size:0.0] : nil);
}


- (NSColor *)randomColor
{
	float		red = 0.0,
				green = 0.0,
				blue = 0.0;
	
	if ([[self colorListClass] isEqualToString:@"Built-in"])
	{
		if ([[self colorListName] isEqualToString:NSLocalizedString(@"All Colors", @"")])
		{
			red = (random() % 256) / 256.0;
			green = (random() % 256) / 256.0;
			blue = (random() % 256) / 256.0;
		}
		else if ([[self colorListName] isEqualToString:NSLocalizedString(@"Grayscale", @"")])
			red = green = blue = (random() % 256) / 256.0;
		else if ([[self colorListName] isEqualToString:NSLocalizedString(@"Redscale", @"")])
		{
			red = (random() % 256) / 256.0;
			green = blue = (random() % (int)(red * 256.0)) / 256.0;
		}
		else if ([[self colorListName] isEqualToString:NSLocalizedString(@"Greenscale", @"")])
		{
			green = (random() % 256) / 256.0;
			red = blue = (random() % (int)(green * 256.0)) / 256.0;
		}
		else if ([[self colorListName] isEqualToString:NSLocalizedString(@"Bluescale", @"")])
		{
			blue = (random() % 256) / 256.0;
			red = green = (random() % (int)(blue * 256.0)) / 256.0;
		}
		else if ([[self colorListName] isEqualToString:NSLocalizedString(@"Sepia Tone", @"")])
		{
				// Convert from HSV space: Hue = 50 degrees, Saturation = 35%, Value = random
			red = (random() % 256) / 256.0;
			green = red * (1.0 - (0.35 * (1.0 - 5.0 / 6.0)));
			blue = red * (1.0 - 0.35);
		}
	}
	else if ([[self colorListClass] isEqualToString:@"System-wide"])
	{
		NSColorList	*colorList = [NSColorList colorListNamed:[self colorListName]];
		NSArray		*colorKeys = [colorList allKeys];
		NSColor		*color = [colorList colorWithKey:[colorKeys objectAtIndex:(random() % [colorKeys count])]];
		
		red = [color redComponent];
		green = [color greenComponent];
		blue = [color blueComponent];
	}
	
	return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:1.0];
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


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage	*image = nil;
	NSFont	*font = [self randomFont];
	
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
			while (fabsf([foregroundColor redComponent] - [backgroundColor redComponent]) < 0.1 && 
				   fabsf([foregroundColor greenComponent] - [backgroundColor greenComponent]) < 0.1 && 
				   fabsf([foregroundColor blueComponent] - [backgroundColor blueComponent]) < 0.1)
			{
				foregroundColor = [self randomColor];
				backgroundColor = [self randomColor];
			}
			
			NSString	*tempIdentifier = [NSString stringWithFormat:
												@"%@\t%d %d %d %d %d %d %d", 
												[font fontName], 
												glyphNum,
												(int)(256.0 * [foregroundColor redComponent]), 
												(int)(256.0 * [foregroundColor greenComponent]), 
												(int)(256.0 * [foregroundColor blueComponent]), 
												(int)(256.0 * [backgroundColor redComponent]), 
												(int)(256.0 * [backgroundColor greenComponent]), 
												(int)(256.0 * [backgroundColor blueComponent])];
			
			image = [self imageForIdentifier:tempIdentifier];
			
			if (image && identifier)
				*identifier = tempIdentifier;
		}
	}
	
	return image;
}


- (BOOL)canRefetchImages
{
	return YES;
}


- (id<NSCopying>)universalIdentifierForIdentifier:(NSString *)identifier
{
	return identifier;
}


- (NSString *)identifierForUniversalIdentifier:(id<NSObject,NSCoding,NSCopying>)universalIdentifier
{
	return (NSString *)universalIdentifier;
}


- (NSImage *)thumbnailForIdentifier:(NSString *)identifier
{
	return nil;
}


- (NSImage *)imageForIdentifier:(NSString *)identifier
{
	NSImage	*image = nil;
	NSArray	*fontNameAndNumbers = [identifier componentsSeparatedByString:@"\t"];
	NSFont	*font = [NSFont fontWithName:[fontNameAndNumbers objectAtIndex:0] size:12.0];
	
	if (font)
	{
		NSArray				*numbers = [[fontNameAndNumbers objectAtIndex:1] componentsSeparatedByString:@" "];
		
			// Get the bounds of the glyph.
		NSBezierPath		*glyphPath = [NSBezierPath bezierPath];
		NSRect				glyphRect;
		[focusWindowLock lock];
			while (![[focusWindow contentView] lockFocusIfCanDraw])
				[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
			[glyphPath moveToPoint:NSZeroPoint];
			[glyphPath appendBezierPathWithGlyph:[[numbers objectAtIndex:0] intValue] inFont:font];
			glyphRect = [glyphPath bounds];
			[[focusWindow contentView] unlockFocus];
		[focusWindowLock unlock];
		
			// Make sure it's non-empty.
		if (glyphRect.size.width > 0 && glyphRect.size.height > 0)
		{
			NSColor				*foreColor = [NSColor colorWithCalibratedRed:[[numbers objectAtIndex:1] intValue] / 256.0 
																	   green:[[numbers objectAtIndex:2] intValue] / 256.0 
																		blue:[[numbers objectAtIndex:3] intValue] / 256.0 
																	   alpha:1.0], 
								*backColor = [NSColor colorWithCalibratedRed:[[numbers objectAtIndex:4] intValue] / 256.0 
																	   green:[[numbers objectAtIndex:5] intValue] / 256.0 
																		blue:[[numbers objectAtIndex:6] intValue] / 256.0 
																	   alpha:1.0];
			float				glyphAspectRatio = NSWidth(glyphRect) / NSHeight(glyphRect), 
								imageAspectRatio = ([self aspectRatio] ? [[self aspectRatio] floatValue] : glyphAspectRatio);
			NSRect				imageRect = NSMakeRect(0.0, 0.0, 0.0, 256.0);
			
				// Scale up the glyph so that it's largest dimension is 256.0 pixels.
			if (imageAspectRatio >= 1.0)
			{
				imageRect.size.width = 256.0;
				imageRect.size.height = 256.0 / imageAspectRatio;
			}
			else
			{
				imageRect.size.width = 256.0 * imageAspectRatio;
				imageRect.size.height = 256.0;
			}
			
			image = [[[NSImage alloc] initWithSize:imageRect.size] autorelease];
			
				// Center the glyph in the image at the largest possible size.
			NSRect				destRect = NSZeroRect;
			NSAffineTransform	*transform = [NSAffineTransform transform];
			if (imageRect.size.width / glyphRect.size.width < imageRect.size.height / glyphRect.size.height)
			{
				destRect.size.width = imageRect.size.width;
				destRect.size.height = imageRect.size.width / glyphAspectRatio;
				destRect.origin.y = (imageRect.size.height - destRect.size.height) / 2.0;
			}
			else
			{
				destRect.size.width = imageRect.size.height * glyphAspectRatio;
				destRect.size.height = imageRect.size.height;
				destRect.origin.x = (imageRect.size.width - destRect.size.width) / 2.0;
			}
			[transform translateXBy:NSMinX(destRect) yBy:NSMinY(destRect)];
			[transform scaleBy:destRect.size.width / glyphRect.size.width];
			[transform translateXBy:-NSMinX(glyphRect) yBy:-NSMinY(glyphRect)];
			[glyphPath transformUsingAffineTransform:transform];
			
				// Render and grab the image.
			NSBitmapImageRep	*imageRep = nil;
			[focusWindowLock lock];
				while (![[focusWindow contentView] lockFocusIfCanDraw])
					[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
				
					// Draw the background color.
				[foreColor set];
				[NSBezierPath fillRect:imageRect];
				
					// Draw the glyph in the foreground color.
				[backColor set];
				[glyphPath fill];
				
					// Grab the image.
				imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:imageRect] autorelease];
				
				[[focusWindow contentView] unlockFocus];
			[focusWindowLock unlock];

			if (imageRep)
				[image addRepresentation:imageRep];
			else
				image = nil;
		}
	}
	
	return image;
}


#pragma mark Colors


- (void)setColorListName:(NSString *)listName ofClass:(NSString *)listClass
{
	[colorListName release];
	colorListName = [listName retain];
	
	[colorListClass release];
	colorListClass = [listClass retain];
	
	imagesShouldBeRemovedForLastChange = YES;
}


- (NSString *)colorListName
{
	return colorListName;
}


- (NSString *)colorListClass
{
	return colorListClass;
}


#pragma mark Letters


- (void)setLetterPool:(NSString *)pool
{
	imagesShouldBeRemovedForLastChange = (!letterPool || [pool hasPrefix:letterPool]);
		
	[letterPool autorelease];
	letterPool = [pool copy];
	
	[glyphsDict removeAllObjects];
}


- (NSString *)letterPool
{
	return (letterPool ? [NSString stringWithString:letterPool] : nil);
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
	NSArray		*fontNameAndNumbers = [identifier componentsSeparatedByString:@"\t"], 
				*numbers = [[fontNameAndNumbers objectAtIndex:1] componentsSeparatedByString:@" "];
	NSString	*fontName = [fontNameAndNumbers objectAtIndex:0];
	
	return [NSString stringWithFormat:@"%@ #%@", fontName, [numbers objectAtIndex:0]];
}	


- (void)dealloc
{
    [fontCollectionName release];
    [fontFamilyName release];
	[colorListName release];
	[colorListClass release];
	[letterPool release];
	[glyphsDict release];
	
    [focusWindow close];
    [focusWindowLock release];
	
    [super dealloc];
}

@end
