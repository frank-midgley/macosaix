#import <Foundation/Foundation.h>
#import <HIToolbox/MacWindows.h>
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "TileMatch.h"
#import "TileImage.h"
#import "DirectoryImageSource.h"
#import "GoogleImageSource.h"
#import "GlyphImageSource.h"
#import "MosaicView.h"
#import "OriginalView.h"
#import "ImageRepCell.h"

// The maximum size of the image URL queue
#define MAX_IMAGE_URLS 16

@implementation MacOSaiXDocument

- (id)init
{
    self = [super init];
    
    _originalImageURL = nil;
    _tiles = nil;
    _combinedOutlines = nil;
    _paused = NO;
    _viewMode = viewMosaicAndOriginal;
    _imagesMatched = 0;
    _imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueue = nil;
    _mosaicImage = nil;
    _mosaicImageDrawWindow = nil;
    _zoom = 0.0;
    _lastSaved = [[NSDate date] retain];
    _autosaveFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] intValue];
    _finishLoading = NO;
    
    // create the image URL queue and its lock
    _imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueueLock = [[NSLock alloc] init];

    _createTilesThreadStatus = _enumerateImageSourcesThreadStatus =
	_processImagesThreadStatus = _integrateMatchesThreadStatus = threadUnborn;
    
    return self;
}


- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    NSToolbar		*toolbar;
    NSRect		windowFrame;
    
    [super windowControllerDidLoadNib:aController];
    
    _mainWindow = [[[self windowControllers] objectAtIndex:0] window];
    
    _viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    _fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];

    _viewIsChanging = NO;
    _statusBarShowing = YES;
    _selectedTile = nil;
    _mosaicImageUpdated = NO;

    _mosaicImageLock = [[NSLock alloc] init];
    _lastBestMatchLock = [[NSLock alloc] init];
    _lastBestMatch = WORST_CASE_PIXEL_MATCH;	// the integration thread doesn't need to re-integrate yet
    _tileMatchesLock = [[NSLock alloc] init];
    
    // and create a timer to watch the queue
    _updateDisplayTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
							   target:(id)self
							 selector:@selector(updateDisplay:)
							 userInfo:nil
							  repeats:YES];
    _animateTileTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
							 target:(id)self
						       selector:@selector(animateSelectedTile:)
						       userInfo:nil
							repeats:YES];

    if (_combinedOutlines) [originalView setTileOutlines:_combinedOutlines];
    [originalView setImage:_originalImage];


    [imageSourcesTable setDataSource:self];
    [[imageSourcesTable tableColumnWithIdentifier:@"type"] setDataCell:[[NSImageCell alloc] init]];
    [[[editorTable documentView] tableColumnWithIdentifier:@"image"] setDataCell:[[NSImageCell alloc] init]];

    // the editor should not be visible initially
