#import <Foundation/Foundation.h>
#import <HIToolbox/MacWindows.h>
#import "MacOSaiX.h"
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "TileImage.h"
#import "MosaicView.h"
#import "OriginalView.h"

	// The maximum size of the image URL queue
#define MAX_IMAGE_URLS 32

@implementation MacOSaiXDocument

- (id)init
{
    self = [super init];
    
    [self setHasUndoManager:FALSE];	// don't track undo-able changes
    
	_mosaicStarted = NO;
    _paused = YES;
    _viewMode = viewMosaicAndOriginal;
    _statusBarShowing = YES;
    _imagesMatched = 0;
    _imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
    _zoom = 0.0;
    _lastSaved = [[NSDate date] retain];
    _autosaveFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] intValue];
    _finishLoading = _windowFinishedLoading = NO;
    _exportProgressTileCount = 0;
    _exportFormat = NSJPEGFileType;
    _documentIsClosing = NO;
        
    // create the image URL queue and its lock
    _imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueueLock = [[NSLock alloc] init];

    _createTilesThreadAlive = _enumerateImageSourcesThreadAlive = _calculateImageMatchesThreadAlive = 
		_exportImageThreadAlive = NO;
	_calculateImageMatchesThreadLock = [[NSLock alloc] init];
	
		// set up ivars for "calculateDisplayedImages" thread
	_calculateDisplayedImagesThreadAlive = NO;
	_calculateDisplayedImagesThreadLock = [[NSLock alloc] init];
	_refreshTilesSet = [[NSMutableSet setWithCapacity:256] retain];
	_refreshTilesSetLock = [[NSLock alloc] init];

    _tileImages = [[NSMutableArray arrayWithCapacity:0] retain];
    _tileImagesLock = [[NSLock alloc] init];
    _unusedTileImage = [[TileImage alloc] initWithIdentifier:@"" fromImageSource:_manualImageSource];
    
    return self;
}


- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    
		// Set some shortcut ivars now that we are instantiated
    _mainWindow = [[[self windowControllers] objectAtIndex:0] window];
    _viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    _fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
    [self performSelector:@selector(chooseOriginalImage) withObject:nil afterDelay:0];
}

- (void)chooseOriginalImage
{
    NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
    
		// prompt the user for the image to make a mosaic from
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:nil
							  file:nil
							 types:[NSImage imageFileTypes]
					modalForWindow:_mainWindow
					 modalDelegate:self
					didEndSelector:@selector(chooseOriginalImageOpenPanelDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    NSToolbar	*toolbar;
    NSRect		windowFrame;

    if (returnCode == NSCancelButton)
	{
		[_mainWindow performSelector:@selector(performClose:) withObject:self afterDelay:0];
		return;
	}

		// remember and load the image the user chose
	_originalImageURL = [[[sheet URLs] objectAtIndex:0] retain];
	_originalImage = [[NSImage alloc] initWithContentsOfURL:_originalImageURL];
	
		// Create an NSImage to hold the mosaic image (somewhat arbitrary size)
    [_mosaicImage autorelease];
    _mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1600 * 
						[_originalImage size].height / [_originalImage size].width)];
    
	[_mosaicView setOriginalImage:_originalImage];
	[_mosaicView setMosaicImage:_mosaicImage];
	[_mosaicView setViewMode:_viewTilesOutline];
	
    _selectedTile = nil;
    _mosaicImageUpdated = NO;

    _mosaicImageLock = [[NSLock alloc] init];
    _refindUniqueTilesLock = [[NSLock alloc] init];
