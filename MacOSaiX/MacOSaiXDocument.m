#import <Foundation/Foundation.h>
#import <HIToolbox/MacWindows.h>
#import "MacOSaiX.h"
#import "MacOSaiXDocument.h"
#import "Tiles.h"
#import "MosaicView.h"
#import "OriginalView.h"


	// The maximum size of the image URL queue
#define MAXIMAGEURLS 32
	// The maximum width or height of the cached thumbnail images
#define kThumbnailMax 64.0
    // The number of cached images that will be held in memory at any one time.
#define IMAGE_CACHE_SIZE 100

@interface MacOSaiXDocument (PrivateMethods)
- (void)cacheImage:(NSImage *)image withIdentifier:(id<NSCopying>)imageIdentifier fromSource:(ImageSource *)imageSource;
- (NSImage *)cachedImageForIdentifier:(id<NSCopying>)imageIdentifier fromSource:(ImageSource *)imageSource;
@end


@implementation MacOSaiXDocument

- (id)init
{
    if (self = [super init])
    {
		[self setHasUndoManager:FALSE];	// don't track undo-able changes
		
		mosaicStarted = NO;
		paused = YES;
		viewMode = viewMosaicAndOriginal;
		statusBarShowing = YES;
		imagesMatched = 0;
		imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
		zoom = 0.0;
		lastSaved = [[NSDate date] retain];
		autosaveFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] intValue];
		finishLoading = windowFinishedLoading = NO;
		exportProgressTileCount = 0;
		exportFormat = NSJPEGFileType;
		documentIsClosing = NO;
			
		// create the image URL queue and its lock
		imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
		imageQueueLock = [[NSLock alloc] init];

		createTilesThreadAlive = enumerateImageSourcesThreadAlive = calculateImageMatchesThreadAlive = 
			exportImageThreadAlive = NO;
		calculateImageMatchesThreadLock = [[NSLock alloc] init];
		
			// set up ivars for "calculateDisplayedImages" thread
		calculateDisplayedImagesThreadAlive = NO;
		calculateDisplayedImagesThreadLock = [[NSLock alloc] init];
		refreshTilesSet = [[NSMutableSet setWithCapacity:256] retain];
		refreshTilesSetLock = [[NSLock alloc] init];

		tileImages = [[NSMutableArray arrayWithCapacity:0] retain];
		tileImagesLock = [[NSLock alloc] init];
		
		cacheLock = [[NSLock alloc] init];
		imageCache = [[NSMutableDictionary dictionary] retain];
		cachedImagesPath = @"/tmp/Cached Images";
        
        orderedCache = [[NSMutableArray array] retain];
        orderedCacheID = [[NSMutableArray array] retain];
	}
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
    mainWindow = [[[self windowControllers] objectAtIndex:0] window];
    viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
    [self performSelector:@selector(chooseOriginalImage) withObject:nil afterDelay:0];
}

- (void)chooseOriginalImage
{
//	[self chooseOriginalImageOpenPanelDidEnd:nil returnCode:NSOKButton contextInfo:nil];

    NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
    
		// prompt the user for the image to make a mosaic from
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:nil
							  file:nil
							 types:[NSImage imageFileTypes]
					modalForWindow:mainWindow
					 modalDelegate:self
					didEndSelector:@selector(chooseOriginalImageOpenPanelDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet 
								returnCode:(int)returnCode
							   contextInfo:(void *)context
{
    if (returnCode == NSCancelButton)
	{
		[mainWindow performSelector:@selector(performClose:) withObject:self afterDelay:0];
		return;
	}

		// remember and load the image the user chose
#if 0
	originalImageURL = [[NSURL fileURLWithPath:@"/Users/fmidgley/Documents/test/kim_sean.jpg"] retain];
#else
	originalImageURL = [[[sheet URLs] objectAtIndex:0] retain];
#endif
	originalImage = [[NSImage alloc] initWithContentsOfURL:originalImageURL];
	
		// Create an NSImage to hold the mosaic image (somewhat arbitrary size)
    [mosaicImage autorelease];
    mosaicImage = [[NSImage alloc] initWithSize:NSMakeSize(1600, 1600 * 
						[originalImage size].height / [originalImage size].width)];
    
	[mosaicView setOriginalImage:originalImage];
	[mosaicView setMosaicImage:mosaicImage];
	[mosaicView setViewMode:viewTilesOutline];
	
    selectedTile = nil;
    mosaicImageUpdated = NO;

    mosaicImageLock = [[NSLock alloc] init];
    refindUniqueTilesLock = [[NSLock alloc] init];
//    refindUniqueTiles = YES;
    
		// create timers to update the window and animate any selected tile
    updateDisplayTimer = [[NSTimer scheduledTimerWithTimeInterval:1.0
							   target:(id)self
							 selector:@selector(updateDisplay:)
							 userInfo:nil
							  repeats:YES] retain];
    animateTileTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
							 target:(id)self
						       selector:@selector(animateSelectedTile:)
						       userInfo:nil
							repeats:YES] retain];

    if (combinedOutlines) [originalView setTileOutlines:combinedOutlines];
    [originalView setImage:originalImage];

    [[NSNotificationCenter defaultCenter] addObserver:self
					     selector:@selector(mosaicViewDidScroll:)
						 name:@"View Did Scroll" object:nil];

    removedSubviews = nil;

		// set up the toolbar
    pauseToolbarItem = nil;
    zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    toolbarItems = [[NSMutableDictionary dictionary] retain];
    NSToolbar   *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [mainWindow setToolbar:toolbar];
    
		// Make sure we have the latest and greatest list of plug-ins
	[[NSApp delegate] discoverPlugIns];

	{
			// Set up the "Tiles Setup" tab
		[tilesSetupView setTitlePosition:NSNoTitle];
		
			// Load the names of the tile setup plug-ins
		NSEnumerator	*enumerator = [[[NSApp delegate] tilesSetupControllerClasses] objectEnumerator];
		Class			tilesSetupControllerClass;
		[tilesSetupPopUpButton removeAllItems];
		while (tilesSetupControllerClass = [enumerator nextObject])
			[tilesSetupPopUpButton addItemWithTitle:[tilesSetupControllerClass name]];
		[self setTilesSetupPlugIn:self];
	}
	
	{	// Set up the "Image Sources" tab
		[imageSourcesTabView setTabViewType:NSNoTabsNoBorder];

		imageSources = [[NSMutableArray arrayWithCapacity:4] retain];
		[[imageSourcesTable tableColumnWithIdentifier:@"Image Source Type"]
			setDataCell:[[[NSImageCell alloc] init] autorelease]];
	
			// Load the image source plug-ins and create an instance of each controller
		NSEnumerator	*enumerator = [[[NSApp delegate] imageSourceControllerClasses] objectEnumerator];
		Class			imageSourceControllerClass;
		[imageSourcesPopUpButton removeAllItems];
		[imageSourcesPopUpButton addItemWithTitle:@"Current Image Sources"];
		while (imageSourceControllerClass = [enumerator nextObject])
		{
				// add the name of the image source to the pop-up menu
			[imageSourcesPopUpButton addItemWithTitle:[NSString stringWithFormat:@"Add %@ Source...", 
																				  [imageSourceControllerClass name]]];
				// create an instance of the class for this document
			ImageSourceController *imageSourceController = [[[imageSourceControllerClass alloc] init] autorelease];
				// let the plug-in know how to message back to us
			[imageSourceController setDocument:self];
			[imageSourceController setWindow:mainWindow];
				// attach it to the menu item (it will be dealloced when the menu item releases it)
			[[imageSourcesPopUpButton lastItem] setRepresentedObject:imageSourceController];
				// add a tab to the view for this plug-in
			NSTabViewItem	*tabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:nil] autorelease];
			[tabViewItem setView:[imageSourceController imageSourceView]];	// this could be done lazily...
			[imageSourcesTabView addTabViewItem:tabViewItem];
		}
		[self setImageSourcesPlugIn:self];
	}
	
	{	// Set up the "Editor" tab
		[[editorTable tableColumnWithIdentifier:@"image"] setDataCell:[[[NSImageCell alloc] init] autorelease]];
	}
	
	[self setViewMode:viewMosaicAndTilesSetup];
	[utilitiesDrawer setContentSize:NSMakeSize(400, [utilitiesDrawer contentSize].height)];
    
    documentIsClosing = NO;	// gets set to true when threads for this document should shut down

    [self setZoom:self];
    
    NSRect		windowFrame;
    if (finishLoading)
    {
		//	[self setViewMode:viewMode];
		
			// this doc was opened from a file
		if (paused)
		{
			[pauseToolbarItem setLabel:@"Resume"];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
			[[fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
		}
	
			//	broken & disabled until next version
		//	[self windowWillResize:mainWindow toSize:storedWindowFrame.size];
		//	[mainWindow setFrame:storedWindowFrame display:YES];
		windowFrame = [mainWindow frame];
		windowFrame.size = [self windowWillResize:mainWindow toSize:windowFrame.size];
		[mainWindow setFrame:windowFrame display:YES animate:YES];
    }
    else
    {
			// this doc is new
		windowFrame = [mainWindow frame];
		windowFrame.size = [self windowWillResize:mainWindow toSize:windowFrame.size];
		[mainWindow setFrame:windowFrame display:YES animate:YES];
    }
	[pauseToolbarItem setLabel:@"Start Mosaic"];
}


- (void)startMosaic
{    
	mosaicStarted = YES;
    if (tiles == nil)
			// spawn a thread to create a data structure for each tile including outlines, bitmaps, etc.
		[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
					toTarget:self withObject:nil];
	else
		[self spawnImageSourceThreads];
    
		// TODO: I can't remember what this is for?
    windowFinishedLoading = YES;
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
    BOOL		wasPaused = paused;
    NSMutableDictionary	*storage = [NSMutableDictionary dictionary];

    paused = YES;

    // wait for threads to pause
//    while (enumerateImageSourcesThreadAlive || calculateImageMatchesThreadAlive)
//		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
    
#if 1
	[self save];
#else
    [storage setObject:@"1.0b1" forKey:@"Version"];
    [storage setObject:originalImageURL forKey:@"originalImageURL"];
    [storage setObject:imageSources forKey:@"imageSources"];
    [storage setObject:[NSArchiver archivedDataWithRootObject:tileImages] forKey:@"tileImages"];
    [storage setObject:[NSArchiver archivedDataWithRootObject:tiles] forKey:@"tiles"];
    [storage setObject:[NSNumber numberWithLong:imagesMatched] forKey:@"imagesMatched"];
    [storage setObject:imageQueue forKey:@"imageQueue"];
    [storage setObject:[NSNumber numberWithInt:viewMode] forKey:@"viewMode"];
    [storage setObject:[NSValue valueWithRect:[mainWindow frame]] forKey:@"window frame"];
    [storage setObject:[NSNumber numberWithInt:(paused ? 1 : 0)] forKey:@"paused"];
#endif
    
    paused = wasPaused;

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
	imageData = [[storage objectForKey:@"originalImageURL"] resourceDataUsingCache:NO];
	image = [[[NSImage alloc] initWithData:imageData] autorelease];
	[image setDataRetained:YES];
	[image setScalesWhenResized:YES];
//	[self setOriginalImage:image fromURL:[storage objectForKey:@"originalImageURL"]];
	
//	[self setImageSources:[storage objectForKey:@"imageSources"]];
	
	pool = [[NSAutoreleasePool alloc] init];
	    [tileImages release];
	    tileImages = [[NSUnarchiver unarchiveObjectWithData:[storage objectForKey:@"tileImages"]] retain];
	[pool release];
	
	pool = [[NSAutoreleasePool alloc] init];
	    tiles = [[NSUnarchiver unarchiveObjectWithData:[storage objectForKey:@"tiles"]] retain];
	[pool release];
	
	// finish loading tiles
	tileOutlines = nil;
	combinedOutlines = [[NSBezierPath bezierPath] retain];
	for (index = 0; index < [tiles count]; index++)
	{
	    [combinedOutlines appendBezierPath:[[tiles objectAtIndex:index] outline]];
	    [[tiles objectAtIndex:index] setDocument:self];
	}
	
	imagesMatched = [[storage objectForKey:@"imagesMatched"] longValue];
	
	[imageQueue addObjectsFromArray:[storage objectForKey:@"imageQueue"]];
	
//	viewMode = [[storage objectForKey:@"viewMode"] intValue];
	
	storedWindowFrame = [[storage objectForKey:@"window frame"] rectValue];
    
	paused = ([[storage objectForKey:@"paused"] intValue] == 1 ? YES : NO);
	
	finishLoading = YES;
	
	[lastSaved autorelease];
	lastSaved = [[NSDate date] retain];

	return YES;	// document was loaded successfully
    }
    
    return NO;	// unknown version of saved document
}


