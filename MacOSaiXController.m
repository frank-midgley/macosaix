#import <Foundation/Foundation.h>
#import "MacOSaiXController.h"
#import "Matcher.h"

@implementation MacOSaiXController

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
    NSPort		*port1,  *port2;
    NSArray		*portArray;
    NSConnection	*kitConnection;
    
    // Spawn a thread that will do the actual work of matching images
    port1 = [NSPort port];
    port2 = [NSPort port];
    
    kitConnection = [[NSConnection alloc] initWithReceivePort:port1 sendPort:port2];
    [kitConnection setRootObject:self];
    
    portArray = [NSArray arrayWithObjects:port2, port1, nil];	// ports intentionally switched here
    [NSThread detachNewThreadSelector:@selector(connectWithPorts:) toTarget:[Matcher class]
	withObject:portArray];
}

- (void)setServer:(id)anObject
{
    [anObject setProtocolForProxy:@protocol(MatcherMethods)];
    matcher = (id <MatcherMethods>)[anObject retain];
    return;
}

-(void)awakeFromNib
{
    inProgress = NO;
    matcherIdle = YES;
    pixPath = [[NSHomeDirectory() stringByAppendingString:@"/Pictures"] retain];
}

- (void)startMosaic:(id)sender
{
    int			tilesWide, tilesHigh, result, x, y;
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    NSRect		subRect;
    NSSize		pixletSize;
    NSImage		*pixletImage;
    NSBitmapImageRep	*pixletRep;
    NSPoint		thePoint;
    NSAffineTransform	*translate = [NSAffineTransform transform];
    NSBezierPath	*tileOutline, *clipPath;
    NSEnumerator	*tileEnumerator;
    NSData		*tileData;
    Tile		*tile;
//    NSMutableArray	*tileImages;
    
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
    
    bestMatch = (float *)malloc(sizeof(float) * [tileOutlines count]);
    for (x = 0 ; x < [tileOutlines count]; x++)
	bestMatch[x] = 0.0;
	
    // then, for each item in the array:
    //	create a new NSImage using the paths bounds
    //	set the images clip path to bounds
    //	copy the sub-rect from the original image
    //	extract the bitmap rep
    _tiles = [[TileCollection alloc] init];
//    _tileImages = [[NSMutableArray arrayWithCapacity:[tileOutlines count]] retain];
//    _tileImages = (NSBitmapImageRep **)malloc([tileOutlines count] * sizeof(NSBitmapImageRep *));
    x = 0;
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
	pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
	tileData = [NSData dataWithBytes:[pixletRep bitmapData]
			   length:(subRect.size.height * [pixletRep bytesPerRow])];
	tile = [[Tile alloc] init];
	[tile setSize:[pixletImage size]];
	[tile setBitmapData:tileData];
	[_tiles addTile:tile];
	//[tile autorelease];
	//[tileData autorelease];
	[pixletRep release];
	
//	[_tileImages addObject:[[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect] retain]];
//	_tileImages[x++] = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect] retain];
	[pixletImage unlockFocus];
	[pixletImage release];
    }
    [matcher setTileCollection:_tiles];
//    [self setTileImages:tileImages];
//    tileImagesTransporter = [[ArrayTransporter alloc] retain];
//    [tileImagesTransporter setArray:tileImages];
    [originalView setImage:originalImage];
    
    mosaicImage = [[NSImage alloc] initWithSize:[originalImage size]];
    [mosaicView setImage:mosaicImage];
    
    //[goButton setTitle:@"Stop"];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:1
		     target:(id)self
		     selector:@selector(processFiles:)
		     userInfo:nil
		     repeats:YES];
}

- (void)setTileImages:(NSMutableArray *)newTileImages
{
/*    NSMutableArray *oldTileImages = nil;
    if (_tileImages != newTileImages)		// If they're the same, do nothing
    {
	oldTileImages = _tileImages;		// Copy the reference
	_tileImages = [newTileImages retain];	// First retain the new object
	[oldTileImages release];		// Then release the old object
    }

    return;*/
}