//    _refindUniqueTiles = YES;
    
		// create timers to update the window and animate any selected tile
    _updateDisplayTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
							   target:(id)self
							 selector:@selector(updateDisplay:)
							 userInfo:nil
							  repeats:YES] retain];
    _animateTileTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
							 target:(id)self
						       selector:@selector(animateSelectedTile:)
						       userInfo:nil
							repeats:YES] retain];

    if (_combinedOutlines) [_originalView setTileOutlines:_combinedOutlines];
    [_originalView setImage:_originalImage];

    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(mosaicViewDidScroll:)
						 name:@"View Did Scroll" object:nil];

    _removedSubviews = nil;

		// set up the toolbar
    _pauseToolbarItem = nil;
    _zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [_zoomToolbarMenuItem setSubmenu:_zoomToolbarSubmenu];
    _toolbarItems = [[NSMutableDictionary dictionary] retain];
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [_mainWindow setToolbar:toolbar];
    
		// Make sure we have the latest and greatest list of plug-ins
	[[NSApp delegate] discoverPlugIns];

	{	// Set up the "Tiles Setup" tab
		[_tilesSetupView setTitlePosition:NSNoTitle];
		
			// Load the names of the tile setup plug-ins
		NSEnumerator	*enumerator = [[[NSApp delegate] tilesSetupControllerClasses] objectEnumerator];
		Class			tilesSetupControllerClass;
		[_tilesSetupPopUpButton removeAllItems];
		while (tilesSetupControllerClass = [enumerator nextObject])
			[_tilesSetupPopUpButton addItemWithTitle:[tilesSetupControllerClass name]];
		[self setTilesSetupPlugIn:self];
	}
	
	{	// Set up the "Image Sources" tab
		[_imageSourcesTabView setTabViewType:NSNoTabsNoBorder];

		_imageSources = [[NSMutableArray arrayWithCapacity:4] retain];
		[[_imageSourcesTable tableColumnWithIdentifier:@"Image Source Type"]
			setDataCell:[[[NSImageCell alloc] init] autorelease]];
	
			// Load the image source plug-ins and create an instance of each controller
		NSEnumerator	*enumerator = [[[NSApp delegate] imageSourceControllerClasses] objectEnumerator];
		Class			imageSourceControllerClass;
		[_imageSourcesPopUpButton removeAllItems];
		[_imageSourcesPopUpButton addItemWithTitle:@"Current Image Sources"];
		while (imageSourceControllerClass = [enumerator nextObject])
		{
				// add the name of the image source to the pop-up menu
			[_imageSourcesPopUpButton addItemWithTitle:[NSString stringWithFormat:@"Add %@ Source...", 
																				  [imageSourceControllerClass name]]];
				// create an instance of the class for this document
			ImageSourceController *imageSourceController = [[[imageSourceControllerClass alloc] init] autorelease];
				// let the plug-in know how to message back to us
			[imageSourceController setDocument:self];
			[imageSourceController setWindow:_mainWindow];
				// attach it to the menu item (it will be dealloced when the menu item releases it)
			[[_imageSourcesPopUpButton lastItem] setRepresentedObject:imageSourceController];
				// add a tab to the view for this plug-in
			NSTabViewItem	*tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
			[tabViewItem setView:[imageSourceController imageSourceView]];	// this could be done lazily...
			[_imageSourcesTabView addTabViewItem:tabViewItem];
		}
		[self setImageSourcesPlugIn:self];
	}
	
	{	// Set up the "Editor" tab
		[[_editorTable tableColumnWithIdentifier:@"image"] setDataCell:[[[NSImageCell alloc] init] autorelease]];
	}
	
	[self setViewMode:viewMosaicAndTilesSetup];
	[_utilitiesDrawer setContentSize:NSMakeSize(400, [_utilitiesDrawer contentSize].height)];
    
    _documentIsClosing = NO;	// gets set to true when threads for this document should shut down

    [self setZoom:self];
    
    if (_finishLoading)
    {
		//	[self setViewMode:_viewMode];
		
			// this doc was opened from a file
		if (_paused)
		{
			[_pauseToolbarItem setLabel:@"Resume"];
			[_pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
			[[_fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
		}
	
			//	broken & disabled until next version
		//	[self windowWillResize:_mainWindow toSize:_storedWindowFrame.size];
		//	[_mainWindow setFrame:_storedWindowFrame display:YES];
		windowFrame = [_mainWindow frame];
		windowFrame.size = [self windowWillResize:_mainWindow toSize:windowFrame.size];
		[_mainWindow setFrame:windowFrame display:YES animate:YES];
    }
    else
    {
			// this doc is new
		windowFrame = [_mainWindow frame];
		windowFrame.size = [self windowWillResize:_mainWindow toSize:windowFrame.size];
		[_mainWindow setFrame:windowFrame display:YES animate:YES];
    }
	[_pauseToolbarItem setLabel:@"Start Mosaic"];
}


- (void)startMosaic
{    
	_mosaicStarted = YES;
    if (_tiles == nil)
			// spawn a thread to create a data structure for each tile including outlines, bitmaps, etc.
		[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
					toTarget:self withObject:nil];
	else
		[self spawnImageSourceThreads];
    
		// TODO: I can't remember what this is for?
    _windowFinishedLoading = YES;
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    BOOL		wasPaused = _paused;
    NSMutableDictionary	*storage = [NSMutableDictionary dictionary];

    _paused = YES;

    // wait for threads to pause
    while (_enumerateImageSourcesThreadAlive || _calculateImageMatchesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
    
    [storage setObject:@"1.0b1" forKey:@"Version"];
    [storage setObject:_originalImageURL forKey:@"_originalImageURL"];
    [storage setObject:_imageSources forKey:@"_imageSources"];
    [storage setObject:[NSArchiver archivedDataWithRootObject:_tileImages] forKey:@"_tileImages"];
    [storage setObject:[NSArchiver archivedDataWithRootObject:_tiles] forKey:@"_tiles"];
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
    NSAutoreleasePool	*pool;
    int			index;
    
    if ([version isEqualToString:@"1.0b1"])
    {
	imageData = [[storage objectForKey:@"_originalImageURL"] resourceDataUsingCache:NO];
	image = [[[NSImage alloc] initWithData:imageData] autorelease];
	[image setDataRetained:YES];
	[image setScalesWhenResized:YES];
//	[self setOriginalImage:image fromURL:[storage objectForKey:@"_originalImageURL"]];
	
//	[self setImageSources:[storage objectForKey:@"_imageSources"]];
	
	pool = [[NSAutoreleasePool alloc] init];
	    [_tileImages release];
	    _tileImages = [[NSUnarchiver unarchiveObjectWithData:[storage objectForKey:@"_tileImages"]] retain];
	[pool release];
	
	pool = [[NSAutoreleasePool alloc] init];
	    _tiles = [[NSUnarchiver unarchiveObjectWithData:[storage objectForKey:@"_tiles"]] retain];
	[pool release];
	
	// finish loading _tiles
	_tileOutlines = nil;
	_combinedOutlines = [[NSBezierPath bezierPath] retain];
	for (index = 0; index < [_tiles count]; index++)
	{
	    [_combinedOutlines appendBezierPath:[[_tiles objectAtIndex:index] outline]];
	    [[_tiles objectAtIndex:index] setDocument:self];
	}
	
	_imagesMatched = [[storage objectForKey:@"_imagesMatched"] longValue];
	
	[_imageQueue addObjectsFromArray:[storage objectForKey:@"_imageQueue"]];
	
//	_viewMode = [[storage objectForKey:@"_viewMode"] intValue];
	
	_storedWindowFrame = [[storage objectForKey:@"window frame"] rectValue];
    
	_paused = ([[storage objectForKey:@"_paused"] intValue] == 1 ? YES : NO);
	
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
    
    if (_documentIsClosing) return;
    
    // update the status bar
    if (_createTilesThreadAlive)
		statusMessage = [NSString stringWithString:@"Extracting tile images..."];
    else if (_calculateImageMatchesThreadAlive && _calculateDisplayedImagesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching and finding unique tiles..."];
    else if (_calculateImageMatchesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching images..."];
    else if (_calculateDisplayedImagesThreadAlive)
		statusMessage = [NSString stringWithString:@"Finding unique tiles..."];
    else if (_enumerateImageSourcesThreadAlive)
		statusMessage = [NSString stringWithString:@"Looking for new images..."];
    else if (_paused)
		statusMessage = [NSString stringWithString:@"Paused"];
    else
		statusMessage = [NSString stringWithString:@"Idle"];
	
    fullMessage = [NSString stringWithFormat:@"Images Matched/Kept: %d/%d     Mosaic Quality: %2.1f%%     Status: %@",
											 _imagesMatched, [_tileImages count], _overallMatch, statusMessage];
	if ([fullMessage sizeWithAttributes:[[_statusMessageView attributedStringValue] attributesAtIndex:0 effectiveRange:nil]].width 
		> [_statusMessageView frame].size.width)
		fullMessage = [NSString stringWithFormat:@"%d/%d     %2.1f%%     %@",
												 _imagesMatched, [_tileImages count], _overallMatch, statusMessage];
    [_statusMessageView setStringValue:fullMessage];
    
    // update the mosaic image
    if (_mosaicImageUpdated && [_mosaicImageLock tryLock])
    {
	//	OSStatus	result;
		
		[_mosaicView setMosaicImage:nil];
		[_mosaicView setMosaicImage:_mosaicImage];
		_mosaicImageUpdated = NO;
	//	if (IsWindowCollapsed([_mainWindow windowRef]))
		if ([_mainWindow isMiniaturized])
		{
	//	    [_mainWindow setViewsNeedDisplay:YES];
			[_mainWindow setMiniwindowImage:_mosaicImage];
	//	    result = UpdateCollapsedWindowDockTile([_mainWindow windowRef]);
		}
		[_mosaicImageLock unlock];
    }
    
    // update the image sources table
    [_imageSourcesTable reloadData];
    
    // autosave if it's time
    if ([_lastSaved timeIntervalSinceNow] < _autosaveFrequency * -60)
    {
		[self saveDocument:self];
		[_lastSaved autorelease];
		_lastSaved = [[NSDate date] retain];
    }
    
    // 
    if (_exportImageThreadAlive)
		[_exportProgressIndicator setDoubleValue:_exportProgressTileCount];
    else if (!_exportImageThreadAlive && _exportProgressTileCount > 0)
    {
		// the export is finished, close the panel
		[NSApp endSheet:_exportProgressPanel];
		[_exportProgressPanel orderOut:nil];
		_exportProgressTileCount = 0;
    }
}


- (void)synchronizeMenus
{
    [[_fileMenu itemWithTag:1] setTitle:(_paused ? @"Resume Matching" : @"Pause Matching")];
    
    [[_viewMenu itemWithTitle:@"View Mosaic and Original"]
	setState:(_viewMode == viewMosaicAndOriginal ? NSOnState : NSOffState)];
    [[_viewMenu itemWithTitle:@"View Mosaic Alone"]
	setState:(_viewMode == viewMosaicAlone ? NSOnState : NSOffState)];
    [[_viewMenu itemWithTitle:@"View Mosaic Editor"]
	setState:(_viewMode == viewMosaicEditor ? NSOnState : NSOffState)];

    [[_viewMenu itemWithTitle:@"Show Status Bar"]
	setTitle:(_statusBarShowing ? @"Hide Status Bar" : @"Show Status Bar")];
}


/*    [_mosaicImageDrawWindow autorelease];
    _mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
								  [_mosaicImage size].width,
								  [_mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];*/
- (void)setTileOutlines:(NSArray *)tileOutlines
{
	[tileOutlines retain];
	[_tileOutlines release];
	_tileOutlines = tileOutlines;
	[_mosaicView setTileOutlines:tileOutlines];
	[_totalTilesField setIntValue:[tileOutlines count]];
	
	_mosaicStarted = NO;
}


- (void)spawnImageSourceThreads
{
	NSEnumerator	*imageSourceEnumerator = [_imageSources objectEnumerator];
	ImageSource		*imageSource;
	
	while (imageSource = [imageSourceEnumerator nextObject])
		[NSThread detachNewThreadSelector:@selector(enumerateImageSourceInNewThread:) toTarget:self withObject:imageSource];
}


#pragma mark -
#pragma mark Thread entry points


- (void)createTileCollectionWithOutlines:(id)object
{
    if (_tileOutlines == nil || _originalImage == nil)
		return;
    else
		_createTilesThreadAlive = YES;

    int					index;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    NSWindow			*drawWindow;
    NSBezierPath		*combinedOutline = [NSBezierPath bezierPath];

		// create an offscreen window to draw into (it will have a single, empty view the size of the window)
    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000,
								  [_originalImage size].width, 
								  [_originalImage size].height)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];
    
    _tiles = [[NSMutableArray arrayWithCapacity:[_tileOutlines count]] retain];
	NSRect	*tileBounds = (NSRect *)malloc(sizeof(NSRect) * [_tileOutlines count]); 
    
	/* Loop through each tile outline and:
		1.  Create a Tile instance.
		2.  Copy out the rect of the original image that this tile covers.
		3.  Calculate an image mask that indicates which part of the copied rect is contained within the tile's outline.
	*/
	NSEnumerator	*tileOutlineEnumerator = [_tileOutlines objectEnumerator];
	NSBezierPath	*tileOutline = nil;
    while (!_documentIsClosing && (tileOutline = [tileOutlineEnumerator nextObject]))
	{
			// Create the tile and add it to the collection.
		Tile				*tile = [[[Tile alloc] initWithOutline:tileOutline fromDocument:self] autorelease];
		[_tiles addObject:tile];
		
			// Add this outline to the master path used to draw all of the tile outlines over the full image.
		[combinedOutline appendBezierPath:tileOutline];
		
			// Lock focus on our 'scratch' window.
		while (![[drawWindow contentView] lockFocusIfCanDraw])
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
		
			// Determine the bounds of the tile in the original image and in the scratch window.
		NSRect  origRect = NSMakeRect([tileOutline bounds].origin.x * [_originalImage size].width,
									  [tileOutline bounds].origin.y * [_originalImage size].height,
									  [tileOutline bounds].size.width * [_originalImage size].width,
									  [tileOutline bounds].size.height * [_originalImage size].height),
				destRect = (origRect.size.width > origRect.size.height) ?
							NSMakeRect(0, 0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE * origRect.size.height / origRect.size.width) : 
							NSMakeRect(0, 0, TILE_BITMAP_SIZE * origRect.size.width / origRect.size.height, TILE_BITMAP_SIZE);
		
			// Start with a black image to overwrite any previous scratch contents.
		[[NSColor blackColor] set];
		[[NSBezierPath bezierPathWithRect:destRect] fill];
		
			// Copy out the portion of the original image contained by the tile's outline.
		[_originalImage drawInRect:destRect fromRect:origRect operation:NSCompositeCopy fraction:1.0];
		NSBitmapImageRep	*tileRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect] autorelease];
		if (tileRep == nil) NSLog(@"Could not create tile bitmap");
        #if 0
            [[tileRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] 
                writeToFile:[NSString stringWithFormat:@"/tmp/MacOSaiX/%4d.tiff", index] atomically:NO];
        #endif
	
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
            NSBitmapImageRep	*maskRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect] autorelease];
			[tile setBitmapRep:tileRep withMask:maskRep];
			#if 0
				[[maskRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0] 
					writeToFile:[NSString stringWithFormat:@"/tmp/MacOSaiX/%4dMask.tiff", index++] atomically:NO];
			#endif
        [[NSGraphicsContext currentContext] restoreGraphicsState];
		
			// Release our lock on the GUI in case the main thread needs it.
		[[drawWindow contentView] unlockFocus];
		
		tileBounds[index] = [tileOutline bounds];
	}

    [[drawWindow contentView] unlockFocus];
    [drawWindow close];

#if 0
		// Calculate the neighboring tiles of each tile based on number of tiles away repeats are allowed.
		// For example if tiles are allowed to repeat past 1 neighbor than the direct neighbors of a tile
		// would be in its neighbor set.  If 2 then the direct neighbors and all of their direct neighbors
		// would be in the set.
		// TO DO: This currently only calculates the direct neighbors.
	NSEnumerator	*tileEnumerator = [_tileOutlines objectEnumerator];
	Tile			*tile = nil;
    while (!_documentIsClosing && (tile = [tileEnumerator nextObject]))
	{
		NSRect	zoomedTileBounds = NSZeroRect;
		
			// scale the rect up slightly so it overlaps with it's neighbors
		zoomedTileBounds.size = NSMakeSize([[tile outline] bounds].size.width * 1.01, [[tile outline] bounds].size.height * 1.01);
		zoomedTileBounds.origin.x += NSMidX([[tile outline] bounds]) - NSMidX(zoomedTileBounds);
		zoomedTileBounds.origin.y += NSMidY([[tile outline] bounds]) - NSMidY(zoomedTileBounds);
		
			// Loop through the other tiles and add as neighbors any that intersect.
			// TO DO: This currently just checks if the bounding boxes of the tiles intersect.
			//        For non-rectangular tiles this will not be accurate enough.
		NSEnumerator	*tileEnumerator2 = [_tileOutlines objectEnumerator];
		Tile			*tile2 = nil;
		while (!_documentIsClosing && (tile2 = [tileEnumerator2 nextObject]))
			if (tile2 != tile && NSIntersectsRect(zoomedTileBounds, [[tile2 outline] bounds]))
				[tile addNeighbor:tile2];
				
//		NSLog(@"Tile at index %d has %d neighbors.", index, [[tile neighbors] count]);
	}
#endif
	
    [(OriginalView *)_originalView setTileOutlines:combinedOutline];
    
		// ...
	[self spawnImageSourceThreads];

    [pool release];
    
    _createTilesThreadAlive = NO;
}