- (void)updateDisplay:(id)timer
{
    NSString	*statusMessage, *fullMessage;
    
    if (documentIsClosing) return;
    
    // update the status bar
    if (createTilesThreadAlive)
		statusMessage = [NSString stringWithFormat:@"Extracting tile images (%d%%)", extractionPercentComplete];
    else if (calculateImageMatchesThreadAlive && calculateDisplayedImagesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching and finding unique tiles..."];
    else if (calculateImageMatchesThreadAlive)
		statusMessage = [NSString stringWithString:@"Matching images..."];
    else if (calculateDisplayedImagesThreadAlive)
		statusMessage = [NSString stringWithString:@"Finding unique tiles..."];
    else if (enumerateImageSourcesThreadAlive)
		statusMessage = [NSString stringWithString:@"Looking for new images..."];
    else if (paused)
		statusMessage = [NSString stringWithString:@"Paused"];
    else
		statusMessage = [NSString stringWithString:@"Idle"];
	
    fullMessage = [NSString stringWithFormat:@"Images Matched/Kept: %d/%d     Mosaic Quality: %2.1f%%     Status: %@",
											 imagesMatched, [tileImages count], overallMatch, statusMessage];
	if ([fullMessage sizeWithAttributes:[[statusMessageView attributedStringValue] attributesAtIndex:0 effectiveRange:nil]].width 
		> [statusMessageView frame].size.width)
		fullMessage = [NSString stringWithFormat:@"%d/%d     %2.1f%%     %@",
												 imagesMatched, [tileImages count], overallMatch, statusMessage];
    [statusMessageView setStringValue:fullMessage];
    
    // update the mosaic image
    if (mosaicImageUpdated && [mosaicImageLock tryLock])
    {
	//	OSStatus	result;
		
		[mosaicView setMosaicImage:nil];
		[mosaicView setMosaicImage:mosaicImage];
		mosaicImageUpdated = NO;
	//	if (IsWindowCollapsed([mainWindow windowRef]))
		if ([mainWindow isMiniaturized])
		{
	//	    [mainWindow setViewsNeedDisplay:YES];
			[mainWindow setMiniwindowImage:mosaicImage];
	//	    result = UpdateCollapsedWindowDockTile([mainWindow windowRef]);
		}
		[mosaicImageLock unlock];
    }
    
    // update the image sources table
//    [imageSourcesTable reloadData];
    
    // autosave if it's time
    if ([lastSaved timeIntervalSinceNow] < autosaveFrequency * -60)
    {
		[self saveDocument:self];
		[lastSaved autorelease];
		lastSaved = [[NSDate date] retain];
    }
    
    // 
    if (exportImageThreadAlive)
		[exportProgressIndicator setDoubleValue:exportProgressTileCount];
    else if (!exportImageThreadAlive && exportProgressTileCount > 0)
    {
		// the export is finished, close the panel
		[NSApp endSheet:exportProgressPanel];
		[exportProgressPanel orderOut:nil];
		exportProgressTileCount = 0;
    }
}


- (void)synchronizeMenus
{
    [[fileMenu itemWithTag:1] setTitle:(paused ? @"Resume Matching" : @"Pause Matching")];
    
    [[viewMenu itemWithTitle:@"View Mosaic and Original"]
	setState:(viewMode == viewMosaicAndOriginal ? NSOnState : NSOffState)];
    [[viewMenu itemWithTitle:@"View Mosaic Alone"]
	setState:(viewMode == viewMosaicAlone ? NSOnState : NSOffState)];
    [[viewMenu itemWithTitle:@"View Mosaic Editor"]
	setState:(viewMode == viewMosaicEditor ? NSOnState : NSOffState)];

    [[viewMenu itemWithTitle:@"Show Status Bar"]
	setTitle:(statusBarShowing ? @"Hide Status Bar" : @"Show Status Bar")];
}


/*    [mosaicImageDrawWindow autorelease];
    mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
								  [mosaicImage size].width,
								  [mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];*/
- (void)setTileOutlines:(NSArray *)inTileOutlines
{
	[inTileOutlines retain];
	[tileOutlines autorelease];
	tileOutlines = inTileOutlines;
	
	[mosaicView setTileOutlines:tileOutlines];
	[totalTilesField setIntValue:[tileOutlines count]];
	
	mosaicStarted = NO;
}


- (void)spawnImageSourceThreads
{
	NSEnumerator	*imageSourceEnumerator = [imageSources objectEnumerator];
	ImageSource		*imageSource;
	
	while (imageSource = [imageSourceEnumerator nextObject])
		[NSThread detachNewThreadSelector:@selector(enumerateImageSourceInNewThread:) toTarget:self withObject:imageSource];
}


#pragma mark -
#pragma mark Thread entry points


- (void)createTileCollectionWithOutlines:(id)object
{
    if (tileOutlines == nil || originalImage == nil)
		return;
    else
		createTilesThreadAlive = YES;

    int					index = 0;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
    NSWindow			*drawWindow;
    NSBezierPath		*combinedOutline = [NSBezierPath bezierPath];

		// create an offscreen window to draw into (it will have a single, empty view the size of the window)
    drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000,
								  [originalImage size].width, 
								  [originalImage size].height)
					     styleMask:NSBorderlessWindowMask
					       backing:NSBackingStoreBuffered defer:NO];
    
    tiles = [[NSMutableArray arrayWithCapacity:[tileOutlines count]] retain];
    
	/* Loop through each tile outline and:
		1.  Create a Tile instance.
		2.  Copy out the rect of the original image that this tile covers.
		3.  Calculate an image mask that indicates which part of the copied rect is contained within the tile's outline.
	*/
	NSEnumerator	*tileOutlineEnumerator = [tileOutlines objectEnumerator];
	NSBezierPath	*tileOutline = nil;
    while (!documentIsClosing && (tileOutline = [tileOutlineEnumerator nextObject]))
	{
			// Create the tile and add it to the collection.
		Tile				*tile = [[[Tile alloc] initWithOutline:tileOutline fromDocument:self] autorelease];
		[tiles addObject:tile];
		
		index++;
		
			// Add this outline to the master path used to draw all of the tile outlines over the full image.
		[combinedOutline appendBezierPath:tileOutline];
		
			// Lock focus on our 'scratch' window.
		while (![[drawWindow contentView] lockFocusIfCanDraw])
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
		
			// Determine the bounds of the tile in the original image and in the scratch window.
		NSRect  origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
									  [tileOutline bounds].origin.y * [originalImage size].height,
									  [tileOutline bounds].size.width * [originalImage size].width,
									  [tileOutline bounds].size.height * [originalImage size].height),
				destRect = (origRect.size.width > origRect.size.height) ?
							NSMakeRect(0, 0, TILE_BITMAP_SIZE, TILE_BITMAP_SIZE * origRect.size.height / origRect.size.width) : 
							NSMakeRect(0, 0, TILE_BITMAP_SIZE * origRect.size.width / origRect.size.height, TILE_BITMAP_SIZE);
		
			// Start with a black image to overwrite any previous scratch contents.
		[[NSColor blackColor] set];
		[[NSBezierPath bezierPathWithRect:destRect] fill];
		
			// Copy out the portion of the original image contained by the tile's outline.
		[originalImage drawInRect:destRect fromRect:origRect operation:NSCompositeCopy fraction:1.0];
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
					writeToFile:[NSString stringWithFormat:@"/tmp/MacOSaiX/%4dMask.tiff", index] atomically:NO];
			#endif
        [[NSGraphicsContext currentContext] restoreGraphicsState];
		
			// Release our lock on the GUI in case the main thread needs it.
		[[drawWindow contentView] unlockFocus];
		
		extractionPercentComplete = (int)(index * 50.0 / [tileOutlines count]);
	}

