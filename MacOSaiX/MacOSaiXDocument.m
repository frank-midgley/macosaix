/*
	MacOSaiXDocument.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


//#import <HIToolbox/MacWindows.h>
#import "MacOSaiX.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXWindowController.h"
#import "Tiles.h"
//#import <unistd.h>

	// The maximum size of the image URL queue
#define MAXIMAGEURLS 10


	// Notifications
NSString	*MacOSaiXOriginalImageDidChangeNotification = @"MacOSaiXOriginalImageDidChangeNotification";


@interface MacOSaiXDocument (PrivateMethods)
- (void)spawnImageSourceThreads;
- (BOOL)started;
- (void)lockWhilePaused;
- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;
- (void)calculateImageMatches:(id)path;
- (void)createTileCollectionWithOutlines:(id)object;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(ImageMatch *)tileMatch selecting:(BOOL)selecting;
- (NSImage *)createEditorImage:(int)rowIndex;
@end


@implementation MacOSaiXDocument

- (id)init
{
    if (self = [super init])
    {
		[self setHasUndoManager:FALSE];	// don't track undo-able changes
		
		paused = YES;
		imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
		lastSaved = [[NSDate date] retain];
		autosaveFrequency = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] intValue];

		pauseLock = [[NSLock alloc] init];
		[pauseLock lock];
			
		// create the image URL queue and its lock
		imageQueue = [[NSMutableArray arrayWithCapacity:0] retain];
		imageQueueLock = [[NSLock alloc] init];

		calculateImageMatchesThreadLock = [[NSLock alloc] init];
		
			// set up ivars for "calculateDisplayedImages" thread
		calculateDisplayedImagesThreadAlive = NO;
		calculateDisplayedImagesThreadLock = [[NSLock alloc] init];
		refreshTilesSet = [[NSMutableSet setWithCapacity:256] retain];
		refreshTilesSetLock = [[NSLock alloc] init];

		tileImages = [[NSMutableArray arrayWithCapacity:0] retain];
		tileImagesLock = [[NSLock alloc] init];
		
		enumerationThreadCountLock = [[NSLock alloc] init];
		
		imageCache = [[MacOSaiXImageCache alloc] init];
	}
	
    return self;
}


- (void)makeWindowControllers
{
	MacOSaiXWindowController	*controller = [[MacOSaiXWindowController alloc] initWithWindowNibName:@"MacOSaiXDocument"];
	
	[self addWindowController:controller];
	[controller showWindow:self];
}


- (MacOSaiXImageCache *)imageCache
{
	return imageCache;
}


- (void)setOriginalImagePath:(NSString *)path
{
	if (![path isEqualToString:originalImagePath])
	{
		[originalImagePath release];
		[originalImage release];
		
		originalImagePath = [[NSString stringWithString:path] retain];
		originalImage = [[NSImage alloc] initWithContentsOfFile:path];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXOriginalImageDidChangeNotification object:self];
	}
}


- (NSString *)originalImagePath
{
	return originalImagePath;
}


- (NSImage *)originalImage
{
	return originalImage;
}


#pragma mark
#pragma mark Pausing/resuming


- (BOOL)isPaused
{
	return paused;
}


- (void)pause
{
	if (!paused)
	{
			// Wait for the one-shot startup thread to end.
		while (createTilesThreadAlive)
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

			// Tell the enumeration threads to stop sending in any new images.
		[pauseLock lock];
		
			// Wait for any queued images to get processed.
			// TBD: can we condition lock here instead of poll?
			// TBD: this could block the main thread
		while (calculateImageMatchesThreadAlive)
			[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
		
		paused = YES;
	}
}


- (void)lockWhilePaused
{
	[pauseLock lock];
	[pauseLock unlock];
}


- (void)resume
{
	if (paused)
	{
		if ([[tiles objectAtIndex:0] bitmapRep] == nil)
			[NSApplication detachDrawingThread:@selector(createTileCollectionWithOutlines:)
									  toTarget:self
									withObject:nil];
		else
		{
				// Start or restart the image sources
			[pauseLock unlock];
			
			paused = NO;
		}
	}
}


#pragma mark
#pragma mark Save and Open methods


- (IBAction)saveDocument:(id)sender
{
	NSWindow	*window = [[[self windowControllers] objectAtIndex:0] window];
	
	NSBeginAlertSheet(@"MacOSaiX", @"Dang", nil, nil, window, nil, nil, nil, nil, @"Saving is not available in this version.");
}

- (IBAction)saveDocumentAs:(id)sender
{
	[self saveDocument:sender];
}


- (IBAction)saveDocumentTo:(id)sender
{
	[self saveDocument:sender];
}


- (IBAction)revertDocumentToSaved:(id)sender
{
	[self saveDocument:sender];
}


- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)type;
{
	BOOL			success = NO,
					wasPaused = paused;
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	
		// Pause the mosaic so that it is in a static state while saving.
	[self pause];
	
	// TBD: set a "saving" flag?
	
		// Create the wrapper directory if it doesn't already exist.
	if ([fileManager fileExistsAtPath:fileName] || [fileManager createDirectoryAtPath:fileName attributes:nil])
	{
//		if (![cachedImagesPath hasPrefix:fileName])
//		{
//				// This is the first time this mosaic has been saved so move 
//				// the image cache directory from /tmp to the new location.
//			NSString	*savedCachedImagesPath = [fileName stringByAppendingPathComponent:@"Cached Images"];
//			[fileManager movePath:cachedImagesPath toPath:savedCachedImagesPath handler:nil];
//			[cachedImagesPath autorelease];
//			cachedImagesPath = [savedCachedImagesPath retain];
//		}
		
			// Display a sheet while the save is underway
			// TODO: figure out how to do this asynchronously and coordinate with window controller
//		[progressPanelLabel setStringValue:@"Saving..."];
//		[progressPanelIndicator setDoubleValue:0.0];
//		[progressPanelCancelButton setAction:@selector(cancelSave:)];
//		[NSApp beginSheet:progressPanel 
//		   modalForWindow:mainWindow 
//			modalDelegate:self 
//		   didEndSelector:@selector(saveSheetDidEnd:returnCode:contextInfo:) 
//			  contextInfo:nil];
//		
//		[NSThread detachNewThreadSelector:@selector(threadedSaveToPath:) 
//								 toTarget:self 
//							   withObject:[NSArray arrayWithObjects:fileName, [NSNumber numberWithBool:wasPaused], nil]];
		
		success = YES;
	}
	
	return success;
}


- (IBAction)cancelSave:(id)sender
{
}


- (void)saveSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
}


- (void)threadedSaveToPath:(NSArray *)parameters
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*savePath = [parameters objectAtIndex:0];
	BOOL				wasPaused = [[parameters objectAtIndex:1] boolValue];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
			// Create the master save file in XML format.
	NSString	*xmlPath = [savePath stringByAppendingPathComponent:@"Mosaic new.xml"];
	if (![[NSFileManager defaultManager] createFileAtPath:xmlPath contents:nil attributes:nil])
	{
	}
	else
	{
		NSFileHandle	*fileHandle = [NSFileHandle fileHandleForWritingAtPath:xmlPath];
		
			// Write out the XML header.
		[fileHandle writeData:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		[fileHandle writeData:[@"<!DOCTYPE plist PUBLIC \"-//Frank M. Midgley//DTD MacOSaiX 1.0//EN\" \"http://homepage.mac.com/knarf/DTDs/MacOSaiX-1.0.dtd\">" dataUsingEncoding:NSUTF8StringEncoding]];
		
			// Write out the image sources.
		[fileHandle writeData:[@"<IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		int	index;
		for (index = 0; index < [imageSources count]; index++)
		{
			id<MacOSaiXImageSource>	imageSource = [imageSources objectAtIndex:index];
			NSString				*className = NSStringFromClass([imageSource class]);
			
			[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_SOURCE ID=\"%d\">\n", index] dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[[NSString stringWithFormat:@"\t\t<SETTINGS CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
	//		[fileHandle writeData:[[imageSource XMLRepresentation] dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[@"\t\t</SETTINGS>\n" dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[@"\t</IMAGE_SOURCE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		}
		[fileHandle writeData:[@"</IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];

			// Write out the tiles setup
			// TODO: needs rework once tile setup is freed from framework
//		NSString	*className = NSStringFromClass([tilesSetupController class]);
//		[fileHandle writeData:[@"<TILES_SETUP>\n" dataUsingEncoding:NSUTF8StringEncoding]];
//		[fileHandle writeData:[[NSString stringWithFormat:@"\t\t<SETTINGS CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
//	//    [fileHandle writeData:[[tilesSetupController XMLRepresentation] dataUsingEncoding:NSUTF8StringEncoding]];
//		[fileHandle writeData:[@"\t</SETTINGS>\n" dataUsingEncoding:NSUTF8StringEncoding]];
//		[fileHandle writeData:[@"</TILES_SETUP>\n" dataUsingEncoding:NSUTF8StringEncoding]];
		
			// Write out the cached images
		[fileHandle writeData:[[imageCache xmlData] dataUsingEncoding:NSUTF8StringEncoding]];
		
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
	}
	
	if (wasPaused)
		[self resume];
	
	[pool release];
}


- (NSData *)dataRepresentationOfType:(NSString *)aType
{
		// Saving is totally overriden in -writeToFile:ofType:.
	return nil;
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
	for (index = 0; index < [tiles count]; index++)
	    [(Tile *)[tiles objectAtIndex:index] setDocument:self];
	
	imagesMatched = [[storage objectForKey:@"imagesMatched"] longValue];
	
	[imageQueue addObjectsFromArray:[storage objectForKey:@"imageQueue"]];
	
//	viewMode = [[storage objectForKey:@"viewMode"] intValue];
	
//	storedWindowFrame = [[storage objectForKey:@"window frame"] rectValue];
    
	paused = ([[storage objectForKey:@"paused"] intValue] == 1 ? YES : NO);
	
	finishLoading = YES;
	
	[lastSaved autorelease];
	lastSaved = [[NSDate date] retain];

	return YES;	// document was loaded successfully
    }
    
    return NO;	// unknown version of saved document
}


#pragma mark
#pragma mark Tile management


- (void)calculateTileNeighborhoods
{
		// At a minimum each tile neighbors its direct neighbors.
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	Tile			*tile = nil;
	while (tile = [tileEnumerator nextObject])
		[tile setNeighbors:[directNeighbors objectForKey:[NSString stringWithFormat:@"%p", tile]]];
	
	int	degreeOfSeparation;
	for (degreeOfSeparation = 1; degreeOfSeparation < neighborhoodSize; degreeOfSeparation++)
	{
			// Add the direct neighbors of every tile's neighbor to the tile's neighborhood.
		NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
		Tile			*tile = nil;
		while (tile = [tileEnumerator nextObject])
		{ 
			NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
			NSEnumerator		*neighborEnumerator = [[tile neighbors] objectEnumerator];
			Tile				*neighbor = nil;
			
			while (![self isClosing] && (neighbor = [neighborEnumerator nextObject]))
				[tile addNeighbors:[directNeighbors objectForKey:[NSString stringWithFormat:@"%p", neighbor]]];
			
			[pool2 release];
		}
	}
}


- (void)setTileOutlines:(NSArray *)inTileOutlines
{
	[inTileOutlines retain];
	[tileOutlines autorelease];
	tileOutlines = inTileOutlines;
	
		// Discard any tiles created from a previous set of outlines.
	if (!tiles)
		tiles = [[NSMutableArray arrayWithCapacity:[tileOutlines count]] retain];
	else
		[tiles removeAllObjects];

		// Create a new tile collection from the outlines.
	NSEnumerator	*tileOutlineEnumerator = [tileOutlines objectEnumerator];
	NSBezierPath	*tileOutline = nil,
					*combinedOutline = [NSBezierPath bezierPath];
    while (tileOutline = [tileOutlineEnumerator nextObject])
	{
		[tiles addObject:[[[Tile alloc] initWithOutline:tileOutline fromDocument:self] autorelease]];
		
			// Add this outline to the master path used to draw all of the tile outlines over the full image.
		[combinedOutline appendBezierPath:tileOutline];
	}
	
		// Calculate the directly neighboring tiles of each tile.  This is used to calculate
		// each tile's neighborhood when combined with the neighborhood size setting.
	if (!directNeighbors)
		directNeighbors = [[NSMutableDictionary dictionary] retain];
	else
		[directNeighbors removeAllObjects];
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	Tile			*tile = nil;
    while (tile = [tileEnumerator nextObject])
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
		NSMutableArray	*directNeighborArray = [NSMutableArray array];
		NSEnumerator	*tileEnumerator2 = [tiles objectEnumerator];
		Tile			*tile2 = nil;
		while (tile2 = [tileEnumerator2 nextObject])
			if (tile2 != tile && NSIntersectsRect(zoomedTileBounds, [[tile2 outline] bounds]))
				[directNeighborArray addObject:tile2];
		
		[directNeighbors setObject:directNeighborArray forKey:[NSString stringWithFormat:@"%p", tile]];
	}
	
	[self calculateTileNeighborhoods];
		
	mosaicStarted = NO;
}


- (void)setNeighborhoodSize:(int)size
{
	neighborhoodSize = size;
	
	[[NSUserDefaults standardUserDefaults] setInteger:neighborhoodSize forKey:@"Neighborhood Size"];
	
	// TODO: what if a mosaic is already in the works?  how do we reset?
	
	[self calculateTileNeighborhoods];
}


- (void)createTileCollectionWithOutlines:(id)object
{
    if (tileOutlines == nil || originalImage == nil)
		return;
    else
		createTilesThreadAlive = YES;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
    int					index = 0;
    NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];

		// create an offscreen window to draw into (it will have a single, empty view the size of the window)
    NSWindow			*drawWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(-10000, -10000,
																					   [originalImage size].width, 
																					   [originalImage size].height)
																  styleMask:NSBorderlessWindowMask
																    backing:NSBackingStoreBuffered 
																	  defer:NO];
    
	/* Loop through each tile and:
		1. Copy out the rect of the original image that this tile covers.
		2. Calculate an image mask that indicates which part of the copied rect is contained within the tile's outline.
		3. ?
	*/
	NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
	Tile			*tile = nil;
    while (!documentIsClosing && (tile = [tileEnumerator nextObject]))
	{
		index++;
		
			// Lock focus on our 'scratch' window.
		while (![[drawWindow contentView] lockFocusIfCanDraw])
			[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:0.1]];
		
		NS_DURING
				// Determine the bounds of the tile in the original image and in the scratch window.
			NSBezierPath	*tileOutline = [tile outline];
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
		NS_HANDLER
			NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
		NS_ENDHANDLER
		
			// Release our lock on the GUI in case the main thread needs it.
		[[drawWindow contentView] unlockFocus];
		
		tileCreationPercentComplete = (int)(index * 50.0 / [tileOutlines count]);
	}
	
    [drawWindow close];
    
		// Start up the mosaic
	[self resume];

    [pool release];
    
    createTilesThreadAlive = NO;
}


