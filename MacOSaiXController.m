#import <Foundation/Foundation.h>
#import "MacOSaiXController.h"
#import "Tiles.h"

@implementation MacOSaiXController

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
}

-(void)awakeFromNib
{
    inProgress = NO;
    pixPath = [[NSHomeDirectory() stringByAppendingString:@"/Pictures"] retain];
    mosaicLock = [[NSLock alloc] init];
    [progressIndicator setIndeterminate:FALSE];
    [[progressIndicator retain] removeFromSuperview];
}

// Called by the 'Go' button
- (void)startMosaic:(id)sender
{
    int			tilesWide, tilesHigh, result, x, y;
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    NSRect		subRect;
    NSSize		pixletSize;
    NSImage		*pixletImage;
    NSPoint		thePoint;
    NSAffineTransform	*translate = [NSAffineTransform transform];
    NSBezierPath	*tileOutline, *clipPath;
    NSEnumerator	*tileEnumerator;
    Tile		*tile;
    NSString		*file;
    id			timer;
    
    // prompt the user for the image to make a mosaic from
    result = [oPanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
	file:nil types:[NSImage imageFileTypes]];
    if (result != NSOKButton) return;
    
    [[goButton superview] addSubview:progressIndicator];
    [progressIndicator release];
    
    enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:pixPath] retain];
    imageCount = 0; maxImages = 100;
    inProgress = YES;
    
    originalImage = [[NSImage alloc] initWithContentsOfFile: [[oPanel filenames] objectAtIndex:0]];
    NSAssert([originalImage isValid], @"Original image invalid");
    [originalImage setScalesWhenResized:YES];
    // [originalImage setSize:NSMakeSize([originalImage size].width / 2.0 , [originalImage size].height / 2.0)];
    
    // Make NSArray of clip paths
    // this will eventually be broken out into plug-in bundles (rects, puzzle pieces, etc.)
    // the user will be able to choose which plug-in to use
    tilesWide = 40; tilesHigh = 40;
    tileOutlines = [[NSMutableArray arrayWithCapacity:tilesWide*tilesHigh] retain];
    pixletSize.width = trunc([originalImage size].width / tilesWide);
    pixletSize.height = trunc([originalImage size].height / tilesHigh);
    subRect.size = pixletSize;
    for (x = 0; x < tilesWide; x++)
	for (y = 0; y < tilesHigh; y++)
	{
	    subRect.origin.x = x * pixletSize.width;
	    subRect.origin.y = y * pixletSize.height;
	    [tileOutlines addObject:[NSBezierPath bezierPathWithRect:subRect]];
	}
    
    bestMatch = (float *)malloc(sizeof(float) * [tileOutlines count]);
    for (x = 0 ; x < [tileOutlines count]; x++)
	bestMatch[x] = 520200.0;	//256.0 * 256.0 * 4.0;
	
    // then, for each item in the array:
    //	create a new NSImage using the paths bounds
    //	set the images clip path to bounds
    //	copy the sub-rect from the original image
    //	extract the bitmap rep
    _tiles = [[NSMutableArray arrayWithCapacity:0] retain];
    tileEnumerator= [tileOutlines objectEnumerator];
    while (tileOutline = [tileEnumerator nextObject])
    {
	pixletImage = [[NSImage alloc] initWithSize:[tileOutline bounds].size];
	[pixletImage lockFocus];
	[NSGraphicsContext saveGraphicsState];
	thePoint = [tileOutline bounds].origin;
	[translate translateXBy:thePoint.x * -1 yBy:thePoint.y * -1];
	clipPath = [translate transformBezierPath:tileOutline];
	[translate translateXBy:thePoint.x yBy:thePoint.y];
	[clipPath addClip];
	[originalImage compositeToPoint:NSMakePoint(0, 0) fromRect:[tileOutline bounds]
	    operation:NSCompositeCopy];
	[NSGraphicsContext restoreGraphicsState];
	subRect.origin = NSMakePoint(0, 0);
	subRect.size = [pixletImage size];
	tile = [Tile alloc];
	[tile setBitmapRep:[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect]];
	//[tile setSize:subRect.size];
	[_tiles addObject:tile];
	[pixletImage unlockFocus];
	[pixletImage release];
	pixletImage = nil;
    }

    [originalView setImage:originalImage];
    /*[originalView lockFocus];
    [originalImage compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeCopy];
    [originalView unlockFocus];*/
    
    mosaicImage = [[NSImage alloc] initWithSize:[originalImage size]];
    [mosaicView setImage:mosaicImage];
    
    //[goButton setTitle:@"Stop"];
    
    while (0 == 1) //(file = [enumerator nextObject]))
	if (file != nil && [file isEqualToString:@"ftp.sunet.se/tv.film/Star_Wars/swshuttle.gif"])
	    break;
    
    [NSThread detachNewThreadSelector:@selector(enumerateAndMatchFiles:)
		toTarget:self
		withObject:nil
		];
		     
    somethingChanged = NO;
    timer = [NSTimer scheduledTimerWithTimeInterval:1
		     target:(id)self
		     selector:@selector(updateDisplay:)
		     userInfo:nil
		     repeats:YES];
}


