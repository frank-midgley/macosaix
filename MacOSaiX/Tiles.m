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
		outline = [inOutline copy];
		document = inDocument;	// the document retains us so we don't retain it
		
		cachedMatches = [[NSMutableDictionary dictionary] retain];
		cachedMatchesOrder = [[NSMutableArray array] retain];
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


- (void)setBitmapRep:(NSBitmapImageRep *)inBitmapRep withMask:(NSBitmapImageRep *)inMaskRep
{
    [bitmapRep autorelease];
    bitmapRep = [inBitmapRep retain];
    [maskRep autorelease];
    maskRep = [inMaskRep retain];
}


- (NSBitmapImageRep *)bitmapRep
{
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
	
	bitmap1 = [bitmapRep bitmapData];	NSAssert(bitmap1 != nil, @"bitmap1 is nil");
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
	[cachedMatches release];
	[cachedMatchesOrder release];
	
    [super dealloc];
}


@end