//    [[editorLabel retain] removeFromSuperview];
//    [[editorTable retain] removeFromSuperview];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(mosaicViewDidScroll:)
						 name:@"View Did Scroll" object:nil];
    
    _removedSubviews = nil;

    // set up the toolbar
    _pauseToolbarItem = nil;
    _viewToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    [_viewToolbarMenuItem setSubmenu:viewToolbarSubmenu];
    _zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [_zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    _toolbarItems = [[NSMutableDictionary dictionary] retain];
    toolbar = [[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [_mainWindow setToolbar:toolbar];
    
    _stillAlive = YES;

    [self setZoom:nil];
    
    if (_finishLoading)
    {
	[self updateMosaicImage:[NSMutableArray arrayWithArray:_tiles]];

	if (_paused)
	{
	    [_pauseToolbarItem setLabel:@"Resume"];
	    [_pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
	    [[_fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
	}

	[self windowWillResize:_mainWindow toSize:_storedWindowFrame.size];
	[_mainWindow setFrame:_storedWindowFrame display:YES];
    }
    else
    {
	windowFrame = [_mainWindow frame];
	windowFrame.size = [self windowWillResize:_mainWindow toSize:windowFrame.size];
	[_mainWindow setFrame:windowFrame display:YES animate:YES];
    }
    
    // spawn a thread to create data structure for each tile including outlines, bitmaps, etc.
    if (_tiles == nil)
	[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
				  toTarget:self withObject:nil];
    
    // spawn a thread to enumerate the image sources
    [NSApplication detachDrawingThread:@selector(enumerateImageSources:) toTarget:self withObject:nil];
    
    // start the image matching thread
    [NSApplication detachDrawingThread:@selector(processImageURLQueue:) toTarget:self withObject:nil];
    
    // start the image integrating thread
    [NSApplication detachDrawingThread:@selector(recalculateTileDisplayMatches:)
			      toTarget:self withObject:nil];
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    BOOL		wasPaused = _paused;
    NSMutableDictionary	*storage = [NSMutableDictionary dictionary];

    _paused = YES;

    // wait for threads to pause
    while (_enumerateImageSourcesThreadStatus == threadWorking || _processImagesThreadStatus == threadWorking)
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
    
    [storage setObject:@"1.0b1" forKey:@"Version"];
    [storage setObject:_originalImageURL forKey:@"_originalImageURL"];
    [storage setObject:_imageSources forKey:@"_imageSources"];
    [storage setObject:_tiles forKey:@"_tiles"];
    [storage setObject:[NSNumber numberWithLong:_imagesMatched] forKey:@"_imagesMatched"];
    [storage setObject:_imageQueue forKey:@"_imageQueue"];
    [storage setObject:[NSNumber numberWithInt:_viewMode] forKey:@"_viewMode"];
    [storage setObject:[NSValue valueWithRect:[_mainWindow frame]] forKey:@"window frame"];
    [storage setObject:[NSNumber numberWithInt:(_paused ? 1 : 0)] forKey:@"_paused"];
    
    _paused = wasPaused;

    return [NSArchiver archivedDataWithRootObject:storage];
}


- (BOOL)loadDataRepresentation:(NSData *)data ofType:(NSString *)aType
{
    NSDictionary	*storage = [NSUnarchiver unarchiveObjectWithData:data];
    NSString		*version = [storage objectForKey:@"Version"];
    NSData		*imageData;
    NSImage		*image;
    int			index;
    
    if ([version isEqualToString:@"1.0b1"])
    {
	imageData = [[storage objectForKey:@"_originalImageURL"] resourceDataUsingCache:NO];
	image = [[[NSImage alloc] initWithData:imageData] autorelease];
	[image setDataRetained:YES];
	[image setScalesWhenResized:YES];
	[self setOriginalImage:image fromURL:[storage objectForKey:@"_originalImageURL"]];
	
	[self setImageSources:[storage objectForKey:@"_imageSources"]];
	
	_tiles = [[storage objectForKey:@"_tiles"] retain];
	_tileOutlines = nil;
	_combinedOutlines = [[NSBezierPath bezierPath] retain];
	for (index = 0; index < [_tiles count]; index++)
	    [_combinedOutlines appendBezierPath:[[_tiles objectAtIndex:index] outline]];
	
	_imagesMatched = [[storage objectForKey:@"_imagesMatched"] longValue];
	
	NS_DURING
	    [_imageQueue addObjectsFromArray:[storage objectForKey:@"_imageQueue"]];
	NS_HANDLER
	    NSLog(@"Could not add image sources");
	NS_ENDHANDLER
	[_imageQueue makeObjectsPerformSelector:@selector(retain)];	// mimics enumeration thread's behavior
	
	[self setViewMode:[[storage objectForKey:@"_viewMode"] intValue]];
	
	_storedWindowFrame = [[storage objectForKey:@"window frame"] rectValue];
    
	_paused = ([[storage objectForKey:@"_paused"] intValue] == 1 ? YES : NO);
	
	_createTilesThreadStatus = threadTerminated;
	
	_finishLoading = YES;
	
	[_lastSaved autorelease];
	_lastSaved = [[NSDate date] retain];

	return YES;	// document was loaded successfully
    }
    
    return NO;	// unknown version of saved document
}


- (void)updateDisplay:(id)timer
{
    NSString	*statusMessage, *fullMessage;
    
    // update the status bar
    if (_createTilesThreadStatus == threadWorking)
	statusMessage = [NSString stringWithString:@"Extracting tile images..."];
    else if (_processImagesThreadStatus == threadWorking && _integrateMatchesThreadStatus == threadWorking)
	statusMessage = [NSString stringWithString:@"Matching and integrating images..."];
    else if (_processImagesThreadStatus == threadWorking)
	statusMessage = [NSString stringWithString:@"Matching images..."];
    else if (_integrateMatchesThreadStatus == threadWorking)
	statusMessage = [NSString stringWithString:@"Integrating matched images..."];
    else if (_enumerateImageSourcesThreadStatus == threadWorking)
	statusMessage = [NSString stringWithString:@"Looking for images..."];
    else if (_paused)
	statusMessage = [NSString stringWithString:@"Paused"];
    else
	statusMessage = [NSString stringWithString:@"Idle"];
	
    if ([_mainWindow frame].size.width > 200)
	fullMessage = [NSString stringWithFormat:
	    @"Images Matched: %d     Mosaic Quality: %2.1f%%     Status: %@",
	    _imagesMatched, _overallMatch, statusMessage];
    else
	fullMessage = [NSString stringWithFormat:@"%d     %2.1f%%     %@",
	    _imagesMatched, _overallMatch, statusMessage];
    [statusMessageView setStringValue:fullMessage];
    
    // update the mosaic image
    if (_mosaicImageUpdated && [_mosaicImageLock tryLock])
    {
	OSStatus	result;
	
	[[mosaicView documentView] setImage:_mosaicImage];
	[[mosaicView documentView] updateCell: [[mosaicView documentView] cell]];
	_mosaicImageUpdated = NO;
	if (IsWindowCollapsed([_mainWindow windowRef]))
	    result = UpdateCollapsedWindowDockTile([_mainWindow windowRef]);
	[_mosaicImageLock unlock];
    }
    
    // update the image sources table
    [imageSourcesTable reloadData];
    
    // autosave if it's time
    if ([_lastSaved timeIntervalSinceNow] < _autosaveFrequency * -60)
    {
	[self saveDocument:self];
	[_lastSaved autorelease];
	_lastSaved = [[NSDate date] retain];
    }
}


- (void)animateSelectedTile:(id)timer
{
    if (_selectedTile != nil)
	[[mosaicView documentView] animateHighlight];
}


- (void)setOriginalImage:(NSImage *)image fromURL:(NSURL *)imageURL
{
    [_originalImage autorelease];
    _originalImage = [image copy];
    
    [originalView setImage:_originalImage];

    [_originalImageURL autorelease];
    _originalImageURL = [imageURL retain];

    // Create an NSImage to hold the mosaic image (somewhat arbitrary size)
    [_mosaicImage autorelease];
    _mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1600 * 
						[_originalImage size].height / [_originalImage size].width)];
    [_mosaicImageDrawWindow autorelease];
    _mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
								  [_mosaicImage size].width,
								  [_mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];
}


- (void)setTileOutlines:(NSMutableArray *)tileOutlines
{
    _tileOutlines = [tileOutlines retain];
}


- (void)setImageSources:(NSMutableArray *)imageSources
{
    [_imageSources autorelease];
    _imageSources = [imageSources retain];
}


- (void)createTileCollectionWithOutlines:(id)object
{
    int			index;
    NSAutoreleasePool	*pool;
    NSWindow		*drawWindow;
    NSBezierPath	*combinedOutline = [NSBezierPath bezierPath];
    
    if (_tileOutlines == nil || _originalImage == nil) return;

    _createTilesThreadStatus = threadWorking;
    
    pool = [[NSAutoreleasePool alloc] init];

    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];

    // create an offscreen window to draw into (it will have a single, empty view the size of the window)
    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000,
								  [_originalImage size].width, 
								  [_originalImage size].height)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];
    while (![[drawWindow contentView] lockFocusIfCanDraw])
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
    
    _tiles = [[NSMutableArray arrayWithCapacity:[_tileOutlines count]] retain];
    for (index = 0; index < [_tileOutlines count] && _stillAlive; index++)
    {
	Tile			*tile;
	NSBezierPath		*clipPath;
	NSAffineTransform	*transform;
	NSRect			origRect, destRect;
	NSBitmapImageRep	*tileRep;
	
	// create the tile object and add it to the collection
	tile = [[Tile alloc] init];	NSAssert(tile != nil, @"Could not allocate tile");
	NS_DURING
	    [_tiles addObject:tile];
	NS_HANDLER
	    NSLog(@"Could not add tile");
	NS_ENDHANDLER
	
	[tile setTileMatchesLock:_tileMatchesLock];
	[tile setMaxMatches:[_tileOutlines count]];
	[tile setOutline:[_tileOutlines objectAtIndex:index]];
	
	[combinedOutline appendBezierPath:[_tileOutlines objectAtIndex:index]];
	
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
	tileRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect];
	if (tileRep == nil)
	    NSLog(@"Could not create tile bitmap");
	[tile setBitmapRep:tileRep];
	
	if (index % 20 == 19 && index != [_tileOutlines count] - 1)
	{
	    [[drawWindow contentView] unlockFocus];
	    while (![[drawWindow contentView] lockFocusIfCanDraw])
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
	}
    }

    [[drawWindow contentView] unlockFocus];
    [drawWindow close];
    
    [(OriginalView *)originalView setTileOutlines:combinedOutline];
    
    [pool release];
    
    _createTilesThreadStatus = threadTerminated;
}