//    [[drawWindow contentView] unlockFocus];
    [drawWindow close];

		// Calculate the neighboring tiles of each tile based on number of tiles away repeats are allowed.
		// For example if tiles are allowed to repeat past 1 neighbor than the direct neighbors of a tile
		// would be in its neighbor set.  If 2 then the direct neighbors and all of their direct neighbors
		// would be in the set.
		// TO DO: This currently only calculates the direct neighbors.
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	Tile			*tile = nil;
    while (!documentIsClosing && (tile = [tileEnumerator nextObject]))
	{
		NSRect	tileBounds = [[tile outline] bounds],
				zoomedTileBounds = NSZeroRect;
		
			// scale the rect up slightly so it overlaps with it's neighbors
		zoomedTileBounds.size = NSMakeSize(tileBounds.size.width * 1.01, tileBounds.size.height * 1.01);
		zoomedTileBounds.origin.x += NSMidX(tileBounds) - NSMidX(zoomedTileBounds);
		zoomedTileBounds.origin.y += NSMidY(tileBounds) - NSMidY(zoomedTileBounds);
		
			// Loop through the other tiles and add as neighbors any that intersect.
			// TO DO: This currently just checks if the bounding boxes of the tiles intersect.
			//        For non-rectangular tiles this will not be accurate enough.
		NSEnumerator	*tileEnumerator2 = [tiles objectEnumerator];
		Tile			*tile2 = nil;
		while (!documentIsClosing && (tile2 = [tileEnumerator2 nextObject]))
			if (tile2 != tile && NSIntersectsRect(zoomedTileBounds, [[tile2 outline] bounds]))
				[tile addNeighbor:tile2];
				
//		NSLog(@"Tile at %p has %d neighbors.", tile, [[tile neighbors] count]);
		extractionPercentComplete = 50 + (int)(index * 50.0 / [tileOutlines count]);
	}
	
    [(OriginalView *)originalView setTileOutlines:combinedOutline];
    
		// ...
	[self spawnImageSourceThreads];

    [pool release];
    
    createTilesThreadAlive = NO;
}


