#import <Foundation/Foundation.h>
#import <HIToolbox/MacWindows.h>
#import "MacOSaiX.h"
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "TileImage.h"
#import "MosaicView.h"
#import "OriginalView.h"
#import "ImageRepCell.h"

	// The maximum size of the image URL queue
#define MAX_IMAGE_URLS 32

@implementation MacOSaiXDocument

- (id)init
{
    self = [super init];
    
    [self setHasUndoManager:FALSE];	// don't track undo-able changes
    
    _originalImageURL = nil;
    _tiles = nil;
    _combinedOutlines = nil;
    _paused = NO;
    _viewMode = viewMosaicAndOriginal;
    _statusBarShowing = YES;
    _imagesMatched = 0;
    _imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueue = nil;
    _mosaicImage = nil;
    _mosaicImageDrawWindow = nil;
    _zoom = 0.0;
    _lastSaved = [[NSDate date] retain];
    _autosaveFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] intValue];
    _finishLoading = _windowFinishedLoading = NO;
    _exportProgressTileCount = 0;
    _exportFormat = NSJPEGFileType;
    _selectedTileImages = nil;
    _documentIsClosing = NO;
        
    // create the image URL queue and its lock
    _imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
    _imageQueueLock = [[NSLock alloc] init];

    _createTilesThreadAlive = _enumerateImageSourcesThreadAlive = _processImagesThreadAlive = 
		_integrateMatchesThreadAlive = _exportImageThreadAlive = NO;
    
    _tileImages = [[NSMutableArray arrayWithCapacity:0] retain];
    _tileImagesLock = [[NSLock alloc] init];
    _unusedTileImage = [[TileImage alloc] initWithIdentifier:@"" fromImageSourceIndex:-1];
    
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
    
    _viewIsChanging = NO;
    _selectedTile = nil;
    _mosaicImageUpdated = NO;

    _mosaicImageLock = [[NSLock alloc] init];
    _refindUniqueTilesLock = [[NSLock alloc] init];
    _refindUniqueTiles = YES;
    
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

/*
    [_imageSourcesTable setDataSource:self];
    [[_imageSourcesTable tableColumnWithIdentifier:@"type"]
			    setDataCell:[[[NSImageCell alloc] init] autorelease]];
    [[[_editorTable documentView] tableColumnWithIdentifier:@"image"]
				    setDataCell:[[[NSImageCell alloc] init] autorelease]];
*/

    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(mosaicViewDidScroll:)
						 name:@"View Did Scroll" object:nil];

    _removedSubviews = nil;

		// set up the toolbar
    _viewToolbarItem = _pauseToolbarItem = nil;
    _viewToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"View" action:nil keyEquivalent:@""];
    [_viewToolbarMenuItem setSubmenu:viewToolbarSubmenu];
    _zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [_zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    _toolbarItems = [[NSMutableDictionary dictionary] retain];
    toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [_mainWindow setToolbar:toolbar];
    
	[self setViewMode:viewMosaicAndTilesSetup];
    
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
		[self setDocumentState:nascentState];
    }
}


- (void)setDocumentState:(MacOSaiXDocumentState)state
{
	switch (state)
	{
		case nascentState:
				// only set initially for a newly created mosaic
//			[(MacOSaiX *)NSApp discoverPlugIns];	// check if any new plug-ins were added
//			[_tilePopUpButton addItemsWithTitles:[(MacOSaiX *)NSApp tileSetupControllerClasses]];
			break;
		default:
			break;
	}
}