- (void)recalculateTileDisplayMatches:(id)object
{
/*
    NSAutoreleasePool	*pool, *pool2;
    float		overallMatch = 0.0;
    
    pool = [[NSAutoreleasePool alloc] init];
	NSAssert(pool, @"pool");
    
    _mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
									      [_mosaicImage size].width,
									      [_mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];
    while (!_documentIsClosing)
	{
		// allocate a second auto-release pool
		pool2 = [[NSAutoreleasePool alloc] init];
		while (pool2 == nil)
		{
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
			pool2 = [[NSAutoreleasePool alloc] init];
		}
		
		_integrateMatchesThreadAlive = YES;
		
		// wait until all tiles have at least one match before finding uniqueness
		// (otherwise, the orderedTiles order is the same as _tiles and the
		//  screen gets updated too orderly.)
		while ([[_tiles lastObject] matchCount] == 0 && !_documentIsClosing)
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	
		[_refindUniqueTilesLock lock];
		if (!_refindUniqueTiles)
		{
			// there hasn't been a better match since we last recalculated, wait a second and check again
			[_refindUniqueTilesLock unlock];
			_integrateMatchesThreadAlive = YES;
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		}
		else
		{
			NSArray		*orderedTiles;
			NSMutableArray	*updatedTiles = [NSMutableArray arrayWithCapacity:10],
					*imagesInUse = [NSMutableArray arrayWithCapacity:[_tiles count]];
			int			index;
			
			_integrateMatchesThreadAlive = YES;
			_refindUniqueTiles = NO;
			[_refindUniqueTilesLock unlock];
			
			overallMatch = 0.0;
			
			orderedTiles = [_tiles sortedArrayUsingSelector:@selector(compareBestMatchValue:)];
			for (index = 0; index < [orderedTiles count] && !_documentIsClosing; index++)
			{
			Tile		*tile = [orderedTiles objectAtIndex:index];
			TileMatch	*matches = [tile matches];
			int		matchCount = [tile matchCount];
			
			[tile lockMatches];
				if ([tile userChosenImageIndex] != -1)
				{
	//			overallMatch += (721 - sqrt( ??? ) / 721;
				[updatedTiles addObject:tile];
				[imagesInUse addObject:[_tileImages objectAtIndex:[tile userChosenImageIndex]]];
				}
				else
				{
				int	i;
				BOOL	foundMatch = NO;
				
				for (i = 0; i < matchCount && !_documentIsClosing; i++)
				{
					if (![imagesInUse containsObject:
						[_tileImages objectAtIndex:matches[i].tileImageIndex]])
					{
					foundMatch = YES;
					if ([tile bestUniqueMatch] != &matches[i])
					{
						[updatedTiles addObject:tile];
						[tile setBestUniqueMatchIndex:i];
					}
					[imagesInUse addObject:[_tileImages objectAtIndex:matches[i].tileImageIndex]];
					
					break;
					}
				}
				
				if (foundMatch == NO && [tile bestUniqueMatch] != nil && !_documentIsClosing)
				{	// this tile had a match but has no matching image now
					[tile setBestUniqueMatchIndex:-1];
					[updatedTiles addObject:tile];
				}
				
				if (foundMatch)
					overallMatch += (721 - sqrt([tile bestUniqueMatchValue])) / 721;
				}
				
				if ([updatedTiles count] >= 10 && !_documentIsClosing) // && !_paused)
				[self updateMosaicImage:updatedTiles];
			[tile unlockMatches];
			
			[_refindUniqueTilesLock lock];
				//if (_refindUniqueTiles) index = [orderedTiles count];
			[_refindUniqueTilesLock unlock];
			}
			if ([updatedTiles count] > 0 && !_documentIsClosing)	// && !_paused)
			[self updateMosaicImage:updatedTiles];
			_overallMatch = overallMatch * 100.0 / [_tiles count];
		}
		
		[pool2 release];
	}	// end of while (!_documentIsClosing)
    
    [_mosaicImageDrawWindow close];

    [pool release];

    _integrateMatchesThreadAlive = NO;
*/
}