- (void)recalculateTileDisplayMatches:(id)object
{
    NSAutoreleasePool	*pool, *pool2;
    float		lastBestMatch = WORST_CASE_PIXEL_MATCH, overallMatch = 0.0;
    
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }
    
    while (_stillAlive)
    {
	pool2 = [[NSAutoreleasePool alloc] init];
	while (pool2 == nil)
	{
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    pool2 = [[NSAutoreleasePool alloc] init];
	}
	
	[_lastBestMatchLock lock];
	if (lastBestMatch <= _lastBestMatch)
	{
	    [_lastBestMatchLock unlock];
	    _integrateMatchesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	else
	{
	    NSArray		*orderedTiles;
	    NSMutableArray	*updatedTiles = [NSMutableArray arrayWithCapacity:10],
				*imagesInUse = [NSMutableArray arrayWithCapacity:[_tiles count]];
	    int	index;
	    
	    _integrateMatchesThreadStatus = threadWorking;
	    lastBestMatch = _lastBestMatch;
	    _lastBestMatch = WORST_CASE_PIXEL_MATCH;
	    [_lastBestMatchLock unlock];
	    
	    overallMatch = 0.0;
	    
	    orderedTiles = [_tiles sortedArrayUsingSelector:@selector(compareBestMatchValue:)];
	    for (index = 0; index < [orderedTiles count] && _stillAlive; index++)
	    {
		Tile		*tile = [orderedTiles objectAtIndex:index];
		
		if ([tile userMatch] != nil || [tile displayMatchValue] < lastBestMatch)
		{
		    [_tileMatchesLock lock];
			if ([tile userMatch] != nil)
			{
			    overallMatch += (721 - sqrt([[tile userMatch] matchValue])) / 721;
			    NS_DURING [updatedTiles addObject:tile];
			    NS_HANDLER NSLog(@"Could not add tile to update array"); NS_ENDHANDLER
			    NS_DURING [imagesInUse addObject:[[tile userMatch] tileImage]];
			    NS_HANDLER NSLog(@"Could not add image to in use array"); NS_ENDHANDLER
			}
			else
			{
			    overallMatch += (721 - sqrt([tile displayMatchValue])) / 721;
			    NS_DURING [imagesInUse addObject:[[tile displayMatch] tileImage]];
			    NS_HANDLER NSLog(@"Could not add image to in use array 2"); NS_ENDHANDLER
			}
		    [_tileMatchesLock unlock];
		}
		else
		{
		    NSArray	*matches;
		    int	i;
		    BOOL	foundMatch = NO;
		    
		    [_tileMatchesLock lock];
			matches = [NSArray arrayWithArray:[tile matches]];
		    [_tileMatchesLock unlock];
    
		    for (i = 0; i < [matches count] && _stillAlive; i++)
		    {
			TileMatch	*theMatch;
    
			NS_DURING theMatch = [matches objectAtIndex:i];
			NS_HANDLER NSLog(@"[tile matches] has no object at index %d", i); NS_ENDHANDLER
			
			if ([imagesInUse indexOfObjectIdenticalTo:[theMatch tileImage]] == NSNotFound)
			{
			    foundMatch = YES;
			    if ([tile displayMatch] != theMatch)
			    {
				NS_DURING [updatedTiles addObject:tile];
				NS_HANDLER NSLog(@"Could not add tile to update queue"); NS_ENDHANDLER
				[tile setDisplayMatch:theMatch];
			    }
			    NS_DURING [imagesInUse addObject:[theMatch tileImage]];
			    NS_HANDLER NSLog(@"Could not add image to in use array"); NS_ENDHANDLER
			    break;
			}
		    }
		    if (foundMatch == NO && [tile displayMatch] != nil && _stillAlive)
		    {	// this tile had a match but has no matching image now
			[tile setDisplayMatch:nil];
			NS_DURING [updatedTiles addObject:tile];
			NS_HANDLER NSLog(@"Could not add ..."); NS_ENDHANDLER
		    }
		    if (foundMatch) overallMatch += (721 - sqrt([tile displayMatchValue])) / 721;
		}
		if ([updatedTiles count] >= 10 && _stillAlive) [self updateMosaicImage:updatedTiles];
	    }
	    if ([updatedTiles count] > 0 && _stillAlive) [self updateMosaicImage:updatedTiles];
	    lastBestMatch = [[orderedTiles lastObject] displayMatchValue];
	    _overallMatch = overallMatch / [_tiles count] * 100.0;
	}
	
	[pool2 release];
    }	// end of while (_stillAlive)
    
    [pool release];
    
    _integrateMatchesThreadStatus = threadTerminated;
}