// This methos gets called repeatedy while an image is being processed.
// It walks through the collection of images, one per invocation,
// and tells the processing thread to work on an image. 
- (void)processFiles:(id)timer
{
    NSString	*file;
    
    if (!inProgress || !matcherIdle) return;
    
    while ((file = [enumerator nextObject])) // && imageCount < maxImages)
    {
	if ([[NSImage imageFileTypes] containsObject:[file pathExtension]])
	{
	    matcherIdle = NO;
	    [matcher calculateMatchesWithFile:[pixPath stringByAppendingPathComponent:file] connection:self];
	    break;
	}
	//[file release];
    }
}

- (void *)getTileImages
{
    return (void *)_tileImages;
}

- (NSBitmapImageRep *)getTileImageRep:(int)index
{
    return [_tileImages objectAtIndex:index];
}

// this gets called from the matcher thread
- (void)checkInMatch:(float)matchValue atIndex:(int)index forFile:(NSString *)filePath
{
    NSImage	*pixletImage;
//    int		index;
    NSPoint	thePoint;
    
    imageCount++;

    if (matchValue > bestMatch[index])
    {
	pixletImage = [[NSImage alloc] initWithContentsOfFile:filePath];
	if ([pixletImage isValid])
	{
	    [pixletImage setScalesWhenResized:YES];
	
	    bestMatch[index] = matchValue;
	    [pixletImage setSize:[[tileOutlines objectAtIndex:index] bounds].size];
	    [mosaicImage lockFocus];
//		[NSGraphicsContext saveGraphicsState];
//		[[tileOutlines objectAtIndex:index] addClip];
	    thePoint = [[tileOutlines objectAtIndex:index] bounds].origin;
	    [pixletImage compositeToPoint:thePoint operation:NSCompositeCopy];
//		[NSGraphicsContext restoreGraphicsState];
	    [mosaicImage unlockFocus];
	    //[mosaicView setImage:mosaicImage];
	
//    [imagesMatched setEditable:YES];
//    [imagesMatched insertText:[NSString stringWithFormat: @"%d", imageCount]];
//    [imagesMatched setEditable:NO];

	}
	[pixletImage release];
    }
    
    if (index == 99) matcherIdle = YES;
}





/*	    // load the pixlet image and create an NSBitmapImageRep from it for direct pixel access
	    pixletImage = [[NSImage alloc]initByReferencingFile:[pixPath stringByAppendingPathComponent:file]];
	    //NSAssert([pixletImage isValid], @"Tile image invalid");
	    if ([pixletImage isValid])
	    {
		[pixletImage setScalesWhenResized:YES];
		[pixletImage setSize:pixletSize];
		subRect.origin.x = subRect.origin.y = 0.0;
		[pixletImage lockFocus];
		pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
		[pixletImage unlockFocus];
		
		// loop through the tiles of the main image and check the pixlet's match against the previous best
		for (x = 0; x < tilesWide; x++)
		    for (y = 0; y < tilesHigh; y++)
		    {
			thisMatch = [self computeMatch:subImage[x][y] with:pixletRep];
			if (thisMatch > bestMatch[x][y])
			{
			    thePoint.x = x * pixletSize.width;
			    thePoint.y = y * pixletSize.height;
			    [mosaicImage lockFocus];
			    [pixletImage compositeToPoint:thePoint operation:NSCompositeCopy];
			    [mosaicImage unlockFocus];
			    bestMatch[x][y] = thisMatch;
			}
		    }
		[pixletRep release];
		[pixletImage release];
	    }
    

- (float)computeMatch:(NSBitmapImageRep *)imageRep1 with:(NSBitmapImageRep *)imageRep2
{
    int			x, y, redDiff, greenDiff, blueDiff;
    unsigned char	*bitmap1, *bitmap2;
    float		matchValue = 0.0;
    
    if (imageRep1 == NULL || imageRep2 == NULL) return 0.0;
    bitmap1 = [imageRep1 bitmapData];
    bitmap2 = [imageRep2 bitmapData];
    for (x = 0; x < [imageRep1 pixelsWide]; x++)
	for (y = 0; y < [imageRep1 pixelsHigh]; y++)
	{
	    redDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 8.0;
	    greenDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 8.0;
	    blueDiff = (256 - abs(*bitmap1++ - *bitmap2++)) / 8.0;
	    bitmap1++; bitmap2++;	//skip alpha value
	    
	    matchValue += redDiff * greenDiff * blueDiff;
	}
    return matchValue;
}*/

@end
