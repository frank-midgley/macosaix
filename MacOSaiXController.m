#import <Foundation/Foundation.h>
#import "MacOSaiXController.h"
#import "Tiles.h"
#import "TileMatch.h"

@implementation MacOSaiXController

- (void)applicationDidFinishLaunching:(NSNotification *)note
{
}

-(void)awakeFromNib
{
    pixPath = [[NSHomeDirectory() stringByAppendingString:@"/Pictures"] retain];
    mosaicLock = [[NSLock alloc] init];
    _updatedTilesLock = [[NSLock alloc] init];
}

// Called by the 'Go' button
- (void)startMosaic:(id)sender
{
    int			result;
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    id			updateWindowTimer;
    
    // prompt the user for the image to make a mosaic from
    result = [oPanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
	file:nil types:[NSImage imageFileTypes]];
    if (result != NSOKButton) return;

    [openButton setEnabled:NO];
    [saveButton setEnabled:YES];
    
    originalImage = [[NSImage alloc] initWithContentsOfFile: [[oPanel filenames] objectAtIndex:0]];
    NSAssert([originalImage isValid], @"Original image invalid");
    [originalImage setDataRetained:YES];
    [originalImage setScalesWhenResized:YES];
    //[originalImage setSize:NSMakeSize([originalImage size].width / 2.0 , [originalImage size].height / 2.0)];
    //[originalImage setSize:NSMakeSize(400, 400)];
    [originalView setImage:originalImage];

    // Create an NSImage to hold the mosaic
    mosaicImage = [[NSImage alloc] initWithSize:[originalImage size]];
    [mosaicImage setDataRetained:YES];
        
    enumerator = [[[NSFileManager defaultManager] enumeratorAtPath:pixPath] retain];
    
    _updatedTiles = [[NSMutableArray arrayWithCapacity:0] retain];
    [_updatedTiles addObject:_updatedTilesLock];
    
    [NSThread detachNewThreadSelector:@selector(enumerateAndMatchFiles:) toTarget:self withObject:nil];
		     
    updateWindowTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
				 target:(id)self
				 selector:@selector(updateDisplay:)
				 userInfo:nil
				 repeats:YES];
}


- (void)updateDisplay:(id)timer
{
    int		index;
    float	overallMatch;
    Tile*	tile;
    
    if (_selectedTile == nil)
	[selectedTileFilePath setStringValue:@"none"];
    else
	[selectedTileFilePath setStringValue:[[_selectedTile bestMatch] filePath]];
    
    //NSLog(@"%d tiles in display queue", [_updatedTiles count]-1);
    if ([_updatedTiles count] < 2) return;
    
    // recalculate and display the overall match
    for (overallMatch = 0.0, index = 0; index < [_tiles count]; index++)
	overallMatch += (721 - sqrt([[[_tiles objectAtIndex:index] bestMatch] matchValue])) / 721;
    overallMatch /= [_tiles count];
    overallMatch = (overallMatch >= 0.5) ? (overallMatch - 0.5) * 2.0 : 0.0;
    overallMatch = (overallMatch * overallMatch) * 100.0;
    [progressIndicator setDoubleValue:overallMatch];
    
    // add any new matching files to the mosaic
    [[_updatedTiles objectAtIndex:0] lock];
    [mosaicImage lockFocus];
    while ([_updatedTiles count] > 1)
    {
	tile = [_updatedTiles objectAtIndex:1];
	[NSGraphicsContext saveGraphicsState];
	NSAssert([tile outline] != nil, @"Tile outline has been freed");
	[[tile outline] addClip];
	[[[tile bestMatch] bitmapRep] drawInRect:[[tile outline] bounds]];
	[NSGraphicsContext restoreGraphicsState];
	[_updatedTiles removeObjectAtIndex:1];
    }
    [mosaicImage unlockFocus];
    [[_updatedTiles objectAtIndex:0] unlock];

    [mosaicView setImage:nil];	// annoying hack to get the NSImageView to redisplay and updated NSImage
    [mosaicView setImage:mosaicImage];
}