- (void)startMosaic:(id)sender
{    
    // spawn a thread to create a data structure for each tile including outlines, bitmaps, etc.
    if (_tiles == nil)
		[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
					toTarget:self withObject:nil];
    
    // spawn a thread to enumerate the image sources
//    [NSApplication detachDrawingThread:@selector(enumerateImageSources:) toTarget:self withObject:nil];
    
		// start the image matching thread
    [NSApplication detachDrawingThread:@selector(processImageURLQueue:) toTarget:self withObject:nil];
    
		// start the image integrating thread
    [NSApplication detachDrawingThread:@selector(recalculateTileDisplayMatches:)
			      toTarget:self withObject:nil];
    
// TODO: what is this for again?
    _windowFinishedLoading = YES;
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    BOOL		wasPaused = _paused;
    NSMutableDictionary	*storage = [NSMutableDictionary dictionary];

    _paused = YES;

    // wait for threads to pause
    while (_enumerateImageSourcesThreadAlive || _processImagesThreadAlive)
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
    else if (_processImagesThreadAlive && _integrateMatchesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching and finding unique tiles..."];
    else if (_processImagesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching images..."];
    else if (_integrateMatchesThreadAlive)
		statusMessage = [NSString stringWithString:@"Finding unique tiles..."];
    else if (_enumerateImageSourcesThreadAlive)
		statusMessage = [NSString stringWithString:@"Looking for new images..."];
    else if (_paused)
		statusMessage = [NSString stringWithString:@"Paused"];
    else
		statusMessage = [NSString stringWithString:@"Idle"];
	
    fullMessage = [NSString stringWithFormat:
	@"Images Matched/Kept: %d/%d     Mosaic Quality: %2.1f%%     Status: %@",
	_imagesMatched, [_tileImages count], _overallMatch, statusMessage];
    if ([fullMessage sizeWithAttributes:[[statusMessageView attributedStringValue] attributesAtIndex:0 effectiveRange:nil]].width > [statusMessageView frame].size.width)
	fullMessage = [NSString stringWithFormat:@"%d/%d     %2.1f%%     %@",
	    _imagesMatched, [_tileImages count], _overallMatch, statusMessage];
    [statusMessageView setStringValue:fullMessage];
    
    // update the mosaic image
    if (_mosaicImageUpdated && [_mosaicImageLock tryLock])
    {
//	OSStatus	result;
	
	[[mosaicView documentView] setImage:_mosaicImage];
	[[mosaicView documentView] updateCell: [[mosaicView documentView] cell]];
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
    [imageSourcesTable reloadData];
    
    // autosave if it's time
    if ([_lastSaved timeIntervalSinceNow] < _autosaveFrequency * -60)
    {
	[self saveDocument:self];
	[_lastSaved autorelease];
	_lastSaved = [[NSDate date] retain];
    }
    
    // 
    if (_exportImageThreadAlive)
		[exportProgressIndicator setDoubleValue:_exportProgressTileCount];
    else if (!_exportImageThreadAlive && _exportProgressTileCount > 0)
    {
		// the export is finished, close the panel
		[NSApp endSheet:exportProgressPanel];
		[exportProgressPanel orderOut:nil];
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


- (void)setOriginalImage:(NSImage *)image fromURL:(NSURL *)imageURL
{
    [_originalImage autorelease];
    _originalImage = [image copy];
    
    [_originalView setImage:_originalImage];

    [_originalImageURL autorelease];
    _originalImageURL = [imageURL retain];

    // Create an NSImage to hold the mosaic image (somewhat arbitrary size)
    [_mosaicImage autorelease];
    _mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1600 * 
						[_originalImage size].height / [_originalImage size].width)];
/*    [_mosaicImageDrawWindow autorelease];
    _mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
								  [_mosaicImage size].width,
								  [_mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];*/
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


#pragma mark -
#pragma mark Thread entry points


- (void)createTileCollectionWithOutlines:(id)object
{
    int			index;
    NSAutoreleasePool	*pool;
    NSWindow		*drawWindow;
    NSBezierPath	*combinedOutline = [NSBezierPath bezierPath];
    
    if (_tileOutlines == nil || _originalImage == nil) return;

    _createTilesThreadAlive = YES;
    
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
    for (index = 0; index < [_tileOutlines count] && !_documentIsClosing; index++)
    {
	Tile			*tile;
	NSBezierPath		*clipPath;
	NSAffineTransform	*transform;
	NSRect			origRect, destRect;
	NSBitmapImageRep	*tileRep;
	
	// create the tile object and add it to the collection
	tile = [[[Tile alloc] init] autorelease];	NSAssert(tile != nil, @"Could not allocate tile");
	[_tiles addObject:tile];
	
	[tile setDocument:self];
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
	tileRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:destRect] autorelease];
	if (tileRep == nil)
	    NSLog(@"Could not create tile bitmap");
	[tile setBitmapRep:tileRep];
	
	if (index % 20 == 10 && index != [_tileOutlines count] - 1)
	{
	    [[drawWindow contentView] unlockFocus];
	    while (![[drawWindow contentView] lockFocusIfCanDraw])
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
	}
    }

    [[drawWindow contentView] unlockFocus];
    [drawWindow close];
    
    [(OriginalView *)_originalView setTileOutlines:combinedOutline];
    
    [pool release];
    
    _createTilesThreadAlive = NO;
}


- (void)recalculateTileDisplayMatches:(id)object
{
    NSAutoreleasePool	*pool, *pool2;
    float		overallMatch = 0.0;
    
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil || _createTilesThreadAlive)
    {
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		if (pool == nil) pool = [[NSAutoreleasePool alloc] init];
    }
    
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
}


- (void)enumerateImageSources:(id)object
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    id					imageIdentifier;
    int					i;
    
    _enumerateImageSourcesThreadAlive = YES;

    while (pool == nil)
    {
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		pool = [[NSAutoreleasePool alloc] init];
    }

    while (!_documentIsClosing)
	{
		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		BOOL			imageWasFound = NO;
		
		while (pool2 == nil)
		{
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
			pool2 = [[NSAutoreleasePool alloc] init];
		}
		
		while (_paused && !_documentIsClosing)
		{
			NSAutoreleasePool	*pool3 = [[NSAutoreleasePool alloc] init];
			
			_enumerateImageSourcesThreadAlive = YES;
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
			
			[pool3 release];
		}
		_enumerateImageSourcesThreadAlive = YES;
		
		// start at index 1 to skip over the image source used for manual images
		for (i = 1; i < [_imageSources count] && !_documentIsClosing; i++)
		{
			if ((imageIdentifier = [[_imageSources objectAtIndex:i] nextImageIdentifier]) != nil)
			{
				TileImage	*tileImage;
				NSImage		*pixletImage;
				
				imageWasFound = YES;
				
				tileImage = [[[TileImage alloc] initWithIdentifier:imageIdentifier
								fromImageSourceIndex:i] autorelease];
				pixletImage = [tileImage imageFromSources:_imageSources]; // pre-load the image
		
				[_imageQueueLock lock];
				while ([_imageQueue count] >= MAX_IMAGE_URLS && !_documentIsClosing)
				{
					NSAutoreleasePool	*pool3 = [[NSAutoreleasePool alloc] init];
					
						// the queue is full, wait for the matching thread to free up space
					[_imageQueueLock unlock];
					_enumerateImageSourcesThreadAlive = YES;
					[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
					[_imageQueueLock lock];
					[pool3 release];
				}
				if (!_documentIsClosing)
				{
					_enumerateImageSourcesThreadAlive = YES;
					[_imageQueue addObject:tileImage];
				}
				[_imageQueueLock unlock];
			}
		}
		if (!imageWasFound && !_documentIsClosing)
		{ // none of the image sources found an image, wait a second and try again
			_enumerateImageSourcesThreadAlive = YES;
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		}
		
		[pool2 release];
	}
    
    [pool release];
    
    _enumerateImageSourcesThreadAlive = NO;
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

    while (!_documentIsClosing)
    {
	NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
	
	while (pool2 == nil && !_documentIsClosing) pool2 = [[NSAutoreleasePool alloc] init];

		// wait for the tiles to get created
	while ((_createTilesThreadAlive || _paused) && !_documentIsClosing)
	{
	    NSAutoreleasePool	*pool3 = [[NSAutoreleasePool alloc] init];

	    _processImagesThreadAlive = YES;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    
	    [pool3 release];
	}
    
	[_imageQueueLock lock];
	if ([_imageQueue count] == 0 || _documentIsClosing)
	{
	    [_imageQueueLock unlock]; // there aren't any image URLs to process
	    _processImagesThreadAlive = YES;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	}
	else
	{
	    TileImage		*tileImage = nil;
	    NSImage		*pixletImage = nil;
	    NSMutableArray	*cachedReps = nil;
	    int			index;
	    long		tileImageIndex;
	    
	    _processImagesThreadAlive = YES;
	    
			// pull the next image from the queue
	    tileImage = [[[_imageQueue objectAtIndex:0] retain] autorelease];
	    [_imageQueue removeObjectAtIndex:0];
	    [_imageQueueLock unlock];
		
			// if the image loaded and it's not miniscule, match it against the tiles
	    if ((pixletImage = [tileImage imageFromSources:_imageSources]) &&
			[pixletImage size].width >= TILE_BITMAP_SIZE &&
			[pixletImage size].height >= TILE_BITMAP_SIZE)
		{
			cachedReps = [NSMutableArray arrayWithCapacity:0];
			tileImageIndex = [self addTileImage:tileImage];
			[self tileImageIndexInUse:tileImageIndex];
			
				// loop through the tiles and compute the pixlet's match
			for (index = 0; index < [_tiles count] && !_documentIsClosing; index++)
			{
				Tile	*tile = nil;
				float	scale, newMatch;
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
						// no bitmap at the correct size was found, create a new one
					if (![[drawWindow contentView] lockFocusIfCanDraw])
						NSLog(@"Could not lock focus on pixlet window");
					else
					{
						NSBitmapImageRep	*rep = nil;
						
						[pixletImage drawInRect:subRect fromRect:NSZeroRect operation:NSCompositeCopy 
								fraction:1.0];
						rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect];
						if (rep != nil)
							[cachedReps addObject:[rep autorelease]];
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
							tileImage:tileImage tileImageIndex:tileImageIndex forDocument:self];
					if ([tile bestUniqueMatch] == nil || newMatch < [tile bestUniqueMatchValue])
					{
						[_refindUniqueTilesLock lock];
							_refindUniqueTiles = YES;
						[_refindUniqueTilesLock unlock];
					}
				}
			}
				// release the tileImage if no tile ended up using it
			[self tileImageIndexNotInUse:tileImageIndex];
			_imagesMatched++;
		}
		else
			NSLog(@"Could not load tile image with identifier %@", [tileImage imageIdentifier]);
	}

	while ((_paused || _viewMode == viewMosaicEditor) && !_documentIsClosing)
	{
	    NSAutoreleasePool	*pool3 = [[NSAutoreleasePool alloc] init];

	    _processImagesThreadAlive = YES;
	    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	    [pool3 release];
	}
	
	[pool2 release];
    }
    
    [drawWindow close];
    
    [pool release];

    _processImagesThreadAlive = NO;
}