- (void)recalculateTileDisplayMatches:(id)object
{
/*
    NSAutoreleasePool	*pool, *pool2;
    float		overallMatch = 0.0;
    
    pool = [[NSAutoreleasePool alloc] init];
	NSAssert(pool, @"pool");
    
    mosaicImageDrawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0,
									      [mosaicImage size].width,
									      [mosaicImage size].height)
							 styleMask:NSBorderlessWindowMask
							   backing:NSBackingStoreBuffered defer:NO];
    while (!documentIsClosing)
	{
		// allocate a second auto-release pool
		pool2 = [[NSAutoreleasePool alloc] init];
		while (pool2 == nil)
		{
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
			pool2 = [[NSAutoreleasePool alloc] init];
		}
		
		integrateMatchesThreadAlive = YES;
		
		// wait until all tiles have at least one match before finding uniqueness
		// (otherwise, the orderedTiles order is the same as tiles and the
		//  screen gets updated too orderly.)
		while ([[tiles lastObject] matchCount] == 0 && !documentIsClosing)
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	
		[refindUniqueTilesLock lock];
		if (!refindUniqueTiles)
		{
			// there hasn't been a better match since we last recalculated, wait a second and check again
			[refindUniqueTilesLock unlock];
			integrateMatchesThreadAlive = YES;
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		}
		else
		{
			NSArray		*orderedTiles;
			NSMutableArray	*updatedTiles = [NSMutableArray arrayWithCapacity:10],
					*imagesInUse = [NSMutableArray arrayWithCapacity:[tiles count]];
			int			index;
			
			integrateMatchesThreadAlive = YES;
			refindUniqueTiles = NO;
			[refindUniqueTilesLock unlock];
			
			overallMatch = 0.0;
			
			orderedTiles = [tiles sortedArrayUsingSelector:@selector(compareBestMatchValue:)];
			for (index = 0; index < [orderedTiles count] && !documentIsClosing; index++)
			{
			Tile		*tile = [orderedTiles objectAtIndex:index];
			ImageMatch	*matches = [tile matches];
			int		matchCount = [tile matchCount];
			
			[tile lockMatches];
				if ([tile userChosenImageIndex] != -1)
				{
	//			overallMatch += (721 - sqrt( ??? ) / 721;
				[updatedTiles addObject:tile];
				[imagesInUse addObject:[tileImages objectAtIndex:[tile userChosenImageIndex]]];
				}
				else
				{
				int	i;
				BOOL	foundMatch = NO;
				
				for (i = 0; i < matchCount && !documentIsClosing; i++)
				{
					if (![imagesInUse containsObject:
						[tileImages objectAtIndex:matches[i].tileImageIndex]])
					{
					foundMatch = YES;
					if ([tile bestUniqueMatch] != &matches[i])
					{
						[updatedTiles addObject:tile];
						[tile setBestUniqueMatchIndex:i];
					}
					[imagesInUse addObject:[tileImages objectAtIndex:matches[i].tileImageIndex]];
					
					break;
					}
				}
				
				if (foundMatch == NO && [tile bestUniqueMatch] != nil && !documentIsClosing)
				{	// this tile had a match but has no matching image now
					[tile setBestUniqueMatchIndex:-1];
					[updatedTiles addObject:tile];
				}
				
				if (foundMatch)
					overallMatch += (721 - sqrt([tile bestUniqueMatchValue])) / 721;
				}
				
				if ([updatedTiles count] >= 10 && !documentIsClosing) // && !paused)
				[self updateMosaicImage:updatedTiles];
			[tile unlockMatches];
			
			[refindUniqueTilesLock lock];
				//if (refindUniqueTiles) index = [orderedTiles count];
			[refindUniqueTilesLock unlock];
			}
			if ([updatedTiles count] > 0 && !documentIsClosing)	// && !paused)
			[self updateMosaicImage:updatedTiles];
			overallMatch = overallMatch * 100.0 / [tiles count];
		}
		
		[pool2 release];
	}	// end of while (!documentIsClosing)
    
    [mosaicImageDrawWindow close];

    [pool release];

    integrateMatchesThreadAlive = NO;
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
	
	while (!documentIsClosing && sourceHasMoreImages)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		
		[imageSource waitWhilePaused];	// pause if the user says so	(why message the image source???)
		
			// Get the next image from the source (and identifier if there is one)
		id<NSCopying>   imageIdentifier = nil;
		NSImage			*image = nil;
		if ([imageSource canRefetchImages])
			imageIdentifier = [imageSource nextImageIdentifier];
		image = [imageSource imageForIdentifier:imageIdentifier];
		
		if (image)
		{
			[imageQueueLock lock];	// this will be locked if the queue is full
				while ([imageQueue count] > MAXIMAGEURLS)
				{
					[imageQueueLock unlock];
					[imageQueueLock lock];
				}
				[imageQueue addObject:[NSDictionary dictionaryWithObjectsAndKeys:
											image, @"Image",
											imageSource, @"Image Source", 
											imageIdentifier, @"Image Identifier", 
											nil]];
			[imageQueueLock unlock];

			if (!calculateImageMatchesThreadAlive)
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
	[calculateImageMatchesThreadLock lock];
		if (calculateImageMatchesThreadAlive)
		{
                // Another copy is running, just exit.
			[calculateImageMatchesThreadLock unlock];
			[pool release];
			return;
		}
		calculateImageMatchesThreadAlive = YES;
	[calculateImageMatchesThreadLock unlock];

    NSImage				*scratchImage = [[[NSImage alloc] initWithSize:NSMakeSize(1024, 1024)] autorelease];
	
	NSLog(@"Calculating image matches\n");

	[imageQueueLock lock];
    while (!documentIsClosing && [imageQueue count] > 0)
	{
			// As long as the image source threads are feeding images into the queue this loop
			// will continue running so create a pool just for this pass through the loop.
		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		NSMutableArray		*cachedReps = nil;
		int					index;
		BOOL				queueLocked = NO;
		
			// pull the next image from the queue
		NSDictionary		*nextImageDict = [[[imageQueue objectAtIndex:0] retain] autorelease];
		[imageQueue removeObjectAtIndex:0];
		
			// let the image source threads add more images if the queue is not full
		if ([imageQueue count] < MAXIMAGEURLS)
			[imageQueueLock unlock];
		else
			queueLocked = YES;
		
		NSImage			*pixletImage = [nextImageDict objectForKey:@"Image"];
		ImageSource		*pixletImageSource = [nextImageDict objectForKey:@"Image Source"];
		id<NSCopying>   pixletImageIdentifier = [nextImageDict objectForKey:@"Image Identifier"];

			// Cache this image to disk.
			// TODO: how does the image ever get purged?
		if ([pixletImageSource canRefetchImages])
		{
				// Just cache a thumbnail, no need to waste the disk since we can refetch.
			NSSize				thumbnailSize, pixletImageSize = [pixletImage size];
			if (pixletImageSize.width > pixletImageSize.height)
				thumbnailSize = NSMakeSize(kThumbnailMax, pixletImageSize.height * kThumbnailMax / pixletImageSize.width);
			else
				thumbnailSize = NSMakeSize(pixletImageSize.width * kThumbnailMax / pixletImageSize.height, kThumbnailMax);
			NSImage				*thumbnailImage = [[[NSImage alloc] initWithSize:thumbnailSize] autorelease];
//			NSBitmapImageRep	*thumbnailRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil 
//																						 pixelsWide:thumbnailSize.width 
//																						 pixelsHigh:thumbnailSize.height 
//																					  bitsPerSample:8 
//																					samplesPerPixel:3 
//																						   hasAlpha:NO 
//																						   isPlanar:NO 
//																					 colorSpaceName:NSDeviceRGBColorSpace 
//																						bytesPerRow:0 
//																					   bitsPerPixel:0] autorelease];
//			[thumbnailImage addRepresentation:thumbnailRep];
			[thumbnailImage lockFocus];	//OnRepresentation:thumbnailRep];
				[pixletImage drawInRect:NSMakeRect(0.0, 0.0, thumbnailSize.width, thumbnailSize.height) 
							   fromRect:NSMakeRect(0.0, 0.0, pixletImageSize.width, pixletImageSize.height) 
							  operation:NSCompositeCopy 
							   fraction:1.0];
			[thumbnailImage unlockFocus];
			[self cacheImage:thumbnailImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
		}
		else
		{
				// Cache the full sized image since we can't refetch it from the image source.
			[self cacheImage:pixletImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
		}

		cachedReps = [NSMutableArray arrayWithCapacity:0];
		
			// loop through the tiles and compute the pixlet's match
		for (index = 0; index < [tiles count] && !documentIsClosing; index++)
		{
			Tile	*tile = nil;
			float	scale;
			NSRect	subRect;
			int	cachedRepIndex;
	
			tile = [tiles objectAtIndex:index];
			
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
													withIdentifier:pixletImageIdentifier
												   fromImageSource:pixletImageSource])
			{
				[refreshTilesSetLock lock];
					[refreshTilesSet addObject:tile];
					[refreshTilesSet addObjectsFromArray:[tile neighbors]];
				[refreshTilesSetLock unlock];

				if (!calculateDisplayedImagesThreadAlive)
					[NSApplication detachDrawingThread:@selector(calculateDisplayedImages:) toTarget:self withObject:nil];
			}
		}

		imagesMatched++;
		
		if (!queueLocked) [imageQueueLock lock];

		[pool2 release];
	}
	[imageQueueLock unlock];

	[calculateImageMatchesThreadLock lock];
		calculateImageMatchesThreadAlive = NO;
	[calculateImageMatchesThreadLock unlock];

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
	[calculateDisplayedImagesThreadLock lock];
		if (calculateDisplayedImagesThreadAlive)
		{
                // another copy is already running, just return
			[calculateDisplayedImagesThreadLock unlock];
			[pool release];
			return;
		}
		calculateDisplayedImagesThreadAlive = YES;
	[calculateDisplayedImagesThreadLock unlock];

//	NSLog(@"Calculating displayed images\n");

    BOOL	tilesAddedToRefreshSet = NO;
    
		// set up a transform so we can scale the tiles to the mosaic's size (tiles are defined on a unit square)
	NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform translateXBy:0.5 yBy:0.5];	// line up with pixel boundaries
	[transform scaleXBy:[mosaicImage size].width yBy:[mosaicImage size].height];

        // Make a local copy of the set of tiles to refresh and then clear 
        // the main set so new tiles can be added while we work.
	[refreshTilesSetLock lock];
        NSArray	*tilesToRefresh = [refreshTilesSet allObjects];
        [refreshTilesSet removeAllObjects];
    [refreshTilesSetLock unlock];
    
        // Now loop through each tile in the set and re-calculate which image it should use
    NSEnumerator	*tileEnumerator = [tilesToRefresh objectEnumerator];
    Tile			*tileToRefresh = nil;
    while (!documentIsClosing && (tileToRefresh = [tileEnumerator nextObject]))
        if ([tileToRefresh calculateBestMatch])
        {
			// The image to display for this tile changed so update the mosaic image and add the tile's neighbors 
			// to the set of tiles to refresh in case they can use the image we just stopped using.
            
            tilesAddedToRefreshSet = YES;
            
            [refreshTilesSetLock lock];
                [refreshTilesSet addObjectsFromArray:[tileToRefresh neighbors]];
            [refreshTilesSetLock unlock];
            
			ImageMatch		*imageMatch = [tileToRefresh displayedImageMatch];
            NSImage			*matchImage = [self cachedImageForIdentifier:[imageMatch imageIdentifier] 
															  fromSource:[imageMatch imageSource]];
            if (!matchImage)
                NSLog(@"Could not load image\t%@", [imageMatch imageIdentifier]);
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
                [mosaicImageLock lock];
                    NS_DURING
                        [mosaicImage lockFocus];
                            [clipPath setClip];
                            [matchImage drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
                        [mosaicImage unlockFocus];
                    NS_HANDLER
                        NSLog(@"Could not lock focus on mosaic image");
                    NS_ENDHANDLER
                    mosaicImageUpdated = YES;
                [mosaicImageLock unlock];
            }
        }

	[calculateDisplayedImagesThreadLock lock];
	    calculateDisplayedImagesThreadAlive = NO;
	[calculateDisplayedImagesThreadLock unlock];

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
    
    if (![[mosaicImageDrawWindow contentView] lockFocusIfCanDraw])
	NSLog(@"Could not lock focus for mosaic image update.");
    else
    {
	[[NSColor whiteColor] set];
	[[NSBezierPath bezierPathWithRect:[[mosaicImageDrawWindow contentView] bounds]] fill];
	// start with the current image
	[mosaicImage compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
	transform = [NSAffineTransform transform];
	[transform scaleXBy:[mosaicImage size].width yBy:[mosaicImage size].height];
	while (!documentIsClosing && [updatedTiles count] > 0)
	{
	    Tile		*tile = [updatedTiles objectAtIndex:0];
	    NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
	    NSImage		*matchImage;
	    NSRect		drawRect;
	    
	    if ([tile userChosenImageIndex] != -1)
	    {
		matchImage = [[tileImages objectAtIndex:[tile userChosenImageIndex]] image];
		if (matchImage == nil)
		    NSLog(@"Could not load image\t%@",
				[[tileImages objectAtIndex:[tile userChosenImageIndex]] imageIdentifier]);
	    }
	    else
	    {
		if ([tile bestUniqueMatch] != nil)
		{
		    matchImage = [[tileImages objectAtIndex:[tile bestUniqueMatch]->tileImageIndex] image];
		    if (matchImage == nil)
			NSLog(@"Could not load image\t%@",
			   [[tileImages objectAtIndex:[tile bestUniqueMatch]->tileImageIndex] imageIdentifier]);
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
	[mosaicImageLock lock];
	    newRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:
						    [[mosaicImageDrawWindow contentView] bounds]];
	    [mosaicImage autorelease];
	    mosaicImage = [[NSImage alloc] initWithSize:[mosaicImage size]];
	    [mosaicImage addRepresentation:newRep];
	    [newRep release];
	    mosaicImageUpdated = YES;
	[mosaicImageLock unlock];
	[[mosaicImageDrawWindow contentView] unlockFocus];
    }
    
    [pool release];
*/
}


#pragma mark -
#pragma mark Tile setup methods

- (void)setTilesSetupPlugIn:(id)sender
{
	NSString		*selectedPlugIn = [tilesSetupPopUpButton titleOfSelectedItem];
	NSEnumerator	*enumerator = [[[NSApp delegate] tilesSetupControllerClasses] objectEnumerator];
	Class			tilesSetupControllerClass;
	
	while (tilesSetupControllerClass = [enumerator nextObject])
		if ([selectedPlugIn isEqualToString:[tilesSetupControllerClass name]])
		{
			if (tilesSetupController)
			{
					// remove the tile setup that was have been set before
				[tilesSetupView setContentView:nil];
				[tilesSetupController release];
			}
			
				// create an instance of the class for this document
			tilesSetupController = [[tilesSetupControllerClass alloc] init];
			
				// let the plug-in know how to message back to us
			[tilesSetupController setDocument:self];
			
				// Display the plug-in's view
			[tilesSetupView setContentView:[tilesSetupController setupView]];
			
			return;
		}
}