- (BOOL)isCreatingTiles
{
	return createTilesThreadAlive;
}


- (float)tileCreationPercentComplete
{
	return tileCreationPercentComplete;
}


- (NSArray *)tiles
{
	return tiles;
}


#pragma mark
#pragma mark Image source enumeration


- (void)spawnImageSourceThreads
{
	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
	id<MacOSaiXImageSource>	imageSource;
	
	while (imageSource = [imageSourceEnumerator nextObject])
		[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) toTarget:self withObject:imageSource];
}


- (void)enumerateImageSourceInNewThread:(id<MacOSaiXImageSource>)imageSource
{
	[enumerationThreadCountLock lock];
			enumerationThreadCount++;
	[enumerationThreadCountLock unlock];
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
		// Check if the source has any images left.
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	BOOL				sourceHasMoreImages = [imageSource hasMoreImages];
	[pool release];
	
	while (!documentIsClosing && sourceHasMoreImages)
	{
		NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
		
		[self lockWhilePaused];
		
			// Get the next image from the source (and identifier if there is one)
		NSString	*imageIdentifier = nil;
		NSImage		*image = [imageSource nextImageAndIdentifier:&imageIdentifier];
		
		if (image && [image isValid] && [image size].width > 16 && [image size].height > 16)
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
											imageIdentifier, @"Image Identifier", // last since it could be nil
											nil]];
			[imageQueueLock unlock];

			if (!calculateImageMatchesThreadAlive)
				[NSApplication detachDrawingThread:@selector(calculateImageMatches:) toTarget:self withObject:nil];
		}
		sourceHasMoreImages = [imageSource hasMoreImages];
		
		[pool release];
	}
	
	[enumerationThreadCountLock lock];
			enumerationThreadCount--;
	[enumerationThreadCountLock unlock];
}