#pragma mark -


- (long)addTileImage:(TileImage *)tileImage
{
    long	unusedIndex;
    
    [_tileImagesLock lock];
	unusedIndex = [_tileImages indexOfObjectIdenticalTo:_unusedTileImage];
	if (unusedIndex == NSNotFound)
	{
	    unusedIndex = [_tileImages count];
	    [_tileImages addObject:tileImage];
	}
	else
	    [_tileImages replaceObjectAtIndex:unusedIndex withObject:tileImage];
    [_tileImagesLock unlock];
    return unusedIndex;
}


- (void)tileImageIndexInUse:(long)index
{
    NSAssert(index >= 0 && index < [_tileImages count], @"check 3");
    [_tileImagesLock lock];
	[[_tileImages objectAtIndex:index] imageIsInUse];
    [_tileImagesLock unlock];
}


- (void)tileImageIndexNotInUse:(long)index
{
    NSAssert(index >= 0 && index < [_tileImages count], @"check 4");
    [_tileImagesLock lock];
	if ([_tileImages objectAtIndex:index] == _unusedTileImage)
	    NSLog(@"");
	if ([[_tileImages objectAtIndex:index] imageIsNotInUse])
	    [_tileImages replaceObjectAtIndex:index withObject:_unusedTileImage];
    [_tileImagesLock unlock];
}


