/*
	MacOSaiXDocument.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXDocument.h"

#import "MacOSaiX.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXSourceImage.h"
#import "Tiles.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"

#import <pthread.h>
#import <unistd.h>


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (BOOL)started;
- (void)lockWhilePaused;

- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;

- (void)spawnImageSourceThreads;
- (void)setImageCount:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource;

- (void)extractTileImagesFromOriginalImage;
- (void)calculateImageMatches:(id)path;

- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (NSImage *)createEditorImage:(int)rowIndex;
@end


@implementation MacOSaiXDocument

- (id)init
{
    if (self = [super init])
    {
		[self setHasUndoManager:FALSE];	// don't track undo-able changes
		
		autoSaveEnabled = YES;
		
		lastSaved = [[NSDate date] retain];
		
		[self setMosaic:[[[MacOSaiXMosaic alloc] init] autorelease]];
	}
	
    return self;
}


- (void)makeWindowControllers
{
	if (![self fileName])	// TBD: is this the right way to check for this?
	{
		// This is a new document, not one loaded from disk.
		
		loading = YES;
		
		NSString	*defaultShapesClassString = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Chosen Tile Shapes Class"];
		[mosaic setTileShapes:[[[NSClassFromString(defaultShapesClassString) alloc] init] autorelease]
				creatingTiles:YES];
		
			// Create a temporary cache directory until we get saved.
		FSRef	chewableItemsRef;
		if (FSFindFolder(kUserDomain, kChewableItemsFolderType, kCreateFolder, &chewableItemsRef) == noErr)
		{
			CFURLRef		chewableItemsURLRef = CFURLCreateFromFSRef(kCFAllocatorDefault, &chewableItemsRef);
			if (chewableItemsURLRef)
			{
				NSString	*chewableItemsPath = [(NSURL *)chewableItemsURLRef path], 
							*tempPathTemplate = [chewableItemsPath stringByAppendingPathComponent:@"MacOSaiX Image Cache XXXX"];
				char		*tempPath = mkdtemp((char *)[tempPathTemplate fileSystemRepresentation]);
				if (tempPath)
					[[self mosaic] setDiskCachePath:[NSString stringWithCString:tempPath]];
				
				CFRelease(chewableItemsURLRef);
			}
		}
	}
	
	mainWindowController = [[MacOSaiXWindowController alloc] initWithWindow:nil];
	[mainWindowController setMosaic:[self mosaic]];
	[self addWindowController:mainWindowController];
	[mainWindowController showWindow:self];
	
	if (![self fileName])	// TBD: is this the right way to check for this?
		loading = NO;
}


- (MacOSaiXWindowController *)mainWindowController
{
	return mainWindowController;
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (mosaic)
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mosaic];
	
	[mosaic autorelease];
	mosaic = [inMosaic retain];
	
	if (mosaic)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChange:) 
													 name:MacOSaiXOriginalImageDidChangeNotification 
												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChange:) 
													 name:MacOSaiXTileShapesDidChangeStateNotification 
												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChange:) 
													 name:MacOSaiXMosaicDidChangeImageSourcesNotification 
												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChange:) 
													 name:MacOSaiXTileImageDidChangeNotification 
												   object:mosaic];
	}
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (void)mosaicDidChange:(NSNotification *)notification
{
	if (!loading)
		[self updateChangeCount:NSChangeDone];
}


#pragma mark -
#pragma mark Original image path


- (void)setOriginalImagePath:(NSString *)path
{
	if (![originalImagePath isEqualToString:path])
	{
		[originalImagePath release];
		originalImagePath = [path copy];
	}
}


- (NSString *)originalImagePath
{
	return originalImagePath;
}


#pragma mark -
#pragma mark Autosave


- (void)setAutoSaveEnabled:(BOOL)flag
{
	autoSaveEnabled = flag;
	
		// Save now if we missed the timer when we were disabled.
	if (flag && [self isDocumentEdited] && missedAutoSave)
		[self performSelectorOnMainThread:@selector(saveDocument:) withObject:self waitUntilDone:NO];
	
	missedAutoSave = NO;
}


- (BOOL)autoSaveEnabled
{
	return autoSaveEnabled;
}


- (void)startAutosaveTimer
{
		// Clear out any previous timer.
	if ([autosaveTimer isValid])
		[autosaveTimer invalidate];
	[autosaveTimer autorelease];
	
		// Set up a new timer.
	int	autosaveInterval = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Autosave Frequency"] description] intValue] * 60;
	if (autosaveInterval < 60)
		autosaveInterval = 60;
	autosaveTimer = [[NSTimer scheduledTimerWithTimeInterval:autosaveInterval 
													  target:self 
													selector:@selector(autoSave:) 
													userInfo:nil 
													 repeats:NO] retain];
}


- (void)autoSave:(NSTimer *)timer
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Save Mosaics"])
	{
		if ([self autoSaveEnabled])
		{
			if ([self isDocumentEdited])
				[self saveDocument:self];
		}
		else
			missedAutoSave = YES;
	}
}


#pragma mark -
#pragma mark Saving


- (void)updateChangeCountOnMainThread:(NSNumber *)changeType
{
	if ([changeType intValue] == NSChangeDone && !autosaveTimer && [[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Save Mosaics"])
		[self startAutosaveTimer];
	
	[super updateChangeCount:[changeType intValue]];
}


- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:@selector(updateChangeCountOnMainThread:) withObject:[NSNumber numberWithInt:changeType] waitUntilDone:YES];
	else
		[self updateChangeCountOnMainThread:[NSNumber numberWithInt:changeType]];
}


- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setRequiredFileType:@"mosaic"];
	return YES;
}


- (NSString *)xmlRepresentation
{
	NSMutableString	*xmlRepresentation = [NSMutableString string];
	NSArray			*imageSources = [[self mosaic] imageSources];
	
		// Write out the XML header.
	[xmlRepresentation appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"];
	[xmlRepresentation appendString:@"<!DOCTYPE plist PUBLIC \"-//Frank M. Midgley//DTD MacOSaiX 1.0//EN\" \"http://homepage.mac.com/knarf/DTDs/MacOSaiX-1.0.dtd\">\n\n"];

	[xmlRepresentation appendString:@"<MOSAIC>\n\n"];

		// Write out the path to the original image
		// TODO: also store an alias
	[xmlRepresentation appendFormat:@"<ORIGINAL_IMAGE PATH=\"%@\"/>\n\n", [[self originalImagePath] stringByEscapingXMLEntites]];
	
	{		// Write out the tile shapes settings
		NSString		*className = NSStringFromClass([[mosaic tileShapes] class]);
		NSMutableString	*tileShapesXML = [NSMutableString stringWithString:
														[[[mosaic tileShapes] settingsAsXMLElement] stringByTrimmingCharactersInSet:
															[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
		[tileShapesXML replaceOccurrencesOfString:@"\n" withString:@"\n\t" options:0 range:NSMakeRange(0, [tileShapesXML length])];
		[tileShapesXML insertString:@"\t" atIndex:0];
		[tileShapesXML appendString:@"\n"];
		[xmlRepresentation appendFormat:@"<TILE_SHAPES_SETTINGS CLASS=\"%@\">\n%@</TILE_SHAPES_SETTINGS>\n\n", className, tileShapesXML];
		
		[xmlRepresentation appendString:@"<IMAGE_USAGE>\n"];
		[xmlRepresentation appendFormat:@"\t<IMAGE_REUSE COUNT=\"%d\" DISTANCE=\"%d\"/>\n", [mosaic imageUseCount], [mosaic imageReuseDistance]];
		[xmlRepresentation appendFormat:@"\t<IMAGE_CROP LIMIT=\"%d\"/>\n", [mosaic imageCropLimit]];
		[xmlRepresentation appendString:@"</IMAGE_USAGE>\n\n"];
	}
	
	{		// Write out the image sources.
		[xmlRepresentation appendString:@"<IMAGE_SOURCES>\n"];
		
		int		index;
		for (index = 0; index < [imageSources count]; index++)
		{
			id<MacOSaiXImageSource>	imageSource = [imageSources objectAtIndex:index];
			NSString				*className = NSStringFromClass([imageSource class]);
			BOOL					isFiller = [mosaic imageSourceIsFiller:imageSource], 
									imagesLost = [mosaic imageSourceHasLostImages:imageSource];
			
			if ([imageSource canRefetchImages])
				[xmlRepresentation appendFormat:@"\t<IMAGE_SOURCE ID=\"%d\" CLASS=\"%@\" IMAGE_COUNT=\"%d\" FILLER=\"%@\" IMAGES_LOST=\"%@\">\n", 
												index, className, [mosaic countOfImagesFromSource:imageSource], (isFiller ? @"YES" : @"NO"), (imagesLost ? @"YES" : @"NO")];
			else
				[xmlRepresentation appendFormat:@"\t<IMAGE_SOURCE ID=\"%d\" CLASS=\"%@\" IMAGE_COUNT=\"%d\" FILLER=\"%@\" IMAGES_LOST=\"%@\" CACHE_NAME=\"%@\">\n", 
												index, className, [mosaic countOfImagesFromSource:imageSource], (isFiller ? @"YES" : @"NO"), (imagesLost ? @"YES" : @"NO"),
												[[self mosaic] diskCacheSubPathForImageSource:imageSource]];
			
				// Output the settings for this image source.
				// TODO: need to tag this element with the source's namespace
			NSMutableString			*imageSourceXML = [NSMutableString stringWithString:
														[[imageSource settingsAsXMLElement] stringByTrimmingCharactersInSet:
															[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
			[imageSourceXML replaceOccurrencesOfString:@"\n" withString:@"\n\t\t" options:0 range:NSMakeRange(0, [imageSourceXML length])];
			[imageSourceXML insertString:@"\t\t" atIndex:0];
			[imageSourceXML appendString:@"\n"];
			[xmlRepresentation appendString:imageSourceXML];
			
			NSArray					*queuedImages = [[self mosaic] imagesQueuedForSource:imageSource];
			if ([queuedImages count] > 0)
			{
				[xmlRepresentation appendString:@"\t\t<QUEUED_IMAGES>\n"];
				NSEnumerator	*queuedImageEnumerator = [queuedImages objectEnumerator];
				NSString		*queuedImageIdentifier = nil;
				while (queuedImageIdentifier = [queuedImageEnumerator nextObject])
					[xmlRepresentation appendFormat:@"\t\t\t<QUEUED_IMAGE ID=\"%@\"/>\n", [queuedImageIdentifier stringByEscapingXMLEntites]];
				// TODO: also save the image if the source can't refetch.
				[xmlRepresentation appendString:@"\t\t</QUEUED_IMAGES>\n"];
			}
			
			NSArray					*scrapImages = [[self mosaic] scrapImagesForSource:imageSource];
			if ([scrapImages count] > 0)
			{
				[xmlRepresentation appendString:@"\t\t<SCRAP_IMAGES>\n"];
				NSEnumerator	*scrapImageEnumerator = [scrapImages objectEnumerator];
				NSString		*scrapImageIdentifier = nil;
				while (scrapImageIdentifier = [scrapImageEnumerator nextObject])
					[xmlRepresentation appendFormat:@"\t\t\t<SCRAP_IMAGE ID=\"%@\"/>\n", [scrapImageIdentifier stringByEscapingXMLEntites]];
				// TODO: also save the image if the source can't refetch.
				[xmlRepresentation appendString:@"\t\t</SCRAP_IMAGES>\n"];
			}
			
			[xmlRepresentation appendString:@"\t</IMAGE_SOURCE>\n\n"];
		}
		
		[xmlRepresentation appendString:@"</IMAGE_SOURCES>\n\n"];
	}
	
	{		// Write out the tiles
		NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
		MacOSaiXTile	*tile = nil;
		
		[xmlRepresentation appendString:@"<TILES>\n"];
		
		while (tile = [tileEnumerator nextObject])
		{
			NSAutoreleasePool	*tilePool = [[NSAutoreleasePool alloc] init];
			
			[xmlRepresentation appendFormat:@"\t<TILE%@>\n", ([tile uniqueImageMatchIsOptimal] ? @"" : @" OPTIMAL=\"NO\"")];
			
				// First write out the tile's outline
			[xmlRepresentation appendString:@"\t\t<OUTLINE>\n"];
			int index;
			for (index = 0; index < [[tile outline] elementCount]; index++)
			{
				NSPoint points[3];
				switch ([[tile outline] elementAtIndex:index associatedPoints:points])
				{
					case NSMoveToBezierPathElement:
						[xmlRepresentation appendFormat:@"\t\t\t<MOVE_TO X=\"%g\" Y=\"%g\"/>\n", points[0].x, points[0].y];
						break;
					case NSLineToBezierPathElement:
						[xmlRepresentation appendFormat:@"\t\t\t<LINE_TO X=\"%g\" Y=\"%g\"/>\n", points[0].x, points[0].y];
						break;
					case NSCurveToBezierPathElement:
						[xmlRepresentation appendFormat:@"\t\t\t<CURVE_TO X=\"%g\" Y=\"%g\" C1X=\"%g\" C1Y=\"%g\" C2X=\"%g\" C2Y=\"%g\"/>\n", points[2].x, points[2].y, points[0].x, points[0].y, points[1].x, points[1].y];
						break;
					case NSClosePathBezierPathElement:
						[xmlRepresentation appendString:@"\t\t\t<CLOSE_PATH/>\n"];
						break;
				}
			}
			[xmlRepresentation appendString:@"\t\t</OUTLINE>\n"];
			
				// Now write out the tile's matches.
			MacOSaiXImageMatch	*userChosenMatch = [tile userChosenImageMatch];
			if (userChosenMatch)
				[xmlRepresentation appendFormat:@"\t\t<USER_CHOSEN_MATCH ID=\"%@\" VALUE=\"%g\"/>\n", 
												[[[userChosenMatch sourceImage] identifier] stringByEscapingXMLEntites], [userChosenMatch matchValue]];
			MacOSaiXImageMatch	*uniqueMatch = [tile uniqueImageMatch];
			if (uniqueMatch)
			{
				unsigned long	sourceIndex = [imageSources indexOfObjectIdenticalTo:[[uniqueMatch sourceImage] source]];
					// Hack: this check shouldn't be necessary if the "Remove Image Source" code was 
					// fully working.
				if (sourceIndex != NSNotFound)
					[xmlRepresentation appendFormat:@"\t\t<UNIQUE_MATCH SOURCE=\"%d\" ID=\"%@\" VALUE=\"%g\"/>\n", 
													sourceIndex, [[[uniqueMatch sourceImage] identifier] stringByEscapingXMLEntites], [uniqueMatch matchValue]];
#ifdef DEBUG
				else
					NSLog(@"oops");
#endif
			}
			MacOSaiXImageMatch	*bestMatch = [tile bestImageMatch];
			if (bestMatch)
			{
				unsigned long	sourceIndex = [imageSources indexOfObjectIdenticalTo:[[bestMatch sourceImage] source]];
					// Hack: this check shouldn't be necessary if the "Remove Image Source" code was 
					// fully working.
				if (sourceIndex != NSNotFound)
					[xmlRepresentation appendFormat:@"\t\t<BEST_MATCH SOURCE=\"%d\" ID=\"%@\" VALUE=\"%g\"/>\n", 
													sourceIndex, [[[bestMatch sourceImage] identifier] stringByEscapingXMLEntites], [bestMatch matchValue]];
#ifdef DEBUG
				else
					NSLog(@"oops");
#endif
			}
			
			[xmlRepresentation appendString:@"\t</TILE>\n"];
			
			[tilePool release];
		}
		
		[xmlRepresentation appendString:@"</TILES>\n"];
	}
	
	[xmlRepresentation appendString:@"</MOSAIC>\n\n"];
	
	return xmlRepresentation;
}


- (NSFileWrapper *)fileWrapperRepresentationOfType:(NSString *)type
{
	NSFileWrapper	*fileWrapper = nil;
	
	if ([type isEqualToString:@"MacOSaiX Project"])
	{
		NSMutableDictionary	*fileWrappers = [NSMutableDictionary dictionary];
		
		[fileWrappers setObject:[[[NSFileWrapper alloc] initRegularFileWithContents:[[self xmlRepresentation] dataUsingEncoding:NSUTF8StringEncoding]] autorelease] forKey:@"Mosaic.xml"];
		
		fileWrapper = [[[NSFileWrapper alloc] initDirectoryWithFileWrappers:fileWrappers] autorelease];
	}
	
	return fileWrapper;
}


- (BOOL)writeToFile:(NSString *)fileName 
			 ofType:(NSString *)docType 
	   originalFile:(NSString *)originalFileName 
	  saveOperation:(NSSaveOperationType)saveOperationType
{
	BOOL	success = [super writeToFile:fileName ofType:docType originalFile:originalFileName saveOperation:saveOperationType];
	
	if (success && ![fileName isEqualToString:originalFileName])
	{
			// Make the folder a package.
		FSRef		folderRef;
		OSStatus	status = FSPathMakeRef((const UInt8 *)[fileName UTF8String], &folderRef, NULL);
		if (status == noErr)
		{
			FSCatalogInfo	info;
			OSErr			err = FSGetCatalogInfo(&folderRef, kFSCatInfoFinderInfo, &info, NULL, NULL, NULL);
			if (err == noErr)
			{
				((FInfo *)&(info.finderInfo))->fdFlags |= kHasBundle;
				err = FSSetCatalogInfo(&folderRef, kFSCatInfoFinderInfo, &info);
			}
		}
		
			// Move or copy the disk caches to the save location.
		NSEnumerator			*imageSourceEnumerator = [[[self mosaic] imageSources] objectEnumerator];
		id<MacOSaiXImageSource>	imageSource = nil;
		NSString				*originalCachePath = [[self mosaic] diskCachePath];
		while (imageSource = [imageSourceEnumerator nextObject])
			if (![imageSource canRefetchImages])
			{
				NSString	*subPath = [[self mosaic] diskCacheSubPathForImageSource:imageSource], 
							*oldCachePath = [originalCachePath stringByAppendingPathComponent:subPath], 
							*newCachePath = [fileName stringByAppendingPathComponent:subPath];
				
				if (!originalFileName || saveOperationType == NSSaveOperation)
					[[NSFileManager defaultManager] movePath:oldCachePath toPath:newCachePath handler:nil];
				else
					[[NSFileManager defaultManager] copyPath:oldCachePath toPath:newCachePath handler:nil];
			}
	}
	
	return success;
}


- (BOOL)writeWithBackupToFile:(NSString *)fullDocumentPath ofType:(NSString *)docType saveOperation:(NSSaveOperationType)saveOperationType
{
	BOOL	success = NO, 
			wasRunning = ![mosaic isPaused];
	
	if (wasRunning)
		[mosaic pause];
	
	[[self mainWindowController] setProgressCancelAction:nil];
	[[self mainWindowController] displayProgressPanelWithMessage:NSLocalizedString(@"Saving mosaic project...", @"")];

	// Moving image source disk cache folders and updating their disk cache path must be done atomically.  Otherwise the "refresh tiles" thread could try to grab an image from disk after the cache folder had moved but before the path got updated.
	// TODO: Figure out how to do this without blocking all mosaics.
	[[MacOSaiXImageCache sharedImageCache] lock];
	{
		success = [super writeWithBackupToFile:fullDocumentPath ofType:docType saveOperation:saveOperationType];
		
		if (success && (saveOperationType == NSSaveOperation || saveOperationType == NSSaveAsOperation))
			[[self mosaic] setDiskCachePath:fullDocumentPath];
	}
	[[MacOSaiXImageCache sharedImageCache] unlock];
	
	[[self mainWindowController] closeProgressPanel];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Save Mosaics"])
		[self startAutosaveTimer];
	
	if (wasRunning)
		[mosaic resume];

	return success;
}


#pragma mark -
#pragma mark Loading


// Loading the saved XML is currently done using the CFXML API so that we can run on Jaguar.
// Once Jaguar support is no longer required this could be cleaned up by switching to the NSXML API.

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
	[NSThread detachNewThreadSelector:@selector(loadXMLFile:) toTarget:self withObject:fileName];

	return YES;
}


	// Parser callback prototypes.
void		*createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info);
void		addChild(CFXMLParserRef parser, void *parent, void *child, void *info);
void		endStructure(CFXMLParserRef parser, void *xmlType, void *info);


- (void)loadXMLFile:(NSString *)fileName
{
	NSString			*errorMessage = nil;
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	loading = YES;
	
	while ([[self windowControllers] count] == 0)
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	[[self mainWindowController] displayProgressPanelWithMessage:@"Loading the mosaic project..."];
	
	[[self mosaic] setDiskCachePath:fileName];
	
	NSData	*xmlData = [NSData dataWithContentsOfFile:[fileName stringByAppendingPathComponent:@"Mosaic.xml"]];
	
	if (xmlData)
	{
			// Set up the parser callbacks and context.
		CFXMLParserCallBacks	callbacks = {0, createStructure, addChild, endStructure, NULL, NULL};	//resolveExternalEntity, handleError};
		NSMutableArray			*stack = [NSMutableArray arrayWithObjects:self, mosaic, nil],
								*contextArray = [NSMutableArray arrayWithObjects:stack, 
																				 [NSNumber numberWithLong:[xmlData length]], 
																				 [NSNumber numberWithInt:0], 
																				 nil];
		CFXMLParserContext		context = {0, contextArray, NULL, NULL, NULL};
		
			// Create the parser with the option to skip whitespace.
		CFXMLParserRef			parser = CFXMLParserCreate(kCFAllocatorDefault, 
														   (CFDataRef)xmlData, 
														   NULL, 
														   kCFXMLParserSkipWhitespace, 
														   kCFXMLNodeCurrentVersion, 
														   &callbacks, 
														   &context);

			// Invoke the parser.
		if (!CFXMLParserParse(parser))
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
			
			errorMessage = [NSString stringWithFormat:@"Error at line %d: %@", CFXMLParserGetLineNumber(parser), parserError];
			
			[parserError release];
		}
		
		CFRelease(parser);
	}
	else
		errorMessage = @"The file could not be read.";
	
	if (!errorMessage)
		[NSApplication detachDrawingThread:@selector(extractTileBitmaps) toTarget:mosaic withObject:nil];
	
	[[self mainWindowController] closeProgressPanel];
	
	loading = NO;
	
	if (errorMessage)
		[self performSelectorOnMainThread:@selector(presentFailedLoadSheet:) 
							   withObject:errorMessage 
						    waitUntilDone:NO];
//	else
//		[[self mainWindowController] performSelectorOnMainThread:@selector(synchronizeGUIWithDocument) 
//													  withObject:nil 
//												   waitUntilDone:NO];
	[pool release];
}


void *createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
		MacOSaiXDocument	*document = [stack objectAtIndex:0];
		MacOSaiXMosaic		*mosaic = [stack objectAtIndex:1];
		
		switch (CFXMLNodeGetTypeCode(node))
		{
			case kCFXMLNodeTypeElement:
			{
				NSString			*elementType = (NSString *)CFXMLNodeGetString(node);
				CFXMLElementInfo	*nodeInfo = (CFXMLElementInfo *)CFXMLNodeGetInfoPtr(node);
				NSDictionary		*nodeAttributes = (NSDictionary *)nodeInfo->attributes;
				
				if ([elementType isEqualToString:@"MOSAIC"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"ORIGINAL_IMAGE"])
				{
					newObject = [[nodeAttributes objectForKey:@"PATH"] stringByUnescapingXMLEntites];
				}
				else if ([elementType isEqualToString:@"TILE_SHAPES_SETTINGS"])
				{
					NSString	*className = [nodeAttributes objectForKey:@"CLASS"];
					
					newObject = [[NSClassFromString(className) alloc] init];
				}
				else if ([elementType isEqualToString:@"IMAGE_USAGE"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_REUSE"])
				{
					NSString	*imageReuseCount = [nodeAttributes objectForKey:@"COUNT"],
								*imageReuseDistance = [nodeAttributes objectForKey:@"DISTANCE"];
					
					[mosaic setImageUseCount:[imageReuseCount intValue]];
					[mosaic setImageReuseDistance:[imageReuseDistance intValue]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_CROP"])
				{
					NSString	*cropLimitString = [nodeAttributes objectForKey:@"LIMIT"];
					
					[mosaic setImageCropLimit:[cropLimitString intValue]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_SOURCES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_SOURCE"])
				{
					NSString	*className = [nodeAttributes objectForKey:@"CLASS"],
								*imageCount = [nodeAttributes objectForKey:@"IMAGE_COUNT"], 
								*cacheName = [nodeAttributes objectForKey:@"CACHE_NAME"], 
								*isFiller = [nodeAttributes objectForKey:@"FILLER"], 
								*imagesLost = [nodeAttributes objectForKey:@"IMAGES_LOST"];
					
					newObject = [[NSClassFromString(className) alloc] init];
					
					[mosaic setImageCount:[imageCount intValue] forImageSource:newObject];
					
					[mosaic setImageSource:newObject isFiller:[isFiller isEqualToString:@"YES"]];
					
					[mosaic setImageSource:newObject hasLostImages:[imagesLost isEqualToString:@"YES"]];
					
					if (cacheName)
						[mosaic setDiskCacheSubPath:cacheName forImageSource:newObject];
				}
				else if ([elementType isEqualToString:@"QUEUED_IMAGES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"QUEUED_IMAGE"] && [stack lastObject] == mosaic)
				{
					NSString				*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
					NSEnumerator			*stackEnumerator = [stack reverseObjectEnumerator];
					id<MacOSaiXImageSource>	imageSource = [stackEnumerator nextObject];
					while (imageSource && ![imageSource conformsToProtocol:@protocol(MacOSaiXImageSource)])
						imageSource = [stackEnumerator nextObject];
					
					if (imageSource)
						[mosaic revisitSourceImage:[MacOSaiXSourceImage sourceImageWithImage:nil 
																				  identifier:imageIdentifier 
																					  source:imageSource]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"SCRAP_IMAGES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"SCRAP_IMAGE"])
				{
					NSString				*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
					NSEnumerator			*stackEnumerator = [stack reverseObjectEnumerator];
					id<MacOSaiXImageSource>	imageSource = [stackEnumerator nextObject];
					while (imageSource && ![imageSource conformsToProtocol:@protocol(MacOSaiXImageSource)])
						imageSource = [stackEnumerator nextObject];
					
					if (imageSource)
						[mosaic addSourceImageToScrap:[MacOSaiXSourceImage sourceImageWithImage:nil 
																					 identifier:imageIdentifier 
																						 source:imageSource]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"TILES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"TILE"])
				{
					NSString		*optimalAttribute = [nodeAttributes objectForKey:@"OPTIMAL"];
					MacOSaiXTile	*tile = [[MacOSaiXTile alloc] initWithOutline:nil fromMosaic:mosaic];
					
					if ([optimalAttribute isEqualToString:@"NO"])
						[tile setUniqueImageMatchIsOptimal:NO];
					
					newObject = tile;
				}
				else if ([elementType isEqualToString:@"OUTLINE"])
				{
					newObject = [[NSBezierPath bezierPath] retain];
				}
				else if ([elementType isEqualToString:@"MOVE_TO"] || 
						 [elementType isEqualToString:@"LINE_TO"] || 
						 [elementType isEqualToString:@"CURVE_TO"] || 
						 [elementType isEqualToString:@"CLOSE_PATH"])
				{
					newObject = [[NSMutableDictionary dictionaryWithDictionary:nodeAttributes] retain];
					[(NSMutableDictionary *)newObject setObject:elementType forKey:@"Element Type"];
				}
				else if ([elementType isEqualToString:@"BEST_MATCH"])
				{
					if ([[document mainWindowController] viewingOriginal])
						[[document mainWindowController] performSelectorOnMainThread:@selector(setViewMosaic:) 
																		  withObject:nil 
																	   waitUntilDone:NO];
					
					int					sourceIndex = [[nodeAttributes objectForKey:@"SOURCE"] intValue];
					if (sourceIndex >= 0 && sourceIndex < [[mosaic imageSources] count])
					{
						NSString	*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
						float		matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
						
						newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																	   sourceImage:[MacOSaiXSourceImage sourceImageWithImage:nil 
																												  identifier:imageIdentifier 
																													  source:[[mosaic imageSources] objectAtIndex:sourceIndex]] 
																			  tile:(MacOSaiXTile *)@"Best"];
					}
					else
						CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, CFSTR("Tile is using an image from an unknown source."));
				}
				else if ([elementType isEqualToString:@"UNIQUE_MATCH"])
				{
					if ([[document mainWindowController] viewingOriginal])
						[[document mainWindowController] performSelectorOnMainThread:@selector(setViewMosaic:) 
																		  withObject:nil 
																	   waitUntilDone:NO];
					
					int					sourceIndex = [[nodeAttributes objectForKey:@"SOURCE"] intValue];
					if (sourceIndex >= 0 && sourceIndex < [[mosaic imageSources] count])
					{
						NSString	*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
						float		matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
						
						newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																	   sourceImage:[MacOSaiXSourceImage sourceImageWithImage:nil 
																												  identifier:imageIdentifier 
																													  source:[[mosaic imageSources] objectAtIndex:sourceIndex]] 
																			  tile:(MacOSaiXTile *)@"Unique"];
					}
					else
						CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, CFSTR("Tile is using an image from an unknown source."));
				}
				else if ([elementType isEqualToString:@"USER_CHOSEN_MATCH"])
				{
					NSString	*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
					float		matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
					
					newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																   sourceImage:[MacOSaiXSourceImage sourceImageWithImage:nil 
																											  identifier:imageIdentifier 
																												  source:[mosaic handPickedImageSource]] 
																		  tile:(MacOSaiXTile *)@"User Chosen"];
				}
				else
				{
					newObject = [[NSMutableDictionary dictionaryWithDictionary:nodeAttributes] retain];
					[(NSMutableDictionary *)newObject setObject:elementType forKey:@"Element Type"];
				}
				break;
			}
			
			case kCFXMLNodeTypeText:
				if ([[stack lastObject] isKindOfClass:[NSMutableDictionary class]])
					[[stack lastObject] setObject:(NSString *)CFXMLNodeGetString(node) 
										   forKey:kMacOSaiXImageSourceSettingText];
				break;
			
			default:
				;
	//			NSLog(@"Ignoring %d", CFXMLNodeGetTypeCode(node));
		}
		
		if (newObject)
			[stack addObject:newObject];
	NS_HANDLER
		CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:@"Could not create structure (%@)", [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
		// Return the object that will be passed to the addChild and endStructure callbacks.
    return (void *)newObject;
}


void addChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
	MacOSaiXDocument	*document = [stack objectAtIndex:0];
	MacOSaiXMosaic		*mosaic = [stack objectAtIndex:1];

	if (parent == mosaic && [(id)child isKindOfClass:[NSString class]])
	{
			// Set the original image path.
		[document setOriginalImagePath:(NSString *)child];
		NSImage		*originalImage = [[NSImage alloc] initWithContentsOfFile:child];
		[mosaic setOriginalImage:originalImage];
		[originalImage release];
	}
	else if ([(id)parent conformsToProtocol:@protocol(MacOSaiXTileShapes)] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a setting on to the tile shapes instance.
		[(id<MacOSaiXTileShapes>)parent useSavedSetting:(NSDictionary *)child];
	}
	else if ([(id)parent conformsToProtocol:@protocol(MacOSaiXImageSource)] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a setting on to one of the image sources.
		[(id<MacOSaiXImageSource>)parent useSavedSetting:(NSDictionary *)child];
	}
	else if ([(id)parent isKindOfClass:[NSDictionary class]] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a nested setting on to either the tile shapes instance or one of the image source instances.
		NSEnumerator	*stackEnumerator = [stack reverseObjectEnumerator];
		id				stackObject = nil;
		while (stackObject = [stackEnumerator nextObject])
			if ([stackObject conformsToProtocol:@protocol(MacOSaiXTileShapes)] || [stackObject conformsToProtocol:@protocol(MacOSaiXImageSource)])
			{
				[stackObject addSavedChildSetting:(NSDictionary *)child toParent:(NSDictionary *)parent];
				break;
			}
	}
	else if (parent == mosaic && [(id)child isKindOfClass:[MacOSaiXTile class]])
	{
			// Add a tile to the mosaic.
		[mosaic addTile:(MacOSaiXTile *)child];
	}
	else if ([(id)parent isKindOfClass:[NSBezierPath class]] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Add a path element to a tile's outline.
		NSBezierPath	*tileOutline = (NSBezierPath *)parent;
		NSDictionary	*attributes = (NSDictionary *)child;
		NSString		*elementType = [attributes objectForKey:@"Element Type"];
		
		if ([elementType isEqualToString:@"MOVE_TO"])
			[tileOutline moveToPoint:NSMakePoint([[attributes objectForKey:@"X"] floatValue], [[attributes objectForKey:@"Y"] floatValue])];
		else if ([elementType isEqualToString:@"LINE_TO"])
			[tileOutline lineToPoint:NSMakePoint([[attributes objectForKey:@"X"] floatValue], [[attributes objectForKey:@"Y"] floatValue])];
		else if ([elementType isEqualToString:@"CURVE_TO"])
			[tileOutline curveToPoint:NSMakePoint([[attributes objectForKey:@"X"] floatValue], [[attributes objectForKey:@"Y"] floatValue])
						 controlPoint1:NSMakePoint([[attributes objectForKey:@"C1X"] floatValue], [[attributes objectForKey:@"C1Y"] floatValue]) 
						 controlPoint2:NSMakePoint([[attributes objectForKey:@"C2X"] floatValue], [[attributes objectForKey:@"C2Y"] floatValue])];
		else if ([elementType isEqualToString:@"CLOSE_PATH"])
			[tileOutline closePath];
	}
	else if ([(id)parent isKindOfClass:[MacOSaiXTile class]] && [(id)child isKindOfClass:[MacOSaiXImageMatch class]])
	{
		MacOSaiXImageMatch	*match = child;
		NSString			*matchType = (NSString *)[match tile];
		
		[match setTile:parent];
		
		if ([matchType isEqualToString:@"Best"])
			[(MacOSaiXTile *)parent setBestImageMatch:match];
		else if ([matchType isEqualToString:@"Unique"])
		{
			[(MacOSaiXTile *)parent setUniqueImageMatch:match];
			
			[mosaic setImageMatchIsInUse:match];
		}
		else if ([matchType isEqualToString:@"User Chosen"])
			[(MacOSaiXTile *)parent setUserChosenImageMatch:match];
		
		[(MacOSaiXImageMatch *)child setTile:(MacOSaiXTile *)parent];
	}
	
//	NSLog(@"Parent <%@: %p> added child <%@: %p>", NSStringFromClass([parent class]), (void *)parent, NSStringFromClass([child class]), (void *)child);

	[pool release];
}


void endStructure(CFXMLParserRef parser, void *newObject, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
	MacOSaiXDocument	*document = [stack objectAtIndex:0];
	MacOSaiXMosaic		*mosaic = [stack objectAtIndex:1];
	id					parent = [stack objectAtIndex:[stack count] - 2];
	
	if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXTileShapes)])
	{
		[mosaic setTileShapes:(id<MacOSaiXTileShapes>)newObject creatingTiles:NO];
		[(id)newObject release];
	}
	else if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXImageSource)])
	{
		BOOL	isFiller = [mosaic imageSourceIsFiller:(id<MacOSaiXImageSource>)newObject];

		[mosaic addImageSource:(id<MacOSaiXImageSource>)newObject isFiller:isFiller];
		
		[(id)newObject release];
	}
	else if ([(id)newObject isKindOfClass:[NSBezierPath class]] && [(id)parent isKindOfClass:[MacOSaiXTile class]])
	{
		// Add the bezier path outline for a tile.
		[(MacOSaiXTile *)parent setOutline:(NSBezierPath *)newObject];
	}
	else if ([(id)newObject isKindOfClass:[MacOSaiXTile class]] || 
			 [(id)newObject isKindOfClass:[NSBezierPath class]] || 
			 [(id)newObject isKindOfClass:[NSDictionary class]] || 
			 [(id)newObject isKindOfClass:[MacOSaiXImageMatch class]])
	{
			// Release any objects we created in createStructure() now that they are retained by their parent.
		[(id)newObject release];
	}
	
	if ([(id)newObject isKindOfClass:[NSDictionary class]])
	{
		NSEnumerator	*stackEnumerator = [stack reverseObjectEnumerator];
		id				stackObject = nil;
		while (stackObject = [stackEnumerator nextObject])
			if ([stackObject conformsToProtocol:@protocol(MacOSaiXTileShapes)] || [stackObject conformsToProtocol:@protocol(MacOSaiXImageSource)])
			{
				[stackObject savedSettingIsCompletelyLoaded:(NSDictionary *)newObject];
				break;
			}
	}

	[stack removeLastObject];
	
		// Update the progress.
	long	lengthOfXML = [[(NSArray *)info objectAtIndex:1] longValue];
	int		currentPercentage = CFXMLParserGetLocation(parser) * 100.0 / lengthOfXML;
	
	if (currentPercentage > [[(NSArray *)info objectAtIndex:2] intValue])
	{
		NSNumber	*percentComplete = [NSNumber numberWithInt:currentPercentage];
		[[[document windowControllers] objectAtIndex:0] setProgressPercentComplete:percentComplete];
		[(NSMutableArray *)info replaceObjectAtIndex:2 withObject:percentComplete];
	}
	
	[pool release];
}


- (void)presentFailedLoadSheet:(id)errorMessage
{
	NSBeginAlertSheet(@"The mosaic could not be loaded.", @"Close", nil, nil, [mainWindowController window], 
					  self, nil, @selector(failedLoadSheetDidDismiss:returnCode:contextInfo:), nil, errorMessage);
}


- (void)failedLoadSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[self close];
}


#pragma mark -


- (BOOL)isClosing
{
	return documentIsClosing;
}


- (void)close
{
	if (documentIsClosing)
		return;	// make sure to do the steps below only once (not sure why this method sometimes gets called twice...)
	
		// Let the helper threads know we are closing and resume so that they can clean up and exit.
	documentIsClosing = YES;
	[mosaic documentIsClosing];
	
	if ([autosaveTimer isValid])
	{
		[autosaveTimer invalidate];
		[autosaveTimer autorelease];
		autosaveTimer = nil;
	}
	
		// wait for the threads to shut down
    while ([mosaic isBusy])
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
	
    [super close];
}


#pragma mark -

- (void)dealloc
{
	[self setMosaic:nil];
	[mainWindowController release];
    [lastSaved release];
	if ([autosaveTimer isValid])
		[autosaveTimer invalidate];
	[autosaveTimer release];
	
    [super dealloc];
}

@end