- (void)updateMosaicImage:(NSMutableArray *)updatedTiles
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    NSAffineTransform	*transform;
    NSBitmapImageRep	*newRep;
    
    while (pool == nil) pool = [[NSAutoreleasePool alloc] init];

    if (![[_mosaicImageDrawWindow contentView] lockFocusIfCanDraw])
	NSLog(@"Could not lock focus");
    else
    {
	[[NSColor whiteColor] set];
	[[NSBezierPath bezierPathWithRect:[[_mosaicImageDrawWindow contentView] bounds]] fill];
	[_mosaicImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];	//start with the current image
	transform = [NSAffineTransform transform];
	[transform scaleXBy:[_mosaicImage size].width yBy:[_mosaicImage size].height];
	while ([updatedTiles count] > 0)
	{
	    Tile		*tile = [updatedTiles objectAtIndex:0];
	    NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
	    NSImage		*matchImage;
	    NSRect		drawRect;
	    
	    if ([tile userMatch] != nil)
	    {
		matchImage = [[[tile userMatch] tileImage] image];
		if (matchImage == nil)
		    NSLog(@"Could not load image\n\t%@", [[[tile userMatch] tileImage] imageIdentifier]);
	    }
	    else
	    {
		if ([tile displayMatch] != nil)
		{
		    matchImage = [[[tile displayMatch] tileImage] image];
		    if (matchImage == nil)
			NSLog(@"Could not load image\n\t%@", [[[tile displayMatch] tileImage] imageIdentifier]);
		}
		else
		    matchImage = [NSImage imageNamed:@"White"];	// this image has no match
	    }
	    [clipPath setClip];
	    // scale the image to the tile's size, but preserve it's aspect ratio
	    if ([clipPath bounds].size.width / [matchImage size].width <
		[clipPath bounds].size.height / [matchImage size].height)
	    {
		drawRect.size = NSMakeSize([clipPath bounds].size.height * [matchImage size].width /
					    [matchImage size].height,
					    [clipPath bounds].size.height);
		drawRect.origin = NSMakePoint([clipPath bounds].origin.x - 
						(drawRect.size.width - [clipPath bounds].size.width) / 2.0,
						[clipPath bounds].origin.y);
	    }
	    else
	    {
		drawRect.size = NSMakeSize([clipPath bounds].size.width,
					    [clipPath bounds].size.width * [matchImage size].height /
					    [matchImage size].width);
		drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
						[clipPath bounds].origin.y - 
					    (drawRect.size.height - [clipPath bounds].size.height) /2.0);
	    }
	    [matchImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	    [updatedTiles removeObjectAtIndex:0];
	}
	[_mosaicImageLock lock];
	    newRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
						    [[_mosaicImageDrawWindow contentView] bounds]];
	    if (_mosaicImage != nil) [_mosaicImage release];
	    _mosaicImage = [[NSImage alloc] initWithSize:[[_mosaicImageDrawWindow contentView] bounds].size];
	    [_mosaicImage addRepresentation:newRep];
	    [newRep release];
	    _mosaicImageUpdated = YES;
	[_mosaicImageLock unlock];
	[[_mosaicImageDrawWindow contentView] unlockFocus];
    }
    
    [pool release];
}


- (void)enumerateImageSources:(id)object
{
    NSAutoreleasePool	*pool, *pool2;
    id			imageIdentifier;
    int			i;
    
    _enumerateImageSourcesThreadStatus = threadWorking;

    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }

    while (_stillAlive)
    {
	BOOL	imageWasFound = NO;
	
	pool2 = [[NSAutoreleasePool alloc] init];
	while (pool2 == nil)
	{
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    pool2 = [[NSAutoreleasePool alloc] init];
	}
	
	while (_paused && _stillAlive)
	{
	    _enumerateImageSourcesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	_enumerateImageSourcesThreadStatus = threadWorking;
	
	for (i = 0; i < [_imageSources count] && _stillAlive; i++)
	    if ((imageIdentifier = [[_imageSources objectAtIndex:i] nextImageIdentifier]) != nil)
	    {
		TileImage	*tileImage;
		NSImage		*pixletImage;
		
		imageWasFound = YES;
		
		tileImage = [[TileImage alloc] initWithIdentifier:imageIdentifier
							fromSource:[_imageSources objectAtIndex:i]];
			     //autorelease];
		pixletImage = [tileImage image]; // pre-load the image

		[_imageQueueLock lock];
		while ([_imageQueue count] >= MAX_IMAGE_URLS && _stillAlive)
		{
		    // the queue is full, wait for the matching thread to free up space
		    [_imageQueueLock unlock];
		    _enumerateImageSourcesThreadStatus = threadIdle;
		    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		    [_imageQueueLock lock];
		}
		if (_stillAlive)
		{
		    _enumerateImageSourcesThreadStatus = threadWorking;
		    NS_DURING [_imageQueue addObject:tileImage];
		    NS_HANDLER NSLog(@"Could not add image to processing queue"); NS_ENDHANDLER
		}
		[_imageQueueLock unlock];
	    }
	if (!imageWasFound && _stillAlive)
	{ // none of the image sources found an image, wait a second and try again
	    _enumerateImageSourcesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	
	[pool2 release];
    }
    
    [pool release];
    
    _enumerateImageSourcesThreadStatus = threadTerminated;
}


- (void)processImageURLQueue:(id)foo
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    NSWindow		*drawWindow;
    
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }

    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000, 1024, 1024)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];

    while (_stillAlive)
    {
	NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
	
	while (pool2 == nil) pool2 = [[NSAutoreleasePool alloc] init];

	// wait for the tiles to get created
	while (_createTilesThreadStatus != threadTerminated || _paused)
	{
	    _processImagesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
    
	[_imageQueueLock lock];
	if ([_imageQueue count] == 0)
	{
	    [_imageQueueLock unlock]; // there aren't any image URLs to process
	    _processImagesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	else
	{
	    TileImage		*tileImage = nil;
	    NSImage		*pixletImage = nil;
	    NSMutableArray	*cachedReps = nil;
	    int			index;
	    
	    _processImagesThreadStatus = threadWorking;
	    
	    // pull the next image from the queue
	    NS_DURING
		tileImage = [[_imageQueue objectAtIndex:0] autorelease];
	    NS_HANDLER
		NSLog(@"_imageQueue has no object at index 0");
	    NS_ENDHANDLER
	    [_imageQueue removeObjectAtIndex:0];
	    [_imageQueueLock unlock];
		
	    pixletImage = [tileImage image];
	    cachedReps = [NSMutableArray arrayWithCapacity:0];
		
	    // loop through the tiles and compute the pixlet's match
	    for (index = 0; index < [_tiles count] && _stillAlive; index++)
	    {
		Tile	*tile = nil;
		float	scale, newMatch;
		NSRect	subRect;
		int	cachedRepIndex;

		NS_DURING
		    tile = [_tiles objectAtIndex:index];
		NS_HANDLER
		    NSLog(@"_tiles has no object at index %d", index);
		NS_ENDHANDLER
		
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
			NSBitmapImageRep	*rep = nil;
			
			[pixletImage drawInRect:subRect fromRect:NSZeroRect operation:NSCompositeCopy 
				       fraction:1.0];
			rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
			if (rep != nil)
			{
			    NS_DURING [cachedReps addObject:[rep autorelease]];
			    NS_HANDLER NSLog(@"Could not add rep to cache"); NS_ENDHANDLER
			}
			else
			    cachedRepIndex = -1;
			[[drawWindow contentView] unlockFocus];
		    }
		}

		// Calculate how well they match, and if it's better than the previous best
		// then add it to the mosaic
		if (cachedRepIndex != -1)
		{
		    newMatch = [tile matchAgainst:[cachedReps objectAtIndex:cachedRepIndex]
					tileImage:tileImage forDocument:self];
		    if ([tile displayMatch] == nil || newMatch < [tile displayMatchValue])
		    {
			[_lastBestMatchLock lock];
			_lastBestMatch = MIN(_lastBestMatch, newMatch);
			[_lastBestMatchLock unlock];
		    }
		}
	    }
	    _imagesMatched++;
	}

	while ((_paused || _viewMode == viewMosaicEditor) && _stillAlive)
	{
	    _processImagesThreadStatus = threadIdle;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	
	[pool2 release];
    }
    
    [drawWindow close];
    
    [pool release];
    
    _processImagesThreadStatus = threadTerminated;
}