- (void)removeTileImage:(TileImage *)tileImage
{
    [_tileImagesLock lock];
	[_tileImages replaceObjectAtIndex:[_tileImages indexOfObjectIdenticalTo:tileImage]
			       withObject:_unusedTileImage];
    [_tileImagesLock unlock];
    
}


#pragma mark -


- (void)updateMosaicImage:(NSMutableArray *)updatedTiles
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
    NSAffineTransform	*transform;
    NSBitmapImageRep	*newRep;
    
    while (pool == nil) pool = [[NSAutoreleasePool alloc] init];

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
		matchImage = [[_tileImages objectAtIndex:[tile userChosenImageIndex]] 
									imageFromSources:_imageSources];
		if (matchImage == nil)
		    NSLog(@"Could not load image\t%@",
				[[_tileImages objectAtIndex:[tile userChosenImageIndex]] imageIdentifier]);
	    }
	    else
	    {
		if ([tile bestUniqueMatch] != nil)
		{
		    matchImage = [[_tileImages objectAtIndex:[tile bestUniqueMatch]->tileImageIndex] 
									    imageFromSources:_imageSources];
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
}


#pragma mark -
#pragma mark Editor methods

- (void)selectTileAtPoint:(NSPoint)thePoint
{
    int	i;
    
    if (_viewMode != viewMosaicEditor) return;
    
    thePoint.x = thePoint.x / [[mosaicView documentView] frame].size.width;
    thePoint.y = thePoint.y / [[mosaicView documentView] frame].size.height;
    
    for (i = 0; i < [_tiles count]; i++)
	if ([[[_tiles objectAtIndex:i] outline] containsPoint:thePoint])
	{
	    [_editorLabel setStringValue:@"Image to use for selected tile:"];
	    [_editorUseCustomImage setEnabled:YES];
	    [_editorUseBestUniqueMatch setEnabled:YES];
	    _selectedTile = [_tiles objectAtIndex:i];
	    
	    [(MosaicView *)[mosaicView documentView] highlightTile:_selectedTile];
	    [[_editorTable documentView] scrollRowToVisible:0];
	    [self updateEditor];
	    
	    return;
	}
}


- (void)animateSelectedTile:(id)timer
{
    if (_selectedTile != nil && !_documentIsClosing)
	[[mosaicView documentView] animateHighlight];
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
	
	if ([_selectedTile userChosenImageIndex] != -1)
	{
	    [_editorUseCustomImage setState:NSOnState];
	    [_editorUseBestUniqueMatch setState:NSOffState];
	    [_editorUserChosenImage setImage:[[_tileImages objectAtIndex:[_selectedTile userChosenImageIndex]]
							    imageFromSources:_imageSources]];
	}
	else
	{
	    [_editorUseCustomImage setState:NSOffState];
	    [_editorUseBestUniqueMatch setState:NSOnState];
	    [_editorUserChosenImage setImage:nil];
	}

	[_editorChooseImage setEnabled:YES];
	[_editorUseSelectedImage setEnabled:YES];
    
	_selectedTileImages = [[NSMutableArray arrayWithCapacity:[_selectedTile matchCount]] retain];
	for (i = 0; i < [_selectedTile matchCount]; i++)
	    [_selectedTileImages addObject:[NSNull null]];
    }
    
    [[_editorTable documentView] reloadData];
}


