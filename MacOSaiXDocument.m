#import <Foundation/Foundation.h>
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "TileMatch.h"
#import "DirectoryImageSource.h"
#import "GoogleImageSource.h"
#import "MosaicView.h"
#import "OriginalView.h"
#import "ImageRepCell.h"

// The maximum size of the image URL queue
#define MAX_IMAGE_URLS 32

@implementation MacOSaiXDocument

- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    NSToolbar	*toolbar;
    NSTimer	*timer;
    
    [super windowControllerDidLoadNib:aController];
    
    _viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];

    _viewMode = viewMosaicAndOriginal;
    _viewIsChanging = NO;
    _statusBarShowing = YES;
    _selectedTile = nil;
    _mosaicImageUpdated = NO;
    
    _imageSources = [[NSMutableArray arrayWithCapacity:0] retain];

    _mosaicImageLock = [[NSLock alloc] init];
    _lastBestMatchLock = [[NSLock alloc] init];
    
    // and create a timer to watch the queue
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0
				 target:(id)self
				 selector:@selector(updateDisplay:)
				 userInfo:nil
				 repeats:YES];
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1
				 target:(id)self
				 selector:@selector(animateSelectedTile:)
				 userInfo:nil
				 repeats:YES];
    _imagesMatched = 0;

    [imageSourcesTable setDataSource:self];
    [[imageSourcesTable tableColumnWithIdentifier:@"type"] setDataCell:[[NSImageCell alloc] init]];
    [[[editorTable documentView] tableColumnWithIdentifier:@"image"] setDataCell:[[NSImageCell alloc] init]];

    // the editor should not be visible initially
    [[editorLabel retain] removeFromSuperview];
    [[editorTable retain] removeFromSuperview];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(mosaicViewDidScroll:)
						 name:@"View Did Scroll" object:nil];
    
    _toolbarItems = [NSMutableDictionary dictionary];
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"];
    [toolbar setDelegate:self];
    [[[[self windowControllers] objectAtIndex:0] window] setToolbar:toolbar];
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    BOOL		wasPaused = _paused;
    NSMutableDictionary	*storage = [NSMutableDictionary dictionary];

    _paused = YES;
    
//    [storage setObject:_originalImageURL forKey:@"_originalImageURL"];
    [storage setObject:_imageSources forKey:@"_imageSources"];
    [storage setObject:_tiles forKey:@"_tiles"];
    [storage setObject:[NSNumber numberWithLong:_imagesMatched] forKey:@"_imagesMatched"];
    [storage setObject:[NSNumber numberWithInt:_viewMode] forKey:@"_viewMode"];
    [storage setObject:[NSValue valueWithRect:
			[[[[self windowControllers] objectAtIndex:0] window] frame]] forKey:@"window frame"];
    [storage setObject:[NSNumber numberWithInt:(_paused ? 1 : 0)] forKey:@"_paused"];
    
    _paused = wasPaused;

    return [NSArchiver archivedDataWithRootObject:storage];
}


- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    NSDictionary	*storage = [NSUnarchiver unarchiveObjectWithData:data];
    
//    [self setOriginalImageWithURL:[storage objectForKey:@"_originalImageURL"]];
    
    [self setImageSources:[storage objectForKey:@"_imageSources"]];
    
    _tiles = [[storage objectForKey:@"_tiles"] retain];
    
    _imagesMatched = [[storage objectForKey:@"_imagesMatched"] longValue];
    
    [self setViewMode:[[storage objectForKey:@"_viewMode"] intValue]];
    
    [[[[self windowControllers] objectAtIndex:0] window]
	setFrame:[[storage objectForKey:@"window frame"] rectValue] display:YES];

    _paused = ([[storage objectForKey:@"_paused"] intValue] == 1 ? YES : NO);
    
    return YES;
}


- (void)updateDisplay:(id)timer
{
    [imageSourcesTable reloadData];
    
    [mosaicQualityView setDoubleValue:_overallMatch];
    
    if (_mosaicImageUpdated && [_mosaicImageLock tryLock])
    {
	[[mosaicView documentView] setImage:_mosaicImage];
	[[mosaicView documentView] updateCell: [[mosaicView documentView] cell]];
	_mosaicImageUpdated = NO;
	[_mosaicImageLock unlock];
    }
    
    [imagesMatchedView setStringValue:[NSString stringWithFormat:@"%d", _imagesMatched]];
}


- (void)animateSelectedTile:(id)timer
{
    if (_selectedTile != nil)
	[[mosaicView documentView] animateHighlight];
}


- (void)setOriginalImage:(NSImage *)image
{
    if (_originalImage) [_originalImage autorelease];
    _originalImage = [image copy];
    
    [originalView setImage:_originalImage];
}


- (void)setTileOutlines:(NSMutableArray *)tileOutlines
{
    _tileOutlines = [tileOutlines retain];
}


- (void)setImageSources:(NSMutableArray *)imageSources
{
    _imageSources = [imageSources retain];
}


- (void)startMosaic:(id)sender
{
    // Create an NSImage to hold the mosaic image (somewhat arbitrary size)
    _mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1600 * 
						[_originalImage size].height / [_originalImage size].width)];
    _mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
								  [_mosaicImage size].width,
								  [_mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];
    
    [self setZoom:self];
    
    // create the image URL queue with a lock as its first item
    _imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueueLock = [[NSLock alloc] init];

    _stillAlive = YES;
    
    // spawn a thread to create data structure for each tile including outlines, bitmaps, etc.
    if (_tileOutlines != nil)
	[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
				  toTarget:self withObject:nil];
    
    // spawn a thread to enumerate the image sources
    [NSThread detachNewThreadSelector:@selector(enumerateImageSources:) toTarget:self withObject:nil];
    
    // start the image matching thread
    [NSApplication detachDrawingThread:@selector(processImageURLQueue:) toTarget:self withObject:nil];
    
    // start the image integrating thread
    [NSApplication detachDrawingThread:@selector(recalculateTileDisplayMatches:)
			      toTarget:self withObject:nil];
}