#pragma mark -
#pragma mark Image Sources methods

- (void)setImageSourcesPlugIn:(id)sender
{
		// Display the view chosen in the menu
	[imageSourcesTabView selectTabViewItemAtIndex:[imageSourcesPopUpButton indexOfSelectedItem]];
	
		// If the user just chose to add an image source then tell the appropriate image controller
	if ([imageSourcesPopUpButton indexOfSelectedItem] > 0)
		[[[imageSourcesPopUpButton selectedItem] representedObject] editImageSource:nil];
}


- (void)showCurrentImageSources
{
	[imageSourcesPopUpButton selectItemAtIndex:0];
	[self setImageSourcesPlugIn:self];
}


- (void)addImageSource:(ImageSource *)imageSource
{
		// if it's a new image source then add it to the array (paused if we haven't started yet)
	if ([imageSources indexOfObjectIdenticalTo:imageSource] == NSNotFound)
	{
		if (!mosaicStarted)
			[imageSource pause];
		[imageSources addObject:imageSource];
	}
	[imageSourcesTable reloadData];
}


#pragma mark -
#pragma mark Image cache methods


- (NSString *)filePathForCachedImageID:(long)imageID
{
	return [cachedImagesPath stringByAppendingPathComponent:[NSString stringWithFormat:@"Image %u.jpg", imageID]];
}


- (NSMutableDictionary *)cacheDictionaryForImageSource:(ImageSource *)imageSource
{
	if (!cachedImagesDictionary)
		cachedImagesDictionary = [[NSMutableDictionary dictionary] retain];
	
		// locking?
	NSNumber			*sourceKey = [NSNumber numberWithUnsignedLong:(unsigned long)imageSource];
	NSMutableDictionary *sourceDict = [cachedImagesDictionary objectForKey:sourceKey];
	
	if (!sourceDict)
	{
		sourceDict = [NSMutableDictionary dictionary];
		[cachedImagesDictionary setObject:sourceDict forKey:sourceKey];
	}
	
	return sourceDict;
}


- (void)cacheImage:(NSImage *)image withIdentifier:(id<NSCopying>)imageIdentifier fromSource:(ImageSource *)imageSource
{
	[cacheLock lock];
		long		imageID = cachedImageCount++;
		
			// Permanently store the image.  Squeeze it down to fit within one allocation block on disk (4KB).
		NSBitmapImageRep	*bitmapRep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
		NSData				*imageData = nil;
		float				compressionFactor = 1.0;
		do
		{
			imageData = [bitmapRep representationUsingType:NSJPEGFileType 
												properties:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor]
																					   forKey:NSImageCompressionFactor]];
			compressionFactor -= 0.05;
		} while ([imageData length] > 4096);
		[imageData writeToFile:[self filePathForCachedImageID:imageID] atomically:NO];
		
		NSMutableDictionary	*imageSourceCache = [self cacheDictionaryForImageSource:imageSource];
		
			// Associate the ID with the image source/image identifier combo
		[imageSourceCache setObject:[NSNumber numberWithLong:imageID] forKey:imageIdentifier];
		
			// Cache the image for efficient retrieval.
		[imageCache setObject:image forKey:[NSNumber numberWithLong:imageID]];
		[orderedCache insertObject:image atIndex:0];
		[orderedCacheID insertObject:[NSNumber numberWithLong:imageID] atIndex:0];
		if ([orderedCache count] > IMAGE_CACHE_SIZE)
		{
			[imageCache removeObjectForKey:[orderedCacheID lastObject]];
			[orderedCache removeLastObject];
			[orderedCacheID removeLastObject];
		}
	[cacheLock unlock];
}


- (NSImage *)cachedImageForIdentifier:(id<NSCopying>)imageIdentifier fromSource:(ImageSource *)imageSource
{
	NSImage		*image = nil;
	
	[cacheLock lock];
		long		imageID = [[[self cacheDictionaryForImageSource:imageSource] objectForKey:imageIdentifier] longValue];
		NSNumber	*imageKey = [NSNumber numberWithLong:imageID];
		
		image = [imageCache objectForKey:imageKey];
		if (image)
        {
			int index = [orderedCache indexOfObjectIdenticalTo:image];
            if (index != NSNotFound)
            {
                [orderedCache removeObjectAtIndex:index];
                [orderedCacheID removeObjectAtIndex:index];
            }
        }
		else
		{
			image = [[[NSImage alloc] initWithContentsOfFile:[self filePathForCachedImageID:imageID]] autorelease];
            if (!image)
                NSLog(@"Huh?");
			[imageCache setObject:image forKey:imageKey];
		}
		[orderedCache insertObject:image atIndex:0];
		[orderedCacheID insertObject:[NSNumber numberWithLong:imageID] atIndex:0];
		if ([orderedCache count] > IMAGE_CACHE_SIZE)
		{
			[imageCache removeObjectForKey:[NSNumber numberWithLong:imageID]];
			[orderedCache removeLastObject];
			[orderedCacheID removeLastObject];
		}
	[cacheLock unlock];
	
	return image;
}


#pragma mark -
#pragma mark Editor methods


- (void)selectTileAtPoint:(NSPoint)thePoint
{
    int	i;
    
    if ([mosaicView viewMode] != viewHighlightedTile) return;
    
    thePoint.x = thePoint.x / [mosaicView frame].size.width;
    thePoint.y = thePoint.y / [mosaicView frame].size.height;
    
        // TBD: this isn't terribly efficient...
    for (i = 0; i < [tiles count]; i++)
        if ([[[tiles objectAtIndex:i] outline] containsPoint:thePoint])
        {
            [editorLabel setStringValue:@"Image to use for selected tile:"];
            [editorUseCustomImage setEnabled:YES];
            [editorUseBestUniqueMatch setEnabled:YES];
            selectedTile = [tiles objectAtIndex:i];
            
            [mosaicView highlightTile:selectedTile];
            [editorTable scrollRowToVisible:0];
            [self updateEditor];
            
            return;
        }
}


- (void)animateSelectedTile:(id)timer
{
    if (selectedTile != nil && !documentIsClosing)
        [mosaicView animateHighlight];
}


- (void)updateEditor
{
    [selectedTileImages release];
    
    if (selectedTile == nil)
    {
        [editorUseCustomImage setState:NSOffState];
        [editorUseBestUniqueMatch setState:NSOffState];
        [editorUserChosenImage setImage:nil];
        [editorChooseImage setEnabled:NO];
        [editorUseSelectedImage setEnabled:NO];
        selectedTileImages = [[NSMutableArray arrayWithCapacity:0] retain];
    }
    else
    {
        if ([selectedTile userChosenImageMatch])
        {
            [editorUseCustomImage setState:NSOnState];
            [editorUseBestUniqueMatch setState:NSOffState];
// TODO:            [editorUserChosenImage setImage:[[selectedTile userChosenImageMatch] image]];
        }
        else
        {
            [editorUseCustomImage setState:NSOffState];
            [editorUseBestUniqueMatch setState:NSOnState];
            [editorUserChosenImage setImage:nil];
            
            NSImage	*image = [[[NSImage alloc] initWithSize:[[selectedTile bitmapRep] size]] autorelease];
            [image addRepresentation:[selectedTile bitmapRep]];
            [editorUserChosenImage setImage:image];
        }
    
        [editorChooseImage setEnabled:YES];
        [editorUseSelectedImage setEnabled:YES];
        
        selectedTileImages = [[NSMutableArray arrayWithCapacity:[selectedTile matchCount]] retain];
        int	i;
        for (i = 0; i < [selectedTile matchCount]; i++)
            [selectedTileImages addObject:[NSNull null]];
    }
    
    [editorTable reloadData];
}


- (BOOL)showTileMatchInEditor:(ImageMatch *)tileMatch selecting:(BOOL)selecting
{
//    if (selectedTile == nil) return NO;
//    
//    int	i;
//    for (i = 0; i < [selectedTile matchCount]; i++)
//        if (&([selectedTile matches][i]) == tileMatch)
//        {
//            if (selecting)
//                [editorTable selectRow:i byExtendingSelection:NO];
//            [editorTable scrollRowToVisible:i];
//            return YES;
//        }
    
    return NO;
}


- (NSImage *)createEditorImage:(int)rowIndex
{
    NSImage				*image = nil;
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSSize				tileSize = [[selectedTile outline] bounds].size;
    float				scale;
    NSPoint				origin;
    NSBezierPath		*bezierPath = [NSBezierPath bezierPath];
    
    [selectedTile lockMatches];
		ImageMatch	*imageMatch = [[selectedTile matches] objectAtIndex:rowIndex];
        image = [self cachedImageForIdentifier:[imageMatch imageIdentifier] fromSource:[imageMatch imageSource]];
    [selectedTile unlockMatches];
    if (image == nil)
        return [NSImage imageNamed:@"Blank"];
	
    image = [[image copy] autorelease];
    
    // scale the image to at most 80 pixels (the size of the editor column)
    if ([image size].width > [image size].height)
        [image setSize:NSMakeSize(80, 80 / [image size].width * [image size].height)];
    else
        [image setSize:NSMakeSize(80 / [image size].height * [image size].width, 80)];

    tileSize.width *= [mosaicImage size].width;
    tileSize.height *= [mosaicImage size].height;
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
    [transform scaleXBy:[mosaicImage size].width yBy:[mosaicImage size].height];
    [transform translateXBy:[[selectedTile outline] bounds].origin.x * -1
			yBy:[[selectedTile outline] bounds].origin.y * -1];
    
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
	[bezierPath appendBezierPath:[transform transformBezierPath:[selectedTile outline]]];
	[bezierPath fill];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set]; //darken
	[bezierPath stroke];
	
	// add a badge if it's the user chosen image