- (BOOL)showTileMatchInEditor:(TileMatch *)tileMatch selecting:(BOOL)selecting
{
/*    int	i;
    
    if (_selectedTile == nil) return NO;
    
    for (i = 0; i < [[_selectedTile matches] count]; i++)
	if ([[_selectedTile matches] objectAtIndex:i] == tileMatch)
	{
	    if (selecting)
		[[editorTable documentView] selectRow:i byExtendingSelection:NO];
	    [[editorTable documentView] scrollRowToVisible:i];
	    return YES;
	}
*/    return NO;
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
    image = [[_tileImages objectAtIndex:[_selectedTile matches][rowIndex].tileImageIndex]
				imageFromSources:_imageSources];
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
/*	if ([[_selectedTile matches] objectAtIndex:rowIndex] == [_selectedTile displayMatch])
	{
	    NSBezierPath	*badgePath = [NSBezierPath bezierPathWithOvalInRect:
						NSMakeRect([image size].width - 12, 2, 10, 10)];
						
	    [[NSColor colorWithCalibratedRed:1.0 green:0 blue:0 alpha:1.0] set];
	    [badgePath fill];
	    [[NSColor colorWithCalibratedRed:0.5 green:0 blue:0 alpha:1.0] set];
	    [badgePath stroke];
	}*/
    [image unlockFocus];
    [_selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
    return image;
}


- (void)useCustomImage:(id)sender
{
    if ([_selectedTile bestUniqueMatch] != nil)
	[_selectedTile setUserChosenImageIndex:[_selectedTile bestUniqueMatch]->tileImageIndex];
    else
	[_selectedTile setUserChosenImageIndex:[_selectedTile bestMatch]->tileImageIndex];
    [_selectedTile setBestUniqueMatchIndex:-1];
	
    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];
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

    tileImage = [[[TileImage alloc] initWithIdentifier:[[sheet URLs] objectAtIndex:0]
				 fromImageSourceIndex:0] autorelease];
    [_selectedTile setUserChosenImageIndex:[self addTileImage:tileImage]];
    [_selectedTile setBestUniqueMatchIndex:-1];
    
    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];

    [self updateChangeCount:NSChangeDone];
}


- (void)useBestUniqueMatch:(id)sender
{
    [_selectedTile setUserChosenImageIndex:-1];
    
    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];
    
    [self updateChangeCount:NSChangeDone];
}


