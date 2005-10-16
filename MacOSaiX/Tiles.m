#import "Tiles.h"

#import "MacOSaiXDocument.h"


@implementation MacOSaiXTile


- (id)initWithOutline:(NSBezierPath *)inOutline fromMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (self = [super init])
	{
		outline = [inOutline retain];
		mosaic = inMosaic;	// non-retained, it retains us
	}
	return self;
}


- (void)setNeighboringTiles:(NSArray *)neighboringTiles
{
	[neighborSet autorelease];
	neighborSet = [[NSMutableSet setWithArray:neighboringTiles] retain];
	[neighborSet removeObject:self];
}


- (NSArray *)neighboringTiles
{
	return [neighborSet allObjects];
}

- (void)setOutline:(NSBezierPath *)inOutline
{
    [outline autorelease];
    outline = [inOutline retain];
}


- (NSBezierPath *)outline
{
    return outline;
}


- (float)worstCaseMatchValue
{
	return 255.0 * 255.0 * 9.0;
}


- (void)resetBitmapRepAndMask
{
		// TODO: this should not be called from outside.  we should listen for notifications 
		// that the original image or tile shapes changed for our mosaic and reset at that
		// point.
    [bitmapRep autorelease];
    bitmapRep = nil;
    [maskRep autorelease];
    maskRep = nil;
}


- (void)createBitmapRep
{
	NS_DURING
			// Determine the bounds of the tile in the original image and in the workingImage.
		NSBezierPath	*tileOutline = [self outline];
		NSImage			*originalImage = [mosaic originalImage];
		NSRect			origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
											  [tileOutline bounds].origin.y * [originalImage size].height,
											  [tileOutline bounds].size.width * [originalImage size].width,
											  [tileOutline bounds].size.height * [originalImage size].height),
						destRect = (origRect.size.width > origRect.size.height) ?
									NSMakeRect(0, 0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE * origRect.size.height / origRect.size.width) : 
									NSMakeRect(0, 0, TILE_BITMAP_SIZE * origRect.size.width / origRect.size.height, TILE_BITMAP_SIZE);
		
		NSImage	*workingImage = [[[NSImage alloc] initWithSize:destRect.size] autorelease];
		[workingImage setCachedSeparately:YES];
		[workingImage setCacheMode:NSImageCacheNever];
		[workingImage lockFocus];
		
			// Start with a black image to overwrite any previous scratch contents.
		[[NSColor blackColor] set];
		[[NSBezierPath bezierPathWithRect:destRect] fill];
		
			// Copy out the portion of the original image contained by the tile's outline.
		[originalImage drawInRect:destRect fromRect:origRect operation:NSCompositeCopy fraction:1.0];
		bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect];
		if (bitmapRep == nil)
			NSLog(@"Could not extract tile image from original.");
	
			// Calculate a mask image using the tile's outline that is the same size as the image
			// extracted from the original.  The mask will be white for pixels that are inside the 
			// tile and black outside.
			// (This would work better if we could just replace the previous rep's alpha channel
			//  but I haven't figured out an easy way to do that yet.)
		[[NSGraphicsContext currentContext] saveGraphicsState];	// so we can undo the clip
				// Start with a black background.
			[[NSColor blackColor] set];
			[[NSBezierPath bezierPathWithRect:destRect] fill];
			
				// Fill the tile's outline with white.
			NSAffineTransform  *transform = [NSAffineTransform transform];
			[transform scaleXBy:destRect.size.width / [tileOutline bounds].size.width
							yBy:destRect.size.height / [tileOutline bounds].size.height];
			[transform translateXBy:[tileOutline bounds].origin.x * -1
								yBy:[tileOutline bounds].origin.y * -1];
			[[NSColor whiteColor] set];
			[[transform transformBezierPath:tileOutline] fill];
			
				// Copy out the mask image and store it in the tile.
				// TO DO: RGB is wasting space, should be grayscale.
			maskRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
	NS_HANDLER
		NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
	NS_ENDHANDLER
}

- (NSBitmapImageRep *)bitmapRep
{
	if (!bitmapRep)
		[self performSelectorOnMainThread:@selector(createBitmapRep) withObject:nil waitUntilDone:YES];
	
    return bitmapRep;
}


- (NSBitmapImageRep *)maskRep
{
	return maskRep;
}


- (void)sendNotificationThatImageChangedFrom:(MacOSaiXImageMatch *)previousMatch
{
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileImageDidChangeNotification
														object:mosaic 
													  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																	self, @"Tile", 
																	previousMatch, @"Previous Match",
																	nil]];
}


	// Match this tile's bitmap against matchRep and return whether the new match is better
	// than this tile's previous worst.
/*
- (float)matchValueForImageRep:(NSBitmapImageRep *)matchRep
			    withIdentifier:(NSString *)imageIdentifier
			   fromImageSource:(id<MacOSaiXImageSource>)imageSource
					  optimize:(BOOL)optimize
{
	if (!uniqueImageMatch && (!nonUniqueImageMatch || matchValue < [nonUniqueImageMatch matchValue]))
	{
		[nonUniqueImageMatch autorelease];
		nonUniqueImageMatch = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
														  forImageIdentifier:imageIdentifier 
															 fromImageSource:imageSource 
																	 forTile:self];
		
		if (!userChosenImageMatch && NO)	// TODO: check showBestNonUniqueMatch pref
			[self sendImageChangedNotification];
	}
	
	return matchValue;
}
*/


- (void)setUniqueImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != uniqueImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = uniqueImageMatch;
		
		[uniqueImageMatch autorelease];
		uniqueImageMatch = [match retain];
		
			// Now that we have a real match we don't need the placeholder anymore.
			// TBD: or do we?  what if this gets set back to nil?
		[nonUniqueImageMatch autorelease];
		nonUniqueImageMatch = nil;
		
		if (!userChosenImageMatch)
			[self sendNotificationThatImageChangedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)uniqueImageMatch
{
	return [[uniqueImageMatch retain] autorelease];
}


- (void)setUserChosenImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != userChosenImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = userChosenImageMatch;
		
		[userChosenImageMatch autorelease];
		userChosenImageMatch = [match retain];
		
		[self sendNotificationThatImageChangedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)userChosenImageMatch;
{
	return [[userChosenImageMatch retain] autorelease];
}


- (MacOSaiXImageMatch *)displayedImageMatch
{
	if (userChosenImageMatch)
		return userChosenImageMatch;
	else if (uniqueImageMatch)
		return uniqueImageMatch;
	else if (NO)	// TODO: check showBestNonUniqueMatch pref
		return nonUniqueImageMatch;
	else
		return nil;
}

- (void)dealloc
{
    [outline release];
	[neighborSet release];
    [bitmapRep release];
	[maskRep release];
	[uniqueImageMatch release];
    [userChosenImageMatch release];
	[nonUniqueImageMatch release];
	
    [super dealloc];
}


@end
