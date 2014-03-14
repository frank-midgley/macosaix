#import "Tiles.h"

#import "MacOSaiXDocument.h"
#import "MacOSaiXImageMatchCache.h"
#import "MacOSaiXSourceImage.h"


@interface MacOSaiXMosaic (TilePrivate)
- (void)tileDidExtractBitmap:(MacOSaiXTile *)tile;
@end


@implementation MacOSaiXTile


- (id)initWithOutline:(NSBezierPath *)inOutline fromMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (self = [super init])
	{
		[self setOutline:inOutline];
		mosaic = inMosaic;	// non-retained, it retains us
		bitmapsLock = [[NSLock alloc] init];
		recentUniqueImageMatches = [[NSMutableArray alloc] init];
		uniqueImageMatchIsOptimal = YES;
		bestMatchLock = [[NSLock alloc] init];
		cachedMatches = [[NSMutableDictionary alloc] init];
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


#pragma mark -
#pragma mark Outline


- (void)setOutline:(NSBezierPath *)inOutline
{
    [outline autorelease];
    outline = [inOutline retain];
	
	outlineMidPoint = NSMakePoint(NSMidX([outline bounds]), NSMidY([outline bounds]));
}


- (NSBezierPath *)outline
{
    return outline;
}


- (NSPoint)outlineMidPoint
{
	return outlineMidPoint;
}


#pragma mark -


- (float)worstCaseMatchValue
{
	return 255.0 * 255.0 * 9.0;
}


#pragma mark -
#pragma mark Bitmap and mask


- (void)createBitmapRep
{
	/*
		100x100 => 360 MB	=> 34 MB
		 40x40  =>  63 MB	=> 14 MB
		 10x10  =>   2.6 MB	=>  
	 */
	
	
		// Determine the bounds of the tile in the original image and in the workingImage.
	NSBezierPath	*tileOutline = [self outline];
	NSImage			*originalImage = [mosaic originalImage];
	
	if (originalImage)
	{
		NSRect			origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
											  [tileOutline bounds].origin.y * [originalImage size].height,
											  [tileOutline bounds].size.width * [originalImage size].width,
											  [tileOutline bounds].size.height * [originalImage size].height),
						destRect = (origRect.size.width > origRect.size.height) ?
									NSMakeRect(0, 0, TILE_BITMAP_SIZE, (int)(TILE_BITMAP_SIZE * origRect.size.height / origRect.size.width)) : 
									NSMakeRect(0, 0, (int)(TILE_BITMAP_SIZE * origRect.size.width / origRect.size.height), TILE_BITMAP_SIZE);
		
		if (NSWidth(destRect) >= 1.0 && NSHeight(destRect) >= 1.0)
		{
			NSImage	*workingImage = [[NSImage alloc] initWithSize:destRect.size];
//			[workingImage setCachedSeparately:YES];
			
			BOOL	focusLocked = NO;
			
			NS_DURING
				[workingImage lockFocus];
				focusLocked = YES;
				
					// Start with a clear image to overwrite any previous scratch contents.
				[[NSColor clearColor] set];
				NSRectFill(destRect);
				
					// Copy out the portion of the original image contained by the tile's outline.
				[originalImage drawInRect:destRect fromRect:origRect operation:NSCompositeSourceOver fraction:1.0];
//				bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect];
//				#ifdef DEBUG
//					if (bitmapRep == nil)
//						NSLog(@"Could not extract tile image from original.");
//				#endif
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
				#endif
			NS_ENDHANDLER
			
			if (focusLocked)
			{
				[workingImage unlockFocus];
				bitmapRep = [[MacOSaiXBitmapImageRep alloc] initWithData:[workingImage TIFFRepresentation]];
				[bitmapRep setProperty:NSImageColorSyncProfileData withValue:nil];
				#ifdef DEBUG
					if (bitmapRep == nil)
						NSLog(@"Could not extract tile image from original.");
				#endif
			}
			
			focusLocked = NO;
			NS_DURING
				[workingImage lockFocus];
				focusLocked = YES;
				
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
//					maskRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect];
				[[NSGraphicsContext currentContext] restoreGraphicsState];
			NS_HANDLER
				#ifdef DEBUG
					NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
				#endif
			NS_ENDHANDLER
			
			if (focusLocked)
			{
				[workingImage unlockFocus];
				maskRep = [[MacOSaiXBitmapImageRep alloc] initWithData:[workingImage TIFFRepresentation]];
				[maskRep setProperty:NSImageColorSyncProfileData withValue:nil];
				#ifdef DEBUG
					if (maskRep == nil)
						NSLog(@"Could not create mask rep for tile.");
				#endif
			}
			
			[workingImage release];
		}
	}
}