- (void)useSelectedImage:(id)sender
{
    long	index = [_selectedTile matches][[[_editorTable documentView] selectedRow]].tileImageIndex;
    
    [_selectedTile setUserChosenImageIndex:index];
    [_selectedTile setBestUniqueMatchIndex:-1];

    [_refindUniqueTilesLock lock];
	_refindUniqueTiles = YES;
    [_refindUniqueTilesLock unlock];

    [self updateEditor];

    [self updateChangeCount:NSChangeDone];
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
    NSRect	newFrame = [_mainWindow frame];
    
    if (mode == _viewMode) return;
    
    // flag the window resize code
    _viewIsChanging = YES;
    
    // un-highlight the currently highlighted view button in the toolbar
/*
    if (_viewMode == viewMosaicAndOriginal)
		[viewCompareButton setImage:[NSImage imageNamed:@"ViewCompareOff"]];
    if (_viewMode == viewMosaicAndTilesSetup)
		[viewTilesSetupButton setImage:[NSImage imageNamed:@"ViewTilesSetupOff"]];
    if (_viewMode == viewMosaicAndRegions)
		[viewRegionsButton setImage:[NSImage imageNamed:@"ViewRegionsOff"]];
    if (_viewMode == viewMosaicAlone)
		[viewAloneButton setImage:[NSImage imageNamed:@"ViewAloneOff"]];
    if (_viewMode == viewMosaicEditor)
		[viewEditorButton setImage:[NSImage imageNamed:@"ViewEditorOff"]];
*/

    _viewMode = mode;
	switch (mode)
	{
		case viewMosaicAndOriginal:
//			[viewCompareButton setImage:[NSImage imageNamed:@"ViewCompareOn"]];
//			newFrame.size.width = [mosaicView frame].size.width * 2 - 16;
//			newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
			[tabView selectTabViewItemWithIdentifier:@"Mosaic and Original"];
			[_utilitiesDrawer open];
			break;
		case viewMosaicAndTilesSetup:
//			[viewTilesSetupButton setImage:[NSImage imageNamed:@"ViewTilesSetupOn"]];
//			newFrame.size.width = [mosaicView frame].size.width + 300;
//			newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
			[tabView selectTabViewItemWithIdentifier:@"Mosaic and Tiles Setup"];
			break;
		case viewMosaicAlone:
//			[viewAloneButton setImage:[NSImage imageNamed:@"ViewAloneOn"]];
//			newFrame.size.width = [mosaicView frame].size.width;
//			newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
			[_utilitiesDrawer close];
			break;
		case viewMosaicAndRegions:
//			[viewRegionsButton setImage:[NSImage imageNamed:@"ViewRegionsOn"]];
//			newFrame.size.width = [mosaicView frame].size.width;
//			newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
			[tabView selectTabViewItemWithIdentifier:@"Mosaic And Regions"];
			break;
		case viewMosaicEditor:
			[viewEditorButton setImage:[NSImage imageNamed:@"ViewEditorOn"]];
			newFrame.size.width = [mosaicView frame].size.width + 300;
			newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
			[tabView selectTabViewItemWithIdentifier:@"Mosaic and Editor"];
			break;
    }
    [_mainWindow setFrame:newFrame display:YES animate:YES];
    [_mainWindow displayIfNeeded];	// make sure the toolbar redraws
    _viewIsChanging = NO;
    newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
    [self synchronizeMenus];
    if (mode == viewMosaicEditor)
    {
		[(MosaicView *)[mosaicView documentView] highlightTile:_selectedTile];
		[self updateEditor];
		[[_editorTable documentView] scrollRowToVisible:0];
		[[_editorTable documentView] reloadData];
    }
    else
		[(MosaicView *)[mosaicView documentView] highlightTile:nil];
}