//	if ([[selectedTile matches] objectAtIndex:rowIndex] == [selectedTile displayMatch])
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
    [selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
    return image;
}


- (void)useCustomImage:(id)sender
{
/* TBD
    if ([selectedTile bestUniqueMatch] != nil)
	[selectedTile setUserChosenImageIndex:[selectedTile bestUniqueMatch]->tileImageIndex];
    else
	[selectedTile setUserChosenImageIndex:[selectedTile bestMatch]->tileImageIndex];
    [selectedTile setBestUniqueMatchIndex:-1];
	
    [refindUniqueTilesLock lock];
	refindUniqueTiles = YES;
    [refindUniqueTilesLock unlock];

    [self updateEditor];
*/
}


- (void)allowUserToChooseImage:(id)sender
{
/*
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:[NSImage imageFileTypes]
		    modalForWindow:mainWindow
		     modalDelegate:self
		    didEndSelector:@selector(allowUserToChooseImageOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
*/}


- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet 
								   returnCode:(int)returnCode
								  contextInfo:(void *)context
{
/*
    CachedImage	*cachedImage;
    
    if (returnCode != NSOKButton) return;

    cachedImage = [[[CachedImage alloc] initWithIdentifier:[[sheet URLs] objectAtIndex:0] fromImageSource:manualImageSource] autorelease];
//TBD    [selectedTile setUserChosenImageIndex:[self addTileImage:cachedImage]];
//TBD    [selectedTile setBestUniqueMatchIndex:-1];
    
    [refindUniqueTilesLock lock];
//TBD	refindUniqueTiles = YES;
    [refindUniqueTilesLock unlock];

    [self updateEditor];

    [self updateChangeCount:NSChangeDone];
*/
}


- (void)useBestUniqueMatch:(id)sender
{
/*	TBD
    [selectedTile setUserChosenImageIndex:-1];
    
    [refindUniqueTilesLock lock];
	refindUniqueTiles = YES;
    [refindUniqueTilesLock unlock];

    [self updateEditor];
    
    [self updateChangeCount:NSChangeDone];
*/
}


- (void)useSelectedImage:(id)sender
{
/* TBD
    long	index = [selectedTile matches][[editorTable selectedRow]].tileImageIndex;
    
    [selectedTile setUserChosenImageIndex:index];
    [selectedTile setBestUniqueMatchIndex:-1];

    [refindUniqueTilesLock lock];
	refindUniqueTiles = YES;
    [refindUniqueTilesLock unlock];

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
    if (mode == viewMode) return;
    
    viewMode = mode;
	[mosaicView highlightTile:nil];
	switch (mode)
	{
		case viewMosaicAndOriginal:
			[mosaicView setViewMode:viewMosaic];
			[utilitiesTabView selectTabViewItemWithIdentifier:@"Original Image"];
			[utilitiesDrawer open];
			break;
		case viewMosaicAndTilesSetup:
			[mosaicView setViewMode:viewTilesOutline];
			[utilitiesTabView selectTabViewItemWithIdentifier:@"Tiles Setup"];
			[utilitiesDrawer open];
			break;
		case viewMosaicAndRegions:
			[mosaicView setViewMode:viewImageRegions];
			[utilitiesTabView selectTabViewItemWithIdentifier:@"Image Regions"];
			[utilitiesDrawer open];
			break;
		case viewMosaicEditor:
			[mosaicView setViewMode:viewHighlightedTile];
			[mosaicView highlightTile:selectedTile];
			[self updateEditor];
			[editorTable scrollRowToVisible:0];
			[editorTable reloadData];
			[utilitiesTabView selectTabViewItemWithIdentifier:@"Tile Editor"];
			[utilitiesDrawer open];
			break;
		case viewMosaicAlone:
			[mosaicView setViewMode:viewMosaic];
			[utilitiesDrawer close];
			break;
    }
    [self synchronizeMenus];
}


- (void)setZoom:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
		if ([[sender title] isEqualToString:@"Minimum"]) zoom = 0.0;
		if ([[sender title] isEqualToString:@"Medium"]) zoom = 0.5;
		if ([[sender title] isEqualToString:@"Maximum"]) zoom = 1.0;
    }
    else zoom = [zoomSlider floatValue];
    
    // set the zoom...
    zoom = zoom;
    [zoomSlider setFloatValue:zoom];
    
    if (mosaicImage != nil)
    {
		NSRect	bounds, frame;
		
		frame = NSMakeRect(0, 0,
				[[mosaicScrollView contentView] frame].size.width + ([mosaicImage size].width - 
				[[mosaicScrollView contentView] frame].size.width) * zoom,
				[[mosaicScrollView contentView] frame].size.height + ([mosaicImage size].height - 
				[[mosaicScrollView contentView] frame].size.height) * zoom);
		bounds = NSMakeRect(NSMidX([[mosaicScrollView contentView] bounds]) * frame.size.width / 
						[mosaicView frame].size.width,
					NSMidY([[mosaicScrollView contentView] bounds]) * frame.size.height / 
						[mosaicView frame].size.height,
					frame.size.width -
						(frame.size.width - [[mosaicScrollView contentView] frame].size.width) * zoom,
					frame.size.height -
						(frame.size.height - [[mosaicScrollView contentView] frame].size.height) * zoom);
		bounds.origin.x = MIN(MAX(0, bounds.origin.x - bounds.size.width / 2.0),
							  frame.size.width - bounds.size.width);
		bounds.origin.y = MIN(MAX(0, bounds.origin.y - bounds.size.height / 2.0),
							  frame.size.height - bounds.size.height);
		[mosaicView setFrame:frame];
		[[mosaicScrollView contentView] setBounds:bounds];
		[mosaicScrollView setNeedsDisplay:YES];
    }
    [originalView setNeedsDisplay:YES];
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([[menuItem title] isEqualToString:@"Center on Selected Tile"])
	return (viewMode == viewMosaicEditor && selectedTile != nil && zoom != 0.0);
    else
	return [super validateMenuItem:menuItem];
}


- (void)centerViewOnSelectedTile:(id)sender
{
    NSPoint	contentOrigin = NSMakePoint(NSMidX([[selectedTile outline] bounds]),
					     NSMidY([[selectedTile outline] bounds]));
    
    contentOrigin.x *= [mosaicView frame].size.width;
    contentOrigin.x -= [[mosaicScrollView contentView] bounds].size.width / 2;
    if (contentOrigin.x < 0) contentOrigin.x = 0;
    if (contentOrigin.x + [[mosaicScrollView contentView] bounds].size.width >
		[mosaicView frame].size.width)
		contentOrigin.x = [mosaicView frame].size.width - 
				[[mosaicScrollView contentView] bounds].size.width;

    contentOrigin.y *= [mosaicView frame].size.height;
    contentOrigin.y -= [[mosaicScrollView contentView] bounds].size.height / 2;
    if (contentOrigin.y < 0) contentOrigin.y = 0;
    if (contentOrigin.y + [[mosaicScrollView contentView] bounds].size.height >
		[mosaicView frame].size.height)
	contentOrigin.y = [mosaicView frame].size.height - 
			  [[mosaicScrollView contentView] bounds].size.height;

    [[mosaicScrollView contentView] scrollToPoint:contentOrigin];
    [mosaicScrollView reflectScrolledClipView:[mosaicScrollView contentView]];
}


- (void)mosaicViewDidScroll:(NSNotification *)notification
{
    NSRect	orig, content,doc;
    
    if ([notification object] != mosaicScrollView) return;
    
    orig = [originalView bounds];
    content = [[mosaicScrollView contentView] bounds];
    doc = [mosaicView frame];
    [originalView setFocusRect:NSMakeRect(content.origin.x * orig.size.width / doc.size.width,
					  content.origin.y * orig.size.height / doc.size.height,
					  content.size.width * orig.size.width / doc.size.width,
					  content.size.height * orig.size.height / doc.size.height)];
    [originalView setNeedsDisplay:YES];
}


- (void)toggleStatusBar:(id)sender
{
    NSRect	newFrame = [mainWindow frame];
    int		i;
    
    if (statusBarShowing)
    {
		statusBarShowing = NO;
		removedSubviews = [[statusBarView subviews] copy];
		for (i = 0; i < [removedSubviews count]; i++)
			[[removedSubviews objectAtIndex:i] removeFromSuperview];
		[statusBarView retain];
		[statusBarView removeFromSuperview];
		newFrame.origin.y += [statusBarView frame].size.height;
		newFrame.size.height -= [statusBarView frame].size.height;
		newFrame.size = [self windowWillResize:mainWindow toSize:newFrame.size];
		[mainWindow setFrame:newFrame display:YES animate:YES];
		[[viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
    }
    else
    {
		statusBarShowing = YES;
		newFrame.origin.y -= [statusBarView frame].size.height;
		newFrame.size.height += [statusBarView frame].size.height;
		newFrame.size = [self windowWillResize:mainWindow toSize:newFrame.size];
		[mainWindow setFrame:newFrame display:YES animate:YES];
	
		[statusBarView setFrame:NSMakeRect(0, [[mosaicScrollView superview] frame].size.height - [statusBarView frame].size.height, [[mosaicScrollView superview] frame].size.width, [statusBarView frame].size.height)];
		[[mosaicScrollView superview] addSubview:statusBarView];
		[statusBarView release];
		for (i = 0; i < [removedSubviews count]; i++)
		{
			[[removedSubviews objectAtIndex:i] setFrameSize:NSMakeSize([statusBarView frame].size.width,[[removedSubviews objectAtIndex:i] frame].size.height)];
			[statusBarView addSubview:[removedSubviews objectAtIndex:i]];
		}
		[removedSubviews release]; removedSubviews = nil;
	
		[[viewMenu itemWithTitle:@"Show Status Bar"] setTitle:@"Hide Status Bar"];
    }
}


- (void)setShowOutlines:(id)sender
{
    [originalView setDisplayTileOutlines:([showOutlinesSwitch state] == NSOnState)];
}


#pragma mark -
#pragma mark Utility methods


- (void)toggleImageSourcesDrawer:(id)sender
{
    [utilitiesDrawer toggle:(id)sender];
    if ([utilitiesDrawer state] == NSDrawerClosedState)
		[[viewMenu itemWithTitle:@"Show Image Sources"] setTitle:@"Hide Image Sources"];
    else
		[[viewMenu itemWithTitle:@"Hide Image Sources"] setTitle:@"Show Image Sources"];
}


- (void)togglePause:(id)sender
{
	NSEnumerator	*imageSourceEnumerator = [imageSources objectEnumerator];
	ImageSource		*imageSource;

	if (paused)
	{
		if (!mosaicStarted) [self startMosaic];	// spawn the image source threads
		[pauseToolbarItem setLabel:@"Pause"];
		[pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[[fileMenu itemWithTitle:@"Resume Matching"] setTitle:@"Pause Matching"];
		while (imageSource = [imageSourceEnumerator nextObject])
			[imageSource resume];
		paused = NO;
	}
	else
	{
		[pauseToolbarItem setLabel:@"Resume"];
		[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		[[fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
		while (imageSource = [imageSourceEnumerator nextObject])
			[imageSource pause];
		paused = YES;
	}
}


#pragma mark -
#pragma mark Export image methods

- (void)beginExportImage:(id)sender
{
    savePanel = [[NSSavePanel savePanel] retain];

/*
    if ([[tiles lastObject] matchCount] < [tiles count])
    {
	NSBeginAlertSheet(@"Export Image", nil, nil, nil, mainWindow, self, nil, nil, nil,
	    @"Not enough images have been found.");
	return;
    }
*/
	
    if (!paused) [self togglePause:self];
    
    if ([exportWidth intValue] == 0)
    {
        [exportWidth setIntValue:[originalImage size].width * 4];
        [exportHeight setIntValue:[originalImage size].height * 4];
    }
    [savePanel setAccessoryView:exportPanelAccessoryView];
    
    // ask the user where to save the image
    [savePanel beginSheetForDirectory:NSHomeDirectory()
				 file:@"Mosaic.jpg"
		       modalForWindow:mainWindow
			modalDelegate:self
		       didEndSelector:@selector(exportImageSavePanelDidEnd:returnCode:contextInfo:)
			  contextInfo:savePanel];
}