- (NSBitmapImageRep *)bitmapRep
{
	NSBitmapImageRep *rep = nil;
	
	[bitmapsLock lock];
		if (!bitmapRep)
		{
			[self performSelectorOnMainThread:@selector(createBitmapRep) withObject:nil waitUntilDone:YES];
			//[self createBitmapRep];
			
			if (bitmapRep)
				[mosaic tileDidExtractBitmap:self];
		}
		
		rep = bitmapRep;
	[bitmapsLock unlock];
		
    return rep;
}


- (NSBitmapImageRep *)maskRep
{
	NSBitmapImageRep *rep = nil;
	
	[bitmapsLock lock];
		if (!bitmapRep)
		{
			[self performSelectorOnMainThread:@selector(createBitmapRep) withObject:nil waitUntilDone:YES];
			
			if (bitmapRep)
				[mosaic tileDidExtractBitmap:self];
		}
		rep = maskRep;
	[bitmapsLock unlock];
	
	return rep;
}


#pragma mark -


- (void)sendNotificationThatImageMatch:(NSString *)matchType changedFrom:(MacOSaiXImageMatch *)previousMatch
{
	[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileImageDidChangeNotification
														object:mosaic 
													  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																	self, @"Tile", 
																	matchType, @"Match Type", 
																	previousMatch, @"Previous Match",
																	nil]];
}


#pragma mark -
#pragma mark Unique image match


- (void)setUniqueImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != uniqueImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = uniqueImageMatch;
		
		if (match && previousMatch && [match matchValue] > [previousMatch matchValue] && ![mosaic allImagesCanBeRevisited])
		{
			// match will only ever be worse than the previous unique match if the previous image can't be used in this tile any longer without violating the image usage rules.  This may change when other tiles' unique matches change so remember that we could have gotten a better match.
			
			uniqueImageMatchIsOptimal = NO;
		}
		
		[uniqueImageMatch autorelease];
		uniqueImageMatch = [match retain];
		
			// Update the list of recent unique matches.
			// TBD: locking?
		if (match)
			[recentUniqueImageMatches removeObjectIdenticalTo:match];
		if (previousMatch)
		{
			[recentUniqueImageMatches insertObject:previousMatch atIndex:0];
			if ([recentUniqueImageMatches count] > 16)
				[recentUniqueImageMatches removeLastObject];
		}
		
			// If this match is the best the tile has ever seen then it's obviously optimal.
		if (match && match == [self bestImageMatch])
			uniqueImageMatchIsOptimal = YES;
		
		[self sendNotificationThatImageMatch:@"Unique" changedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)uniqueImageMatch
{
	return [[uniqueImageMatch retain] autorelease];
}


- (NSArray *)recentUniqueImageMatches
{
	return [NSArray arrayWithArray:recentUniqueImageMatches];	// TBD: locking?
}


- (NSComparisonResult)compareUniqueImageMatchValue:(MacOSaiXTile *)otherTile
{
	MacOSaiXImageMatch	*otherMatch = [otherTile uniqueImageMatch];
	
	if (!uniqueImageMatch && !otherMatch)
		return NSOrderedSame;
	else if (uniqueImageMatch && !otherMatch)
		return NSOrderedAscending;
	else if (!uniqueImageMatch && otherMatch)
		return NSOrderedDescending;
	else
	{
		float	myValue = [uniqueImageMatch matchValue], 
				otherValue = [uniqueImageMatch matchValue];
		
		if (myValue < otherValue)
			return NSOrderedAscending;
		else if (myValue > otherValue)
			return NSOrderedDescending;
		else
			return NSOrderedSame;
	}
}


- (void)setUniqueImageMatchIsOptimal:(BOOL)flag
{
	uniqueImageMatchIsOptimal = flag;
}


- (BOOL)uniqueImageMatchIsOptimal
{
	return uniqueImageMatchIsOptimal;
}


#pragma mark -
#pragma mark Best image match