- (void)selectTileAtPoint:(NSPoint)thePoint
{
    int	i;
    
    if (_viewMode != viewMosaicEditor) return;
    
    thePoint.x = thePoint.x / [[mosaicView documentView] frame].size.width;
    thePoint.y = thePoint.y / [[mosaicView documentView] frame].size.height;
    
    for (i = 0; i < [_tiles count]; i++)
	if ([[[_tiles objectAtIndex:i] outline] containsPoint:thePoint])
	{
	    _selectedTile = [_tiles objectAtIndex:i];
	    
	    [(MosaicView *)[mosaicView documentView] highlightTile:_selectedTile];
	    
	    [self updateEditor];
	    
	    return;
	}
}

- (void)updateEditor
{
    if (_selectedTileImages != nil) [_selectedTileImages release];
    
    if (_selectedTile == nil)
    {
	[editorImageInUse setImage:nil];
	[editorChooseImage setEnabled:NO];
	[editorLabel setStringValue:@"Best matches:"];
	_selectedTileImages = [[NSMutableArray arrayWithCapacity:0] retain];
    }
    else
    {
	if ([_selectedTile userMatch] != nil)
	    [editorImageInUse setImage:[[[_selectedTile userMatch] tileImage] image]];
	else if ([_selectedTile displayMatch] != nil)
	    [editorImageInUse setImage:[[[_selectedTile displayMatch] tileImage] image]];
	else
	    [editorImageInUse setImage:nil];

	[editorChooseImage setEnabled:YES];
    
	[editorLabel setStringValue:[NSString stringWithFormat:@"%d best matches:",
					[[_selectedTile matches] count]]];
    
	_selectedTileImages = [[NSMutableArray arrayWithArray:[_selectedTile matches]] retain];
    }
    
    [[editorTable documentView] reloadData];
}


- (void)showUserChoiceInEditor:(id)sender
{
    [self showTileMatchInEditor:[_selectedTile userMatch] selecting:NO];
}


- (void)showMacOSaiXChoiceInEditor:(id)sender
{
    [self showTileMatchInEditor:[_selectedTile displayMatch] selecting:NO];
}


- (BOOL)showTileMatchInEditor:(TileMatch *)tileMatch selecting:(BOOL)selecting
{
    int	i;
    
    if (_selectedTile == nil) return NO;
    
    for (i = 0; i < [[_selectedTile matches] count]; i++)
	if ([[_selectedTile matches] objectAtIndex:i] == tileMatch)
	{
	    if (selecting)
		[[editorTable documentView] selectRow:i byExtendingSelection:NO];
	    [[editorTable documentView] scrollRowToVisible:i];
	    return YES;
	}
    return NO;
}

#pragma mark -
#pragma mark View methods

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
    NSRect	newFrame = [_mainWindow frame];
    
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
	[(MosaicView *)[mosaicView documentView] highlightTile:nil];
	[viewCompareButton setImage:[NSImage imageNamed:@"ViewCompareOn"]];
	newFrame.size.width = [mosaicView frame].size.width * 2 - 20;
	_viewMode = viewMosaicAndOriginal;
	[self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
						[[_mainWindow contentView] bounds].size.height )];
	[_mainWindow setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width * 2 - 16;
    }

    if (mode == viewMosaicAlone)
    {
	[(MosaicView *)[mosaicView documentView] highlightTile:nil];
	[viewAloneButton setImage:[NSImage imageNamed:@"ViewAloneOn"]];
	newFrame.size.width = [mosaicView frame].size.width + 4;
	[self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
						[[_mainWindow contentView] bounds].size.height )];
	[_mainWindow setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width;
	_viewMode = viewMosaicAlone;
    }
    
    if (mode == viewMosaicEditor)
    {
	[(MosaicView *)[mosaicView documentView] highlightTile:_selectedTile];
	[self updateEditor];
	[[editorTable documentView] scrollRowToVisible:0];
	[[editorTable documentView] reloadData];
	[viewEditorButton setImage:[NSImage imageNamed:@"ViewEditorOn"]];
	newFrame.size.width = [mosaicView frame].size.width + 266;
	_viewMode = viewMosaicEditor;
	[self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
						[[_mainWindow contentView] bounds].size.height )];
	[_mainWindow setFrame:newFrame display:YES animate:YES];
	newFrame.size.width = [mosaicView frame].size.width + 270;
    }

    _viewIsChanging = NO;
    [self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
					     [[_mainWindow contentView] bounds].size.height )];
    [_mainWindow setFrame:newFrame display:YES animate:NO];
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
    _zoom = zoom;
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
//	[[mosaicView documentView] scaleUnitSquareToSize:NSMakeSize(1, 1)];
	[mosaicView setNeedsDisplay:YES];
    }
    [originalView setNeedsDisplay:YES];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([[menuItem title] isEqualToString:@"Center on Selected Tile"])
	return (_viewMode == viewMosaicEditor && _selectedTile != nil && _zoom != 0.0);
    else
	return [super validateMenuItem:menuItem];
}