- (void)createTileCollectionWithOutlines:(id)object
{
    int			index;
    NSAutoreleasePool	*pool;
    NSWindow		*drawWindow;
    
    if (_tileOutlines == nil || _originalImage == nil) return;

    pool = [[NSAutoreleasePool alloc] init];

    // create an offscreen window to draw into (it will have a single, empty view the size of the window)
    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000,
								  [_originalImage size].width, 
								  [_originalImage size].height)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];
    while (![[drawWindow contentView] lockFocusIfCanDraw])
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
    
    _tiles = [[NSMutableArray arrayWithCapacity:[_tileOutlines count]] retain];
    for (index = 0; index < [_tileOutlines count]; index++)
    {
	Tile			*tile;
	NSBezierPath		*clipPath;
	NSAffineTransform	*transform;
	NSRect			origRect, destRect;

	// create the tile object and add it to the collection
	tile = [[Tile alloc] init];	NSAssert(tile != nil, @"Could not allocate tile");
	[_tiles addObject:tile];
	
	[tile setOutline:[_tileOutlines objectAtIndex:index]];
	
	// copy out the portion of the original image contained by the tile's outline (using a clipping path)
	origRect = NSMakeRect([[tile outline] bounds].origin.x * [_originalImage size].width,
			    [[tile outline] bounds].origin.y * [_originalImage size].height,
			    [[tile outline] bounds].size.width * [_originalImage size].width,
			    [[tile outline] bounds].size.height * [_originalImage size].height);
	if ([[tile outline] bounds].size.width > [[tile outline] bounds].size.height)
	    destRect = NSMakeRect(0, 0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE * 
				  [[tile outline] bounds].size.height / [[tile outline] bounds].size.width);
	else
	    destRect = NSMakeRect(0, 0, TILE_BITMAP_SIZE * [[tile outline] bounds].size.width /  
				    [[tile outline] bounds].size.height, TILE_BITMAP_SIZE);
	// start with pure alpha so pixels outside the tile outline can be ignored
	[[NSColor clearColor] set];
	[[NSBezierPath bezierPathWithRect:destRect] fill];
	transform = [NSAffineTransform transform];
	[transform scaleXBy:destRect.size.width / [[tile outline] bounds].size.width
			yBy:destRect.size.height / [[tile outline] bounds].size.height];
	[transform translateXBy:[[tile outline] bounds].origin.x * -1
			    yBy:[[tile outline] bounds].origin.y * -1];
	clipPath = [transform transformBezierPath:[tile outline]];
	[clipPath setClip];
	[_originalImage drawInRect:destRect fromRect:origRect operation:NSCompositeCopy fraction:1.0];
	[tile setBitmapRep:[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect]];
    }

    [[drawWindow contentView] unlockFocus];
    [drawWindow close];
    
    [pool release];
}


- (void)recalculateTileDisplayMatches:(id)object
{
    NSAutoreleasePool	*pool, *pool2;
    float		lastBestMatch, overallMatch = 0.0;
    NSMutableArray	*updatedTiles = nil, *orderedTiles = nil, *imagesInUse = nil;
    NSDate		*lastUpdate;
    
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }
    
    while ([_tiles count] < [_tileOutlines count])
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    
    updatedTiles = [[NSMutableArray arrayWithCapacity:0] retain];
    imagesInUse = [[NSMutableArray arrayWithCapacity:0] retain];
    lastUpdate = [[NSDate date] retain];
    while (_stillAlive)
    {
	pool2 = [[NSAutoreleasePool alloc] init];
	while (pool2 == nil)
	{
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    pool2 = [[NSAutoreleasePool alloc] init];
	}
	
	if (orderedTiles == nil || [orderedTiles count] == 0)
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];

	// recalculate the displayMatch for each tile
	// (order the tiles by their best match, then, starting with the best match,
	//  set each tile's display match to the best matching image that hasn't
	//  already been used the maximum number of times by other tiles)
	if (orderedTiles != nil && [orderedTiles count] > 0)
	{
	    Tile		*tile = [orderedTiles objectAtIndex:0];
	    
	    lastBestMatch = [tile bestMatchValue];
	    if ([tile userMatch] != nil)
	    {
		NS_DURING
		    [updatedTiles addObject:tile];
		NS_HANDLER
		    NSLog(@"Could not add tile to update queue");
		NS_ENDHANDLER
	    }
	    else
	    {
		//matchEnumerator = [[tile matches] objectEnumerator];
		//while (theMatch = [matchEnumerator nextObject])
		int	i;
		
		for (i = 0; i < [[tile matches] count]; i++)
		{
		    TileMatch	*theMatch;
		    NSURL	*imageURL;

		    NS_DURING
			theMatch = [[tile matches] objectAtIndex:i];
		    NS_HANDLER
			NSLog(@"[tile matches] has no object at index %d", i);
		    NS_ENDHANDLER
		    imageURL = [theMatch imageURL];
		    
		    if ([imagesInUse indexOfObjectIdenticalTo:imageURL] == NSNotFound)
		    {
			if ([tile displayMatch] != theMatch)
			{
			    NS_DURING
				[updatedTiles addObject:tile];
			    NS_HANDLER
				NSLog(@"Could not add tile to update queue");
			    NS_ENDHANDLER
			    [tile setDisplayMatch:theMatch];
			}
			overallMatch += (721 - sqrt([tile displayMatchValue])) / 721;
			NS_DURING
			    [imagesInUse addObject:imageURL];
			NS_HANDLER
			    NSLog(@"Could add image URL to in use list");
			NS_ENDHANDLER
			break;
		    }
		}
		if (i == [[tile matches] count] && [tile displayMatch] != nil)
		{
		    NS_DURING
			[updatedTiles addObject:tile];
		    NS_HANDLER
			NSLog(@"Could not add ...");
		    NS_ENDHANDLER
		    [tile setDisplayMatch:nil];
		}
	    }
	    [orderedTiles removeObjectAtIndex:0];
	    if ([orderedTiles count] == 0)
	    {
		overallMatch = overallMatch / [_tiles count];
		overallMatch = (overallMatch >= 0.5) ? (overallMatch - 0.5) * 200.0 : 0.0;
		_overallMatch = overallMatch;
	    }
	}
	
	if ([updatedTiles count] == 10 || 
	    ([updatedTiles count] > 0 && [lastUpdate timeIntervalSinceNow] < -1.0))
	{
	    [self updateMosaicImage:updatedTiles];
	    [updatedTiles release];
	    updatedTiles = [[NSMutableArray arrayWithCapacity:10] retain];
	    [lastUpdate release];
	    lastUpdate = [[NSDate date] retain];
	}
	
	[_lastBestMatchLock lock];
	if (_lastBestMatch != 0.0)
	{	// a better best match has been found, start over
	    if (orderedTiles != nil) [orderedTiles release];
	    orderedTiles = [[NSMutableArray arrayWithArray:
		    [_tiles sortedArrayUsingSelector:@selector(compareBestMatchValue:)]] retain];
	    overallMatch = 0.0;
	    if (imagesInUse != nil) [imagesInUse release];
	    imagesInUse = [[NSMutableArray arrayWithCapacity:0] retain];
	    _lastBestMatch = 0.0;
	}
	[_lastBestMatchLock unlock];
	
	[pool2 release];
    }
    
    [pool release];
}