- (void)setBestImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != bestImageMatch)
	{
		[bestMatchLock lock];
			MacOSaiXImageMatch	*previousMatch = bestImageMatch;
			
			[bestImageMatch autorelease];
			bestImageMatch = [match retain];
		[bestMatchLock unlock];
		
		[self sendNotificationThatImageMatch:@"Best" changedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)bestImageMatch
{
	MacOSaiXImageMatch	*match = nil;
	
	[bestMatchLock lock];
		match = [[bestImageMatch retain] autorelease];
	[bestMatchLock unlock];
	
	return match;
}


#pragma mark -
#pragma mark User chosen image match


- (void)setUserChosenImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != userChosenImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = userChosenImageMatch;
		
		[userChosenImageMatch autorelease];
		userChosenImageMatch = [match retain];
		
		[self sendNotificationThatImageMatch:@"User Chosen" changedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)userChosenImageMatch;
{
	return [[userChosenImageMatch retain] autorelease];
}


#pragma mark -


- (MacOSaiXImageMatch *)displayedImageMatch
{
	if (userChosenImageMatch)
		return userChosenImageMatch;
	else if (uniqueImageMatch)
		return uniqueImageMatch;
	else if (bestImageMatch)
		return bestImageMatch;
	else
		return nil;
}


- (void)imageSourceWasRemoved:(id<MacOSaiXImageSource>)imageSource
{
	if ([[[self userChosenImageMatch] sourceImage] source] == imageSource)
		[self setUserChosenImageMatch:nil];
	if ([[[self uniqueImageMatch] sourceImage] source] == imageSource)
		[self setUniqueImageMatch:nil];
	if ([[[self bestImageMatch] sourceImage] source] == imageSource)
		[self setBestImageMatch:nil];
	
		// Remove any previous unique matches from this source.
		// TBD: locking?
	NSEnumerator		*previousMatchEnumerator = [[self recentUniqueImageMatches] objectEnumerator];
	MacOSaiXImageMatch	*previousMatch = nil;
	while (previousMatch = [previousMatchEnumerator nextObject])
		if ([[previousMatch sourceImage] source] == imageSource)
			[recentUniqueImageMatches removeObjectIdenticalTo:previousMatch];
	
	[[MacOSaiXImageMatchCache sharedCache] lock];
        NSEnumerator		*cacheKeyEnumerator = [[cachedMatches allKeys] objectEnumerator];
        NSString			*cacheKey;
        while (cacheKey = [cacheKeyEnumerator nextObject])
        {
            MacOSaiXImageMatch	*cachedMatch = [cachedMatches objectForKey:cacheKey];
            if ([[cachedMatch sourceImage] source] == imageSource)
                [cachedMatches removeObjectForKey:cacheKey];
        }
	[[MacOSaiXImageMatchCache sharedCache] unlock];
}


- (void)reset
{
    [bitmapRep autorelease];
    bitmapRep = nil;
    [maskRep autorelease];
    maskRep = nil;
    
	[bestMatchLock lock];
		[bestImageMatch autorelease];
		bestImageMatch = nil;
	[bestMatchLock unlock];
	
    [uniqueImageMatch autorelease];
    uniqueImageMatch = nil;
    [recentUniqueImageMatches removeAllObjects];
	uniqueImageMatchIsOptimal = YES;
    
    {
        [[MacOSaiXImageMatchCache sharedCache] lock];
            [cachedMatches removeAllObjects];
        [[MacOSaiXImageMatchCache sharedCache] unlock];
    }
}


#pragma mark -
#pragma mark Matches cache

// All of these methods assume that the global image cache is locked.

- (void)cacheMatch:(MacOSaiXImageMatch *)match
{
	[cachedMatches setObject:match forKey:[[match sourceImage] key]];
}


- (NSArray *)cachedMatches
{
	return [NSArray arrayWithArray:[cachedMatches allValues]];
}


- (void)removeCachedMatch:(MacOSaiXImageMatch *)match
{
	[cachedMatches removeObjectForKey:[[match sourceImage] key]];
}


- (void)removeCachedMatches
{
	[cachedMatches removeAllObjects];	// this crashes for a 200x200 mosaic if the original is changed after some matching has been done
}


#pragma mark -


- (void)dealloc
{
    [outline release];
	[neighborSet release];
    [bitmapRep release];
	[maskRep release];
	[bitmapsLock release];
	[uniqueImageMatch release];
	[bestImageMatch release];
	[bestMatchLock release];
    [userChosenImageMatch release];
	[cachedMatches release];	// TBD: this crashed twice
	[recentUniqueImageMatches release];
	
    [super dealloc];
}


@end