- (void)updateDisplay:(id)timer
{
    int		x, y;
    float	overallMatch = 0.0;
    
    if (!somethingChanged) return;
    
    /*[originalView lockFocus];
    [originalImage compositeToPoint:NSMakePoint(0, 0) operation:NSCompositeCopy];
    [originalView unlockFocus];*/

    // recalculate and display the overall match
    for (x = 0; x < 40; x++)
	for (y = 0; y < 40; y++)
	    overallMatch += (721 - sqrt(bestMatch[x*40 + y])) / 7.21;
    overallMatch /= 40.0 * 40.0;
    overallMatch = (overallMatch >= 50.0) ? (overallMatch - 50.0) * 2.0 : 0.0;
    [progressIndicator setDoubleValue:overallMatch];
    
    [mosaicLock lock];
    [mosaicView setImage:nil];
//    [mosaicImage recache];
    [mosaicView setImage:mosaicImage];
    somethingChanged = NO;
    [mosaicLock unlock];

}


- (void)enumerateAndMatchFiles:(id)foo
{
    NSAutoreleasePool		*pool;
    NSString			*file, *filePath;
    int				tileCount, index = 0;
    NSImage			*pixletImage;
    NSRect			subRect;
    NSPoint			thePoint;
    NSBitmapImageRep		*pixletRep = nil;
    float			matchValue;
    Tile			*tile;
    
    pool = [[NSAutoreleasePool alloc] init];	// this is the first method called in the spawned thread
    if (pool == nil)
    {
	NSLog(@"Could not allocate autorelease pool");
	return;
    }
    
    tileCount = [_tiles count];
	    
    while ((file = [enumerator nextObject])) // && imageCount < maxImages)
    {
	if (file != nil && [[NSImage imageFileTypes] containsObject:[file pathExtension]])	// if it's an image
	{
	    filePath = [pixPath stringByAppendingPathComponent:file];
	
	    NSLog(@"Matching %@\n", file);
	    
	    // load the image from the file
	    pixletImage = [[NSImage alloc] initWithContentsOfFile:filePath];
	    if (pixletImage != nil && [pixletImage isValid])
	    {
		//create an NSBitmapImageRep from the image for direct pixel access
		[pixletImage setScalesWhenResized:YES];
		
		// loop through the tiles of the main image and compute the pixlet's match
		for (index = 0; index < tileCount; index++)
		{
		    tile = [_tiles objectAtIndex:index];
		    NSAssert(tile != nil, @"tile is nil");
		    
		    // Scale the pixlet to the same size as the tile (if it isn't already)
		    if ([pixletImage size].width != [[tile bitmapRep] size].width || [pixletImage size].height != [[tile bitmapRep] size].height)
			[pixletImage setSize:[[tile bitmapRep] size]];
		    subRect.origin.x = subRect.origin.y = 0.0;
		    subRect.size = [pixletImage size];
		    [pixletImage lockFocus];
		    pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [pixletImage size].width,
											     [pixletImage size].height)];
		    [pixletImage unlockFocus];
		    NSAssert(pixletRep != nil, @"pixletRep not allocated");
		    
		    // Calculate how well they match, and if it's better than the previous best, add it to the mosaic
		    matchValue = [self computeMatch:tile with:pixletRep previousBest:bestMatch[index]];
		    if (matchValue < bestMatch[index])
		    {
			//NSLog(@"    matches better (%f vs. %f) at position %d\n", matchValue, bestMatch[index], index);
			[mosaicLock lock];
			bestMatch[index] = matchValue;
			[mosaicImage lockFocus];
	    //		[NSGraphicsContext saveGraphicsState];
	    //		[[tileOutlines objectAtIndex:index] addClip];
			thePoint = [[tileOutlines objectAtIndex:index] bounds].origin;
			[pixletImage compositeToPoint:thePoint operation:NSCompositeCopy];
	    //		[NSGraphicsContext restoreGraphicsState];
			[mosaicImage unlockFocus];
			somethingChanged = YES;
			[mosaicLock unlock];
		    }
		    
		    // Clean up
		    [pixletRep release];
		    pixletRep = nil;
		    //NSLog(@"Finished comparing tile %s to pixlet %d of main image.\n", filePath, index);
		}
	    }
	    
	    // More clean up
	    if (pixletImage != nil) [pixletImage release];
	    pixletImage = nil;
	}
    }
    [pool release];
    pool = nil;
}