- (void)enumerateImageSourceInNewThread:(ImageSource *)imageSource
{
	BOOL	sourceHasMoreImages = YES;

	NSLog(@"Enumerating image source %@\n", imageSource);
	
		// don't do anything if the source is dry
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	sourceHasMoreImages = [imageSource hasMoreImages];
	[pool release];
	
	while (!_documentIsClosing && sourceHasMoreImages)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		
		[imageSource waitWhilePaused];	// pause if the user says so
		
		id imageIdentifier = [imageSource nextImageIdentifier];
		if (imageIdentifier)
		{
			TileImage	*tileImage = [[[TileImage alloc] initWithIdentifier:imageIdentifier fromImageSource:imageSource] 
														autorelease];

			[_imageQueueLock lock];	// this will be locked if the queue is full
				while ([_imageQueue count] > MAX_IMAGE_URLS)
				{
					[_imageQueueLock unlock];
					[_imageQueueLock lock];
				}
				[_imageQueue addObject:tileImage];
			[_imageQueueLock unlock];

			if (!_calculateImageMatchesThreadAlive)
				[NSApplication detachDrawingThread:@selector(calculateImageMatches:) toTarget:self withObject:nil];
		}
		sourceHasMoreImages = [imageSource hasMoreImages];
		[pool release];
	}
}


- (void)calculateImageMatches:(id)dummy
{
		// This method is called in a new thread whenever a non-empty image queue is discovered.
		// It pulls images from the queue and matches them against each tile.  Once the queue
		// is empty the method will end and the thread is terminated.
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];

        // Make sure only one copy of this thread runs at any time.
	[_calculateImageMatchesThreadLock lock];
		if (_calculateImageMatchesThreadAlive)
		{
                // Another copy is running, just exit.
			[pool release];
			return;
		}
		_calculateImageMatchesThreadAlive = YES;
	[_calculateImageMatchesThreadLock unlock];

    NSImage				*scratchImage = [[[NSImage alloc] initWithSize:NSMakeSize(1024, 1024)] autorelease];
	
	NSLog(@"Calculating image matches\n");

	[_imageQueueLock lock];
    while (!_documentIsClosing && [_imageQueue count] > 0)
	{
			// As long as the image source threads are feeding images into the queue this loop
			// will continue running so create a pool just for this pass through the loop.
		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		TileImage			*tileImage = nil;
		NSImage				*pixletImage = nil;
		NSMutableArray		*cachedReps = nil;
		int					index;
		BOOL				queueLocked = NO;
		
			// pull the next image from the queue
		tileImage = [[[_imageQueue objectAtIndex:0] retain] autorelease];
		[_imageQueue removeObjectAtIndex:0];
		
			// let the image source threads add more images if the queue is not full
		if ([_imageQueue count] < MAX_IMAGE_URLS)
			[_imageQueueLock unlock];
		else
			queueLocked = YES;
		
			// if the image loaded and it's not miniscule, match it against the tiles
		if ((pixletImage = [tileImage image]))// &&
//			[pixletImage size].width >= TILE_BITMAP_SIZE &&
//			[pixletImage size].height >= TILE_BITMAP_SIZE)
		{
			cachedReps = [NSMutableArray arrayWithCapacity:0];
//			tileImageIndex = [self addTileImage:tileImage];
			[tileImage imageIsInUse];
			
//			NSLog(@"matching against %@\n", [tileImage imageIdentifier]);

				// loop through the tiles and compute the pixlet's match
			for (index = 0; index < [_tiles count] && !_documentIsClosing; index++)
			{
				Tile	*tile = nil;
				float	scale;
				NSRect	subRect;
				int	cachedRepIndex;
		
				tile = [_tiles objectAtIndex:index];
				
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
				{
						// no bitmap at the correct size was found, try to create a new one
					NSBitmapImageRep	*rep = nil;
					
					NS_DURING
						[scratchImage lockFocus];
							[pixletImage drawInRect:subRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
							rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
							if (rep)
								[cachedReps addObject:[rep autorelease]];
							else
								cachedRepIndex = -1;
						[scratchImage unlockFocus];
					NS_HANDLER
						// TBD: how to handle this?
						NSLog(@"Could not lock focus on scratch image, what should I do?");
					NS_ENDHANDLER
				}
		
					// If the tile reports that the image matches better than its previous worst match
					// then add the tile and its neighbors to the set of tiles potentially needing redraw.
				if (cachedRepIndex != -1 && [tile matchAgainstImageRep:[cachedReps objectAtIndex:cachedRepIndex]
													 fromTileImage:tileImage forDocument:self])
				{
					[_refreshTilesSetLock lock];
						[_refreshTilesSet addObject:tile];
						[_refreshTilesSet addObjectsFromArray:[tile neighbors]];
					[_refreshTilesSetLock unlock];

					if (!_calculateDisplayedImagesThreadAlive)
						[NSApplication detachDrawingThread:@selector(calculateDisplayedImages:) toTarget:self withObject:nil];
				}
			}
				// release the tileImage if no tile ended up using it
			[tileImage imageIsNotInUse];
			_imagesMatched++;
		}
		else
			NSLog(@"Could not load tile image with identifier %@", [tileImage imageIdentifier]);
		
		if (!queueLocked) [_imageQueueLock lock];

		[pool2 release];
	}
	[_imageQueueLock unlock];

	[_calculateImageMatchesThreadLock lock];
		_calculateImageMatchesThreadAlive = NO;
	[_calculateImageMatchesThreadLock unlock];

		// clean up and shutdown this thread
    [pool release];
}


- (void)calculateDisplayedImages:(id)dummy
{
		// This method is called in a new thread whenever a non-empty image queue is discovered.
		// It pulls images from the queue and matches them against each tile.  Once the queue
		// is empty the method will end and the thread is terminated.

    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];

        // make sure we only ever have a single instance of this thread running
	[_calculateDisplayedImagesThreadLock lock];
		if (_calculateDisplayedImagesThreadAlive)
		{
                // another copy is already running, just return
			[_calculateDisplayedImagesThreadLock unlock];
			[pool release];
			return;
		}
		_calculateDisplayedImagesThreadAlive = YES;
	[_calculateDisplayedImagesThreadLock unlock];

//	NSLog(@"Calculating displayed images\n");

    BOOL	tilesAddedToRefreshSet = NO;
    
		// set up a transform so we can scale the tiles to the mosaic's size (tiles are defined on a unit square)
	NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform translateXBy:0.5 yBy:0.5];	// line up with pixel boundaries
	[transform scaleXBy:[_mosaicImage size].width yBy:[_mosaicImage size].height];

        // Make a local copy of the set of tiles to refresh and then clear 
        // the main set so new tiles can be added while we work.
	[_refreshTilesSetLock lock];
        NSArray	*tilesToRefresh = [_refreshTilesSet allObjects];
        [_refreshTilesSet removeAllObjects];
    [_refreshTilesSetLock unlock];
    
        // Now loop through each tile in the set and re-calculate which image it should use
    NSEnumerator	*tileEnumerator = [tilesToRefresh objectEnumerator];
    Tile			*tileToRefresh = nil;
    while (!_documentIsClosing && (tileToRefresh = [tileEnumerator nextObject]))
	{
        TileImage	*previousDiplayedImage = [tileToRefresh displayedTileImage];
        
        [tileToRefresh calculateBestMatch];
        
        if ([tileToRefresh displayedTileImage] != previousDiplayedImage)
        {
                // The image to display for this tile changed so update the mosaic image
                // and add the tile's neighbors to the set of tiles to refresh in case 
                // they can use the image we just stopped using.
            
            tilesAddedToRefreshSet = YES;
            
            [_refreshTilesSetLock lock];
                [_refreshTilesSet addObjectsFromArray:[tileToRefresh neighbors]];
            [_refreshTilesSetLock unlock];
            
            NSImage	*matchImage = [[tileToRefresh displayedTileImage] image];
            if (!matchImage)
                NSLog(@"Could not load image\t%@", [[tileToRefresh displayedTileImage] imageIdentifier]);
            else
            {
                    // Draw the tile's new image in the mosaic
                NSBezierPath	*clipPath = [transform transformBezierPath:[tileToRefresh outline]];
                NSRect			drawRect;
    
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
                    // ...
                [_mosaicImageLock lock];
                    NS_DURING
                        [_mosaicImage lockFocus];
                            [clipPath setClip];
                            [matchImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                        [_mosaicImage unlockFocus];
                    NS_HANDLER
                        NSLog(@"Could not lock focus on mosaic image");
                    NS_ENDHANDLER
                    _mosaicImageUpdated = YES;
                [_mosaicImageLock unlock];
            }
        }
	}

	[_calculateDisplayedImagesThreadLock lock];
	    _calculateDisplayedImagesThreadAlive = NO;
	[_calculateDisplayedImagesThreadLock unlock];

        // Launch another copy of ourself if any other tiles need refreshing
    if (tilesAddedToRefreshSet)
        [NSApplication detachDrawingThread:@selector(calculateDisplayedImages:) toTarget:self withObject:nil];

		// clean up and shutdown this thread
    [pool release];
}


