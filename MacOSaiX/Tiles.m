//#import <string.h>
#import "Tiles.h"
#import "MacOSaiXDocument.h"


@implementation MacOSaiXImageMatch


- (id)initWithMatchValue:(float)inMatchValue 
	  forImageIdentifier:(NSString *)inImageIdentifier 
		 fromImageSource:(id<MacOSaiXImageSource>)inImageSource
				 forTile:(MacOSaiXTile *)inTile
{
	if (self = [super init])
	{
		matchValue = inMatchValue;
		imageIdentifier = [inImageIdentifier retain];
		imageSource = [inImageSource retain];
		tile = inTile;
	}
	
	return self;
}


- (float)matchValue
{
	return matchValue;
}


- (id<MacOSaiXImageSource>)imageSource
{
	return imageSource;
}


- (NSString *)imageIdentifier
{
	return imageIdentifier;
}


- (MacOSaiXTile *)tile
{
	return tile;
}


- (void)setTile:(MacOSaiXTile *)inTile
{
	tile = inTile;	// don't retain
}


- (NSComparisonResult)compare:(MacOSaiXImageMatch *)otherMatch
{
	float	otherMatchValue = [otherMatch matchValue];
	
	if (matchValue > otherMatchValue)
		return NSOrderedDescending;
	else if (matchValue < otherMatchValue)
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}


- (void)dealloc
{
	[imageIdentifier release];
	[imageSource release];
	
	[super dealloc];
}


@end


#pragma mark -


@implementation MacOSaiXTile


- (id)initWithOutline:(NSBezierPath *)inOutline fromDocument:(MacOSaiXDocument *)inDocument
{
	if (self = [super init])
	{
		outline = [inOutline retain];
		document = inDocument;	// the document retains us so we don't retain it
		
//		cachedMatches = [[NSMutableDictionary dictionary] retain];
//		cachedMatchesOrder = [[NSMutableArray array] retain];
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
	return 256.0 * 256.0 * 9.0;
}


- (void)resetBitmapRepAndMask;
{
    [bitmapRep autorelease];
    bitmapRep = nil;
    [maskRep autorelease];
    maskRep = nil;
}


- (NSBitmapImageRep *)bitmapRep
{
	if (!bitmapRep)
	{
		NS_DURING
				// Determine the bounds of the tile in the original image and in the workingImage.
			NSBezierPath	*tileOutline = [self outline];
			NSImage			*originalImage = [document originalImage];
			NSRect			origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
												  [tileOutline bounds].origin.y * [originalImage size].height,
												  [tileOutline bounds].size.width * [originalImage size].width,
												  [tileOutline bounds].size.height * [originalImage size].height),
							destRect = (origRect.size.width > origRect.size.height) ?
										NSMakeRect(0, 0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE * origRect.size.height / origRect.size.width) : 
										NSMakeRect(0, 0, TILE_BITMAP_SIZE * origRect.size.width / origRect.size.height, TILE_BITMAP_SIZE);
			
			NSImage	*workingImage = [[[NSImage alloc] initWithSize:destRect.size] autorelease];
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
	
    return bitmapRep;
}


- (void)sendImageChangedNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileImageDidChangeNotification
														object:document 
													  userInfo:[NSDictionary dictionaryWithObject:self forKey:@"Tile"]];
}


	// Match this tile's bitmap against matchRep and return whether the new match is better
	// than this tile's previous worst.
