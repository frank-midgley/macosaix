#import <Foundation/Foundation.h>
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "TileMatch.h"

@implementation MacOSaiXDocument

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MacOSaiXDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that need to be executed once the windowController has loaded the document's window.
}

- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.  You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
    return nil;
}

- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    // Insert code here to read your document from the given data.  You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
    return YES;
}


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

    //[openButton setEnabled:NO];
    //[saveButton setEnabled:YES];
    
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
    
    // create data structure for each tile including outlines, bitmaps, etc.
    //[self createTileCollectionWithOutlines:[self createTileOutlinesForImage:originalImage]
    //	fromImage:originalImage];

    [NSApplication detachDrawingThread:@selector(enumerateAndMatchFiles:) toTarget:self withObject:nil];
//    [NSThread detachNewThreadSelector:@selector(enumerateAndMatchFiles:) toTarget:self withObject:nil];
		     
    updateWindowTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
				 target:(id)self
				 selector:@selector(updateDisplay:)
				 userInfo:nil
				 repeats:YES];
}


- (void)updateDisplay:(id)timer
{
    int			index;
    float		overallMatch;
    Tile*		tile;
    NSRect		drawRect;
    NSBitmapImageRep*	matchRep;
    
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
	[[tile outline] addClip];
	matchRep = [[tile bestMatch] bitmapRep];
	if ([matchRep size].width > [[tile bitmapRep] size].width)
	{
	    drawRect.size = NSMakeSize([[tile outline] bounds].size.height * [matchRep size].width / [matchRep size].height,
				       [[tile outline] bounds].size.height);
	    drawRect.origin = NSMakePoint([[tile outline] bounds].origin.x - 
					    (drawRect.size.width - [[tile outline] bounds].size.width) / 2.0,
					  [[tile outline] bounds].origin.y);
	}
	else
	{
	    drawRect.size = NSMakeSize([[tile outline] bounds].size.width,
				       [[tile outline] bounds].size.width * [matchRep size].height / [matchRep size].width);
	    drawRect.origin = NSMakePoint([[tile outline] bounds].origin.x,
					  [[tile outline] bounds].origin.y - 
					    (drawRect.size.height - [[tile outline] bounds].size.height) / 2.0);
	}
	[matchRep drawInRect:drawRect];
	[NSGraphicsContext restoreGraphicsState];
	[_updatedTiles removeObjectAtIndex:1];
    }
    [mosaicImage unlockFocus];
    [[_updatedTiles objectAtIndex:0] unlock];

    [mosaicView setImage:nil];	// annoying hack to get the NSImageView to redisplay an updated NSImage
    [mosaicView setImage:mosaicImage];
}


- (void)enumerateAndMatchFiles:(id)foo
{
    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];	// this is the first method called in the spawned thread
    NSString			*file, *filePath;
    int				index = 0;
    NSImage			*pixletImage;
    
    NSAssert(pool != nil, @"Could not allocate autorelease pool");

    // hack to start after a certain file
    //while (file = [enumerator nextObject]))
	//if (file != nil && [file isEqualToString:@"ftp.sunet.se/tv.film/Star_Wars/swshuttle.gif"]) break;

    // create data structure for each tile including outlines, bitmaps, etc.
    [self createTileCollectionWithOutlines:[self createTileOutlinesForImage:originalImage]
	  fromImage:originalImage];

    // Traverse through all of the files and match them against each tile
    while (file = [enumerator nextObject])
    {
	// allocate a second auto-release pool just for objects created for matching against this image
	// (otherwise, auto-released objects won't get released until ALL pictures have been enumerated)
	NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];	NSAssert(pool2 != nil, @"Could not allocate pool2");

	if (file != nil && [[NSImage imageFileTypes] containsObject:[file pathExtension]])	// if it's an image
	{
	    filePath = [pixPath stringByAppendingPathComponent:file];
	
	    // load the image from the file
	    pixletImage = [[[NSImage alloc] initWithContentsOfFile:filePath] autorelease];
	    NS_DURING
	    if (pixletImage != nil && [pixletImage isValid])
	    {
		NSMutableArray	*cachedReps = [NSMutableArray arrayWithCapacity:0];	NSAssert(cachedReps != nil, @"cachedReps == nil");
		
		NSLog(@"Matching %@\n", file);
		
		[pixletImage setScalesWhenResized:YES];
		[pixletImage setDataRetained:YES];
		
		// loop through the tiles and compute the pixlet's match
		for (index = 0; index < [_tiles count]; index++)
		{
		    Tile	*tile = [_tiles objectAtIndex:index];
		    float	scale;
		    NSRect	subRect;
		    int		cachedRepIndex;
		    
		    // scale the smaller of the pixlet's image's dimensions to the size used for pixel matching and extract the rep
		    scale = MAX([[tile bitmapRep] size].width / [pixletImage size].width, 
				[[tile bitmapRep] size].height / [pixletImage size].height);
		    subRect = NSMakeRect(0, 0, (int)([pixletImage size].width * scale + 0.5),
					 (int)([pixletImage size].height * scale + 0.5));
		    
		    // check if we already have a rep of this size
		    for (cachedRepIndex = 0; cachedRepIndex < [cachedReps count]; cachedRepIndex++)
			if (NSEqualSizes([[cachedReps objectAtIndex:cachedRepIndex] size], subRect.size)) break;
		    if (cachedRepIndex == [cachedReps count])
		    {	// no bitmap at the correct size was found, create a new one
			[pixletImage setSize:subRect.size];
			[pixletImage lockFocus];
			[cachedReps addObject:[[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect] autorelease]];
			[pixletImage unlockFocus];
		    }

		    // Calculate how well they match, and if it's better than the previous best, add it to the mosaic
		    [tile matchAgainst:[cachedReps objectAtIndex:cachedRepIndex] fromFile:filePath];

		}
	    }
	    NS_HANDLER
		NSLog(@"Exception raised: %s", [localException name]);
	    NS_ENDHANDLER
	}
	[pool2 release];
    }
    [pool release];
    pool = nil;
}


