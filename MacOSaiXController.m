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
    
    // prompt the user for the image to make a mosaic from
    result = [oPanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
	file:nil types:[NSImage imageFileTypes]];
    if (result != NSOKButton) return;

    enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:pixPath] retain];
    imageCount = 0; maxImages = 100;
    inProgress = YES;
    
    originalImage = [[NSImage alloc] initWithContentsOfFile: [[oPanel filenames] objectAtIndex:0]];
    NSAssert([originalImage isValid], @"Original image invalid");
    [originalImage setScalesWhenResized:YES];
//    [originalImage setSize:NSMakeSize([originalImage size].width / 8.0, [originalImage size].height / 8.0)];
    
    // Make NSArray of clip paths
    // this will eventually be broken out into plug-in bundles (rects, puzzle pieces, etc.)
    // the user will be able to choose which plug-in to use
    tilesWide = tilesHigh = 10;
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
    NSLog(@"Created clip paths.\n");
    
    bestMatch = (float *)malloc(sizeof(float) * [tileOutlines count]);
    for (x = 0 ; x < [tileOutlines count]; x++)
	bestMatch[x] = 0.0;
	
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
	[tile setSize:subRect.size];
	[_tiles addObject:tile];
	[pixletImage unlockFocus];
	[pixletImage release];
	pixletImage = nil;
    }
    NSLog(@"Created pixlets.\n");

    [originalView setImage:originalImage];
    
    mosaicImage = [[NSImage alloc] initWithSize:[originalImage size]];
    [mosaicView setImage:mosaicImage];
    
    //[goButton setTitle:@"Stop"];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:10
		     target:(id)self
		     selector:@selector(processAFile:)
		     userInfo:nil
		     repeats:YES];
		     
    somethingChanged = NO;
    timer = [NSTimer scheduledTimerWithTimeInterval:1
		     target:(id)self
		     selector:@selector(updateDisplay:)
		     userInfo:nil
		     repeats:YES];
}


- (void)updateDisplay:(id)timer
{
    if (somethingChanged)
    {
	[mosaicLock lock];
	[mosaicImage recache];
	[mosaicView setImage:mosaicImage];
	[[mosaicView superview] setNeedsDisplay:YES];
	[mosaicView display];
	[window display];
	[mosaicLock unlock];
    }
}


// This method gets called repeatedy while an image is being processed.
// It walks through the collection of images, one per invocation,
// and tells the processing thread to work on an image. 
- (void)processAFile:(id)timer
{
    NSString	*file;
    
    [timer invalidate];	//run only once for debug
    
    if (!inProgress) return;
    
    while ((file = [enumerator nextObject])) // && imageCount < maxImages)
    {
	if ([[NSImage imageFileTypes] containsObject:[file pathExtension]])	// if it's an image
	{
	    NSLog(@"About to process file %@\n", file);
	    [NSThread detachNewThreadSelector:@selector(calculateMatchesWithFile:)
		      toTarget:self
		      withObject:[pixPath stringByAppendingPathComponent:file]];
	    break;
	}
	//[file release];
    }
}


- (void)calculateMatchesWithFile:(id)filePath
{
    NSAutoreleasePool		*pool;
    int				imageCount, index = 0;
    NSImage			*pixletImage;
    NSRect			subRect;
    NSPoint			thePoint;
    NSBitmapImageRep		*pixletRep;
    float			matchValue;
    Tile			*tile;
    
    NSLog(@"Entering calculateMatchesWithFile...");

    pool = [[NSAutoreleasePool alloc] init];

    imageCount = [_tiles count];
    
    // load the pixlet image
    pixletImage = [[NSImage alloc] initWithContentsOfFile:filePath];
    if ([pixletImage isValid])
    {
	//create an NSBitmapImageRep from the image for direct pixel access
	[pixletImage setScalesWhenResized:YES];
	
	// loop through the tiles of the main image and compute the pixlet's match
	for (index = 0; index < imageCount; index++)
	{
	    NSLog(@"About to compare tile %s to pixlet %d of main image.\n", filePath, index);
	    tile = [_tiles objectAtIndex:index];
	    NSAssert(tile != nil, @"tile is nil");
	    
	    // Scale the pixlet to the same size as the tile
	    [pixletImage setSize:[tile size]];
	    subRect.origin.x = subRect.origin.y = 0.0;
	    subRect.size = [pixletImage size];
	    [pixletImage lockFocus];
	    pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [pixletImage size].width, [pixletImage size].height)];
	    [pixletImage unlockFocus];
	    NSAssert(pixletRep, @"pixletRep not allocated");
	    
	    // Calculate how well they match, and if it's better than the previous best, add it to the mosaic
	    matchValue = [self computeMatch:tile with:pixletRep];
	    if (matchValue > bestMatch[index])
	    {
		bestMatch[index] = matchValue;
		[mosaicLock lock];
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
	    NSLog(@"Finished comparing tile %s to pixlet %d of main image.\n", filePath, index);
	}
    }
    
    // [mosaicView setNeedsDisplay:somethingChanged];
    
    // More clean up
    [pixletImage release];
    pixletImage = nil;
    //[filePath release];

    [pool release];
    pool = nil;
    [NSThread exit];
}

- (float)computeMatch:(Tile *)tile with:(NSBitmapImageRep *)imageRep
{
    int			width, height, x, y, redDiff, greenDiff, blueDiff;
    unsigned char	*bitmap1, *bitmap2;
    float		matchValue = 0.0;
    
    if (tile == nil || imageRep == nil) return 0.0;
    
    bitmap1 = [[tile bitmapRep] bitmapData];    NSAssert(bitmap1 != nil, @"bitmap1 is nil");
    bitmap2 = [imageRep bitmapData];		NSAssert(bitmap2 != nil, @"bitmap2 is nil");
    width = [tile size].width;
    height = [tile size].height;
    for (x = 0; x < width; x++)
	for (y = 0; y < height; y++)
	{
	    redDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    greenDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    blueDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 32.0;
	    bitmap1++; bitmap2++;	//skip alpha value
	    
	    matchValue += redDiff * greenDiff * blueDiff;
	}
    NSLog(@"Match value=%f\n", matchValue);
    return matchValue;
}


@end