- (void)updateMosaicImage:(NSMutableArray *)updatedTiles
{
    NSAffineTransform	*transform;
    int			index;
    NSBitmapImageRep	*newRep;
    
    if (![[_mosaicImageDrawWindow contentView] lockFocusIfCanDraw])
	NSLog(@"Could not lock focus");
    else
    {
	[[NSColor whiteColor] set];
	[[NSBezierPath bezierPathWithRect:[[_mosaicImageDrawWindow contentView] bounds]] fill];
	[_mosaicImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];	//start with the current image
	transform = [NSAffineTransform transform];
	[transform scaleXBy:[_mosaicImage size].width yBy:[_mosaicImage size].height];
	for (index = 0; index < [updatedTiles count]; index++)
	{
	    Tile		*tile = [updatedTiles objectAtIndex:index];
	    NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
	    
	    if ([tile displayMatch] == nil)
	    {
		[[NSColor clearColor] set];
		[clipPath fill];
	    }
	    else
	    {
		NSBitmapImageRep	*matchRep;
		NSRect			drawRect;
    
		if ([tile userMatch] != nil)
		    matchRep = [[tile userMatch] bitmapRep];
		else
		    matchRep = [[tile displayMatch] bitmapRep];
		[clipPath setClip];
		// scale the image to the tile's size, but preserve it's aspect ratio
		if ([clipPath bounds].size.width / [matchRep size].width <
		    [clipPath bounds].size.height / [matchRep size].height)
		{
		    drawRect.size = NSMakeSize([clipPath bounds].size.height * [matchRep size].width /
						[matchRep size].height,
					       [clipPath bounds].size.height);
		    drawRect.origin = NSMakePoint([clipPath bounds].origin.x - 
						  (drawRect.size.width - [clipPath bounds].size.width) / 2.0,
						  [clipPath bounds].origin.y);
		}
		else
		{
		    drawRect.size = NSMakeSize([clipPath bounds].size.width,
					       [clipPath bounds].size.width * [matchRep size].height /
						[matchRep size].width);
		    drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
						  [clipPath bounds].origin.y - 
						(drawRect.size.height - [clipPath bounds].size.height) /2.0);
		}
		[matchRep drawInRect:drawRect];
	    }
	}
	[_mosaicImageLock lock];
	    newRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
						    [[_mosaicImageDrawWindow contentView] bounds]];
/*	    [_mosaicImage addRepresentation:newRep];
	    for (index = [[_mosaicImage representations] count]; index >= 0; index--)
		if ([[_mosaicImage representations] objectAtIndex:index] != newRep)
		    [_mosaicImage removeRepresentation:[[_mosaicImage representations] objectAtIndex:index]];
	    [_mosaicImage recache];*/
	    if (_mosaicImage != nil) [_mosaicImage release];
	    _mosaicImage = [[NSImage alloc] initWithSize:[[_mosaicImageDrawWindow contentView] bounds].size];
	    [_mosaicImage addRepresentation:newRep];
	    [newRep release];
	    _mosaicImageUpdated = YES;
	[_mosaicImageLock unlock];
	[[_mosaicImageDrawWindow contentView] unlockFocus];
    }
}