- (void)calculateFramesFromSize:(NSSize)frameSize
{
    // frameSize is the size of the window's content view, not the entire window frame
 
    if (_statusBarShowing) frameSize.height -= [statusBarView frame].size.height;
    
    if (_viewMode == viewMosaicAlone && !_viewIsChanging)
    {
		[mosaicView setFrame:NSIntegralRect(NSMakeRect(0, 0, frameSize.width, frameSize.height))];
		[tabView setFrame:NSIntegralRect(NSMakeRect([mosaicView frame].size.width, 0,
													[mosaicView frame].size.width,
													[mosaicView frame].size.height))];
    }

    if (_viewMode == viewMosaicAndOriginal)
    {
		if (!_viewIsChanging)
			[mosaicView setFrame:NSIntegralRect(NSMakeRect(0, 0, frameSize.width / 2 + 8, frameSize.height))];
			[tabView setFrame:NSIntegralRect(NSMakeRect([mosaicView frame].size.width, 0,
														[mosaicView frame].size.width - 16,
														[mosaicView frame].size.height))];
    }

    if (_viewMode == viewMosaicEditor)
    {
		if (!_viewIsChanging)
			[mosaicView setFrame:NSIntegralRect(NSMakeRect(0, 0, frameSize.width - 300, frameSize.height))];
		[tabView setFrame:NSIntegralRect(NSMakeRect([mosaicView frame].size.width, 0,
													frameSize.width - [mosaicView frame].size.width,
													frameSize.height))];
    }
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
		[mosaicView setNeedsDisplay:YES];
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
    NSRect	orig, content,doc;
    
    if ([notification object] != mosaicView) return;
    
    orig = [_originalView bounds];
    content = [[mosaicView contentView] bounds];
    doc = [[mosaicView documentView] frame];
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
	_removedSubviews = [[statusBarView subviews] copy];
	for (i = 0; i < [_removedSubviews count]; i++)
	    [[_removedSubviews objectAtIndex:i] removeFromSuperview];
	[statusBarView retain];
	[statusBarView removeFromSuperview];
	newFrame.origin.y += [statusBarView frame].size.height;
	newFrame.size.height -= [statusBarView frame].size.height;
	newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
	[_mainWindow setFrame:newFrame display:YES animate:YES];
	[[_viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
    }
    else
    {
	_statusBarShowing = YES;
	newFrame.origin.y -= [statusBarView frame].size.height;
	newFrame.size.height += [statusBarView frame].size.height;
	newFrame.size = [self windowWillResize:_mainWindow toSize:newFrame.size];
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
    [_originalView setDisplayTileOutlines:([_showOutlinesSwitch state] == NSOnState)];
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


- (void)addImageSource:(ImageSource *)imageSource
{
	[_imageSources addObject:imageSource];
}


/*
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

    [_imageSources addObject:[[[DirectoryImageSource alloc]
			    initWithObject:[[sheet filenames] objectAtIndex:0]] autorelease]];
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
    NSArray	*terms = [[googleTermField stringValue] componentsSeparatedByString:@";"];
    int		i;
    
    for (i = 0; i < [terms count]; i++)
		[_imageSources addObject:[[[GoogleImageSource alloc] initWithObject:[terms objectAtIndex:i]] autorelease]];
	
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)addGlyphImageSource:(id)sender
{
    [_imageSources addObject:[[[GlyphImageSource alloc] initWithObject:nil] autorelease]];
}
*/


#pragma mark -
#pragma mark Export image methods

- (void)beginExportImage:(id)sender
{
    _savePanel = [NSSavePanel savePanel];

    if ([[_tiles lastObject] matchCount] < [_tiles count])
    {
	NSBeginAlertSheet(@"Export Image", nil, nil, nil, _mainWindow, self, nil, nil, nil,
	    @"Not enough images have been found.");
	return;
    }
	
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
    
    [exportProgressLabel setStringValue:@"Waiting to find all unique tiles..."];
    [exportProgressIndicator setIndeterminate:YES];
    [exportProgressIndicator startAnimation:self];
    
    [NSApp beginSheet:exportProgressPanel
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
    NSImage		*exportImage, *pixletImage;
    NSBitmapImageRep	*exportRep;
    NSData		*bitmapData;
    NSAutoreleasePool	*pool;
    BOOL		wasPaused = _paused;
    
    _exportImageThreadAlive = YES;
    
    pool = [[NSAutoreleasePool alloc] init];
    while (pool == nil)
    {
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		pool = [[NSAutoreleasePool alloc] init];
    }

    while (!_integrateMatchesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    [exportProgressLabel setStringValue:@"Exporting mosaic image..."];
    [exportProgressIndicator stopAnimation:self];
    [exportProgressIndicator setMaxValue:[_tiles count]];
    [exportProgressIndicator setIndeterminate:NO];
    [exportProgressPanel displayIfNeeded];
    
    exportImage = [[NSImage alloc] initWithSize:NSMakeSize([_exportWidth intValue], [_exportHeight intValue])];
//    exportImage = [[NSImage alloc] initWithSize:NSMakeSize(2400, 2400 * [_originalImage size].height / 
//								 [_originalImage size].width)];
    [exportImage lockFocus];
    transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
    for (i = 0; i < [_tiles count]; i++)
    {
	NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
	Tile			*tile = [_tiles objectAtIndex:i];
	TileImage		*tileImage = [_tileImages objectAtIndex:([tile userChosenImageIndex] == -1) ?
									[tile bestUniqueMatch]->tileImageIndex :
									[tile userChosenImageIndex]];
	NSBezierPath		*clipPath = [transform transformBezierPath:[tile outline]];
	int			imageFetchCount = 0;
	
	_exportProgressTileCount = i;
	[NSGraphicsContext saveGraphicsState];
	[clipPath addClip];
	
	do
	    pixletImage = [[_imageSources objectAtIndex:[tileImage imageSourceIndex]]
					    imageForIdentifier:[tileImage imageIdentifier]];
	while (pixletImage == nil && imageFetchCount++ < 4);
	
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

    if (_exportFormat == NSJPEGFileType)
	bitmapData = [exportRep representationUsingType:NSJPEGFileType properties:nil];
    else
	bitmapData = [exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
    [bitmapData writeToFile:exportFilename atomically:YES];
    
    [NSApp endSheet:exportProgressPanel];
    [exportProgressPanel orderOut:nil];

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
    windowTop -= diff.height + 16 + (_statusBarShowing ? [statusBarView frame].size.height : 0);
    
    // Calculate the height of the window based on the proposed width
    //   and preserve the aspect ratio of the mosaic image.
    // If the height is too big for the screen, lower the width.
    if (_viewMode == viewMosaicAndOriginal)
    {
	proposedFrameSize.height = (proposedFrameSize.width - 16) / 2 / aspectRatio;
	if (proposedFrameSize.height > windowTop || proposedFrameSize.height < minHeight)
	{
	    proposedFrameSize.height = (proposedFrameSize.height < minHeight) ? minHeight : windowTop;
	    proposedFrameSize.width = proposedFrameSize.height * aspectRatio * 2 + 16;
	}
    }
    else if (_viewMode == viewMosaicAlone)
    {
	proposedFrameSize.height = (proposedFrameSize.width - 16) / aspectRatio;
	if (proposedFrameSize.height > windowTop || proposedFrameSize.height < minHeight)
	{
	    proposedFrameSize.height = (proposedFrameSize.height < minHeight) ? minHeight : windowTop;
	    proposedFrameSize.width = proposedFrameSize.height * aspectRatio + 16;
	}
    }
    else if (_viewMode == viewMosaicEditor)
    {
	proposedFrameSize.height = (proposedFrameSize.width - 300 - 16) / aspectRatio;
	if (proposedFrameSize.height > windowTop || proposedFrameSize.height < minHeight)
	{
	    proposedFrameSize.height = (proposedFrameSize.height < minHeight) ? minHeight : windowTop;
	    proposedFrameSize.width = proposedFrameSize.height * aspectRatio + 16 + 300;
	}
    }
    
    // add height of scroll bar and status bar (if showing)
    proposedFrameSize.height += 16 + (_statusBarShowing ? [statusBarView frame].size.height : 0);
    
    [self calculateFramesFromSize:proposedFrameSize];
    [self setZoom:self];
    
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
//    [self windowWillResize:_mainWindow toSize:[_mainWindow frame].size];
    // this method is called during animated window resizing, not windowWillResize
    [self calculateFramesFromSize:[[_mainWindow contentView] frame].size];
    [self setZoom:self];
    [tabView setNeedsDisplay:YES];
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
    
    if ([itemIdentifier isEqualToString:@"View"])
    {
	[toolbarItem setMinSize:NSMakeSize(95, 32)];
	[toolbarItem setMaxSize:NSMakeSize(95, 32)];
	[toolbarItem setLabel:@"View"];
	[toolbarItem setPaletteLabel:@"View"];
	[toolbarItem setView:viewToolbarView];
	[toolbarItem setMenuFormRepresentation:_viewToolbarMenuItem];
	_viewToolbarItem = toolbarItem;
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
	[toolbarItem setAction:@selector(beginExportImage:)];
	[toolbarItem setToolTip:@"Export an image of the mosaic"];
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
	return ([_imageSources count] - 1) * 2;	// don't count the default image source for custom URL's
    else
	return (_selectedTile == nil ? 0 : [_selectedTile matchCount]);
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if ([aTableView isEqual:imageSourcesTable])
    {
	if (rowIndex % 2 == 0)
	    return ([[aTableColumn identifier] isEqualToString:@"type"]) ?
		(id)[[_imageSources objectAtIndex:(int)(rowIndex / 2 + 1)] typeImage] : 
		(id)[[_imageSources objectAtIndex:(int)(rowIndex / 2 + 1)] descriptor];
	else
	{
	    if ([[aTableColumn identifier] isEqualToString:@"type"])
		return [NSImage imageNamed:@"Blank"];
	    else
	    {
		long	imageCount = [[_imageSources objectAtIndex:(int)(rowIndex / 2 + 1)] imageCount];
		
		return [NSString stringWithFormat:@"(%d image%@ found)", imageCount,
						  (imageCount == 1) ? @"" : @"s"];
	    }
	}
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


#pragma mark -

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector
			 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (!_paused) [self togglePause:nil];
    while (_createTilesThreadAlive || _enumerateImageSourcesThreadAlive || _processImagesThreadAlive || _integrateMatchesThreadAlive)
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
		   _processImagesThreadAlive || _integrateMatchesThreadAlive)
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
