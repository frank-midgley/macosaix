//
//  GlyphImageSource.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Apr 04 2002.
//  Copyright (c) 2001-2005 Frank M. Midgley. All rights reserved.
//

#import "GlyphImageSource.h"
#import "GlyphImageSourceController.h"
#import <fcntl.h>
#import <sys/types.h>
#import <sys/uio.h>
#import <unistd.h>


static NSImage	*glyphSourceImage = nil;

@implementation MacOSaiXGlyphImageSource


+ (void)load
{
	NSString	*imagePath = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"GlyphImageSource"];
	glyphSourceImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
}


+ (NSString *)name
{
	return @"Glyphs";
}


+ (Class)editorClass
{
	return [MacOSaiXGlyphImageSourceController class];
}


+ (BOOL)allowMultipleImageSources
{
	return YES;
}


- (id)init
{
	if (self = [super init])
	{
		fontNames = [[NSMutableArray array] retain];
		focusWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 128, 128)
							   styleMask:NSBorderlessWindowMask
							 backing:NSBackingStoreBuffered defer:NO];
		focusWindowLock = [[NSLock alloc] init];
	}
	
	return self;
}


- (NSString *)settingsAsXMLElement
{
	return nil;
//	[NSString stringWithFormat:@"<ALBUM NAME=\"%@\" LAST_IMAGE_NAME=\"%@\"/>", 
//									  [NSString stringByEscapingXMLEntites:[self albumName]], 
//									  [NSString stringByEscapingXMLEntites:lastEnumeratedImageName]];
}


- (void)useSavedSetting:(NSDictionary *)settingDict
{
//	NSString	*settingType = [settingDict objectForKey:kMacOSaiXImageSourceSettingType];
//	
//	if ([settingType isEqualToString:@"NAME"])
//		[self setAlbumName:[NSString stringByUnescapingXMLEntites:[[settingDict objectForKey:@"NAME"] description]]];
//	else if ([settingType isEqualToString:@"LAST_IMAGE_NAME"])
//	{
//		lastEnumeratedImageName = [[NSString stringByUnescapingXMLEntites:[[settingDict objectForKey:@"LAST_IMAGE_NAME"] description]] retain];
//		imagesHaveBeenEnumerated = NO;
//	}
}


- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict
{
	// not needed
}


- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict
{
	// not needed
}


- (id)copyWithZone:(NSZone *)zone
{
	return [[MacOSaiXGlyphImageSource allocWithZone:zone] init];
}


- (NSImage *)image;
{
	return glyphSourceImage;
}


- (BOOL)hasMoreImages
{
	return (imageCountLimit == 0 || imageCount < imageCountLimit);
}


- (NSString *)descriptor
{
    return @"Random glyphs";
}


- (NSImage *)nextImageAndIdentifier:(NSString **)identifier
{
	NSImage			*image = nil;
	int				devRandom = open("/dev/random", O_RDONLY, 0);
	
	if (devRandom >= 0)
	{
		unsigned int	bytesRead, randomNumbers[10];

		bytesRead = read(devRandom, randomNumbers, sizeof(int) * 10);
		close(devRandom);

		if (bytesRead >= sizeof(unsigned int) * 8 && [fontNames count] > 0)
		{
			unsigned int	fontNum = randomNumbers[0] % [fontNames count];
			NSFont			*font = [NSFont fontWithName:[fontNames objectAtIndex:fontNum] size:12.0];
			
			if (font)
			{
				NSGlyph			glyphNum;
				if ([self letterPool])
				{
					NSLayoutManager	*layoutManager = [[[NSLayoutManager alloc] init] autorelease];
					NSDictionary	*attributes = [NSDictionary dictionaryWithObject:font
																			  forKey:NSFontAttributeName];
					NSTextStorage	*textStorage = [[NSTextStorage alloc] initWithString:[self letterPool]
																			  attributes:attributes];
					[textStorage addLayoutManager:layoutManager];
					unsigned	glyphCount = [layoutManager numberOfGlyphs];
					glyphNum = [layoutManager glyphAtIndex:randomNumbers[1] % glyphCount];
				}
				else
					glyphNum = randomNumbers[1] % ([font numberOfGlyphs] - 1) + 1;
				
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
					NSString	*tempIdentifier = [NSString stringWithFormat:
														@"%@\t%d %d %d %d %d %d %d", 
														[fontNames objectAtIndex:fontNum], glyphNum,
														randomNumbers[2] % 256, randomNumbers[3] % 256, 
														randomNumbers[4] % 256, randomNumbers[5] % 256, 
														randomNumbers[6] % 256, randomNumbers[7] % 256];
					
					image = [self imageForIdentifier:tempIdentifier];
					if (image && identifier)
					{
						*identifier = tempIdentifier;
						imageCount++;
					}
				}
			}
		}
	}
	
	return image;
}