- (NSArray *)createTileOutlinesForImage:(NSImage *)image
{
    int			tilesWide = 40, tilesHigh = 40, x, y;
    NSRect		tileRect = NSMakeRect(0, 0, [image size].width / tilesWide, [image size].height / tilesHigh);
    NSMutableArray	*outlines = [NSMutableArray arrayWithCapacity:0];
    
    for (x = 0; x < tilesWide; x++)
	for (y = 0; y < tilesHigh; y++)
	{
	    tileRect.origin.x = x * tileRect.size.width;
	    tileRect.origin.y = y * tileRect.size.height;
	    [outlines addObject:[NSBezierPath bezierPathWithRect:tileRect]];
	}
    
    return outlines;
}


- (void)createTileCollectionWithOutlines:(NSMutableArray *)outlines fromImage:(NSImage *)image
{
    int			index;
    Tile		*tile;
    NSImage		*tileImage;
    NSPoint		thePoint;
    NSBezierPath	*clipPath;
    NSAffineTransform	*translate = [NSAffineTransform transform];
    
    NSAssert(outlines != nil, @"outlines == nil"); NSAssert(image != nil, @"image == nil");
    
    _tiles = [[NSMutableArray arrayWithCapacity:0] retain];
    for (index = 0; index < [outlines count]; index++)
    {
	// create the tile object and add it to the collection
	tile = [[Tile alloc] init];	NSAssert(tile != nil, @"Could not allocate tile");
	[_tiles addObject:tile];
	
	[tile setOutline:[outlines objectAtIndex:index]];
	
	// let the tile know how to talk to the display update queue (shouldn't be done this way, but it's working)
	[tile setDisplayUpdateQueue:_updatedTiles];

	tileImage = [[NSImage alloc] initWithSize:[[tile outline] bounds].size];
	[tileImage setScalesWhenResized:YES];

	// start with an image the same size as the tile's outline's bounding box
	NSAssert(tileImage != nil, @"tileImage has been released");
	//[tileImage setSize:[[tile outline] bounds].size];
	    
	// copy out the portion of the original image contained by the tile's outline (using a clipping path)
	NSAssert(tileImage != nil, @"tileImage has been released");
	[tileImage lockFocus];	// BAD_ACCESS
	[NSGraphicsContext saveGraphicsState];	// so we can undo the clipping path we add
	thePoint = [[tile outline] bounds].origin;
	[translate translateXBy:thePoint.x * -1 yBy:thePoint.y * -1];
	clipPath = [translate transformBezierPath:[tile outline]];
	[translate translateXBy:thePoint.x yBy:thePoint.y];
	[clipPath addClip];
	[image compositeToPoint:NSMakePoint(0, 0) fromRect:[[tile outline] bounds] operation:NSCompositeCopy];
	[NSGraphicsContext restoreGraphicsState];
	NSAssert(tileImage != nil, @"tileImage has been released");
	[tileImage unlockFocus];
	
	// scale the tile's image to the size used for pixel matching (maximum of TILE_BITMAP_SIZE in either width or height)
	NSAssert([tile outline] != nil, @"tile outline has been released");
	NSAssert(tileImage != nil, @"tileImage has been released");
	if ([[tile outline] bounds].size.width > [[tile outline] bounds].size.height)
	    [tileImage setSize:NSMakeSize(TILE_BITMAP_SIZE, 
					  TILE_BITMAP_SIZE * [[tile outline] bounds].size.height / [[tile outline] bounds].size.width)];
	else
	    [tileImage setSize:NSMakeSize(TILE_BITMAP_SIZE * [[tile outline] bounds].size.width / [[tile outline] bounds].size.height, 
					  TILE_BITMAP_SIZE)];
	
	// grab the image's bitmap rep and store it in the tile
	NSAssert(tileImage != nil, @"tileImage has been released");
	[tileImage lockFocus];
	[tile setBitmapRep:[[NSBitmapImageRep alloc]
			    initWithFocusedViewRect:NSMakeRect(0, 0, [tileImage size].width, [tileImage size].height)]];
	NSAssert(tileImage != nil, @"tileImage has been released");
	[tileImage unlockFocus];	// BAD_ACCESS

	NSAssert(_tiles != nil, @"_tiles has been released");
	[tileImage release];	tileImage = nil;	//BAD_ACCESS
    }
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
    result = [savePanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"] file:@"Mosiac.tiff"];
    if (result != NSOKButton) return;
    
    [mosaicImage lockFocus];
    mosaicRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [mosaicImage size].width, [mosaicImage size].height)];
    [mosaicImage unlockFocus];
    NSAssert(mosaicRep != nil, @"pixletRep not allocated");
    bitmapData = [mosaicRep representationUsingType:NSTIFFFileType properties:[NSDictionary dictionary]];
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