- (void)centerViewOnSelectedTile:(id)sender
{
    NSPoint	contentOrigin = NSMakePoint(NSMidX([[_selectedTile outline] bounds]),
					     NSMidY([[_selectedTile outline] bounds]));
    
    contentOrigin.x *= [[mosaicView documentView] frame].size.width;
    contentOrigin.x -= [[mosaicView contentView] bounds].size.width / 2;
    if (contentOrigin.x < 0) contentOrigin.x = 0;
    if (contentOrigin.x + [[mosaicView contentView] bounds].size.width >
	[[mosaicView documentView] frame].size.width)
	contentOrigin.x = [[mosaicView documentView] frame].size.width - 
			  [[mosaicView contentView] bounds].size.width;

    contentOrigin.y *= [[mosaicView documentView] frame].size.height;
    contentOrigin.y -= [[mosaicView contentView] bounds].size.height / 2;
    if (contentOrigin.y < 0) contentOrigin.y = 0;
    if (contentOrigin.y + [[mosaicView contentView] bounds].size.height >
	[[mosaicView documentView] frame].size.height)
	contentOrigin.y = [[mosaicView documentView] frame].size.height - 
			  [[mosaicView contentView] bounds].size.height;

    [[mosaicView contentView] scrollToPoint:contentOrigin];
    [mosaicView reflectScrolledClipView:[mosaicView contentView]];
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


- (void)calculateFramesFromSize:(NSSize)frameSize
{
    NSRect newFrame;
    
    // frameSize is the size of the window's content view, not the entire window frame
 
    if (_statusBarShowing) frameSize.height -= [statusBarView frame].size.height;
    
    if (_viewMode == viewMosaicAlone && !_viewIsChanging)
    {
	// calculate the mosaic view's new frame
	newFrame = NSMakeRect(0, 0, frameSize.width, frameSize.height);
	[mosaicView setFrame:newFrame];
	
	[tabView selectTabViewItemAtIndex:0];
    }

    if (_viewMode == viewMosaicAndOriginal)
    {
	if (!_viewIsChanging)
	{
	    // calculate the mosaic view's new frame
	    newFrame = NSMakeRect(0, 0, frameSize.width / 2 + 8, frameSize.height);
	    [mosaicView setFrame:newFrame];
	}

	// calculate the original view's new frame
	newFrame = NSMakeRect([mosaicView frame].size.width, 0,
			      frameSize.width - [mosaicView frame].size.width, frameSize.height);
//	newFrame = NSMakeRect([mosaicView frame].size.width, 16,
//			      frameSize.width - [mosaicView frame].size.width,
//			      [mosaicView frame].size.height - 16);
//	[originalView setFrame:newFrame];
	[tabView selectTabViewItemAtIndex:1];
	
	// calculate the original switch's new origin
//	[showOutlinesSwitch setFrameOrigin:NSMakePoint([mosaicView frame].size.width + 5, -1)];
    }

    if (_viewMode == viewMosaicEditor)
    {
	// calculate the mosaic view's new frame
	if (!_viewIsChanging)
	    [mosaicView setFrame:NSMakeRect(0, 0, frameSize.width - 270, frameSize.height)];

	[tabView selectTabViewItemAtIndex:2];

/*	// calculate the editor table's new frame
	[editorTable setFrame:NSMakeRect([mosaicView frame].size.width + 16, 16,
					 96, [mosaicView frame].size.height - 40)];
	
	//calculate the editor label's new origin
	[editorLabel setFrameOrigin:NSMakePoint([mosaicView frame].size.width + 16,
						[mosaicView frame].size.height - 19)];*/
    }
    
    [tabView setFrame:NSMakeRect([mosaicView frame].size.width, 0,
				 frameSize.width - [mosaicView frame].size.width, frameSize.height)];

}


- (void)toggleStatusBar:(id)sender
{
    NSRect	newFrame = [_mainWindow frame];
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
	[self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
						 [[_mainWindow contentView] bounds].size.height - 
						 [statusBarView frame].size.height)];
	[_mainWindow setFrame:newFrame display:YES animate:YES];
	[[_viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
    }
    else
    {
	_statusBarShowing = YES;
	newFrame.origin.y -= [statusBarView frame].size.height;
	newFrame.size.height += [statusBarView frame].size.height;
	[self calculateFramesFromSize:NSMakeSize(newFrame.size.width,
						 [[_mainWindow contentView] bounds].size.height + 
						 [statusBarView frame].size.height)];
	[_mainWindow setFrame:newFrame display:YES animate:YES];

	[statusBarView setFrame:NSMakeRect(0, [[mosaicView superview] frame].size.height - [statusBarView frame].size.height, [[mosaicView superview] frame].size.width, [statusBarView frame].size.height)];
	[[mosaicView superview] addSubview:statusBarView];
	[statusBarView release];
	for (i = 0; i < [_removedSubviews count]; i++)
	{
	    [[_removedSubviews objectAtIndex:i] setFrameSize:NSMakeSize([statusBarView frame].size.width,[[_removedSubviews objectAtIndex:i] frame].size.height)];
	    [statusBarView addSubview:[_removedSubviews objectAtIndex:i]];
	}
	[_removedSubviews release]; _removedSubviews = nil;

	[[_viewMenu itemWithTitle:@"Show Status Bar"] setTitle:@"Hide Status Bar"];
    }
}


- (void)setShowOutlines:(id)sender
{
    [originalView setDisplayTileOutlines:([showOutlinesSwitch state] == NSOnState)];
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


#pragma mark -
#pragma mark Image Sources methods

- (void)toggleImageSourcesDrawer:(id)sender
{
    [imageSourcesDrawer toggle:(id)sender];
    if ([imageSourcesDrawer state] == NSDrawerClosedState)
	[[_viewMenu itemWithTitle:@"Show Image Sources"] setTitle:@"Hide Image Sources"];
    else
	[[_viewMenu itemWithTitle:@"Hide Image Sources"] setTitle:@"Show Image Sources"];
}


- (void)togglePause:(id)sender
{
    if (_paused)
    {
	[_pauseToolbarItem setLabel:@"Pause"];
	[_pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
	[[_fileMenu itemWithTitle:@"Resume Matching"] setTitle:@"Pause Matching"];
	_paused = NO;
    }
    else
    {
	[_pauseToolbarItem setLabel:@"Resume"];
	[_pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
	[[_fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
	_paused = YES;
    }
}


- (void)addDirectoryImageSource:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:nil
		    modalForWindow:_mainWindow
		     modalDelegate:self
		    didEndSelector:@selector(addDirectoryImageSourceOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    if (returnCode != NSOKButton) return;

    NS_DURING
	[_imageSources addObject:[[DirectoryImageSource alloc]
				initWithObject:[[sheet filenames] objectAtIndex:0]]];
    NS_HANDLER
	NSLog(@"Could not add directory image source");
    NS_ENDHANDLER
}


- (void)addGoogleImageSource:(id)sender
{
    [NSApp beginSheet:googleTermPanel
       modalForWindow:_mainWindow
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
    NS_DURING
	[_imageSources addObject:[[GoogleImageSource alloc] initWithObject:[googleTermField stringValue]]];
    NS_HANDLER
	NSLog(@"Could not add google image source");
    NS_ENDHANDLER
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)addGlyphImageSource:(id)sender
{
    NS_DURING
	[_imageSources addObject:[[GlyphImageSource alloc] initWithObject:nil]];
    NS_HANDLER
	NSLog(@"Could not add glyph image source");
    NS_ENDHANDLER
}


#pragma mark -

- (void)exportMacOSaiXImage:(id)sender
{
    int			result, i;
    NSSavePanel		*savePanel = [NSSavePanel savePanel];
    NSAffineTransform	*transform;
    NSRect		drawRect;
    NSImage		*exportImage, *pixletImage;
    NSBitmapImageRep	*exportRep;
    NSData		*bitmapData;
    NSAutoreleasePool	*pool;
    BOOL		wasPaused = _paused;
    
    // ask the user where to save the image
    result = [savePanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"] 
					file:@"Mosaic.tiff"];
    if (result != NSOKButton) return;
    
    _paused = YES;
    [NSApp beginSheet:exportProgressPanel
       modalForWindow:_mainWindow
	modalDelegate:nil
       didEndSelector:nil
	  contextInfo:nil];
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	pool = [[NSAutoreleasePool alloc] init];
    }
    
    while (_integrateMatchesThreadStatus != threadIdle)
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
    exportImage = [[NSImage alloc] initWithSize:NSMakeSize(2400, 2400 * [_originalImage size].height / 
								 [_originalImage size].width)];
    [exportImage lockFocus];
    transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
    [exportProgressIndicator setMaxValue:[_tiles count]];
    for (i = 0; i < [_tiles count]; i++)
    {
	NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
	Tile			*tile = [_tiles objectAtIndex:i];
	TileImage		*tileImage = ([tile userMatch] ? [[tile userMatch] tileImage]: 
								 [[tile displayMatch] tileImage]);
	NSBezierPath		*clipPath = [transform transformBezierPath:[tile outline]];
	
	[exportProgressIndicator setDoubleValue:i];
	[NSGraphicsContext saveGraphicsState];
	[clipPath addClip];
	pixletImage = [[tileImage imageSource] imageForIdentifier:[tileImage imageIdentifier]];
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
	[NSGraphicsContext restoreGraphicsState];
	[pool2 release];
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

    _paused = wasPaused;
}


// window delegate methods

#pragma mark -
#pragma mark Window delegate methods

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
    [self synchronizeViewMenu];
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    float	aspectRatio = [_mosaicImage size].width / [_mosaicImage size].height;
    NSSize	diff;
    NSRect	newFrame, screenFrame = [[_mainWindow screen] frame];
    
    diff.width = [sender frame].size.width - [[sender contentView] frame].size.width;
    diff.height = [sender frame].size.height - [[sender contentView] frame].size.height;
    proposedFrameSize.width -= diff.width;
    
    if (_viewMode == viewMosaicAndOriginal)
    {
	//if ((proposedFrameSize.width - 16) / 2 / aspectRatio > screenFrame.height)
	//{
	//    proposedFrameSize.width = ;
	//}
	//else
	    proposedFrameSize.height = (proposedFrameSize.width - 16) / 2 / aspectRatio;
    }
    else if (_viewMode == viewMosaicAlone)
	proposedFrameSize.height = (proposedFrameSize.width - 16) / aspectRatio;
    else if (_viewMode == viewMosaicEditor)
	proposedFrameSize.height = (proposedFrameSize.width - 270) / aspectRatio;
    
    proposedFrameSize.height += 16 + (_statusBarShowing ? [statusBarView frame].size.height : 0);
    
    [self calculateFramesFromSize:proposedFrameSize];
    [self setZoom:nil];
    
    proposedFrameSize.height += diff.height;
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
}



// Toolbar delegate methods

#pragma mark -
#pragma mark Toolbar delegate methods

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
	[toolbarItem setPaletteLabel:@"View"];
	[toolbarItem setView:viewToolbarView];
	[toolbarItem setMenuFormRepresentation:_viewToolbarMenuItem];
    }
    
    if ([itemIdentifier isEqualToString:@"Zoom"])
    {
	[toolbarItem setMinSize:NSMakeSize(64, 14)];
	[toolbarItem setMaxSize:NSMakeSize(64, 14)];
	[toolbarItem setLabel:@"Zoom"];
	[toolbarItem setPaletteLabel:@"Zoom"];
	[toolbarItem setView:zoomToolbarView];
	[toolbarItem setMenuFormRepresentation:_zoomToolbarMenuItem];
    }

    if ([itemIdentifier isEqualToString:@"ExportImage"])
    {
	[toolbarItem setImage:[NSImage imageNamed:@"ExportImage"]];
	[toolbarItem setLabel:@"Export Image"];
	[toolbarItem setPaletteLabel:@"Export Image"];
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(exportMacOSaiXImage:)];
	[toolbarItem setToolTip:@"Export a high quality image of the mosaic"];
    }

    if ([itemIdentifier isEqualToString:@"ImageSources"])
    {
	[toolbarItem setImage:[NSImage imageNamed:@"ImageSources"]];
	[toolbarItem setLabel:@"Image Sources"];
	[toolbarItem setPaletteLabel:@"Image Sources"];
	[toolbarItem setTarget:imageSourcesDrawer];
	[toolbarItem setAction:@selector(toggle:)];
	[toolbarItem setToolTip:@"Show/hide list of image sources"];
    }

    if ([itemIdentifier isEqualToString:@"Pause"])
    {
	[toolbarItem setImage:[NSImage imageNamed:@"Pause"]];
	[toolbarItem setLabel:_paused ? @"Resume" : @"Pause"];
	[toolbarItem setPaletteLabel:_paused ? @"Resume" : @"Pause"];
	[toolbarItem setTarget:self];
	[toolbarItem setAction:@selector(togglePause:)];
	_pauseToolbarItem = toolbarItem;
    }
    
    [_toolbarItems setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    if ([[theItem itemIdentifier] isEqualToString:@"Pause"])
	return _viewMode != viewMosaicEditor;
    else
	return YES;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"View", @"Zoom", @"ExportImage", @"ImageSources", @"Pause", 
				     NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSpaceItemIdentifier,
				     NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier,
				     nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"View", @"Zoom", @"ExportImage", @"ImageSources", @"Pause", nil];
}


// table view delegate methods

#pragma mark -
#pragma mark Table delegate methods

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
	NSImage	*image;
	
	if (_selectedTile == nil) return nil;
	
	image = [_selectedTileImages objectAtIndex:rowIndex];
	if ([image isKindOfClass:[TileMatch class]] && rowIndex != -1)
	    image = [self createEditorImage:rowIndex];
	    
	return image;
    }
}


- (NSImage *)createEditorImage:(int)rowIndex
{
    NSImage		*image;
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSSize		tileSize = [[_selectedTile outline] bounds].size;
    float		scale;
    NSPoint		origin;
    NSBezierPath	*bezierPath = [NSBezierPath bezierPath];
    
    image = [[[[[[_selectedTile matches] objectAtIndex:rowIndex] tileImage] image] copy] autorelease];
    
    // scale the image to at most 80 pixels (the size of the editor column)
    if ([image size].width > [image size].height)
	[image setSize:NSMakeSize(80, 80 / [image size].width * [image size].height)];
    else
	[image setSize:NSMakeSize(80 / [image size].height * [image size].width, 80)];

    tileSize.width *= [_mosaicImage size].width;
    tileSize.height *= [_mosaicImage size].height;
    if (([image size].width / tileSize.width) < ([image size].height / tileSize.height))
    {
	scale = [image size].width / tileSize.width;
	origin = NSMakePoint(0.0, ([image size].height - tileSize.height * scale) / 2.0);
    }
    else
    {
	scale = [image size].height / tileSize.height;
	origin = NSMakePoint(([image size].width - tileSize.width * scale) / 2.0, 0.0);
    }
    [transform translateXBy:origin.x yBy:origin.y];
    [transform scaleXBy:scale yBy:scale];
    [transform scaleXBy:[_mosaicImage size].width yBy:[_mosaicImage size].height];
    [transform translateXBy:[[_selectedTile outline] bounds].origin.x * -1
			yBy:[[_selectedTile outline] bounds].origin.y * -1];
    
    [image lockFocus];
	// add the tile outline
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];	//lighten
	[bezierPath moveToPoint:NSMakePoint(0, 0)];
	[bezierPath lineToPoint:NSMakePoint(0, [image size].height)];
	[bezierPath lineToPoint:NSMakePoint([image size].width, [image size].height)];
	[bezierPath lineToPoint:NSMakePoint([image size].width, 0)];
	[bezierPath closePath];
	[bezierPath appendBezierPath:[transform transformBezierPath:[_selectedTile outline]]];
	[bezierPath fill];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set]; //darken
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
    
    // mark the document as needing saving
    [self updateChangeCount:NSChangeDone];
    
    return YES;
}