- (void)enumerateImageSources:(id)object
{
    // This is the first method called in a new thread
    NSAutoreleasePool	*pool, *pool2;
    NSURL		*imageURL;
    int			i;
    
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }

    while (_stillAlive)
    {
	BOOL	imageWasFound = NO;
	
	while (_paused) [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	
	for (i = 0; i < [_imageSources count]; i++)
	    if (imageURL = [[_imageSources objectAtIndex:i] nextImageURL])
	    {
		NSData		*imageData;
		NSImage		*pixletImage;
		
		imageWasFound = YES;
		
		pool2 = [[NSAutoreleasePool alloc] init];
		while (pool2 == nil)
		{
		    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		    pool2 = [[NSAutoreleasePool alloc] init];
		}
		
		// load the image
		NS_DURING
		    imageData = [imageURL resourceDataUsingCache:NO];
		NS_HANDLER
		    if (imageData != nil) [imageData release];
		NS_ENDHANDLER
		if (imageData != nil)
		{
		    NS_DURING
			pixletImage = [[NSImage alloc] initWithData:imageData];
		    NS_HANDLER
			if (pixletImage != nil) [pixletImage release];
		    NS_ENDHANDLER
		    if (pixletImage != nil)
		    {
			if (![pixletImage isValid])
			    [pixletImage release];
			else
			{
			    NSMutableDictionary	*dict = [NSMutableDictionary dictionary];
			    
			    [pixletImage setScalesWhenResized:YES];
			    [pixletImage setDataRetained:YES];
			    [dict setObject:imageURL forKey:@"URL"];
			    [dict setObject:pixletImage forKey:@"Image"];
			    
			    [_imageQueueLock lock];
			    while ([_imageQueue count] >= MAX_IMAGE_URLS)
			    {
				[_imageQueueLock unlock];
				[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
				[_imageQueueLock lock];
			    }
			    NS_DURING
				[_imageQueue addObject:dict];
			    NS_HANDLER
				NSLog(@"Could not add image to processing queue");
			    NS_ENDHANDLER
			    [_imageQueueLock unlock];
			}
		    }
		}
		
		[pool2 release];
	    }
	if (!imageWasFound) [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    }
    
    [pool release];
}


- (void)processImageURLQueue:(id)foo
{
    // This is the first method called in a new thread
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    NSWindow		*drawWindow;
    
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }

    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 
								  TILE_BITMAP_DISPLAY_SIZE * 4, 
								  TILE_BITMAP_DISPLAY_SIZE * 4)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];

    while (_stillAlive)
    {
	while (_paused || _viewMode == viewMosaicEditor || [_tiles count] < [_tileOutlines count])
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
	[_imageQueueLock lock];
	if ([_imageQueue count] == 0)
	{
	    [_imageQueueLock unlock]; // there aren't any image URLs to process
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	else
	{
	    int			index;
	    NSMutableArray	*cachedReps;
	    NSMutableDictionary	*dict;
	    NSURL		*imageURL;
	    NSImage		*pixletImage;
	    NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
	    
	    while (pool2 == nil)
	    {
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		pool2 = [[NSAutoreleasePool alloc] init];
	    }

	    // pull the next image from the queue
	    NS_DURING
		dict = [_imageQueue objectAtIndex:0];
	    NS_HANDLER
		NSLog(@"_imageQueue has no object at index 0");
	    NS_ENDHANDLER
	    imageURL = [[dict objectForKey:@"URL"] autorelease];
	    pixletImage = [[dict objectForKey:@"Image"] autorelease];
	    [_imageQueue removeObjectAtIndex:0];
	    [_imageQueueLock unlock];
	    //NSLog(@"Matching %@\n", imageURL);
		
	    cachedReps = [NSMutableArray arrayWithCapacity:0];
		
	    // loop through the tiles and compute the pixlet's match
	    for (index = 0; index < [_tiles count]; index++)
	    {
		Tile	*tile;
		float	scale, newMatch;
		NSRect	subRect;
		int	cachedRepIndex, displayRepIndex;

		NS_DURING
		    tile = [_tiles objectAtIndex:index];
		NS_HANDLER
		    NSLog(@"_tiles has no object at index %d", index);
		NS_ENDHANDLER
		
		if ([tile bitmapRep] == nil) continue;	// *** DEBUG CODE ***
		
		// scale the smaller of the pixlet's image's dimensions to the size used
		// for pixel matching and extract the rep
		scale = MAX([[tile bitmapRep] size].width / [pixletImage size].width, 
			    [[tile bitmapRep] size].height / [pixletImage size].height);
		subRect = NSMakeRect(0, 0, (int)([pixletImage size].width * scale + 0.5),
					(int)([pixletImage size].height * scale + 0.5));
		
		// check if we already have a rep of this size
		for (cachedRepIndex = 0; cachedRepIndex < [cachedReps count]; cachedRepIndex++)
		    if (NSEqualSizes([[cachedReps objectAtIndex:cachedRepIndex] size], subRect.size))
			break;
		if (cachedRepIndex == [cachedReps count])
		{	// no bitmap at the correct size was found, create a new one
		    if (![[drawWindow contentView] lockFocusIfCanDraw])
			NSLog(@"Could not lock focus on pixlet window");
		    else
		    {
			NSBitmapImageRep	*rep;
			
			NSAssert([pixletImage isValid], @"pixlet image no longer valid");
			
			[pixletImage drawInRect:subRect
			    fromRect:NSMakeRect(0, 0, [pixletImage size].width, [pixletImage size].height)  				operation:NSCompositeCopy fraction:1.0];
			rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
			if (rep != nil)
			    [cachedReps addObject:[rep autorelease]];
			else
			    cachedRepIndex = -1;
			[[drawWindow contentView] unlockFocus];
		    }
		}

		subRect.size.width = (int)(subRect.size.width * TILE_BITMAP_DISPLAY_SIZE / 
					    TILE_BITMAP_SIZE);
		subRect.size.height = (int)(subRect.size.height * TILE_BITMAP_DISPLAY_SIZE / 
					    TILE_BITMAP_SIZE);
		
		// check if we already have a rep of this size
		for (displayRepIndex = 0; displayRepIndex < [cachedReps count]; displayRepIndex++)
		    if (NSEqualSizes([[cachedReps objectAtIndex:displayRepIndex] size], subRect.size))
			break;
		if (displayRepIndex == [cachedReps count])
		{	// no bitmap at the correct size was found, create a new one
		    if (![[drawWindow contentView] lockFocusIfCanDraw])
			NSLog(@"Could not lock focus on pixlet window");
		    else
		    {
			NSBitmapImageRep	*rep;
			
			[pixletImage drawInRect:subRect
			    fromRect:NSMakeRect(0, 0, [pixletImage size].width, [pixletImage size].height)  				operation:NSCompositeCopy fraction:1.0];
			rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
			if (rep != nil)
			    [cachedReps addObject:[rep autorelease]];
			else
			    displayRepIndex = -1;
			[[drawWindow contentView] unlockFocus];
		    }
		}

		// Calculate how well they match, and if it's better than the previous best
		// then add it to the mosaic
		if (cachedRepIndex != -1 && displayRepIndex != -1)
		{
		    newMatch = [tile matchAgainst:[cachedReps objectAtIndex:cachedRepIndex] fromURL:imageURL
					displayRep:[cachedReps objectAtIndex:displayRepIndex]
					maxMatches:[_tiles count]];
		    if ([tile displayMatch] == nil || newMatch < [tile displayMatchValue])
		    {
			[_lastBestMatchLock lock];
			_lastBestMatch = 1.0;	//MIN(_lastBestMatch, newMatch);
			[_lastBestMatchLock unlock];
		    }
		}
	    }
	    
	    _imagesMatched++;

	    [pool2 release];
	}
    }
    
    [drawWindow close];
    
    [pool release];
    pool = nil;
}