- (BOOL)isEnumeratingImageSources
{
	return (enumerationThreadCount > 0);
}


- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource
{
	// TODO: should this come from here or the image cache?
	return 0;
}


#pragma mark
#pragma mark Image matching

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
	[scratchImage setCacheMode:NSImageCacheNever];
	
//	NSLog(@"Calculating image matches\n");
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

	[imageQueueLock lock];
    while (!documentIsClosing && [imageQueue count] > 0)
	{
			// As long as the image source threads are feeding images into the queue this loop
			// will continue running so create a pool just for this pass through the loop.
		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		BOOL				queueLocked = NO;
		
			// pull the next image from the queue
		NSDictionary		*nextImageDict = [[[imageQueue objectAtIndex:0] retain] autorelease];
		[imageQueue removeObjectAtIndex:0];
		
			// let the image source threads add more images if the queue is not full
		if ([imageQueue count] < MAXIMAGEURLS)
			[imageQueueLock unlock];
		else
			queueLocked = YES;
		
		NSImage					*pixletImage = [nextImageDict objectForKey:@"Image"];
		id<MacOSaiXImageSource>	pixletImageSource = [nextImageDict objectForKey:@"Image Source"];
		NSString				*pixletImageIdentifier = [nextImageDict objectForKey:@"Image Identifier"];
		
			// Set the caching behavior of the image.  We'll be adding bitmap representations of various
			// sizes to the image so it doesn't need to do any of its own caching.
		[pixletImage setCacheMode:NSImageCacheNever];
		[pixletImage setScalesWhenResized:NO];
		
			// Add this image to the cache.
		if (pixletImageIdentifier)
		{
				// Just cache a thumbnail, no need to waste the disk since we can refetch.
			NSSize				thumbnailSize, pixletImageSize = [pixletImage size];
			if (pixletImageSize.width > pixletImageSize.height)
				thumbnailSize = NSMakeSize(kImageCacheThumbnailSize, 
										   pixletImageSize.height * kImageCacheThumbnailSize / pixletImageSize.width);
			else
				thumbnailSize = NSMakeSize(pixletImageSize.width * kImageCacheThumbnailSize / pixletImageSize.height, 
										   kImageCacheThumbnailSize);
			NSImage				*thumbnailImage = [[NSImage alloc] initWithSize:thumbnailSize];
			
			BOOL				haveFocus = NO;
			
			while (!haveFocus && !documentIsClosing)
			{
				NS_DURING
					[thumbnailImage lockFocus];
					haveFocus = YES;
				NS_HANDLER
					NSLog(@"Couldn't lock focus on thumbnail: %@", localException);
				NS_ENDHANDLER
			}
			
			if (haveFocus)
			{
				[pixletImage drawInRect:NSMakeRect(0.0, 0.0, thumbnailSize.width, thumbnailSize.height) 
							   fromRect:NSMakeRect(0.0, 0.0, pixletImageSize.width, pixletImageSize.height) 
							  operation:NSCompositeCopy 
							   fraction:1.0];
				[thumbnailImage unlockFocus];
				[imageCache cacheImage:thumbnailImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
			}
			else
				NSLog(@"Couldn't create cached thumbnail image.");
			
			[thumbnailImage release];
		}
		else
		{
				// Cache the full sized image since we can't refetch it from the image source.
				// Create an identifier with a fixed prefix we can check for later to know that 
				// the image can't be refetched.
			pixletImageIdentifier = [NSString stringWithFormat:@"Unfetchable %ld", unfetchableCount++];
			[imageCache cacheImage:pixletImage withIdentifier:pixletImageIdentifier fromSource:pixletImageSource];
		}

		NSMutableDictionary	*cachedReps = [NSMutableDictionary dictionaryWithCapacity:16];
		
			// loop through the tiles and compute the pixlet's match
		NSEnumerator	*tileEnumerator = [tiles objectEnumerator];
		Tile			*tile = nil;
		while ((tile = [tileEnumerator nextObject]) && !documentIsClosing)
		{
				// scale the smaller of the pixlet's image's dimensions to the size used
				// for pixel matching and extract the rep
			float	scale = MAX([[tile bitmapRep] size].width / [pixletImage size].width, 
								[[tile bitmapRep] size].height / [pixletImage size].height);
			NSRect	subRect = NSMakeRect(0, 0, (int)([pixletImage size].width * scale + 0.5),
										 (int)([pixletImage size].height * scale + 0.5));
			
				// Check if we already have a rep of this size.
			NSImageRep		*imageRep = [cachedReps objectForKey:NSStringFromSize(subRect.size)];
			if (!imageRep)
			{
					// No bitmap at the correct size was found, try to create a new one
				BOOL	lockedFocus = NO;
				
				while (!lockedFocus)
				{
					NS_DURING
						[scratchImage lockFocus];
						lockedFocus = YES;
					NS_HANDLER
						// TBD: how to handle this?
						NSLog(@"Could not lock focus on scratch image, what should I do?");
					NS_ENDHANDLER
				}
				
				NS_DURING
					[pixletImage drawInRect:subRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
					imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:subRect] autorelease];
					if (imageRep)
						[cachedReps setObject:imageRep forKey:NSStringFromSize(subRect.size)];
				NS_HANDLER
					// TBD: how to handle this?
					NSLog(@"Could not create cached bitmap (%@).", localException);
				NS_ENDHANDLER
				
				[scratchImage unlockFocus];
			}
	
				// If the tile reports that the image matches better than its previous worst match
				// then add the tile and its neighbors to the set of tiles potentially needing redraw.
			if (imageRep && [tile matchAgainstImageRep:(NSBitmapImageRep *)imageRep
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
		
		if (!queueLocked)
			[imageQueueLock lock];

		[pool2 release];
	}
	[imageQueueLock unlock];

	[calculateImageMatchesThreadLock lock];
		calculateImageMatchesThreadAlive = NO;
	[calculateImageMatchesThreadLock unlock];

		// clean up and shutdown this thread
    [pool release];
}

- (BOOL)isCalculatingImageMatches
{
	return calculateImageMatchesThreadAlive;
}


- (unsigned long)imagesMatched
{
	// TODO
	return 0;
}


#pragma mark
#pragma mark Uniqueness

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
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

    BOOL	tilesAddedToRefreshSet = NO;

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
	{
		NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
        if ([tileToRefresh calculateBestMatch])
        {
			// The image to display for this tile changed so update the mosaic image and add the tile's neighbors 
			// to the set of tiles to refresh in case they can use the image we just stopped using.
            
            tilesAddedToRefreshSet = YES;
            
            [refreshTilesSetLock lock];
                [refreshTilesSet addObjectsFromArray:[tileToRefresh neighbors]];
            [refreshTilesSetLock unlock];
            
			ImageMatch		*imageMatch = [tileToRefresh displayedImageMatch];
            NSImage			*matchImage = [imageCache cachedImageForIdentifier:[imageMatch imageIdentifier] 
																	fromSource:[imageMatch imageSource]];
            if (!matchImage)
                NSLog(@"Could not load image\t%@", [imageMatch imageIdentifier]);
            else
            {
				[[NSNotificationCenter defaultCenter] postNotificationName:@"Tile Image Changed" 
																	object:self
																  userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
																				tileToRefresh, @"Tile",
																				matchImage, @"New Image",
																				nil]];
            }
        }
		
		[pool2 release];
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


- (BOOL)isCalculatingDisplayedImages
{
	return calculateDisplayedImagesThreadAlive;
}


#pragma mark -
#pragma mark Images source methods


- (NSArray *)imageSources
{
	return [NSArray arrayWithArray:imageSources];
}


- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[imageSources addObject:imageSource];
	
	[NSApplication detachDrawingThread:@selector(enumerateImageSourceInNewThread:) 
							  toTarget:self 
							withObject:imageSource];
}


- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource
{
	[imageSources removeObject:imageSource];
}


#pragma mark -


- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector
			 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (!paused)
		[self pause];
	
    while (createTilesThreadAlive || enumerationThreadCount > 0 || calculateImageMatchesThreadAlive || 
		   calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
    
    [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector 
			    contextInfo:contextInfo];
}


- (BOOL)isClosing
{
	return documentIsClosing;
}


- (void)close
{
	if (documentIsClosing)
		return;	// make sure to do the steps below only once (not sure why this method sometimes gets called twice...)
	
		// let other threads know we are closing
	documentIsClosing = YES;
	
		// wait for the threads to shut down
	while (createTilesThreadAlive || enumerationThreadCount > 0 || calculateImageMatchesThreadAlive || 
		   calculateDisplayedImagesThreadAlive)
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
		
		// Give the image sources a chance to clean up before we close shop
	[imageSources release];
	imageSources = nil;
	
    [super close];
}


#pragma mark


- (void)dealloc
{
    [originalImagePath release];
    [originalImage release];
	[pauseLock release];
    [imageQueueLock release];
	[enumerationThreadCountLock release];
    [tiles release];
    [tileOutlines release];
    [imageQueue release];
    [lastSaved release];
    [tileImages release];
    [tileImagesLock release];
	[directNeighbors release];
    
    [super dealloc];
}

@end
