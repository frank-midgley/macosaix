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


@implementation MacOSaiXGlyphImageSource


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
	return [NSImage imageNamed:@"GlyphImageSource"];
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
			NSFont			*font = [NSFont fontWithName:[fontNames objectAtIndex:fontNum] size:0.0];
			
			if (font)
			{
				NSGlyph			glyphNum = randomNumbers[1] % ([font numberOfGlyphs] - 1) + 1;
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
	NSFont	*font = [NSFont fontWithName:[fontNameAndNumbers objectAtIndex:0] size:0.0];
	
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
				// Scale up the glyph so that it's largest dimension is 128 pixels.
			if (glyphRect.size.width > glyphRect.size.height)
			{
				destRect.size.width = 128.0;
				destRect.size.height = 128.0 / glyphRect.size.width * glyphRect.size.height;
			}
			else
			{
				destRect.size.width = 128.0 / glyphRect.size.height * glyphRect.size.width;
				destRect.size.height = 128.0;
			}
			[transform scaleBy:destRect.size.width / glyphRect.size.width];
			[transform translateXBy:glyphRect.origin.x * -1 yBy:glyphRect.origin.y * -1];
			[glyphPath transformUsingAffineTransform:transform];
			
				// Create the image now that we know what size it will be.
			image = [[[NSImage alloc] initWithSize:destRect.size] autorelease];
			if (image != nil)
			{
				[focusWindowLock lock];
					while (![[focusWindow contentView] lockFocusIfCanDraw])
						[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
					
						// draw the background color
					[[NSColor colorWithCalibratedRed:backRed/256.0 green:backGreen/256.0 blue:backBlue/256.0
								alpha:1.0] set];
					[[NSBezierPath bezierPathWithRect:destRect] fill];
					
						// draw the glyph in the foreground color
					[[NSColor colorWithCalibratedRed:foreRed/256.0 green:foreGreen/256.0 blue:foreBlue/256.0
								alpha:1.0] set];
					[glyphPath fill];
					
						// grab the image
					imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect] autorelease];
					
					[[focusWindow contentView] unlockFocus];
				[focusWindowLock unlock];

				if (imageRep)
					[image addRepresentation:imageRep];
				else
					image = nil;
			}
		}
	}
	
	return image;
}


- (void)addFontWithName:(NSString *)fontName
{
	[fontNames addObject:fontName];
}


- (void)removeFontWithName:(NSString *)fontName
{
	[fontNames removeObject:fontName];
}


- (NSArray *)fontNames
{
	return [NSArray arrayWithArray:fontNames];
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
    [focusWindow close];
    [focusWindowLock release];
    [super dealloc];
}

@end