- (void)selectTileAtPoint:(NSPoint)thePoint
{
	int	i;
	
	// convert thePoint from the coordinate system of mosaicView to that of mosaicImage
	// (which is the coordinate system that the tiles' outlines are in)
	thePoint.x = thePoint.x / [[mosaicView contentView] frame].size.width;
	thePoint.y = thePoint.y / [[mosaicView contentView] frame].size.height;
	
	for (i = 0; i < [_tiles count]; i++)
	    if ([[[_tiles objectAtIndex:i] outline] containsPoint:thePoint])
	    {
		_selectedTile = [_tiles objectAtIndex:i];
		
		[(MosaicView *)[mosaicView documentView] highlightTile:_selectedTile];
		
		if (_selectedTileImages != nil) [_selectedTileImages release];
		_selectedTileImages = [[NSMutableArray arrayWithArray:[_selectedTile matches]] retain];
		if ([[_selectedTile bitmapRep] size].width > [[_selectedTile bitmapRep] size].height)
		    [[editorTable documentView] setRowHeight:
			[[_selectedTile bitmapRep] size].height * TILE_BITMAP_DISPLAY_SIZE / 
			 [[_selectedTile bitmapRep] size].width];
		[[editorTable documentView] scrollRowToVisible:0];
		[[editorTable documentView] reloadData];
		[mosaicView setNeedsDisplay:YES];
		return;
	    }
}


- (void)setViewCompareMode:(id)sender;
{
    [self setViewMode:viewMosaicAndOriginal];
}


- (void)setViewAloneMode:(id)sender;
{
    [self setViewMode:viewMosaicAlone];
}


- (void)setViewEditMode:(id)sender;
{
    [self setViewMode:viewMosaicEditor];
}