#pragma mark -


- (void)updateMosaicImage:(NSMutableArray *)updatedTiles
{
/*
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    NSAffineTransform	*transform;
    NSBitmapImageRep	*newRep;
    
    if (![[_mosaicImageDrawWindow contentView] lockFocusIfCanDraw])
	NSLog(@"Could not lock focus for mosaic image update.");
    else
    {
	[[NSColor whiteColor] set];
	[[NSBezierPath bezierPathWithRect:[[_mosaicImageDrawWindow contentView] bounds]] fill];
	// start with the current image
	[_mosaicImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
	transform = [NSAffineTransform transform];
	[transform scaleXBy:[_mosaicImage size].width yBy:[_mosaicImage size].height];
	while (!_documentIsClosing && [updatedTiles count] > 0)
	{
	    Tile		*tile = [updatedTiles objectAtIndex:0];
	    NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
	    NSImage		*matchImage;
	    NSRect		drawRect;
	    
	    if ([tile userChosenImageIndex] != -1)
	    {
		matchImage = [[_tileImages objectAtIndex:[tile userChosenImageIndex]] image];
		if (matchImage == nil)
		    NSLog(@"Could not load image\t%@",
				[[_tileImages objectAtIndex:[tile userChosenImageIndex]] imageIdentifier]);
	    }
	    else
	    {
		if ([tile bestUniqueMatch] != nil)
		{
		    matchImage = [[_tileImages objectAtIndex:[tile bestUniqueMatch]->tileImageIndex] image];
		    if (matchImage == nil)
			NSLog(@"Could not load image\t%@",
			   [[_tileImages objectAtIndex:[tile bestUniqueMatch]->tileImageIndex] imageIdentifier]);
		}
		else
		    matchImage = [NSImage imageNamed:@"White"];	// this image has no match
	    }
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
	    [clipPath setClip];
	    [matchImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
	    [updatedTiles removeObjectAtIndex:0];
	}
	
	// now copy the new image into the mosaic image
	[_mosaicImageLock lock];
	    newRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
						    [[_mosaicImageDrawWindow contentView] bounds]];
	    [_mosaicImage autorelease];
	    _mosaicImage = [[NSImage alloc] initWithSize:[_mosaicImage size]];
	    [_mosaicImage addRepresentation:newRep];
	    [newRep release];
	    _mosaicImageUpdated = YES;
	[_mosaicImageLock unlock];
	[[_mosaicImageDrawWindow contentView] unlockFocus];
    }
    
    [pool release];
*/
}


#pragma mark -
#pragma mark Tile setup methods

- (void)setTilesSetupPlugIn:(id)sender
{
	NSString		*selectedPlugIn = [_tilesSetupPopUpButton titleOfSelectedItem];
	NSEnumerator	*enumerator = [[[NSApp delegate] tilesSetupControllerClasses] objectEnumerator];
	Class			tilesSetupControllerClass;
	
	while (tilesSetupControllerClass = [enumerator nextObject])
		if ([selectedPlugIn isEqualToString:[tilesSetupControllerClass name]])
		{
			if (_tilesSetupController)
			{
					// remove the tile setup that was have been set before
				[_tilesSetupView setContentView:nil];
				[_tilesSetupController release];
			}
			
				// create an instance of the class for this document
			_tilesSetupController = [[tilesSetupControllerClass alloc] init];
			
				// let the plug-in know how to message back to us
			[_tilesSetupController setDocument:self];
			
				// Display the plug-in's view
			[_tilesSetupView setContentView:[_tilesSetupController setupView]];
			
			return;
		}
}


#pragma mark -
#pragma mark Image Sources methods

- (void)setImageSourcesPlugIn:(id)sender
{
		// Display the view chosen in the menu
	[_imageSourcesTabView selectTabViewItemAtIndex:[_imageSourcesPopUpButton indexOfSelectedItem]];
	
		// If the user just chose to add an image source then tell the appropriate image controller
	if ([_imageSourcesPopUpButton indexOfSelectedItem] > 0)
		[[[_imageSourcesPopUpButton selectedItem] representedObject] editImageSource:nil];
}


- (void)showCurrentImageSources
{
	[_imageSourcesPopUpButton selectItemAtIndex:0];
	[self setImageSourcesPlugIn:self];
}


- (void)addImageSource:(ImageSource *)imageSource
{
		// if it's a new image source then add it to the array (paused if we haven't started yet)
	if ([_imageSources indexOfObjectIdenticalTo:imageSource] == NSNotFound)
	{
		if (!_mosaicStarted)
			[imageSource pause];
		[_imageSources addObject:imageSource];
	}
	[_imageSourcesTable reloadData];
}


#pragma mark -
#pragma mark Editor methods

- (void)selectTileAtPoint:(NSPoint)thePoint
{
    int	i;
    
    if ([_mosaicView viewMode] != _viewHighlightedTile) return;
    
    thePoint.x = thePoint.x / [_mosaicView frame].size.width;
    thePoint.y = thePoint.y / [_mosaicView frame].size.height;
    
        // TBD: this isn't terribly efficient...
    for (i = 0; i < [_tiles count]; i++)
        if ([[[_tiles objectAtIndex:i] outline] containsPoint:thePoint])
        {
            [_editorLabel setStringValue:@"Image to use for selected tile:"];
            [_editorUseCustomImage setEnabled:YES];
            [_editorUseBestUniqueMatch setEnabled:YES];
            _selectedTile = [_tiles objectAtIndex:i];
            
            [_mosaicView highlightTile:_selectedTile];
            [_editorTable scrollRowToVisible:0];
            [self updateEditor];
            
            return;
        }
}


- (void)animateSelectedTile:(id)timer
{
    if (_selectedTile != nil && !_documentIsClosing)
        [_mosaicView animateHighlight];
}


- (void)updateEditor
{
    [_selectedTileImages release];
    
    if (_selectedTile == nil)
    {
        [_editorUseCustomImage setState:NSOffState];
        [_editorUseBestUniqueMatch setState:NSOffState];
        [_editorUserChosenImage setImage:nil];
        [_editorChooseImage setEnabled:NO];
        [_editorUseSelectedImage setEnabled:NO];
        _selectedTileImages = [[NSMutableArray arrayWithCapacity:0] retain];
    }
    else
    {
        int	i;
        
        if ([_selectedTile userChosenTileImage])
        {
            [_editorUseCustomImage setState:NSOnState];
            [_editorUseBestUniqueMatch setState:NSOffState];
            [_editorUserChosenImage setImage:[[_selectedTile userChosenTileImage] image]];
        }
        else
        {
            [_editorUseCustomImage setState:NSOffState];
            [_editorUseBestUniqueMatch setState:NSOnState];
            [_editorUserChosenImage setImage:nil];
            
            NSImage	*image = [[[NSImage alloc] initWithSize:[[_selectedTile bitmapRep] size]] autorelease];
            [image addRepresentation:[_selectedTile bitmapRep]];
            [_editorUserChosenImage setImage:image];
        }
    
        [_editorChooseImage setEnabled:YES];
        [_editorUseSelectedImage setEnabled:YES];
        
        _selectedTileImages = [[NSMutableArray arrayWithCapacity:[_selectedTile matchCount]] retain];
        for (i = 0; i < [_selectedTile matchCount]; i++)
            [_selectedTileImages addObject:[NSNull null]];
    }
    
    [_editorTable reloadData];
}


- (BOOL)showTileMatchInEditor:(TileMatch *)tileMatch selecting:(BOOL)selecting
{
    int	i;
    
    if (_selectedTile == nil) return NO;
    
    for (i = 0; i < [_selectedTile matchCount]; i++)
        if (&([_selectedTile matches][i]) == tileMatch)
        {
            if (selecting)
                [_editorTable selectRow:i byExtendingSelection:NO];
            [_editorTable scrollRowToVisible:i];
            return YES;
        }
    
    return NO;
}