- (IBAction)setJPEGExport:(id)sender
{
    exportFormat = NSJPEGFileType;
    [savePanel setRequiredFileType:@"jpg"];
}


- (IBAction)setTIFFExport:(id)sender;
{
    exportFormat = NSTIFFFileType;
    [savePanel setRequiredFileType:@"tiff"];
}


- (IBAction)setExportWidthFromHeight:(id)sender
{
    [exportWidth setIntValue:[exportHeight intValue] / [originalImage size].height * [originalImage size].width + 0.5];
}


- (IBAction)setExportHeightFromWidth:(id)sender
{
    [exportHeight setIntValue:[exportWidth intValue] / [originalImage size].width * [originalImage size].height + 0.5];
}


- (void)exportImageSavePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
		[exportProgressLabel setStringValue:@"Waiting to find all unique tiles..."];
		[exportProgressIndicator setIndeterminate:YES];
		[exportProgressIndicator startAnimation:self];
		
		[NSApp beginSheet:exportProgressPanel
		   modalForWindow:mainWindow
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
		
		[NSApplication detachDrawingThread:@selector(exportImage:)
								  toTarget:self 
								withObject:[(NSSavePanel *)savePanel filename]];
	}
	
	[savePanel release];
    savePanel = nil;
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
    BOOL		wasPaused = paused;
    
    exportImageThreadAlive = YES;
    
    pool = [[NSAutoreleasePool alloc] init];
	NSAssert(pool, @"Could not allocate pool");

//    while (calculateDisplayedImagesThreadAlive)
//		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    [exportProgressLabel setStringValue:@"Exporting mosaic image..."];
    [exportProgressIndicator stopAnimation:self];
    [exportProgressIndicator setMaxValue:[tiles count]];
    [exportProgressIndicator setIndeterminate:NO];
    [exportProgressPanel displayIfNeeded];
    
    exportImage = [[NSImage alloc] initWithSize:NSMakeSize([exportWidth intValue], [exportHeight intValue])];
//    exportImage = [[NSImage alloc] initWithSize:NSMakeSize(2400, 2400 * [originalImage size].height / 
//								 [originalImage size].width)];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		NSLog(@"Could not lock focus on export image");
	NS_ENDHANDLER
    transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
    for (i = 0; i < [tiles count]; i++)
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
        Tile				*tile = [tiles objectAtIndex:i];
//        CachedImage			*cachedImage = [tileImages objectAtIndex:([tile userChosenImageIndex] == -1) ?
//                                        [tile bestUniqueMatch]->tileImageIndex :
//                                        [tile userChosenImageIndex]];
        NSBezierPath		*clipPath = [transform transformBezierPath:[tile outline]];
//        int					imageFetchCount = 0;
        
        exportProgressTileCount = i;
        [NSGraphicsContext saveGraphicsState];
        [clipPath addClip];
        
//        do
//            pixletImage = [[cachedImage imageSource] imageForIdentifier:[cachedImage imageIdentifier]];
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

    if (exportFormat == NSJPEGFileType)
        bitmapData = [exportRep representationUsingType:NSJPEGFileType properties:nil];
    else
        bitmapData = [exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
    [bitmapData writeToFile:exportFilename atomically:YES];
    
    [NSApp endSheet:exportProgressPanel];
    [exportProgressPanel orderOut:nil];

    [pool release];
    [exportRep release];
    [exportImage release];

    paused = wasPaused;
    exportImageThreadAlive = NO;
    
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
    float	aspectRatio = [mosaicImage size].width / [mosaicImage size].height,
			windowTop = [sender frame].origin.y + [sender frame].size.height,
			minHeight = 155;
    NSSize	diff;
    NSRect	screenFrame = [[sender screen] frame];
    
    proposedFrameSize.width = MIN(MAX(proposedFrameSize.width, 132),
								  screenFrame.size.width - [sender frame].origin.x);
    diff.width = [sender frame].size.width - [[sender contentView] frame].size.width;
    diff.height = [sender frame].size.height - [[sender contentView] frame].size.height;
    proposedFrameSize.width -= diff.width;
    windowTop -= diff.height + 16 + (statusBarShowing ? [statusBarView frame].size.height : 0);
    
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
    proposedFrameSize.height += 16 + (statusBarShowing ? [statusBarView frame].size.height : 0);
    
    [self setZoom:self];
    
    proposedFrameSize.height += diff.height;
    proposedFrameSize.width += diff.width;

    return proposedFrameSize;
}


- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame
{
    defaultFrame.size = [self windowWillResize:sender toSize:defaultFrame.size];

    [mosaicScrollView setNeedsDisplay:YES];
    
    return defaultFrame;
}


- (void)windowDidResize:(NSNotification *)notification
{
		// this method is called during animated window resizing, not windowWillResize
    [self setZoom:self];
    [utilitiesTabView setNeedsDisplay:YES];
}



// Toolbar delegate methods