- (void)setViewMode:(int)mode
{
    NSRect	newFrame = [[[[self windowControllers] objectAtIndex:0] window] frame];
    
    if (mode == _viewMode) return;
    
    _viewIsChanging = YES;
    
    if (_viewMode == viewMosaicAndOriginal)
	[viewCompareButton setImage:[NSImage imageNamed:@"ViewCompareOff"]];
    if (_viewMode == viewMosaicAlone)
	[viewAloneButton setImage:[NSImage imageNamed:@"ViewAloneOff"]];
    if (_viewMode == viewMosaicEditor)
	[viewEditorButton setImage:[NSImage imageNamed:@"ViewEditorOff"]];

    if (mode == viewMosaicAndOriginal)
    {
	[viewCompareButton setImage:[NSImage imageNamed:@"ViewCompareOn"]];
	[[mosaicView superview] addSubview:originalView];
	[originalView release];
	[[mosaicView superview] addSubview:showOutlinesSwitch];
	[showOutlinesSwitch release];
	newFrame.size.width = [mosaicView frame].size.width * 2 - 20;
	if (_viewMode == viewMosaicEditor)
	{
	    [[editorLabel retain] removeFromSuperview];
	    [[editorTable retain] removeFromSuperview];
	}
	_viewMode = viewMosaicAndOriginal;
	[[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width * 2 - 16;
    }

    if (mode == viewMosaicAlone)
    {
	[viewAloneButton setImage:[NSImage imageNamed:@"ViewAloneOn"]];
	newFrame.size.width = [mosaicView frame].size.width + 4;
	[[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width;
	if (_viewMode == viewMosaicAndOriginal)
	{
	    [[originalView retain] removeFromSuperview];
	    [[showOutlinesSwitch retain] removeFromSuperview];
	}
	if (_viewMode == viewMosaicEditor)
	{
	    [[editorLabel retain] removeFromSuperview];
	    [[editorTable retain] removeFromSuperview];
	}
	_viewMode = viewMosaicAlone;
    }
    
    if (mode == viewMosaicEditor)
    {
	[viewEditorButton setImage:[NSImage imageNamed:@"ViewEditorOn"]];
	[[mosaicView superview] addSubview:editorLabel];
	[editorLabel release];
	[[mosaicView superview] addSubview:editorTable];
	[editorTable release];
	newFrame.size.width = [mosaicView frame].size.width + 124;
	if (_viewMode == viewMosaicAndOriginal)
	{
	    [[originalView retain] removeFromSuperview];
	    [[showOutlinesSwitch retain] removeFromSuperview];
	}
	_viewMode = viewMosaicEditor;
	[[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width + 128;
    }

    _viewIsChanging = NO;
    [[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:NO];
    [self setZoom:self];
    [self synchronizeViewMenu];
}


- (void)setZoom:(id)sender
{
    float	zoom;
    
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
	if ([[sender title] isEqualToString:@"Minimum"]) zoom = 0.0;
	if ([[sender title] isEqualToString:@"Medium"]) zoom = 0.5;
	if ([[sender title] isEqualToString:@"Maximum"]) zoom = 1.0;
    }
    else zoom = [zoomSlider floatValue];
    
    // set the zoom...
    [zoomSlider setFloatValue:zoom];
    
    if (_mosaicImage != nil)
    {
	NSRect	bounds, frame;
		
	frame = NSMakeRect(0, 0,
			   [[mosaicView contentView] frame].size.width + ([_mosaicImage size].width - 
			   [[mosaicView contentView] frame].size.width) * zoom,
			   [[mosaicView contentView] frame].size.height + ([_mosaicImage size].height - 
			   [[mosaicView contentView] frame].size.height) * zoom);
	bounds = NSMakeRect(NSMidX([[mosaicView contentView] bounds]) * frame.size.width / 
			    [[mosaicView documentView] frame].size.width,
			    NSMidY([[mosaicView contentView] bounds]) * frame.size.height / 
			    [[mosaicView documentView] frame].size.height,
			    frame.size.width -
			    (frame.size.width - [[mosaicView contentView] frame].size.width) * zoom,
			    frame.size.height -
			    (frame.size.height - [[mosaicView contentView] frame].size.height) * zoom);
	bounds.origin.x = MIN(MAX(0, bounds.origin.x - bounds.size.width / 2.0),
			    frame.size.width - bounds.size.width);
	bounds.origin.y = MIN(MAX(0, bounds.origin.y - bounds.size.height / 2.0),
			    frame.size.height - bounds.size.height);
	[[mosaicView documentView] setFrame:frame];
	[[mosaicView contentView] setBounds:bounds];
	[mosaicView setNeedsDisplay:YES];
    }
    [originalView setNeedsDisplay:YES];
}


- (void)mosaicViewDidScroll:(NSNotification *)notification
{
    NSRect	orig = [originalView bounds],
		content = [[mosaicView contentView] bounds],
		doc = [[mosaicView documentView] frame];
		
    [originalView setFocusRect:NSMakeRect(content.origin.x * orig.size.width / doc.size.width,
					  content.origin.y * orig.size.height / doc.size.height,
					  content.size.width * orig.size.width / doc.size.width,
					  content.size.height * orig.size.height / doc.size.height)];
    [originalView setNeedsDisplay:YES];
}


- (void)calculateFrames
{
    NSRect newFrame;
    
    if (_viewMode == viewMosaicAlone && !_viewIsChanging)
    {
	// calculate the mosaic view's new frame
	newFrame = NSMakeRect(0, 0, [[mosaicView superview] frame].size.width,
			      [[mosaicView superview] frame].size.height);
	if (_statusBarShowing) newFrame.size.height -= [statusBarView frame].size.height;
	[mosaicView setFrame:newFrame];
    }

    if (_viewMode == viewMosaicAndOriginal)
    {
	if (!_viewIsChanging)
	{
	    // calculate the mosaic view's new frame
	    newFrame = NSMakeRect(0, 0, [[mosaicView superview] frame].size.width / 2 + 8,
				[[mosaicView superview] frame].size.height);
	    if (_statusBarShowing) newFrame.size.height -= [statusBarView frame].size.height;
	    [mosaicView setFrame:newFrame];
	}

	// calculate the original view's new frame
	newFrame = NSMakeRect([mosaicView frame].size.width, 16,
			      [[mosaicView superview] frame].size.width - [mosaicView frame].size.width,
			      [mosaicView frame].size.height - 16);
	[originalView setFrame:newFrame];
	
	//calculate the original label's new frame
	newFrame = NSMakeRect([mosaicView frame].size.width + 5, 0,
			      [showOutlinesSwitch frame].size.width, [showOutlinesSwitch frame].size.height);
	[showOutlinesSwitch setFrame:newFrame];
    }

    if (_viewMode == viewMosaicEditor)
    {
	if (!_viewIsChanging)
	{
	    // calculate the mosaic view's new frame
	    newFrame = NSMakeRect(0, 0, [[mosaicView superview] frame].size.width - 128,
				[[mosaicView superview] frame].size.height);
	    if (_statusBarShowing) newFrame.size.height -= [statusBarView frame].size.height;
	    [mosaicView setFrame:newFrame];
	}

	// calculate the editor table's new frame
	newFrame = NSMakeRect([mosaicView frame].size.width + 16, 16,
			      96, [mosaicView frame].size.height - 40);
	[editorTable setFrame:newFrame];
	
	//calculate the editor label's new frame
	newFrame = NSMakeRect([mosaicView frame].size.width + 16, [mosaicView frame].size.height - 19,
			      [editorLabel frame].size.width, [editorLabel frame].size.height);
	[editorLabel setFrame:newFrame];
    }
}


- (void)toggleStatusBar:(id)sender
{
    NSRect	newFrame = [[[[self windowControllers] objectAtIndex:0] window] frame];
    int		i;
    
    if (_statusBarShowing)
    {
	_statusBarShowing = NO;
	_removedSubviews = [[statusBarView subviews] copy];
	for (i = 0; i < [_removedSubviews count]; i++)
	    [[_removedSubviews objectAtIndex:i] removeFromSuperview];
	[statusBarView retain];
	[statusBarView removeFromSuperview];
	newFrame.origin.y += [statusBarView frame].size.height;
	newFrame.size.height -= [statusBarView frame].size.height;
	[[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:YES];
	[[_viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
    }
    else
    {
	[[mosaicView superview] addSubview:statusBarView];
	[statusBarView release];
	for (i = 0; i < [_removedSubviews count]; i++)
	    [statusBarView addSubview:[_removedSubviews objectAtIndex:i]];
	[_removedSubviews release]; _removedSubviews = nil;
	_statusBarShowing = YES;
	newFrame.origin.y -= [statusBarView frame].size.height;
	newFrame.size.height += [statusBarView frame].size.height;
	[[[[self windowControllers] objectAtIndex:0] window] setFrame:newFrame display:YES animate:YES];
	[statusBarView setFrameOrigin:NSMakePoint(0, [[statusBarView superview] frame].size.height -
						     [statusBarView frame].size.height)];
	[[_viewMenu itemWithTitle:@"Show Status Bar"] setTitle:@"Hide Status Bar"];
    }
}


- (void)toggleImageSourcesDrawer:(id)sender
{
    [imageSourcesDrawer toggle:(id)sender];
}


- (void)addDirectoryImageSource:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:nil
		    modalForWindow:[[[self windowControllers] objectAtIndex:0] window]
		     modalDelegate:self
		    didEndSelector:@selector(addDirectoryImageSourceOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    if (returnCode != NSOKButton) return;

    [_imageSources addObject:[[DirectoryImageSource alloc]
			      initWithObject:[[sheet filenames] objectAtIndex:0]]];
}


- (void)addGoogleImageSource:(id)sender
{
    [NSApp beginSheet:googleTermPanel
       modalForWindow:[[[self windowControllers] objectAtIndex:0] window]
	modalDelegate:nil
       didEndSelector:nil
	  contextInfo:nil];
}


- (void)cancelAddGoogleImageSource:(id)sender;
{
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)okAddGoogleImageSource:(id)sender;
{
    [_imageSources addObject:[[GoogleImageSource alloc] initWithObject:[googleTermField stringValue]]];
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)exportMacOSaiXImage:(id)sender
{
    int			result, i;
    NSSavePanel		*savePanel = [NSSavePanel savePanel];
    NSAffineTransform	*transform;
    NSRect		drawRect;
    NSImage		*exportImage, *pixletImage;
    NSBitmapImageRep	*exportRep;
    NSData		*bitmapData;
    Tile		*tile;
    NSBezierPath	*clipPath;
    NSAutoreleasePool	*pool;
    
    // ask the user where to save the image
    result = [savePanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"] 
					file:@"Mosaic.tiff"];
    if (result != NSOKButton) return;
    
    _paused = YES;
    [NSApp beginSheet:exportProgressPanel
       modalForWindow:[[[self windowControllers] objectAtIndex:0] window]
	modalDelegate:nil
       didEndSelector:nil
	  contextInfo:nil];
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }
    exportImage = [[NSImage alloc] initWithSize:NSMakeSize(2400, 2400 * [_originalImage size].height / 
								 [_originalImage size].width)];
    [exportImage lockFocus];
    transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
    [exportProgressIndicator setMaxValue:[_tiles count]];
    for (i = 0; i < [_tiles count]; i++)
    {
	[exportProgressIndicator setDoubleValue:i];
	tile = [_tiles objectAtIndex:i];
	[NSGraphicsContext saveGraphicsState];
	clipPath = [transform transformBezierPath:[tile outline]];
	[clipPath addClip];
	pixletImage = [[NSImage alloc] initWithData:[[[tile displayMatch] imageURL] 
						     resourceDataUsingCache:YES]];
	if ([clipPath bounds].size.width / [pixletImage size].width <
	    [clipPath bounds].size.height / [pixletImage size].height)
	{
	    drawRect.size = NSMakeSize([clipPath bounds].size.height * [pixletImage size].width /
					[pixletImage size].height,
				       [clipPath bounds].size.height);
	    drawRect.origin = NSMakePoint([clipPath bounds].origin.x - 
					    (drawRect.size.width - [clipPath bounds].size.width) / 2.0,
					  [clipPath bounds].origin.y);
	}
	else
	{
	    drawRect.size = NSMakeSize([clipPath bounds].size.width,
				       [clipPath bounds].size.width * [pixletImage size].height /
					[pixletImage size].width);
	    drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
					  [clipPath bounds].origin.y - 
					    (drawRect.size.height - [clipPath bounds].size.height) / 2.0);
	}
	[pixletImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	[pixletImage release];
	[NSGraphicsContext restoreGraphicsState];
    }
    exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [exportImage size].width, 
									     [exportImage size].height)];
    [exportImage unlockFocus];

    bitmapData = [exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
    [bitmapData writeToFile:[savePanel filename] atomically:YES];
    
    [NSApp endSheet:exportProgressPanel];
    [exportProgressPanel orderOut:nil];

    [pool release];
    [exportRep release];
    [exportImage release];

    _paused = NO;
}


- (void)synchronizeViewMenu
{
    [[_viewMenu itemWithTitle:@"View Mosaic and Original"]
	setState:(_viewMode == viewMosaicAndOriginal ? NSOnState : NSOffState)];
    [[_viewMenu itemWithTitle:@"View Mosaic Alone"]
	setState:(_viewMode == viewMosaicAlone ? NSOnState : NSOffState)];
    [[_viewMenu itemWithTitle:@"View Mosaic Editor"]
	setState:(_viewMode == viewMosaicEditor ? NSOnState : NSOffState)];
}


// window delegate methods

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
    [self synchronizeViewMenu];
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    float	aspectRatio = [_mosaicImage size].width / [_mosaicImage size].height;
    NSSize	diff;
    
    diff.width = [sender frame].size.width - [[sender contentView] frame].size.width;
    diff.height = [sender frame].size.height - [[sender contentView] frame].size.height;
    proposedFrameSize.width -= diff.width;
    
    if (_viewMode == viewMosaicAndOriginal)
	proposedFrameSize.height = (proposedFrameSize.width - 16) / 2 / aspectRatio;
    else if (_viewMode == viewMosaicAlone)
	proposedFrameSize.height = (proposedFrameSize.width - 16) / aspectRatio;
    else if (_viewMode == viewMosaicEditor)
	proposedFrameSize.height = (proposedFrameSize.width - 144) / aspectRatio;
    
    proposedFrameSize.height += diff.height + 16 +
				(_statusBarShowing ? [statusBarView frame].size.height : 0);
    proposedFrameSize.width += diff.width;
    
    return proposedFrameSize;
}


- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
    defaultFrame.size = [self windowWillResize:sender toSize:defaultFrame.size];

    [mosaicView setNeedsDisplay:YES];
    
    return defaultFrame;
}


- (void)windowDidResize:(NSNotification *)notification
{
    [self setZoom:self];
    [self calculateFrames];
    [[mosaicView documentView] setNeedsDisplay:YES];
}



// Toolbar delegate methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem	*toolbarItem = [_toolbarItems objectForKey:itemIdentifier];

    if (toolbarItem) return toolbarItem;
    
    toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    
    if ([itemIdentifier isEqualToString:@"View"])
    {
	[toolbarItem setMinSize:NSMakeSize(88, 24)];
	[toolbarItem setMaxSize:NSMakeSize(88, 24)];
	[toolbarItem setLabel:@"View"];
	[toolbarItem setView:viewToolbarView];
	//[toolbarItem setFormMenu:...];
    }
    
    if ([itemIdentifier isEqualToString:@"Zoom"])
    {
	[toolbarItem setMinSize:NSMakeSize(64, 14)];
	[toolbarItem setMaxSize:NSMakeSize(64, 14)];
	[toolbarItem setLabel:@"Zoom"];
	[toolbarItem setView:zoomToolbarView];
	//[toolbarItem setFormMenu:...];
    }

    if ([itemIdentifier isEqualToString:@"ExportImage"])
    {
	[toolbarItem setImage:[NSImage imageNamed:@"ExportImage"]];
	[toolbarItem setLabel:@"Export Image"];
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(exportMacOSaiXImage:)];
	[toolbarItem setToolTip:@"Export a high quality image of the mosaic"];
    }

    if ([itemIdentifier isEqualToString:@"ImageSources"])
    {
	[toolbarItem setImage:[NSImage imageNamed:@"ImageSources"]];
	[toolbarItem setLabel:@"Image Sources"];
	[toolbarItem setTarget:imageSourcesDrawer];
	[toolbarItem setAction:@selector(toggle:)];
	[toolbarItem setToolTip:@"Show/hide list of image sources"];
    }
    
    [_toolbarItems setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"View", @"Zoom", @"ExportImage", @"ImageSources", nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"View", @"Zoom", @"ExportImage", @"ImageSources", nil];
}


// table view delegate methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if ([aTableView isEqual:imageSourcesTable])
	return [_imageSources count] * 2;
    else
	return (_selectedTile == nil ? 0 : [[_selectedTile matches] count]);
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if ([aTableView isEqual:imageSourcesTable])
    {
	if (rowIndex % 2 == 0)
	{
	    if ([[aTableColumn identifier] isEqualToString:@"type"])
		return [[_imageSources objectAtIndex:(int)(rowIndex / 2)] typeImage];
	    else
		return [[_imageSources objectAtIndex:(int)(rowIndex / 2)] descriptor];
	}
	else
	{
	    if ([[aTableColumn identifier] isEqualToString:@"type"])
		return [NSImage imageNamed:@"Blank"];
	    else
		return [NSString stringWithFormat:@"(%d images found)",
					    [[_imageSources objectAtIndex:(int)(rowIndex / 2)] imageCount]];
	}
    }
    else // it's the editor table
    {
	NSImage	*image = [_selectedTileImages objectAtIndex:rowIndex];
	
	if ([image isKindOfClass:[TileMatch class]] && rowIndex != -1)
	    image = [self createEditorImage:rowIndex];
	    
	return image;
    }
}


- (NSImage *)createEditorImage:(int)rowIndex
{
    NSImage		*image;
    NSBitmapImageRep	*bitmapRep = [[[_selectedTile matches] objectAtIndex:rowIndex] bitmapRep];
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSSize		tileSize = [[_selectedTile outline] bounds].size;
    float		scale;
    NSPoint		origin;
    NSBezierPath	*bezierPath = [NSBezierPath bezierPath];
    
    image = [[[NSImage alloc] initWithSize:[bitmapRep size]] autorelease];

    if (tileSize.width / [image size].width < tileSize.height / [image size].height)
    {
	scale = [image size].height / tileSize.height;
	origin = NSMakePoint(([image size].width - tileSize.width * scale) / 2.0, 0.0);
    }
    else
    {
	scale = [image size].width / tileSize.width;
	origin = NSMakePoint(0.0, ([image size].height - tileSize.height * scale) / 2.0);
    }
    [transform translateXBy:origin.x yBy:origin.y];
    [transform scaleBy:scale];
    [transform translateXBy:[[_selectedTile outline] bounds].origin.x * -1
			yBy:[[_selectedTile outline] bounds].origin.y * -1];
    
    [image lockFocus];
	// draw the pixlet image
	[bitmapRep drawInRect:NSMakeRect(0, 0, [image size].width, [image size].height)];
	
	// now add the tile outline
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
	[bezierPath moveToPoint:NSMakePoint(0, 0)];
	[bezierPath lineToPoint:NSMakePoint(0, [image size].height)];
	[bezierPath lineToPoint:NSMakePoint([image size].width, [image size].height)];
	[bezierPath lineToPoint:NSMakePoint([image size].width, 0)];
	[bezierPath closePath];
	[bezierPath appendBezierPath:[transform transformBezierPath:[_selectedTile outline]]];
	[bezierPath fill];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
	[bezierPath stroke];
	
	// check if it's the user chosen image
	if ([[_selectedTile matches] objectAtIndex:rowIndex] == [_selectedTile userMatch])
	{
	    NSBezierPath	*badgePath = [NSBezierPath bezierPathWithOvalInRect:
						NSMakeRect(2, 2, 10, 10)];
						
	    [[NSColor colorWithCalibratedRed:0 green:1.0 blue:0 alpha:1.0] set];
	    [badgePath fill];
	    [[NSColor colorWithCalibratedRed:0 green:0.5 blue:0 alpha:1.0] set];
	    [badgePath stroke];
	}

	// check if it's the user chosen image
	if ([[_selectedTile matches] objectAtIndex:rowIndex] == [_selectedTile displayMatch])
	{
	    NSBezierPath	*badgePath = [NSBezierPath bezierPathWithOvalInRect:
						NSMakeRect([image size].width - 12, 2, 10, 10)];
						
	    [[NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:1.0] set];
	    [badgePath fill];
	    [[NSColor colorWithCalibratedRed:0.5 green:0 blue:0 alpha:1.0] set];
	    [badgePath stroke];
	}
    [image unlockFocus];
    [_selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
    return image;
}


- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
    if ([aTableView isEqual:imageSourcesTable]) return YES;
    
    if (rowIndex == -1) return NO;

    [_selectedTile setUserMatch:[[_selectedTile matches] objectAtIndex:rowIndex]];

    // remove the badge from the previously selected image
    if ([[editorTable documentView] selectedRow] != -1)
	[self createEditorImage:[[editorTable documentView] selectedRow]];
    // add the badge to the newly selected image
    [self createEditorImage:rowIndex];
    
    // tell the other thread to recalculate the mosaic
    [_lastBestMatchLock lock];
    _lastBestMatch = 1.0;
    [_lastBestMatchLock unlock];
    
    return YES;
}


- (void)dealloc
{
    _stillAlive = NO;
    
    // wait for threads to die...

    if (_toolbarItems) [_toolbarItems release];
    if (_removedSubviews) [_removedSubviews release];
    if (_originalImage) [_originalImage release];
    if (_tileOutlines) [_tileOutlines release];
    if (_imageSources) [_imageSources release];
    if (_mosaicImage) [_mosaicImage release];
    if (_imageQueue) [_imageQueue release];
    if (_imageQueueLock) [_imageQueueLock release];
    if (_tiles) [_tiles release];
    [super dealloc];
}

@end