- (void)enumerateAndMatchFiles:(id)foo
{
    NSAutoreleasePool		*pool, *pool2;
    NSString			*file, *filePath;
    int				tilesWide, tilesHigh, x, y, index = 0;
    NSSize			pixletSize;
    NSImage			*pixletImage;
    NSRect			subRect;
    NSPoint			thePoint;
    NSAffineTransform		*translate;
    NSBitmapImageRep		*pixletRep = nil;
    NSBezierPath		*clipPath;
    Tile			*tile;
    
    pool = [[NSAutoreleasePool alloc] init];	// this is the first method called in the spawned thread
    if (pool == nil)
    {
	NSLog(@"Could not allocate autorelease pool");
	return;
    }
    
    translate = [NSAffineTransform transform];

    // hack to start after a certain file
    //while (file = [enumerator nextObject]))
	//if (file != nil && [file isEqualToString:@"ftp.sunet.se/tv.film/Star_Wars/swshuttle.gif"]) break;
    
    // Create tiles from the original image to match against
    tilesWide = 40; tilesHigh = 40;
//    tilesWide = 45; tilesHigh = 53;
    _tiles = [[NSMutableArray arrayWithCapacity:0] retain];
    pixletSize.width = [originalImage size].width / tilesWide;
    pixletSize.height = [originalImage size].height / tilesHigh;
    subRect.size = pixletSize;
    pixletImage = [[NSImage alloc] initWithSize:NSMakeSize(0, 0)];
    for (x = 0; x < tilesWide; x++)
	for (y = 0; y < tilesHigh; y++)
	{
	    tile = [[Tile alloc] init];
	    NSAssert(tile != nil, @"Could not allocate tile");
	    
	    // define the tile's outline, currently a rectangle
	    // this could eventually be other shapes (rects, puzzle pieces, etc.)
	    // and broken out into plug-in bundles to allow third party development
	    subRect.origin.x = x * pixletSize.width;
	    subRect.origin.y = y * pixletSize.height;
	    [tile setOutline:[NSBezierPath bezierPathWithRect:subRect]];
	    
	    // grab the bitmap from the original image that lies within the tile's outline
	    //pixletImage = [[NSImage alloc] initWithSize:[[tile outline] bounds].size];
	    //NSAssert(pixletImage != nil, @"Could not allocate pixlet image");
	    [pixletImage setSize:[[tile outline] bounds].size];
	    [pixletImage lockFocus];
	    [NSGraphicsContext saveGraphicsState];	// so we undo the clipping path we add
	    thePoint = [[tile outline] bounds].origin;
	    [translate translateXBy:thePoint.x * -1 yBy:thePoint.y * -1];
	    clipPath = [translate transformBezierPath:[tile outline]];
	    [translate translateXBy:thePoint.x yBy:thePoint.y];
	    [clipPath addClip];
	    NSAssert(originalImage != nil, @"Original image has been freed");
	    NSAssert([tile outline] != nil, @"Tile outline has been freed");
	    [originalImage compositeToPoint:NSMakePoint(0, 0) fromRect:[[tile outline] bounds] operation:NSCompositeCopy];
	    [NSGraphicsContext restoreGraphicsState];
	    subRect.origin = NSMakePoint(0, 0);
	    subRect.size = [pixletImage size];
	    [tile setBitmapRep:[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect]];
	    [pixletImage unlockFocus];
	    //[pixletImage release];
	    
	    [tile setDisplayUpdateQueue:_updatedTiles];
	    
	    // add it to the list of tiles
	    [_tiles addObject:tile];
	}
    [pixletImage release];
    pixletImage = nil;

    // Traverse through all of the files and match them against each tile
    while (file = [enumerator nextObject])
    {
	if (file != nil && [[NSImage imageFileTypes] containsObject:[file pathExtension]])	// if it's an image
	{
	    // allocate a second auto-release pool just for objects created for matching against this image
	    // (otherwise, auto-released objects won't get released until ALL pictures have been enumerated)
	    pool2 = [[NSAutoreleasePool alloc] init];
	    NSAssert(pool2 != nil, @"Could not allocate pool2");
	    
	    filePath = [pixPath stringByAppendingPathComponent:file];
	
	    // load the image from the file
	    pixletImage = [[NSImage alloc] initWithContentsOfFile:filePath];
	    if (pixletImage != nil && [pixletImage isValid])
	    {
		NSLog(@"Matching %@\n", file);
	    
		//create an NSBitmapImageRep from the image for direct pixel access
		[pixletImage setScalesWhenResized:YES];
		
		// loop through the tiles of the main image and compute the pixlet's match
		for (index = 0; index < [_tiles count]; index++)
		{
		    tile = [_tiles objectAtIndex:index];
		    NSAssert(tile != nil, @"tile is nil");
		    NSAssert([tile bitmapRep] != nil, @"tile bitmapRep is nil");
		    
		    // Scale the pixlet to the same size as the tile (if it isn't already)
		    if ([pixletImage size].width != [[tile bitmapRep] size].width || 
			[pixletImage size].height != [[tile bitmapRep] size].height)
			[pixletImage setSize:[[tile bitmapRep] size]];
		    subRect.origin.x = subRect.origin.y = 0.0;
		    subRect.size = [pixletImage size];
		    [pixletImage lockFocus];
		    pixletRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
		    [pixletImage unlockFocus];
		    NSAssert(pixletRep != nil, @"pixletRep not allocated");
		    
		    // Calculate how well they match, and if it's better than the previous best, add it to the mosaic
		    [tile matchAgainst:pixletRep fromFile:filePath];
		    
		    // Clean up
		    if (pixletRep != nil) [pixletRep release];
		    pixletRep = nil;
		}
	    }
	    
	    // More clean up
	    if (pixletImage != nil) [pixletImage release];
	    pixletImage = nil;
	    
	    [pool2 release];
	}
    }
    [pool release];
    pool = nil;
}


- (void)selectTileAtPoint:(NSPoint)thePoint
{
	int	i;
	
	// convert thePoint from the coordinate system of mosaicView to that of mosaicImage
	// (which is the coordinate system that the tiles' outlines are in)
	thePoint.x = (thePoint.x - 8) * [mosaicImage size].width / [mosaicView bounds].size.width;
	thePoint.y = (thePoint.y - 8) * [mosaicImage size].height / [mosaicView bounds].size.height;
	
	for (i = 0; i < [_tiles count]; i++)
	    if ([[[_tiles objectAtIndex:i] outline] containsPoint:thePoint])
	    {
		_selectedTile = [_tiles objectAtIndex:i];
		[mosaicView setNeedsDisplay:YES];
		return;
	    }
}


- (void)saveMosaicImage:(id)sender
{
    int			result;
    NSSavePanel		*savePanel = [NSSavePanel savePanel];
    NSBitmapImageRep	*mosaicRep;
    NSData		*bitmapData;
    
    // ask the user where to save the image
    result = [savePanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"] file:@"Mosiac.jpg"];
    if (result != NSOKButton) return;
    
    [mosaicImage lockFocus];
    mosaicRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [mosaicImage size].width, [mosaicImage size].height)];
    [mosaicImage unlockFocus];
    NSAssert(mosaicRep != nil, @"pixletRep not allocated");
    bitmapData = [mosaicRep representationUsingType:NSJPEGFileType properties:[NSDictionary dictionary]];
    [bitmapData writeToFile:[savePanel filename] atomically:YES];
}


// window delegate methods

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