- (float)matchValueForImageRep:(NSBitmapImageRep *)matchRep
			    withIdentifier:(NSString *)imageIdentifier
			   fromImageSource:(id<MacOSaiXImageSource>)imageSource
{
	float		matchValue = 0.0;
	int				bytesPerPixel1, bytesPerRow1, bytesPerPixel2, bytesPerRow2, maskBytesPerPixel, maskBytesPerRow;
	int				pixelCount = 0, pixelsLeft;
	int				x, y, x_off, y_off, x_size, y_size;
	unsigned char	*bitmap1, *bitmap2, *maskBitmap;
	float			currentMatchValue;
	
	if (matchRep == nil) return WORST_CASE_PIXEL_MATCH;
	
		// the size of bitmapRep will be a maximum of TILE_BITMAP_SIZE pixels
		// the size of the smaller dimension of imageRep will be TILE_BITMAP_SIZE pixels
		// pixels in imageRep outside of bitmapRep centered in imageRep will be ignored
	
	bitmap1 = [[self bitmapRep] bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
	maskBitmap = [maskRep bitmapData];
	bitmap2 = [matchRep bitmapData];	NSAssert(bitmap2 != nil, @"bitmap2 is nil");
	bytesPerPixel1 = [bitmapRep hasAlpha] ? 4 : 3;
	bytesPerRow1 = [bitmapRep bytesPerRow];
	maskBytesPerPixel = [maskRep hasAlpha] ? 4 : 3;
	maskBytesPerRow = [maskRep bytesPerRow];
	bytesPerPixel2 = [matchRep hasAlpha] ? 4 : 3;
	bytesPerRow2 = [matchRep bytesPerRow];
	
	currentMatchValue = (imageMatch ? [imageMatch matchValue] : WORST_CASE_PIXEL_MATCH);

		// one of the offsets should be 0
	x_off = ([matchRep size].width - [bitmapRep size].width) / 2.0;
	y_off = ([matchRep size].height - [bitmapRep size].height) / 2.0;

		// sum the difference of all the pixels in the two bitmaps using the Riemersma metric
		// (courtesy of Dr. Dobbs 11/2001 pg. 58)
	x_size = [bitmapRep size].width; y_size = [bitmapRep size].height;
	pixelsLeft = x_size * y_size;
	for (x = 0; x < x_size; x++)
	{
		for (y = 0; y < y_size; y++)
		{
			unsigned char	*bitmap1_off = bitmap1 + x * bytesPerPixel1 + y * bytesPerRow1,
							*bitmap2_off = bitmap2 + (x + x_off) * bytesPerPixel2 + (y + y_off) * bytesPerRow2,
							*mask_off = maskBitmap + x * maskBytesPerPixel + y * maskBytesPerRow;
				
				// If there's no alpha channel or the alpha channel bit is not 0 then consider this pixel
//			if (bytesPerPixel1 == 3 || *bitmap1_off > 0)
			{
				int		redDiff = *bitmap1_off - *bitmap2_off, 
						greenDiff = *(bitmap1_off + 1) - *(bitmap2_off + 1), 
						blueDiff = *(bitmap1_off + 2) - *(bitmap2_off + 2);
				
#if 1
				float	redAverage = (*bitmap1_off + *bitmap2_off) / 2.0;
				matchValue += ((2.0 + redAverage / 256.0) * redDiff * redDiff + 
							   4 * greenDiff * greenDiff + 
							   (2 + (255.0 - redAverage) / 256.0) * blueDiff * blueDiff)
							   * ((*mask_off) / 256.0); // weighted by alpha value from mask
#else
				matchValue += (redDiff * redDiff + greenDiff * greenDiff + blueDiff * blueDiff) * ((*mask_off) / 256.0);
#endif
				pixelCount++;
			}
		}
		pixelsLeft -= y_size;
		
		// The lower the matchValue the better, so if it's already greater than the previous worst
		// then it's no use going any further.
		if (matchValue / (float)(pixelCount + pixelsLeft) > currentMatchValue)
			return WORST_CASE_PIXEL_MATCH;
	}

		// Average the value per pixel.
		// A pixel count of zero means that the image was completely transparent and we shouldn't use it.
	matchValue = (pixelCount == 0 ? WORST_CASE_PIXEL_MATCH : matchValue / pixelCount);
	
	if (!imageMatch && (!nonUniqueImageMatch || matchValue < [nonUniqueImageMatch matchValue]))
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


- (void)setImageMatch:(MacOSaiXImageMatch *)match
{
	[imageMatch autorelease];
	imageMatch = [match retain];
	
		// Now that we have a real match we don't need the placeholder anymore.
		// TBD: or do we?  what if this gets set back to nil?
	[nonUniqueImageMatch autorelease];
	nonUniqueImageMatch = nil;
	
	if (!userChosenImageMatch)
		[self sendImageChangedNotification];
}


- (MacOSaiXImageMatch *)imageMatch
{
	return imageMatch;
}


- (void)setUserChosenImageIdentifer:(NSString *)imageIdentifier fromImageSource:(id<MacOSaiXImageSource>)imageSource
{
/*
        // Don't do anything if the chosen image was already chosen
    if (userChosenImageMatch != nil && userChosenImageMatch->tileImageIndex == index) return;
    
    if (index == -1)
    {
		if (userChosenImageMatch != nil)
		{
			[document tileImageIndexNotInUse:userChosenImageMatch->tileImageIndex];
			free(userChosenImageMatch);
			userChosenImageMatch = nil;
		}
    }
    else
    {
		if (userChosenImageMatch == nil)
			userChosenImageMatch = (MacOSaiXImageMatch *)malloc(sizeof(MacOSaiXImageMatch));
		else
			[document tileImageIndexNotInUse:userChosenImageMatch->tileImageIndex];
		userChosenImageMatch->matchValue = 0;
		userChosenImageMatch->tileImageIndex = index;
		[document tileImageIndexInUse:userChosenImageMatch->tileImageIndex];
    }
*/
	[self sendImageChangedNotification];
}


- (MacOSaiXImageMatch *)userChosenImageMatch;
{
	return [[userChosenImageMatch retain] autorelease];
}


- (MacOSaiXImageMatch *)displayedImageMatch
{
	if (userChosenImageMatch)
		return userChosenImageMatch;
	else if (imageMatch)
		return imageMatch;
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
	[imageMatch release];
    [userChosenImageMatch release];
	[nonUniqueImageMatch release];
//	[cachedMatches release];
//	[cachedMatchesOrder release];
	
    [super dealloc];
}


@end