- (NSImage *)imageForIdentifier:(id)identifier
{
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
							backBlue = [[numbers objectAtIndex:6] intValue];
		NSBezierPath		*glyphPath = [NSBezierPath bezierPath];
		NSRect				glyphRect, 
							destRect = NSZeroRect;
		NSAffineTransform	*transform = [NSAffineTransform transform];
		NSBitmapImageRep	*imageRep = nil;
		
		image = [[[NSImage alloc] initWithSize:glyphsBounds.size] autorelease];
		
			// Get the bounds of the glyph.
		[focusWindowLock lock];
			while (![[focusWindow contentView] lockFocusIfCanDraw])
				[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
			[glyphPath moveToPoint:NSZeroPoint];
			[glyphPath appendBezierPathWithGlyph:glyphNum inFont:font];
			glyphRect = [glyphPath bounds];
			[[focusWindow contentView] unlockFocus];
		[focusWindowLock unlock];
		
			// Make sure it's non-empty.
		if (glyphRect.size.width > 0 && glyphRect.size.height > 0)
		{
			if (glyphNum == 180)
				NSLog(@"");
			
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
			
			[focusWindowLock lock];
				while (![[focusWindow contentView] lockFocusIfCanDraw])
					[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
				
					// draw the background color
				[[NSColor colorWithCalibratedRed:backRed/256.0 green:backGreen/256.0 blue:backBlue/256.0
							alpha:1.0] set];
				[NSBezierPath fillRect:glyphsBounds];
				
					// draw the glyph in the foreground color
				[[NSColor colorWithCalibratedRed:foreRed/256.0 green:foreGreen/256.0 blue:foreBlue/256.0
							alpha:1.0] set];
				[glyphPath fill];
				
					// grab the image
				imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:glyphsBounds] autorelease];
				
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
				NSLayoutManager	*layoutManager = [[[NSLayoutManager alloc] init] autorelease];
				NSDictionary	*attributes = [NSDictionary dictionaryWithObject:font
																		  forKey:NSFontAttributeName];
				NSTextStorage	*textStorage = [[NSTextStorage alloc] initWithString:[self letterPool]
																		  attributes:attributes];
				[textStorage addLayoutManager:layoutManager];
				unsigned	i, glyphCount = [layoutManager numberOfGlyphs];
				for (i = 0; i < glyphCount; i++)
					glyphsBounds = NSUnionRect(glyphsBounds, [font boundingRectForGlyph:[layoutManager glyphAtIndex:i]]);
			}
			else
				glyphsBounds = NSUnionRect(glyphsBounds, [font boundingRectForFont]);
		}
	}
	
	if (glyphsBounds.size.width != 0 && glyphsBounds.size.height != 0)
	{
		if (glyphsBounds.size.width > glyphsBounds.size.height)
		{
			glyphsBounds.size.height = 64.0 / glyphsBounds.size.width * glyphsBounds.size.height;
			glyphsBounds.size.width = 64.0;
		}
		else
		{
			glyphsBounds.size.width = 64.0 / glyphsBounds.size.height * glyphsBounds.size.width;
			glyphsBounds.size.height = 64.0;
		}
	}
	
	glyphsBounds = NSOffsetRect(glyphsBounds, -glyphsBounds.origin.x, -glyphsBounds.origin.y);
}


- (NSSize)glyphsSize
{
	return glyphsBounds.size;
}


- (void)addFontWithName:(NSString *)fontName
{
	[fontNames addObject:fontName];
	[self calculateBoundingRectForGlyphs];
}


- (void)removeFontWithName:(NSString *)fontName
{
	[fontNames removeObject:fontName];
	[self calculateBoundingRectForGlyphs];
}


- (NSArray *)fontNames
{
	return [NSArray arrayWithArray:fontNames];
}


- (void)setLetterPool:(NSString *)pool
{
	[letterPool autorelease];
	letterPool = [pool copy];
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


- (void)reset
{
	imageCount = 0;
}


- (void)dealloc
{
    [fontNames release];
	[letterPool release];
    [focusWindow close];
    [focusWindowLock release];
    [super dealloc];
}

@end