- (NSImage *)createEditorImage:(int)rowIndex
{
    NSImage		*image;
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSSize		tileSize = [[_selectedTile outline] bounds].size;
    float		scale;
    NSPoint		origin;
    NSBezierPath	*bezierPath = [NSBezierPath bezierPath];
    
    [_selectedTile lockMatches];
        image = [[_selectedTile matches][rowIndex].tileImage image];
    [_selectedTile unlockMatches];
    if (image == nil)
        return [NSImage imageNamed:@"Blank"];
	
    image = [[image copy] autorelease];
    
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
    
	NS_DURING
		[image lockFocus];
	NS_HANDLER
		NSLog(@"Could not lock focus on editor image");
	NS_ENDHANDLER
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
//	if ([[_selectedTile matches] objectAtIndex:rowIndex] == [_selectedTile displayMatch])
//	{
//	    NSBezierPath	*badgePath = [NSBezierPath bezierPathWithOvalInRect:
//						NSMakeRect([image size].width - 12, 2, 10, 10)];
//						
//	    [[NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:1.0] set];
//	    [badgePath fill];
//	    [[NSColor colorWithCalibratedRed:0.5 green:0 blue:0 alpha:1.0] set];
//	    [badgePath stroke];
//	}
    [image unlockFocus];
    [_selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
    return image;
}


- (void)useCustomImage:(id)sender
{
/* TBD
    if ([_selectedTile bestUniqueMatch] != nil)
	[_selectedTile setUserChosenImageIndex:[_selectedTile bestUniqueMatch]->tileImageIndex];
    else
	[_selectedTile setUserChosenImageIndex:[_selectedTile bestMatch]->tileImageIndex];
    [_selectedTile setBestUniqueMatchIndex:-1];
	
    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];
*/
}


- (void)allowUserToChooseImage:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:[NSImage imageFileTypes]
		    modalForWindow:_mainWindow
		     modalDelegate:self
		    didEndSelector:@selector(allowUserToChooseImageOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    TileImage	*tileImage;
    
    if (returnCode != NSOKButton) return;

    tileImage = [[[TileImage alloc] initWithIdentifier:[[sheet URLs] objectAtIndex:0] fromImageSource:_manualImageSource] autorelease];
//TBD    [_selectedTile setUserChosenImageIndex:[self addTileImage:tileImage]];
//TBD    [_selectedTile setBestUniqueMatchIndex:-1];
    
    [_refindUniqueTilesLock lock];
//TBD	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];

    [self updateChangeCount:NSChangeDone];
}


- (void)useBestUniqueMatch:(id)sender
{
/*	TBD
    [_selectedTile setUserChosenImageIndex:-1];
    
    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];
    
    [self updateChangeCount:NSChangeDone];
*/
}


- (void)useSelectedImage:(id)sender
{
/* TBD
    long	index = [_selectedTile matches][[_editorTable selectedRow]].tileImageIndex;
    
    [_selectedTile setUserChosenImageIndex:index];
    [_selectedTile setBestUniqueMatchIndex:-1];

    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];

    [self updateChangeCount:NSChangeDone];
*/
}


#pragma mark -
#pragma mark View methods

- (void)setViewCompareMode:(id)sender;
{
    [self setViewMode:viewMosaicAndOriginal];
}


- (void)setViewTileSetupMode:(id)sender
{
    [self setViewMode:viewMosaicAndTilesSetup];
}


- (void)setViewRegionsMode:(id)sender
{
    [self setViewMode:viewMosaicAndRegions];
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
    if (mode == _viewMode) return;
    
    _viewMode = mode;
	[_mosaicView highlightTile:nil];
	switch (mode)
	{
		case viewMosaicAndOriginal:
			[_mosaicView setViewMode:_viewMosaic];
			[_utilitiesTabView selectTabViewItemWithIdentifier:@"Original Image"];
			[_utilitiesDrawer open];
			break;
		case viewMosaicAndTilesSetup:
			[_mosaicView setViewMode:_viewTilesOutline];
			[_utilitiesTabView selectTabViewItemWithIdentifier:@"Tiles Setup"];
			[_utilitiesDrawer open];
			break;
		case viewMosaicAndRegions:
			[_mosaicView setViewMode:_viewImageRegions];
			[_utilitiesTabView selectTabViewItemWithIdentifier:@"Image Regions"];
			[_utilitiesDrawer open];
			break;
		case viewMosaicEditor:
			[_mosaicView setViewMode:_viewHighlightedTile];
			[_mosaicView highlightTile:_selectedTile];
			[self updateEditor];
			[_editorTable scrollRowToVisible:0];
			[_editorTable reloadData];
			[_utilitiesTabView selectTabViewItemWithIdentifier:@"Tile Editor"];
			[_utilitiesDrawer open];
			break;
		case viewMosaicAlone:
			[_mosaicView setViewMode:_viewMosaic];
			[_utilitiesDrawer close];
			break;
    }
    [self synchronizeMenus];
}


- (void)setZoom:(id)sender
{
    float	zoom = 0.0;
    
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
		if ([[sender title] isEqualToString:@"Minimum"]) zoom = 0.0;
		if ([[sender title] isEqualToString:@"Medium"]) zoom = 0.5;
		if ([[sender title] isEqualToString:@"Maximum"]) zoom = 1.0;
    }
    else zoom = [_zoomSlider floatValue];
    
    // set the zoom...
    _zoom = zoom;
    [_zoomSlider setFloatValue:zoom];
    
    if (_mosaicImage != nil)
    {
		NSRect	bounds, frame;
		
		frame = NSMakeRect(0, 0,
				[[_mosaicScrollView contentView] frame].size.width + ([_mosaicImage size].width - 
				[[_mosaicScrollView contentView] frame].size.width) * zoom,
				[[_mosaicScrollView contentView] frame].size.height + ([_mosaicImage size].height - 
				[[_mosaicScrollView contentView] frame].size.height) * zoom);
		bounds = NSMakeRect(NSMidX([[_mosaicScrollView contentView] bounds]) * frame.size.width / 
						[_mosaicView frame].size.width,
					NSMidY([[_mosaicScrollView contentView] bounds]) * frame.size.height / 
						[_mosaicView frame].size.height,
					frame.size.width -
						(frame.size.width - [[_mosaicScrollView contentView] frame].size.width) * zoom,
					frame.size.height -
						(frame.size.height - [[_mosaicScrollView contentView] frame].size.height) * zoom);
		bounds.origin.x = MIN(MAX(0, bounds.origin.x - bounds.size.width / 2.0),
							  frame.size.width - bounds.size.width);
		bounds.origin.y = MIN(MAX(0, bounds.origin.y - bounds.size.height / 2.0),
							  frame.size.height - bounds.size.height);
		[_mosaicView setFrame:frame];
		[[_mosaicScrollView contentView] setBounds:bounds];
		[_mosaicScrollView setNeedsDisplay:YES];
    }
    [_originalView setNeedsDisplay:YES];
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
    
    contentOrigin.x *= [_mosaicView frame].size.width;
    contentOrigin.x -= [[_mosaicScrollView contentView] bounds].size.width / 2;
    if (contentOrigin.x < 0) contentOrigin.x = 0;
    if (contentOrigin.x + [[_mosaicScrollView contentView] bounds].size.width >
		[_mosaicView frame].size.width)
		contentOrigin.x = [_mosaicView frame].size.width - 
				[[_mosaicScrollView contentView] bounds].size.width;

    contentOrigin.y *= [_mosaicView frame].size.height;
    contentOrigin.y -= [[_mosaicScrollView contentView] bounds].size.height / 2;
    if (contentOrigin.y < 0) contentOrigin.y = 0;
    if (contentOrigin.y + [[_mosaicScrollView contentView] bounds].size.height >
		[_mosaicView frame].size.height)
	contentOrigin.y = [_mosaicView frame].size.height - 
			  [[_mosaicScrollView contentView] bounds].size.height;

    [[_mosaicScrollView contentView] scrollToPoint:contentOrigin];
    [_mosaicScrollView reflectScrolledClipView:[_mosaicScrollView contentView]];
}


- (void)mosaicViewDidScroll:(NSNotification *)notification
{
    NSRect	orig, content,doc;
    
    if ([notification object] != _mosaicScrollView) return;
    
    orig = [_originalView bounds];
    content = [[_mosaicScrollView contentView] bounds];
    doc = [_mosaicView frame];
    [_originalView setFocusRect:NSMakeRect(content.origin.x * orig.size.width / doc.size.width,
					  content.origin.y * orig.size.height / doc.size.height,
					  content.size.width * orig.size.width / doc.size.width,
					  content.size.height * orig.size.height / doc.size.height)];
    [_originalView setNeedsDisplay:YES];
}