- (float)computeMatch:(Tile *)tile with:(NSBitmapImageRep *)imageRep previousBest:(float)prevBest
{
    int			width, height, x, y, redDiff, greenDiff, blueDiff;
    int			r1, r2, g1, g2, b1, b2;
    unsigned char	*bitmap1, *bitmap2;
    float		matchValue = 0.0;
    
    if (tile == nil || [tile bitmapRep] == nil || imageRep == nil) return 256.0 * 256.0 * 4.0;
    
    bitmap1 = [[tile bitmapRep] bitmapData];    NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [imageRep bitmapData];		NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    width = [[tile bitmapRep] size].width;
    height = [[tile bitmapRep] size].height;
    prevBest *= height * width;
    for (x = 0; x < width; x++)
	for (y = 0; y < height; y++)
	{
	    // Frank version
	    /*redDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    greenDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    blueDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    matchValue += (redDiff * greenDiff * blueDiff) * (*bitmap1++ / 256.0);
	    bitmap2++;	//skip alpha value in pixlet*/
	    
	    // Riemersma metric (courtesy of Dr. Dobbs 11/2001 pg. 58)
	    r1 = *bitmap1++; g1 = *bitmap1++; b1 = *bitmap1++;
	    r2 = *bitmap2++; g2 = *bitmap2++; b2 = *bitmap2++;
	    redDiff = (r1 + r2) / 2.0;
	    matchValue += (2+redDiff/256.0)*(r1-r2)*(r1-r2) + 4*(g1-g2)*(g1-g2) + (2+(255.0-redDiff)/256.0)*(b1-b2)*(b1-b2);
	    bitmap1++; bitmap2++;	//skip alpha values
	    
	    if (matchValue > prevBest) return matchValue;	// performance tweak
	}
    return matchValue / height / width;
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    /*int currentWidth = (int)NSWidth([sender frame]);
    int proposedWidth = (int)proposedFrameSize.width;

    if((proposedWidth % 2) != (currentWidth % 2))
	proposedWidth += 1;	// WARNING: this could exceed a maximum size
    proposedFrameSize.width = proposedWidth;
    return proposedFrameSize;*/
    return proposedFrameSize;
}


- (void)windowDidResize:(NSNotification *)notification
{
    NSRect newFrame;
    
    // calculate the original view's new frame
    newFrame.origin.x = 0;
    newFrame.origin.y = 50;
    newFrame.size.width = [[originalView superview] frame].size.width / 2;
    newFrame.size.height = [[originalView superview] frame].size.height - 50;
    [[originalView superview] setNeedsDisplayInRect:[originalView frame]];
    [[originalView superview] setNeedsDisplayInRect:newFrame];
    [originalView setFrame:newFrame];
    [originalView setNeedsDisplay:YES];

    // calculate the mosaic view's new frame
    newFrame.origin.x = [[mosaicView superview] frame].size.width / 2;
    [[mosaicView superview] setNeedsDisplayInRect:[mosaicView frame]];
    [[mosaicView superview] setNeedsDisplayInRect:newFrame];
    [mosaicView setFrame:newFrame];
    [mosaicView setNeedsDisplay:YES];
}

@end