#pragma mark -

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector
			 contextInfo:(void *)contextInfo
{
    // pause threads so document dirty state doesn't change
    if (!_paused) [self togglePause:nil];
    while ((_createTilesThreadStatus != threadIdle && _createTilesThreadStatus != threadTerminated) ||
	   _enumerateImageSourcesThreadStatus != threadIdle ||
	   _processImagesThreadStatus != threadIdle ||
	   _integrateMatchesThreadStatus != threadIdle)
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector 
			    contextInfo:contextInfo];
}


- (void)close
{
    // shut down threads and timers
    [_updateDisplayTimer invalidate];
    [_animateTileTimer invalidate];
    _stillAlive = NO;
    while (_createTilesThreadStatus != threadTerminated ||
	   _enumerateImageSourcesThreadStatus != threadTerminated ||
	   _processImagesThreadStatus != threadTerminated ||
	   _integrateMatchesThreadStatus != threadTerminated)
	[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];

    [super close];
}



- (void)dealloc
{
    [_toolbarItems release];
    [_removedSubviews release];
    [_originalImageURL release];
    [_originalImage release];
    [_tileOutlines release];
    [_combinedOutlines release];
    [_imageSources release];
    [_mosaicImage release];
    [_imageQueue release];
    [_imageQueueLock release];
    [_mosaicImageLock release];
    [_lastBestMatchLock release];
    [_tileMatchesLock release];
    [_tiles release];
    
    [super dealloc];
}

@end