- (void)toggleStatusBar:(id)sender
{
    NSRect	newFrame = [_mainWindow frame];
    int		i;
    
    if (_statusBarShowing)
    {
		_statusBarShowing = NO;
		_removedSubviews = [[_statusBarView subviews] copy];
		for (i = 0; i < [_removedSubviews count]; i++)
			[[_removedSubviews objectAtIndex:i] removeFromSuperview];
		[_statusBarView retain];
		[_statusBarView removeFromSuperview];
		newFrame.origin.y += [_statusBarView frame].size.height;
		newFrame.size.height -= [_statusBarView frame].size.height;
		newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
		[_mainWindow setFrame:newFrame display:YES animate:YES];
		[[_viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
    }
    else
    {
		_statusBarShowing = YES;
		newFrame.origin.y -= [_statusBarView frame].size.height;
		newFrame.size.height += [_statusBarView frame].size.height;
		newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
		[_mainWindow setFrame:newFrame display:YES animate:YES];
	
		[_statusBarView setFrame:NSMakeRect(0, [[_mosaicScrollView superview] frame].size.height - [_statusBarView frame].size.height, [[_mosaicScrollView superview] frame].size.width, [_statusBarView frame].size.height)];
		[[_mosaicScrollView superview] addSubview:_statusBarView];
		[_statusBarView release];
		for (i = 0; i < [_removedSubviews count]; i++)
		{
			[[_removedSubviews objectAtIndex:i] setFrameSize:NSMakeSize([_statusBarView frame].size.width,[[_removedSubviews objectAtIndex:i] frame].size.height)];
			[_statusBarView addSubview:[_removedSubviews objectAtIndex:i]];
		}
		[_removedSubviews release]; _removedSubviews = nil;
	
		[[_viewMenu itemWithTitle:@"Show Status Bar"] setTitle:@"Hide Status Bar"];
    }
}


- (void)setShowOutlines:(id)sender
{
    [_originalView setDisplayTileOutlines:([_showOutlinesSwitch state] == NSOnState)];
}


#pragma mark -
#pragma mark Utility methods


- (void)toggleImageSourcesDrawer:(id)sender
{
    [_utilitiesDrawer toggle:(id)sender];
    if ([_utilitiesDrawer state] == NSDrawerClosedState)
		[[_viewMenu itemWithTitle:@"Show Image Sources"] setTitle:@"Hide Image Sources"];
    else
		[[_viewMenu itemWithTitle:@"Hide Image Sources"] setTitle:@"Show Image Sources"];
}


- (void)togglePause:(id)sender
{
	NSEnumerator	*imageSourceEnumerator = [_imageSources objectEnumerator];
	ImageSource		*imageSource;

	if (_paused)
	{
		if (!_mosaicStarted) [self startMosaic];	// spawn the image source threads
		[_pauseToolbarItem setLabel:@"Pause"];
		[_pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[[_fileMenu itemWithTitle:@"Resume Matching"] setTitle:@"Pause Matching"];
		while (imageSource = [imageSourceEnumerator nextObject])
			[imageSource resume];
		_paused = NO;
	}
	else
	{
		[_pauseToolbarItem setLabel:@"Resume"];
		[_pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		[[_fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
		while (imageSource = [imageSourceEnumerator nextObject])
			[imageSource pause];
		_paused = YES;
	}
}


#pragma mark -
#pragma mark Export image methods

- (void)beginExportImage:(id)sender
{
    _savePanel = [NSSavePanel savePanel];

/*
    if ([[_tiles lastObject] matchCount] < [_tiles count])
    {
	NSBeginAlertSheet(@"Export Image", nil, nil, nil, _mainWindow, self, nil, nil, nil,
	    @"Not enough images have been found.");
	return;
    }
*/
	
    if (!_paused) [self togglePause:self];
    
    if ([_exportWidth intValue] == 0)
    {
        [_exportWidth setIntValue:[_originalImage size].width * 4];
        [_exportHeight setIntValue:[_originalImage size].height * 4];
    }
    [_savePanel setAccessoryView:_exportPanelAccessoryView];
    
    // ask the user where to save the image
    [_savePanel beginSheetForDirectory:NSHomeDirectory()
				 file:@"Mosaic.jpg"
		       modalForWindow:_mainWindow
			modalDelegate:self
		       didEndSelector:@selector(exportImageSavePanelDidEnd:returnCode:contextInfo:)
			  contextInfo:_savePanel];
}


- (void)setJPEGExport:(id)sender
{
    _exportFormat = NSJPEGFileType;
    [_savePanel setRequiredFileType:@"jpg"];
}


- (void)setTIFFExport:(id)sender;
{
    _exportFormat = NSTIFFFileType;
    [_savePanel setRequiredFileType:@"tiff"];
}


- (void)setExportWidthFromHeight:(id)sender
{
    [_exportWidth setIntValue:[_exportHeight intValue] / [_originalImage size].height * 
			      [_originalImage size].width + 0.5];
}


- (void)setExportHeightFromWidth:(id)sender
{
    [_exportHeight setIntValue:[_exportWidth intValue] / [_originalImage size].width * 
			       [_originalImage size].height + 0.5];
}


- (void)exportImageSavePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)savePanel
{
    _savePanel = nil;
    
    if (returnCode != NSOKButton) return;
    
    [sheet orderOut:nil];
    
    [_exportProgressLabel setStringValue:@"Waiting to find all unique tiles..."];
    [_exportProgressIndicator setIndeterminate:YES];
    [_exportProgressIndicator startAnimation:self];
    
    [NSApp beginSheet:_exportProgressPanel
       modalForWindow:_mainWindow
	modalDelegate:self
       didEndSelector:nil
	  contextInfo:nil];
    
    [NSApplication detachDrawingThread:@selector(exportImage:) toTarget:self 
	withObject:[(NSSavePanel *)savePanel filename]];
}


- (void)exportImage:(id)exportFilename
{
    int			i;
    NSAffineTransform	*transform;
    NSRect		drawRect;
    NSImage		*exportImage;
    NSBitmapImageRep	*exportRep,
                    *pixletImage;
    NSData		*bitmapData;
    NSAutoreleasePool	*pool;
    BOOL		wasPaused = _paused;
    
    _exportImageThreadAlive = YES;
    
    pool = [[NSAutoreleasePool alloc] init];
	NSAssert(pool, @"Could not allocate pool");

//    while (_calculateDisplayedImagesThreadAlive)
//		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    [_exportProgressLabel setStringValue:@"Exporting mosaic image..."];
    [_exportProgressIndicator stopAnimation:self];
    [_exportProgressIndicator setMaxValue:[_tiles count]];
    [_exportProgressIndicator setIndeterminate:NO];
    [_exportProgressPanel displayIfNeeded];
    
    exportImage = [[NSImage alloc] initWithSize:NSMakeSize([_exportWidth intValue], [_exportHeight intValue])];
//    exportImage = [[NSImage alloc] initWithSize:NSMakeSize(2400, 2400 * [_originalImage size].height / 
//								 [_originalImage size].width)];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		NSLog(@"Could not lock focus on export image");
	NS_ENDHANDLER
    transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
    for (i = 0; i < [_tiles count]; i++)
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
        Tile				*tile = [_tiles objectAtIndex:i];
//        TileImage			*tileImage = [_tileImages objectAtIndex:([tile userChosenImageIndex] == -1) ?
//                                        [tile bestUniqueMatch]->tileImageIndex :
//                                        [tile userChosenImageIndex]];
        NSBezierPath		*clipPath = [transform transformBezierPath:[tile outline]];
        int					imageFetchCount = 0;
        
        _exportProgressTileCount = i;
        [NSGraphicsContext saveGraphicsState];
        [clipPath addClip];
        
//        do
//            pixletImage = [[tileImage imageSource] imageForIdentifier:[tileImage imageIdentifier]];
//        while (pixletImage == nil && imageFetchCount++ < 4);
        
        pixletImage = [tile bitmapRep];
        
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
//        [pixletImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [pixletImage drawInRect:drawRect];
        [NSGraphicsContext restoreGraphicsState];
        [pool2 release];
    }
    exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [exportImage size].width, 
									     [exportImage size].height)];
    [exportImage unlockFocus];

    if (_exportFormat == NSJPEGFileType)
        bitmapData = [exportRep representationUsingType:NSJPEGFileType properties:nil];
    else
        bitmapData = [exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
    [bitmapData writeToFile:exportFilename atomically:YES];
    
    [NSApp endSheet:_exportProgressPanel];
    [_exportProgressPanel orderOut:nil];

    [pool release];
    [exportRep release];
    [exportImage release];

    _paused = wasPaused;
    _exportImageThreadAlive = NO;
    
    [NSThread exit];
}


// window delegate methods

#pragma mark -
#pragma mark Window delegate methods

- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
    [self synchronizeMenus];
}


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    float	aspectRatio = [_mosaicImage size].width / [_mosaicImage size].height,
			windowTop = [sender frame].origin.y + [sender frame].size.height,
			minHeight = 155;
    NSSize	diff;
    NSRect	screenFrame = [[sender screen] frame];
    
    proposedFrameSize.width = MIN(MAX(proposedFrameSize.width, 132),
								  screenFrame.size.width - [sender frame].origin.x);
    diff.width = [sender frame].size.width - [[sender contentView] frame].size.width;
    diff.height = [sender frame].size.height - [[sender contentView] frame].size.height;
    proposedFrameSize.width -= diff.width;
    windowTop -= diff.height + 16 + (_statusBarShowing ? [_statusBarView frame].size.height : 0);
    
    // Calculate the height of the window based on the proposed width
    //   and preserve the aspect ratio of the mosaic image.
    // If the height is too big for the screen, lower the width.
	proposedFrameSize.height = (proposedFrameSize.width - 16) / aspectRatio;
	if (proposedFrameSize.height > windowTop || proposedFrameSize.height < minHeight)
	{
	    proposedFrameSize.height = (proposedFrameSize.height < minHeight) ? minHeight : windowTop;
	    proposedFrameSize.width = proposedFrameSize.height * aspectRatio + 16;
	}
    
    // add height of scroll bar and status bar (if showing)
    proposedFrameSize.height += 16 + (_statusBarShowing ? [_statusBarView frame].size.height : 0);
    
    [self setZoom:self];
    
    proposedFrameSize.height += diff.height;
    proposedFrameSize.width += diff.width;

    return proposedFrameSize;
}


- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
    defaultFrame.size = [self windowWillResize:sender toSize:defaultFrame.size];

    [_mosaicScrollView setNeedsDisplay:YES];
    
    return defaultFrame;
}


