#import "Tiles.h"

#import "MacOSaiXDocument.h"
#import "MacOSaiXImageOrientations.h"
#import "NSBezierPath+MacOSaiX.h"


@interface MacOSaiXMosaic (TilePrivate)
- (void)tileDidExtractBitmap:(MacOSaiXTile *)tile;
@end


@implementation MacOSaiXTile


- (id)initWithUnitOutline:(NSBezierPath *)outline 
		 imageOrientation:(NSNumber *)angle
				   mosaic:(MacOSaiXMosaic *)inMosaic;
{
	if (self = [super init])
	{
		[self setUnitOutline:outline];
		if (angle)
			[self setImageOrientation:[angle floatValue]];
		[self setMosaic:inMosaic];
	}
	return self;
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	mosaic = inMosaic;	// non-retained, it retains us
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}

- (void)setUnitOutline:(NSBezierPath *)outline
{
    [unitOutline autorelease];
    unitOutline = [outline retain];
}


- (NSBezierPath *)unitOutline
{
    return unitOutline;
}


- (NSBezierPath *)targetOutline
{
		// Scale our unit-square-based outline to the target image's dimensions.
	NSSize				targetImageSize = [[mosaic targetImage] size];
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform scaleXBy:targetImageSize.width yBy:targetImageSize.height];
	
	return [transform transformBezierPath:[self unitOutline]];
}


- (NSBezierPath *)rotatedTargetOutline
{
		// Rotate the outline to offset the tile's image orientation.  The rotated outline will be centered at the origin.
	NSBezierPath		*targetOutline = [self targetOutline];
	NSAffineTransform	*transform = [NSAffineTransform transform];
	
	[transform translateXBy:NSMidX([targetOutline bounds]) yBy:NSMidY([targetOutline bounds])];
	[transform rotateByDegrees:-[self imageOrientation]];
	[transform translateXBy:-NSMidX([targetOutline bounds]) yBy:-NSMidY([targetOutline bounds])];
	
	return [transform transformBezierPath:targetOutline];
}


- (void)setImageOrientation:(float)angle
{
	[imageOrientation release];
	imageOrientation = [[NSNumber numberWithFloat:angle] retain];
}


- (float)imageOrientation
{
	float	angle = 0.0;
	
	if (imageOrientation)
		angle = [imageOrientation floatValue];
	else
		angle = [[mosaic imageOrientations] imageOrientationAtPoint:NSMakePoint(NSMidX([[self targetOutline] bounds]), NSMidY([[self targetOutline] bounds])) 
													   inRectOfSize:[[mosaic targetImage] size]];
	
	return angle;
}


- (float)worstCaseMatchValue
{
	return 255.0 * 255.0 * 9.0;
}


- (void)resetBitmapRepAndMask
{
		// TODO: this should not be called from outside.  we should listen for notifications 
		// that the target image or tile shapes changed for our mosaic and reset at that
		// point.
    [bitmapRep autorelease];
    bitmapRep = nil;
    [maskRep autorelease];
    maskRep = nil;
}