#pragma mark -
#pragma mark Toolbar delegate methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem	*toolbarItem = [toolbarItems objectForKey:itemIdentifier];

    if (toolbarItem)
		return toolbarItem;
    
    toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
    if ([itemIdentifier isEqualToString:@"Zoom"])
    {
		[toolbarItem setMinSize:NSMakeSize(64, 14)];
		[toolbarItem setMaxSize:NSMakeSize(64, 14)];
		[toolbarItem setLabel:@"Zoom"];
		[toolbarItem setPaletteLabel:@"Zoom"];
		[toolbarItem setView:zoomToolbarView];
		[toolbarItem setMenuFormRepresentation:zoomToolbarMenuItem];
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
		[toolbarItem setTarget:utilitiesDrawer];
		[toolbarItem setAction:@selector(toggle:)];
		[toolbarItem setToolTip:@"Show/hide utility drawer"];
    }

    if ([itemIdentifier isEqualToString:@"Pause"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[toolbarItem setLabel:paused ? @"Resume" : @"Pause"];
		[toolbarItem setPaletteLabel:paused ? @"Resume" : @"Pause"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(togglePause:)];
		pauseToolbarItem = toolbarItem;
    }
    
    [toolbarItems setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    if ([[theItem itemIdentifier] isEqualToString:@"Pause"])
		return ([tileOutlines count] > 0 && [imageSources count] > 0);
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
	if (tabView == utilitiesTabView)
	{
		int selectedIndex =  [tabView indexOfTabViewItem:tabViewItem];
		
		if (selectedIndex == [utilitiesTabView indexOfTabViewItemWithIdentifier:@"Tiles Setup"])
			[mosaicView setViewMode:viewTilesOutline];
		if (selectedIndex == [utilitiesTabView indexOfTabViewItemWithIdentifier:@"Image Sources"])
			[mosaicView setViewMode:viewImageSources];
		if (selectedIndex == [utilitiesTabView indexOfTabViewItemWithIdentifier:@"Original Image"])
			[mosaicView setViewMode:viewMosaic];
		if (selectedIndex == [utilitiesTabView indexOfTabViewItemWithIdentifier:@"Image Regions"])
			[mosaicView setViewMode:viewImageRegions];
		if (selectedIndex == [utilitiesTabView indexOfTabViewItemWithIdentifier:@"Tile Editor"])
			[mosaicView setViewMode:viewHighlightedTile];
	}
}


#pragma mark -
#pragma mark Table delegate methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == imageSourcesTable)
		return [imageSources count];
		
    if (aTableView == editorTable)
		return (selectedTile == nil ? 0 : [selectedTile matchCount]);
	
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if (aTableView == imageSourcesTable)
    {
		return ([[aTableColumn identifier] isEqualToString:@"Image Source Type"]) ?
				(id)[[imageSources objectAtIndex:rowIndex] image] : 
				(id)[NSString stringWithFormat:@"%@\n(%d images found)",
												[[imageSources objectAtIndex:rowIndex] descriptor],
												[[imageSources objectAtIndex:rowIndex] imageCount]];
    }
    else // it's the editor table
    {
		NSImage	*image;
		
		if (selectedTile == nil) return nil;
		
		image = [selectedTileImages objectAtIndex:rowIndex];
		if ([image isKindOfClass:[NSNull class]] && rowIndex != -1)
		{
			image = [self createEditorImage:rowIndex];
			[selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
		}
		
		return image;
    }
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == editorTable)
    {
//        int	selectedRow = [editorTable selectedRow];
//        
//        if (selectedRow >= 0)
//            [matchValueTextField setStringValue:[NSString stringWithFormat:@"%f", 
//                                                    [selectedTile matches][selectedRow].matchValue]];
//        else
//            [matchValueTextField setStringValue:@""];
    }
}


#pragma mark -

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector
			 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (!paused) [self togglePause:nil];
    while (createTilesThreadAlive || enumerateImageSourcesThreadAlive || calculateImageMatchesThreadAlive || calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector 
			    contextInfo:contextInfo];
}


- (void)close
{
	if (documentIsClosing)
		return;	// make sure to do the steps below only once (not sure why this method sometimes gets called twice...)

		// stop the timers
	if ([updateDisplayTimer isValid]) [updateDisplayTimer invalidate];
	[updateDisplayTimer release];
	if ([animateTileTimer isValid]) [animateTileTimer invalidate];
	[animateTileTimer release];
	
		// let other threads know we are closing
	documentIsClosing = YES;
	
		// wait for the threads to shut down
	while (createTilesThreadAlive || enumerateImageSourcesThreadAlive || 
		   calculateImageMatchesThreadAlive || calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		
		// Give the image sources a chance to clean up before we close shop
	[imageSources release];
	imageSources = nil;
	
    [super close];
}


#pragma mark


- (void)save
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	[[NSFileManager defaultManager] createFileAtPath:@"/tmp/Saved.mosaic/Mosaic.xml" contents:nil attributes:nil];
	NSFileHandle	*fileHandle = [NSFileHandle fileHandleForWritingAtPath:@"/tmp/Saved.mosaic/Mosaic.xml"];
	
		// Write out the XML header.
	[fileHandle writeData:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[fileHandle writeData:[@"<!DOCTYPE plist PUBLIC \"-//Frank M. Midgley//DTD MacOSaiX 1.0//EN\" \"http://homepage.mac.com/knarf/DTDs/MacOSaiX-1.0.dtd\">" dataUsingEncoding:NSUTF8StringEncoding]];
	
		// Write out the image sources.
	[fileHandle writeData:[@"<IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
	int	index;
	for (index = 0; index < [imageSources count]; index++)
	{
		ImageSource	*imageSource = [imageSources objectAtIndex:index];
		NSString	*className = NSStringFromClass([imageSource class]);
		
		[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_SOURCE ID=\"%d\">\n", index] dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:[[NSString stringWithFormat:@"\t\t<SETTINGS CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
//		[fileHandle writeData:[[imageSource XMLRepresentation] dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:[@"\t\t</SETTINGS>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:[@"\t</IMAGE_SOURCE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
	}
	[fileHandle writeData:[@"</IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];

		// Write out the tiles setup
    NSString	*className = NSStringFromClass([tilesSetupController class]);
    [fileHandle writeData:[@"<TILES_SETUP>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle writeData:[[NSString stringWithFormat:@"\t\t<SETTINGS CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
//    [fileHandle writeData:[[tilesSetupController XMLRepresentation] dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle writeData:[@"\t</SETTINGS>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle writeData:[@"</TILES_SETUP>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
        // Write out the cached images
	[fileHandle writeData:[@"<CACHED_IMAGES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
	for (index = 0; index < [imageSources count]; index++)
	{
		ImageSource		*imageSource = [imageSources objectAtIndex:index];
		NSDictionary	*cacheDict = [self cacheDictionaryForImageSource:imageSource];
		NSEnumerator	*imageIDEnumerator = [cacheDict keyEnumerator];
		id<NSCopying>	imageID = nil;
		while (imageID = [imageIDEnumerator nextObject])
			[fileHandle writeData:[[NSString stringWithFormat:@"\t<CACHED_IMAGE SOURCE_ID=\"%d\" IMAGE_ID=\"%@\"/ FILE_ID=\"%@\">\n", 
												index, imageID, [cacheDict objectForKey:imageID]] dataUsingEncoding:NSUTF8StringEncoding]];
    }
	[fileHandle writeData:[@"</CACHED_IMAGES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
        // Write out the tiles
	[fileHandle writeData:[@"<TILES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
    Tile			*tile = nil;
    while (tile = [tileEnumerator nextObject])
    {
        [fileHandle writeData:[@"\t<TILE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		
			// First write out the tile's outline
        [fileHandle writeData:[@"\t\t<OUTLINE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
        int index;
        for (index = 0; index < [[tile outline] elementCount]; index++)
        {
            NSPoint points[3];
            switch ([[tile outline] elementAtIndex:index associatedPoints:points])
            {
                case NSMoveToBezierPathElement:
                    [fileHandle writeData:[[NSString stringWithFormat:@"\t\t\t<MOVE_TO X=\"%0.6f\" Y=\"%0.6f\">\n", 
                                                        points[0].x, points[0].y] dataUsingEncoding:NSUTF8StringEncoding]];
                    break;
                case NSLineToBezierPathElement:
                    [fileHandle writeData:[[NSString stringWithFormat:@"\t\t\t<LINE_TO X=\"%0.6f\" Y=\"%0.6f\">\n", 
                                                        points[0].x, points[0].y] dataUsingEncoding:NSUTF8StringEncoding]];
                    break;
                case NSCurveToBezierPathElement:
                    [fileHandle writeData:[[NSString stringWithFormat:@"\t\t\t<CURVE_TO X=\"%0.6f\" Y=\"%0.6f\" C1X=\"%0.6f\" C1Y=\"%0.6f\" C2X=\"%0.6f\" C2Y=\"%0.6f\">\n", 
                                                        points[2].x, points[2].y, points[0].x, points[0].y, points[1].x, points[1].y] 
                                                dataUsingEncoding:NSUTF8StringEncoding]];
                    break;
				case NSClosePathBezierPathElement:
                    [fileHandle writeData:[@"\t\t\t<CLOSE_PATH>\n" dataUsingEncoding:NSUTF8StringEncoding]];
                    break;
                default:
                    ;
            }
        }
        [fileHandle writeData:[@"\t\t</OUTLINE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		
			// Now write out the tile's matches.
        [fileHandle writeData:[@"\t\t<MATCHES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		NSEnumerator	*matchEnumerator = [[tile matches] objectEnumerator];
		ImageMatch		*match = nil;
		while (match = [matchEnumerator nextObject])
			[fileHandle writeData:[[NSString stringWithFormat:@"\t\t\t<MATCH SOURCE_ID=\"%d\" IMAGE_ID=\"%@\" VALUE=\"%0.6f\"%@>\n", 
												[imageSources indexOfObjectIdenticalTo:[match imageSource]],
												[match imageIdentifier], [match matchValue],
												(match == [tile userChosenImageMatch] ? @"USER_CHOSEN" : @"")] 
										dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle writeData:[@"\t\t</MATCHES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle writeData:[@"\t</TILE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }
	[fileHandle writeData:[@"</TILES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
	
    [fileHandle closeFile];

	[pool release];
}


#pragma mark


- (void)dealloc
{
	[cachedImagesDictionary release];
    [originalImageURL release];
    [originalImage release];
    [mosaicImage release];
    [mosaicImageLock release];
    [refindUniqueTilesLock release];
    [imageQueueLock release];
    [tiles release];
    [tileOutlines release];
    [imageQueue release];
    [selectedTileImages release];
    [toolbarItems release];
    [removedSubviews release];
    [combinedOutlines release];
    [zoomToolbarMenuItem release];
    [viewToolbarMenuItem release];
    [lastSaved release];
    [tileImages release];
    [tileImagesLock release];
    
    [super dealloc];
}

@end