- (void)windowDidResize:(NSNotification *)notification
{
		// this method is called during animated window resizing, not windowWillResize
    [self setZoom:self];
    [_utilitiesTabView setNeedsDisplay:YES];
}



// Toolbar delegate methods

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem	*toolbarItem = [_toolbarItems objectForKey:itemIdentifier];

    if (toolbarItem) return toolbarItem;
    
    toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    if ([itemIdentifier isEqualToString:@"Zoom"])
    {
		[toolbarItem setMinSize:NSMakeSize(64, 14)];
		[toolbarItem setMaxSize:NSMakeSize(64, 14)];
		[toolbarItem setLabel:@"Zoom"];
		[toolbarItem setPaletteLabel:@"Zoom"];
		[toolbarItem setView:_zoomToolbarView];
		[toolbarItem setMenuFormRepresentation:_zoomToolbarMenuItem];
    }

    if ([itemIdentifier isEqualToString:@"ExportImage"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"ExportImage"]];
		[toolbarItem setLabel:@"Export Image"];
		[toolbarItem setPaletteLabel:@"Export Image"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(beginExportImage:)];
		[toolbarItem setToolTip:@"Export an image of the mosaic"];
    }

    if ([itemIdentifier isEqualToString:@"UtilityDrawer"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"UtilityDrawer"]];
		[toolbarItem setLabel:@"Utility Drawer"];
		[toolbarItem setPaletteLabel:@"Utility Drawer"];
		[toolbarItem setTarget:_utilitiesDrawer];
		[toolbarItem setAction:@selector(toggle:)];
		[toolbarItem setToolTip:@"Show/hide utility drawer"];
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
		return ([_tileOutlines count] > 0 && [_imageSources count] > 0);
    else
		return YES;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Zoom", @"ExportImage", @"Pause", @"UtilityDrawer", 
				     NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSpaceItemIdentifier,
				     NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier,
				     nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Zoom", @"ExportImage", @"Pause", 
									 NSToolbarFlexibleSpaceItemIdentifier, @"UtilityDrawer", nil];
}


#pragma mark -
#pragma mark Tab view delegate methods

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if (tabView == _utilitiesTabView)
	{
		int selectedIndex =  [tabView indexOfTabViewItem:tabViewItem];
		
		if (selectedIndex == [_utilitiesTabView indexOfTabViewItemWithIdentifier:@"Tiles Setup"])
			[_mosaicView setViewMode:_viewTilesOutline];
		if (selectedIndex == [_utilitiesTabView indexOfTabViewItemWithIdentifier:@"Image Sources"])
			[_mosaicView setViewMode:_viewImageSources];
		if (selectedIndex == [_utilitiesTabView indexOfTabViewItemWithIdentifier:@"Original Image"])
			[_mosaicView setViewMode:_viewMosaic];
		if (selectedIndex == [_utilitiesTabView indexOfTabViewItemWithIdentifier:@"Image Regions"])
			[_mosaicView setViewMode:_viewImageRegions];
		if (selectedIndex == [_utilitiesTabView indexOfTabViewItemWithIdentifier:@"Tile Editor"])
			[_mosaicView setViewMode:_viewHighlightedTile];
	}
}


#pragma mark -
#pragma mark Table delegate methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == _imageSourcesTable)
		return [_imageSources count];
		
    if (aTableView == _editorTable)
		return (_selectedTile == nil ? 0 : [_selectedTile matchCount]);
	
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if (aTableView == _imageSourcesTable)
    {
		return ([[aTableColumn identifier] isEqualToString:@"Image Source Type"]) ?
				(id)[[_imageSources objectAtIndex:rowIndex] image] : 
				(id)[NSString stringWithFormat:@"%@\n(%d images found)",
												[[_imageSources objectAtIndex:rowIndex] descriptor],
												[[_imageSources objectAtIndex:rowIndex] imageCount]];
    }
    else // it's the editor table
    {
		NSImage	*image;
		
		if (_selectedTile == nil) return nil;
		
		image = [_selectedTileImages objectAtIndex:rowIndex];
		if ([image isKindOfClass:[NSNull class]] && rowIndex != -1)
		{
			image = [self createEditorImage:rowIndex];
			[_selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
		}
		
		return image;
    }
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == _editorTable)
    {
        int	selectedRow = [_editorTable selectedRow];
        
        if (selectedRow >= 0)
            [_matchValueTextField setStringValue:[NSString stringWithFormat:@"%f", 
                                                    [_selectedTile matches][selectedRow].matchValue]];
        else
            [_matchValueTextField setStringValue:@""];
    }
}


#pragma mark -

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector
			 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (!_paused) [self togglePause:nil];
    while (_createTilesThreadAlive || _enumerateImageSourcesThreadAlive || _calculateImageMatchesThreadAlive || _calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector 
			    contextInfo:contextInfo];
}


- (void)close
{
	if (_documentIsClosing)
		return;	// make sure to do the steps below only once (not sure why this method sometimes gets called twice...)

		// stop the timers
	if ([_updateDisplayTimer isValid]) [_updateDisplayTimer invalidate];
	[_updateDisplayTimer release];
	if ([_animateTileTimer isValid]) [_animateTileTimer invalidate];
	[_animateTileTimer release];
	
		// let other threads know we are closing
	_documentIsClosing = YES;
	
		// wait for the threads to shut down
	while (_createTilesThreadAlive || _enumerateImageSourcesThreadAlive || 
		   _calculateImageMatchesThreadAlive || _calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		
		// Give the image sources a chance to clean up before we close shop
	[_imageSources release];
	_imageSources = nil;
	
    [super close];
}



- (void)dealloc
{
    [_originalImageURL release];
    [_originalImage release];
    [_mosaicImage release];
    [_mosaicImageLock release];
    [_refindUniqueTilesLock release];
    [_imageQueueLock release];
    [_tiles release];
    [_tileOutlines release];
    [_imageQueue release];
    [_selectedTileImages release];
    [_toolbarItems release];
    [_removedSubviews release];
    [_combinedOutlines release];
    [_zoomToolbarMenuItem release];
    [_viewToolbarMenuItem release];
    [_lastSaved release];
    [_tileImages release];
    [_tileImagesLock release];
    [_unusedTileImage release];
    
    [super dealloc];
}

@end