- (void)createBitmapRep
{
	NSBezierPath		*rotatedOutline = [self rotatedTargetOutline];
	NSRect				rotatedBounds = [rotatedOutline bounds];
	BOOL				widthLimited = (NSWidth(rotatedBounds) > NSHeight(rotatedBounds));
	
		// Scale the rotated outline to the bitmap size.
	NSAffineTransform	*transform = [NSAffineTransform transform];
	if (widthLimited)
		[transform scaleBy:TILE_BITMAP_SIZE / NSWidth(rotatedBounds)];
	else
		[transform scaleBy:TILE_BITMAP_SIZE / NSHeight(rotatedBounds)];
	[transform translateXBy:-NSMinX(rotatedBounds) yBy:-NSMinY(rotatedBounds)];
	NSBezierPath		*bitmapOutline = [transform transformBezierPath:rotatedOutline];
	NSRect				bitmapBounds = [bitmapOutline bounds];
	if (widthLimited)
		bitmapBounds.origin.y = (TILE_BITMAP_SIZE - NSHeight(bitmapBounds)) / 2.0;
	else
		bitmapBounds.origin.x = (TILE_BITMAP_SIZE - NSWidth(bitmapBounds)) / 2.0;
	
	// TODO: If this is done with CG instead of Cocoa then it doesn't have to be on the main thread.
	BOOL				focusLocked = NO;
	NSImage				*workingImage = [[NSImage alloc] initWithSize:NSMakeSize(TILE_BITMAP_SIZE, TILE_BITMAP_SIZE)];
	
	NS_DURING
		[workingImage lockFocus];
		focusLocked = YES;
		
			// Start with a clear image.
		[[NSColor clearColor] set];
		[[NSBezierPath bezierPathWithRect:NSMakeRect(0.0, 0.0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE)] fill];
		
			// Draw the target image so that the correct portion of the image is rendered at the correct orientation inside the working image.
		[[NSGraphicsContext currentContext] saveGraphicsState];
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:TILE_BITMAP_SIZE / 2.0 yBy:TILE_BITMAP_SIZE / 2.0];
			[transform scaleBy:NSWidth(bitmapBounds) / NSWidth(rotatedBounds)];
			[transform rotateByDegrees:-[self imageOrientation]];
			[transform translateXBy:-NSMidX(rotatedBounds) yBy:-NSMidY(rotatedBounds)];
			[transform concat];
			
			NSImage				*targetImage = [mosaic targetImage];
			NSRect				targetImageBounds = NSMakeRect(0.0, 0.0, [targetImage size].width, [targetImage size].height);
			[targetImage drawInRect:targetImageBounds 
							 fromRect:targetImageBounds 
							operation:NSCompositeCopy 
							 fraction:1.0];
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
		bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:bitmapBounds];
		#ifdef DEBUG
			if (bitmapRep == nil)
				NSLog(@"Could not extract tile image from target.");
		#endif
	NS_HANDLER
		#ifdef DEBUG
			NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
		#endif
	NS_ENDHANDLER
	
	if (focusLocked)
		[workingImage unlockFocus];
	
	[workingImage release];

		// Calculate a mask image using the tile's outline that is the same size as the image extracted from the target.  The mask will be white for pixels that are inside the tile and black outside.
		// (This would work better if we could just replace the previous rep's alpha channel but I haven't figured out an easy way to do that yet.)
	maskRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil 
													   pixelsWide:[bitmapRep size].width
													   pixelsHigh:[bitmapRep size].height 
													bitsPerSample:8 
												  samplesPerPixel:1 
														 hasAlpha:NO 
														 isPlanar:NO 
												   colorSpaceName:NSCalibratedWhiteColorSpace 
													  bytesPerRow:0 
													 bitsPerPixel:0];
	CGColorSpaceRef	grayscaleColorSpace = CGColorSpaceCreateDeviceGray();
	CGContextRef	bitmapContext = CGBitmapContextCreate([maskRep bitmapData], 
														  [maskRep pixelsWide], 
														  [maskRep pixelsHigh], 
														  [maskRep bitsPerSample], 
														  [maskRep bytesPerRow], 
														  grayscaleColorSpace,
														  kCGBitmapByteOrderDefault);
	
		// Start with a black background.
	CGContextSetGrayFillColor(bitmapContext, 0.0, 1.0);
	CGRect				cgDestRect = CGRectMake(0.0, 0.0, bitmapBounds.size.width, bitmapBounds.size.height);
	CGContextFillRect(bitmapContext, cgDestRect);
	
		// Fill the tile's outline with white.
	CGPathRef			cgTileOutline = [bitmapOutline quartzPath];
	CGContextSetGrayFillColor(bitmapContext, 1.0, 1.0);
	CGContextBeginPath(bitmapContext);
	CGContextAddPath(bitmapContext, cgTileOutline);
	CGContextClosePath(bitmapContext);
	CGContextFillPath(bitmapContext);
	CGPathRelease(cgTileOutline);
	
	CGContextRelease(bitmapContext);
	CGColorSpaceRelease(grayscaleColorSpace);
}


- (NSBitmapImageRep *)bitmapRep
{
	if (!bitmapRep)
	{
		[self performSelectorOnMainThread:@selector(createBitmapRep) withObject:nil waitUntilDone:YES];
		
		[mosaic tileDidExtractBitmap:self];
	}
	
    return bitmapRep;
}


- (NSBitmapImageRep *)maskRep
{
	return maskRep;
}


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


- (void)setUniqueImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != uniqueImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = uniqueImageMatch;
		
		[uniqueImageMatch autorelease];
		uniqueImageMatch = [match retain];
		
		[self sendNotificationThatImageMatch:@"Unique" changedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)uniqueImageMatch
{
	return [[uniqueImageMatch retain] autorelease];
}


- (void)setBestImageMatch:(MacOSaiXImageMatch *)match
{
	if (match != bestImageMatch)
	{
		MacOSaiXImageMatch	*previousMatch = bestImageMatch;
		
		[bestImageMatch autorelease];
		bestImageMatch = [match retain];
		
		[self sendNotificationThatImageMatch:@"Best" changedFrom:previousMatch];
	}
}


- (MacOSaiXImageMatch *)bestImageMatch
{
	return [[bestImageMatch retain] autorelease];
}


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


- (void)dealloc
{
    [unitOutline release];
    [bitmapRep release];
	[maskRep release];
	[uniqueImageMatch release];
    [userChosenImageMatch release];
	[bestImageMatch release];
	
    [super dealloc];
}


@end
