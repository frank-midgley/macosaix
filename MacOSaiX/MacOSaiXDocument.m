/*
	MacOSaiXDocument.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXDocument.h"

#import "MacOSaiX.h"
#import "MacOSaiXHandPickedImageSource.h"
#import "MacOSaiXImageOrientations.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXProgressController.h"
#import "MacOSaiXSourceImage.h"
#import "MacOSaiXTileShapes.h"
#import "Tiles.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"

#import <unistd.h>


#define kMacOSaiXCFXMLErrorUserCancelled 1024


@interface MacOSaiXMosaic (PrivateMethods)
- (void)addTile:(MacOSaiXTile *)tile;
- (BOOL)started;
- (void)lockWhilePaused;

- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;

- (void)spawnImageSourceThreads;
- (void)setNumberOfImagesFound:(unsigned long)imageCount forImageSource:(id<MacOSaiXImageSource>)imageSource;

- (void)extractTileImagesFromTargetImage;
- (void)calculateImageMatches:(id)path;

- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (NSImage *)createEditorImage:(int)rowIndex;
@end


@interface MacOSaiXDocument (PrivateMethods)
- (void)setProgressPercentComplete:(NSNumber *)number;
- (BOOL)loadWasCancelled;
@end


@protocol MacOSaiXTileShapesDeprecated <MacOSaiXTileShapes>
- (void)useSavedSetting:(NSDictionary *)settingDict;
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict;
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict;
@end


@protocol MacOSaiXImageSourceDeprecated <MacOSaiXImageSource>
- (void)useSavedSetting:(NSDictionary *)settingDict;
- (void)addSavedChildSetting:(NSDictionary *)childSettingDict toParent:(NSDictionary *)parentSettingDict;
- (void)savedSettingIsCompletelyLoaded:(NSDictionary *)settingDict;
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
	if (![self fileName])
	{
			// This is a new document, not one loaded from disk.
		[(MacOSaiX *)[NSApp delegate] discoverPlugIns];
		NSString	*defaultShapesClassString = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Chosen Tile Shapes Class"], 
					*defaultOrientationsClassString = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Chosen Image Orientations Class"];
		[[self mosaic] setTileShapes:[[[NSClassFromString(defaultShapesClassString) alloc] init] autorelease]
					   creatingTiles:YES];
		[[self mosaic] setImageOrientations:[[[NSClassFromString(defaultOrientationsClassString) alloc] init] autorelease]];
		
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
			}
		}
	}
	
	mainWindowController = [[MacOSaiXWindowController alloc] initWithWindow:nil];
	[mainWindowController setMosaic:[self mosaic]];
	[self addWindowController:mainWindowController];
	
	if ([[self mosaic] isBeingLoaded])
	{
		progressController = [[MacOSaiXProgressController alloc] initWithWindow:nil];
		[progressController setCancelTarget:self action:@selector(cancelLoad:)];
		[mainWindowController showWindow:self];
		[progressController displayPanelWithMessage:NSLocalizedString(@"Loading the mosaic project...", @"") 
									 modalForWindow:[mainWindowController window]];
	}
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
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeImageSourcesNotification 
												   object:mosaic];
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (void)mosaicDidChangeState:(NSNotification *)notification
{
	if (![[self mosaic] isBeingLoaded])
		[self updateChangeCount:NSChangeDone];
}


- (void)setProgressPercentComplete:(NSNumber *)number
{
	[progressController setPercentComplete:number];
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


- (void)startAutosaveTimer:(id)dummy
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


- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	if (changeType == NSChangeDone && !autosaveTimer && 
		[[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Save Mosaics"])
		[self performSelectorOnMainThread:@selector(startAutosaveTimer:) withObject:nil waitUntilDone:YES];
	
	[super updateChangeCount:changeType];
}


- (BOOL)isSaving
{
	return saving;
}


- (void)setIsSaving:(BOOL)isSaving
{
	saving = isSaving;
}


- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setRequiredFileType:@"mosaic"];
	return YES;
}


- (void)createFileWrapperAtPath:(NSString *)newPath 
		   fromOldWrapperAtPath:(NSString *)oldPath 
			copyingCachedImages:(BOOL)copyCachedImages
{
	// Create the wrapper directory if it doesn't already exist.
	NSFileManager	*fileManager = [NSFileManager defaultManager];
	BOOL			isDir;
	if (([fileManager fileExistsAtPath:newPath isDirectory:&isDir] && isDir) || 
		[fileManager createDirectoryAtPath:newPath attributes:nil])
	{
			// Make the folder a package.
		FSRef		folderRef;
		OSStatus	status = FSPathMakeRef([newPath UTF8String], &folderRef, NULL);
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
		
			// Move or copy any image source cache directories to the new file wrapper.
		NSEnumerator					*imageSourceEnumeratorEnumerator = [[[self mosaic] imageSourceEnumerators] objectEnumerator];
		MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = nil;
		while (imageSourceEnumerator = [imageSourceEnumeratorEnumerator nextObject])
			if (![[imageSourceEnumerator imageSource] canRefetchImages])
			{
				NSString	*subPath = [[self mosaic] diskCacheSubPathForImageSource:[imageSourceEnumerator imageSource]], 
							*oldCachePath = [oldPath stringByAppendingPathComponent:subPath], 
							*newCachePath = [newPath stringByAppendingPathComponent:subPath];
				
				if (copyCachedImages)
					[[NSFileManager defaultManager] copyPath:oldCachePath toPath:newCachePath handler:nil];
				else
					[[NSFileManager defaultManager] movePath:oldCachePath toPath:newCachePath handler:nil];
			}
	}
}


- (void)saveToFile:(NSString *)fileName 
	 saveOperation:(NSSaveOperationType)saveOperation 
		  delegate:(id)delegate 
   didSaveSelector:(SEL)didSaveSelector 
	   contextInfo:(void *)contextInfo;
{
	if (!fileName)
		return;	// the user cancelled the save
	
	[self setIsSaving:YES];
	
	BOOL			wasPaused = [[self mosaic] isPaused];
	
		// Display a sheet while the save is underway
	progressController = [[MacOSaiXProgressController alloc] initWithWindow:nil];
	[progressController displayPanelWithMessage:NSLocalizedString(@"Saving mosaic project...", @"") 
								 modalForWindow:[[self mainWindowController] window]];
	
		// Pause the mosaic so that it is in a static state while saving.
	[[self mosaic] pause];
	
		// Create the new file wrapper and move over any cached images.
	[self createFileWrapperAtPath:fileName 
			 fromOldWrapperAtPath:[[self mosaic] diskCachePath] 
			  copyingCachedImages:NO];
	[[self mosaic] setDiskCachePath:fileName];
	
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											fileName, @"Save Path", 
											[NSNumber numberWithInt:saveOperation], @"Save Operation", 
											[NSNumber numberWithBool:wasPaused], @"Was Paused", 
											nil];
	if (delegate)
		[parameters setObject:delegate forKey:@"Did Save Delegate"];
	if (didSaveSelector)
		[parameters setObject:NSStringFromSelector(didSaveSelector) forKey:@"Did Save Selector"];
	if (contextInfo)
		[parameters setObject:[NSNumber numberWithUnsignedLong:(unsigned long)contextInfo] forKey:@"Context Info"];
	
	[NSThread detachNewThreadSelector:@selector(threadedSaveWithParameters:) 
							 toTarget:self 
						   withObject:parameters];
}


- (BOOL)writeToFile:(NSString *)newDocumentPath 
			 ofType:(NSString *)docType 
	   originalFile:(NSString *)oldDocumentPath 
	  saveOperation:(NSSaveOperationType)saveOperationType
{
	[self setIsSaving:YES];
	
	BOOL			wasPaused = [[self mosaic] isPaused];
	
	progressController = [[MacOSaiXProgressController alloc] initWithWindow:nil];
	[progressController displayPanelWithMessage:NSLocalizedString(@"Saving mosaic project...", @"") 
								 modalForWindow:[[self mainWindowController] window]];
	
		// Pause the mosaic so that it is in a static state while saving.
	[[self mosaic] pause];
	
		// Create the new file wrapper and move/copy over any cached images.
	[self createFileWrapperAtPath:newDocumentPath 
			 fromOldWrapperAtPath:oldDocumentPath 
			  copyingCachedImages:(saveOperationType != NSSaveOperation)];
	if (saveOperationType == NSSaveOperation || saveOperationType == NSSaveAsOperation)
		[[self mosaic] setDiskCachePath:newDocumentPath];
	
	NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											newDocumentPath, @"Save Path", 
											[NSNumber numberWithInt:saveOperationType], @"Save Operation", 
											[NSNumber numberWithBool:wasPaused], @"Was Paused", 
											nil];
	[NSThread detachNewThreadSelector:@selector(threadedSaveWithParameters:) 
							 toTarget:self 
						   withObject:parameters];

	return YES;
}


- (IBAction)cancelSave:(id)sender
{
	// TODO?
}


- (NSString *)indexAsAlpha:(int)index
{
	char	buffer[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	char	*p = &buffer[6];
	
	do
	{
		*p-- = (index % 26) + 65;
		index /= 26;
	}
	while (index != 0);
	
	return [NSString stringWithCString:++p];
}


- (void)threadedSaveWithParameters:(NSDictionary *)parameters
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	BOOL				saveSucceeded = NO;
	NSString			*savePath = [parameters objectForKey:@"Save Path"];
	id					didSaveDelegate = [parameters objectForKey:@"Did Save Delegate"];
	SEL					didSaveSelector = NSSelectorFromString([parameters objectForKey:@"Did Save Selector"]);
	void				*contextInfo = (void *)[[parameters objectForKey:@"Context Info"] unsignedLongValue];
	BOOL				wasPaused = [[parameters objectForKey:@"Was Paused"] boolValue];
	
	NS_DURING
			// Don't usurp the main thread.
		[NSThread setThreadPriority:0.1];
		
			// Create the master save file in XML format.
		NSString	*xmlPath = [savePath stringByAppendingPathComponent:@"Mosaic.xml"];
		if (![[NSFileManager defaultManager] createFileAtPath:xmlPath contents:nil attributes:nil])
		{
			// TODO
		}
		else
		{
			NSFileHandle	*fileHandle = [NSFileHandle fileHandleForWritingAtPath:xmlPath];
			
				// Write out the XML header.
			[fileHandle writeData:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[@"<!DOCTYPE plist PUBLIC \"-//Frank M. Midgley//DTD MacOSaiX 1.0//EN\" \"http://homepage.mac.com/knarf/DTDs/MacOSaiX-1.0.dtd\">\n\n" dataUsingEncoding:NSUTF8StringEncoding]];

			[fileHandle writeData:[@"<MOSAIC>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];

				// Write out the path to the target image
			[fileHandle writeData:[[NSString stringWithFormat:@"<TARGET_IMAGE PATH=\"%@\" ASPECT_RATIO=\"%f\"/>\n\n", 
												[[[self mosaic] targetImagePath] stringByEscapingXMLEntites], 
												[[self mosaic] aspectRatio]] 
												dataUsingEncoding:NSUTF8StringEncoding]];
			
			[fileHandle writeData:[@"<IMAGE_USAGE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_REUSE COUNT=\"%d\" DISTANCE=\"%d\"/>\n", [[self mosaic] imageUseCount], [[self mosaic] imageReuseDistance]] dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_CROP LIMIT=\"%d\"/>\n", [[self mosaic] imageCropLimit]] dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[@"</IMAGE_USAGE>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
			
				// Write out the image sources.
			[fileHandle writeData:[@"<IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
			NSArray	*imageSourceEnumerators = [[self mosaic] imageSourceEnumerators];
			int		index;
			for (index = 0; index < [imageSourceEnumerators count]; index++)
			{
				MacOSaiXImageSourceEnumerator	*imageSourceEnumerator = [imageSourceEnumerators objectAtIndex:index];
				id<MacOSaiXImageSource>			imageSource = [imageSourceEnumerator imageSource];
				NSString						*className = NSStringFromClass([imageSource class]);
				if ([imageSource canRefetchImages])
					[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_SOURCE ID=\"%d\" CLASS=\"%@\" IMAGE_COUNT=\"%d\" />\n", 
																	  index, className, [imageSourceEnumerator numberOfImagesFound]] 
												dataUsingEncoding:NSUTF8StringEncoding]];
				else
					[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_SOURCE ID=\"%d\" CLASS=\"%@\" IMAGE_COUNT=\"%d\" CACHE_NAME=\"%@\" />\n", 
																	  index, className, [imageSourceEnumerator numberOfImagesFound],
																	  [[self mosaic] diskCacheSubPathForImageSource:imageSource]] 
												dataUsingEncoding:NSUTF8StringEncoding]];
				NSString	*settingsFileName = [[NSString stringWithFormat:@"Image Source %d", index] stringByAppendingPathExtension:[[imageSource class] settingsExtension]];
				if (![imageSource saveSettingsToFileAtPath:[savePath stringByAppendingPathComponent:settingsFileName]])
					[NSException raise:@"" format:@"Could not save the settings for image source %d.", index];
			}
			[fileHandle writeData:[@"</IMAGE_SOURCES>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
			
				// Write out the image orientations.
			NSString		*className = NSStringFromClass([[[self mosaic] imageOrientations] class]);
			if (![[[self mosaic] imageOrientations] saveSettingsToFileAtPath:[[savePath stringByAppendingPathComponent:@"Image Orientations Settings"] stringByAppendingPathExtension:[[[[self mosaic] imageOrientations] class] settingsExtension]]])
				[NSException raise:@"" format:@"Could not save the image orientations settings."];
			[fileHandle writeData:[[NSString stringWithFormat:@"<IMAGE_ORIENTATIONS CLASS=\"%@\" />\n\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
			
				// Write out the tiles and the shapes settings.
			className = NSStringFromClass([[[self mosaic] tileShapes] class]);
			if (![[[self mosaic] tileShapes] saveSettingsToFileAtPath:[[savePath stringByAppendingPathComponent:@"Tile Shapes Settings"] stringByAppendingPathExtension:[[[[self mosaic] tileShapes] class] settingsExtension]]])
				[NSException raise:@"" format:@"Could not save the tile shapes settings."];
			[fileHandle writeData:[[NSString stringWithFormat:@"<TILES SHAPES_CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
			NSMutableString	*buffer = [NSMutableString string];
			NSEnumerator	*tileEnumerator = [[[self mosaic] tiles] objectEnumerator];
			MacOSaiXTile	*tile = nil;
			while (tile = [tileEnumerator nextObject])
			{
				NSAutoreleasePool	*tilePool = [[NSAutoreleasePool alloc] init];
				
				NSString			*fillStyle = nil;
				if ([tile fillStyle] == fillWithUniqueMatch)
					fillStyle = @"Unique Match";
				else if ([tile fillStyle] == fillWithHandPicked)
					fillStyle = @"User Chosen Image";
				else if ([tile fillStyle] == fillWithTargetImage)
					fillStyle = @"Target Image";
				else
					fillStyle = @"Solid Color";
				
				if ([tile hasImageOrientation])
					[buffer appendFormat:@"\t<TILE FILL_STYLE=\"%@\" IMAGE_ORIENTATION=\"%@\">\n", fillStyle, [NSString stringWithFloat:[tile imageOrientation]]];
				else
					[buffer appendFormat:@"\t<TILE FILL_STYLE=\"%@\">\n", fillStyle];
				
					// Write out the tile's outline.
				[buffer appendString:@"\t\t<OUTLINE>\n"];
				int elementCount = [[tile outline] elementCount], 
					index;
				for (index = 0; index < elementCount; index++)
				{
					NSPoint	points[3];
					switch ([[tile outline] elementAtIndex:index associatedPoints:points])
					{
						case NSMoveToBezierPathElement:
							[buffer appendFormat:@"\t\t\t<MOVE_TO X=\"%@\" Y=\"%@\"/>\n", [NSString stringWithFloat:points[0].x], [NSString stringWithFloat:points[0].y]];
							break;
						case NSLineToBezierPathElement:
							[buffer appendFormat:@"\t\t\t<LINE_TO X=\"%@\" Y=\"%@\"/>\n", [NSString stringWithFloat:points[0].x], [NSString stringWithFloat:points[0].y]];
							break;
						case NSCurveToBezierPathElement:
							[buffer appendFormat:@"\t\t\t<CURVE_TO X=\"%@\" Y=\"%@\" C1X=\"%@\" C1Y=\"%@\" C2X=\"%@\" C2Y=\"%@\"/>\n", 
												 [NSString stringWithFloat:points[2].x], [NSString stringWithFloat:points[2].y], 
												 [NSString stringWithFloat:points[0].x], [NSString stringWithFloat:points[0].y], 
												 [NSString stringWithFloat:points[1].x], [NSString stringWithFloat:points[1].y]];
							break;
						case NSClosePathBezierPathElement:
							[buffer appendString:@"\t\t\t<CLOSE_PATH/>\n"];
							break;
					}
				}
				[buffer appendString:@"\t\t</OUTLINE>\n"];
				
					// Now write out the tile's matches.
				MacOSaiXImageMatch	*userChosenMatch = [tile userChosenImageMatch];
				if (userChosenMatch)
					[buffer appendFormat:@"\t\t<USER_CHOSEN_MATCH ID=\"%@\" VALUE=\"%@\"/>\n", 
										 [[[userChosenMatch sourceImage] imageIdentifier] stringByEscapingXMLEntites],
									     [NSString stringWithFloat:[userChosenMatch matchValue]]];
				MacOSaiXImageMatch	*uniqueMatch = [tile uniqueImageMatch];
				if (uniqueMatch)
				{
						// TODO: Hack: this check shouldn't be necessary if the "Remove Image Source" code was fully working.
					int	sourceIndex = [imageSourceEnumerators indexOfObjectIdenticalTo:[[uniqueMatch sourceImage] enumerator]];
					if (sourceIndex != NSNotFound)
						[buffer appendFormat:@"\t\t<UNIQUE_MATCH SOURCE=\"%d\" ID=\"%@\" VALUE=\"%@\"/>\n", 
											 sourceIndex,
											 [[[uniqueMatch sourceImage] imageIdentifier] stringByEscapingXMLEntites],
											 [NSString stringWithFloat:[uniqueMatch matchValue]]];
				}
				MacOSaiXImageMatch	*bestMatch = [tile bestImageMatch];
				if (bestMatch)
				{
					// TODO: Hack: this check shouldn't be necessary if the "Remove Image Source" code was 
						// fully working.
					int	sourceIndex = [imageSourceEnumerators indexOfObjectIdenticalTo:[[bestMatch sourceImage] enumerator]];
					if (sourceIndex != NSNotFound)
						[buffer appendFormat:@"\t\t<BEST_MATCH SOURCE=\"%d\" ID=\"%@\" VALUE=\"%@\"/>\n", 
											 sourceIndex,
											 [[[bestMatch sourceImage] imageIdentifier] stringByEscapingXMLEntites],
											 [NSString stringWithFloat:[bestMatch matchValue]]];
				}
				NSColor				*fillColor = [tile fillColor];
				if (fillColor)
				{
					[buffer appendFormat:@"\t\t<FILL_COLOR RED=\"%@\" GREEN=\"%@\" BLUE=\"%@\"/>\n", 
										 [NSString stringWithFloat:[fillColor redComponent]],
										 [NSString stringWithFloat:[fillColor greenComponent]],
										 [NSString stringWithFloat:[fillColor blueComponent]]];
				}
				
				[buffer appendString:@"\t</TILE>\n"];
				
				if ([buffer length] > 1<<20)
				{
					[fileHandle writeData:[buffer dataUsingEncoding:NSUTF8StringEncoding]];
					[buffer setString:@""];
				}
				
				[tilePool release];
			}
			[fileHandle writeData:[buffer dataUsingEncoding:NSUTF8StringEncoding]];
			[fileHandle writeData:[@"</TILES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
			
			[fileHandle writeData:[@"</MOSAIC>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
			
			[fileHandle closeFile];
			
			saveSucceeded = YES;
		}
	NS_HANDLER
		NSLog(@"Save failed %@", localException);
	NS_ENDHANDLER
	
		// Dismiss the progress sheet.
	[progressController closePanel];
	[progressController release];
	progressController = nil;
	
	[self setFileName:savePath];
	[self setFileType:@"MacOSaiX Project"];
	[self updateChangeCount:NSChangeCleared];
	
	[self setIsSaving:NO];
	
	if (didSaveDelegate && [didSaveDelegate respondsToSelector:didSaveSelector])
	{
			// Now that the save has completed (successfully or not) let the delegate know.
			// The delegate's selector has the signature:
			// - (void)document:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo
		NSMethodSignature	*signature = [[didSaveDelegate class] instanceMethodSignatureForSelector:didSaveSelector];
		NSInvocation		*saveCallback = [NSInvocation invocationWithMethodSignature:signature];
		
		[saveCallback setTarget:didSaveDelegate];
		[saveCallback setSelector:didSaveSelector];
		[saveCallback setArgument:&self atIndex:2];
		[saveCallback setArgument:&saveSucceeded atIndex:3];
		[saveCallback setArgument:&contextInfo atIndex:4];
		[saveCallback invoke];
	}
	
	if (![(MacOSaiX *)[NSApp delegate] isQuitting])
	{
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Save Mosaics"])
			[self performSelectorOnMainThread:@selector(startAutosaveTimer:) withObject:nil waitUntilDone:NO];
		
		if (!wasPaused)
			[[self mosaic] resume];
	}

	[pool release];
}


#pragma mark -
#pragma mark Loading


// Loading the saved XML is currently done using the CFXML API so that we can run on Jaguar.
// Once Jaguar support is no longer required this could be cleaned up by switching to the NSXML API.

- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type
{
	[[self mosaic] setIsBeingLoaded:YES];
	loadCancelled = NO;
	
	[NSThread detachNewThreadSelector:@selector(loadXMLFile:) 
							 toTarget:self 
						   withObject:[fileName stringByAppendingPathComponent:@"Mosaic.xml"]];

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
	
	while ([[self windowControllers] count] == 0)
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
	[[self mosaic] pause];
	
	[[self mosaic] setDiskCachePath:fileName];
	
	NSData	*xmlData = [NSData dataWithContentsOfFile:fileName];
	
	if (xmlData)
	{
			// Set up the parser callbacks and context.
		CFXMLParserCallBacks	callbacks = {0, createStructure, addChild, endStructure, NULL, NULL};	//resolveExternalEntity, handleError};
		NSMutableArray			*stack = [NSMutableArray arrayWithObjects:self, [self mosaic], nil],
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
		if (!CFXMLParserParse(parser) && !loadCancelled)
		{
				// An error occurred parsing the XML.
			NSString	*parserError = (NSString *)CFXMLParserCopyErrorDescription(parser);
			
			errorMessage = [NSString stringWithFormat:NSLocalizedString(@"Error at line %d: %@", @""), 
																		CFXMLParserGetLineNumber(parser), parserError];
			
			[parserError release];
		}
		
		CFRelease(parser);
	}
	else
		errorMessage = NSLocalizedString(@"The file could not be read.", @"");
	
	if (!errorMessage && !loadCancelled)
	{
			// Let anyone who cares know that our tile shapes (and thus our tiles array) have changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
															object:self 
														  userInfo:nil];
	}
	
		// Dismiss the progress sheet.
	[progressController closePanel];
	[progressController release];
	progressController = nil;
	
	[[self mosaic] setIsBeingLoaded:NO];
	
	if (loadCancelled)
		[self performSelectorOnMainThread:@selector(close) 
							   withObject:nil 
						    waitUntilDone:NO];
	else if (errorMessage)
		[self performSelectorOnMainThread:@selector(presentFailedLoadSheet:) 
							   withObject:errorMessage 
						    waitUntilDone:NO];
	else if (![[self mosaic] targetImage])
		[self performSelectorOnMainThread:@selector(presentTargetImageIsMissingSheet) 
							   withObject:nil 
							waitUntilDone:NO];
	else
		[[self mosaic] resume];
	
	[pool release];
}


- (IBAction)cancelLoad:(id)sender
{
	loadCancelled = YES;
}


- (BOOL)loadWasCancelled
{
	return loadCancelled;
}


void *createStructure(CFXMLParserRef parser, CFXMLNodeRef node, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	volatile id			newObject = nil;
	
	NS_DURING
		NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
		MacOSaiXDocument	*document = [stack objectAtIndex:0];
		MacOSaiXMosaic		*mosaic = [stack objectAtIndex:1];
		
		if ([document loadWasCancelled])
			CFXMLParserAbort(parser, kMacOSaiXCFXMLErrorUserCancelled, CFSTR(""));
		else
		{
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
					else if ([elementType isEqualToString:@"TARGET_IMAGE"] || [elementType isEqualToString:@"ORIGINAL_IMAGE"])
					{
						NSString	*path = [[nodeAttributes objectForKey:@"PATH"] stringByUnescapingXMLEntites];
						
						[mosaic setTargetImagePath:path];
						
						NSImage	*image = [[NSImage alloc] initWithContentsOfFile:path];
						if (!image)
						{
							NSData	*imageData = [NSData dataWithContentsOfMappedFile:path];
							image = [[NSImage alloc] initWithData:imageData];
						}
						
						if (!image)
						{
							NSString	*aspectRatio = [nodeAttributes objectForKey:@"ASPECT_RATIO"];
							if (aspectRatio)
								[mosaic setAspectRatio:[aspectRatio floatValue]];
						}
						
						if (image)
						{
							[mosaic setTargetImage:image];
							[image release];
						}
					}
					else if ([elementType isEqualToString:@"TILE_SHAPES_SETTINGS"])
					{
							// Deprecated.
						NSString	*className = [nodeAttributes objectForKey:@"CLASS"];
						
						newObject = [[NSClassFromString(className) alloc] init];
						
						NSString	*settingsPath = [[[document fileName] stringByAppendingPathComponent:@"Tile Shapes Settings"] stringByAppendingPathExtension:[[newObject class] settingsExtension]];
						if ([[NSFileManager defaultManager] fileExistsAtPath:settingsPath] && 
							![newObject loadSettingsFromFileAtPath:settingsPath])
							CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, CFSTR("The tile shapes settings could not be loaded."));
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
						NSString	*sourceID = [nodeAttributes objectForKey:@"ID"], 
									*className = [nodeAttributes objectForKey:@"CLASS"], 
									*imageCount = [nodeAttributes objectForKey:@"IMAGE_COUNT"], 
									*cacheName = [nodeAttributes objectForKey:@"CACHE_NAME"];
						
						newObject = [[NSClassFromString(className) alloc] init];
						
						if (cacheName)
							[mosaic setDiskCacheSubPath:cacheName forImageSource:newObject];
						
							// Have the source read in its settings file.
						NSString	*settingsPath = [[[document fileName] stringByAppendingPathComponent:
							[NSString stringWithFormat:@"Image Source %@", sourceID]] stringByAppendingPathExtension:[[newObject class] settingsExtension]];
						if ([[NSFileManager defaultManager] fileExistsAtPath:settingsPath] && 
							![newObject loadSettingsFromFileAtPath:settingsPath])
							CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, 
											 (CFStringRef)[NSString stringWithFormat:NSLocalizedString(@"The settings for image source %@ could not be loaded.", @""), sourceID]);
						
						if (CFXMLParserGetStatusCode(parser) <= 0)
						{
							MacOSaiXImageSourceEnumerator *enumerator = [mosaic addImageSource:(id<MacOSaiXImageSource>)newObject];
							
							[enumerator setNumberOfImagesFound:[imageCount intValue]];
						}
					}
					else if ([elementType isEqualToString:@"IMAGE_ORIENTATIONS"])
					{
						NSString	*className = [nodeAttributes objectForKey:@"CLASS"];
						
						if (className)
						{
							newObject = [[NSClassFromString(className) alloc] init];
							
							NSString	*settingsPath = [[[document fileName] stringByAppendingPathComponent:@"Image Orientations Settings"] stringByAppendingPathExtension:[[newObject class] settingsExtension]];
							if (![[NSFileManager defaultManager] fileExistsAtPath:settingsPath] || 
								![newObject loadSettingsFromFileAtPath:settingsPath])
								CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, (CFStringRef)NSLocalizedString(@"The image orientations settings could not be loaded.", @""));
							else
								[mosaic setImageOrientations:(id<MacOSaiXImageOrientations>)newObject];
						}
						else
							newObject = mosaic;
					}
					else if ([elementType isEqualToString:@"TILES"])
					{
						NSString	*shapesClassName = [nodeAttributes objectForKey:@"SHAPES_CLASS"];
						
						if (shapesClassName)
						{
							newObject = [[NSClassFromString(shapesClassName) alloc] init];
							
							NSString	*settingsPath = [[[document fileName] stringByAppendingPathComponent:@"Tile Shapes Settings"] stringByAppendingPathExtension:[[newObject class] settingsExtension]];
							if (![[NSFileManager defaultManager] fileExistsAtPath:settingsPath] || 
								![newObject loadSettingsFromFileAtPath:settingsPath])
								CFXMLParserAbort(parser, kCFXMLErrorMalformedStartTag, (CFStringRef)NSLocalizedString(@"The tile shapes settings could not be loaded.", @""));
							else
								[mosaic setTileShapes:(id<MacOSaiXTileShapes>)newObject creatingTiles:NO];
						}
						else
							newObject = mosaic;
					}
					else if ([elementType isEqualToString:@"TILE"])
					{
						NSString	*fillStyle = [nodeAttributes objectForKey:@"FILL_STYLE"],
									*imageOrientationString = [nodeAttributes objectForKey:@"IMAGE_ORIENTATION"];
						NSNumber	*imageOrientation = (imageOrientationString ? [NSNumber numberWithFloat:[imageOrientationString floatValue]] : nil);
						
						newObject = [[MacOSaiXTile alloc] initWithOutline:nil 
														 imageOrientation:imageOrientation 
																   mosaic:mosaic];
						
						if ([fillStyle isEqualToString:@"User Chosen Image"])
							[(MacOSaiXTile *)newObject setFillStyle:fillWithHandPicked];
						else if ([fillStyle isEqualToString:@"Target Image"])
							[(MacOSaiXTile *)newObject setFillStyle:fillWithTargetImage];
						else if ([fillStyle isEqualToString:@"Solid Color"])
							[(MacOSaiXTile *)newObject setFillStyle:fillWithColor];
						else
							[(MacOSaiXTile *)newObject setFillStyle:fillWithUniqueMatch];
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
						int		sourceIndex = [[nodeAttributes objectForKey:@"SOURCE"] intValue];
						if (sourceIndex >= 0 && sourceIndex < [[mosaic imageSourceEnumerators] count])
						{
							NSString			*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
							float				matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
							MacOSaiXSourceImage	*sourceImage = [MacOSaiXSourceImage sourceImageWithIdentifier:imageIdentifier 
																							   fromEnumerator:[[mosaic imageSourceEnumerators] objectAtIndex:sourceIndex]];
							
							newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																	forSourceImage:sourceImage 
																		   forTile:(MacOSaiXTile *)@"Best"];
						}
						else
							CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, (CFStringRef)NSLocalizedString(@"Tile is using an image from an unknown source.", @""));
					}
					else if ([elementType isEqualToString:@"UNIQUE_MATCH"])
					{
						int					sourceIndex = [[nodeAttributes objectForKey:@"SOURCE"] intValue];
						if (sourceIndex >= 0 && sourceIndex < [[mosaic imageSourceEnumerators] count])
						{
							NSString			*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
							float				matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
							MacOSaiXSourceImage	*sourceImage = [MacOSaiXSourceImage sourceImageWithIdentifier:imageIdentifier 
																							   fromEnumerator:[[mosaic imageSourceEnumerators] objectAtIndex:sourceIndex]];
							
							newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																		forSourceImage:sourceImage 
																			   forTile:(MacOSaiXTile *)@"Unique"];
						}
						else
							CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, (CFStringRef)NSLocalizedString(@"Tile is using an image from an unknown source.", @""));
					}
					else if ([elementType isEqualToString:@"USER_CHOSEN_MATCH"])
					{
						NSString			*imageIdentifier = [[nodeAttributes objectForKey:@"ID"] stringByUnescapingXMLEntites];
						float				matchValue = [[nodeAttributes objectForKey:@"VALUE"] floatValue];
						MacOSaiXSourceImage	*sourceImage = [MacOSaiXSourceImage sourceImageWithIdentifier:imageIdentifier 
																						   fromEnumerator:nil];	// TBD: is this right now?
						
						newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																	forSourceImage:sourceImage 
																		   forTile:(MacOSaiXTile *)@"User Chosen"];
					}
					else if ([elementType isEqualToString:@"FILL_COLOR"])
					{
						NSString	*redString = [nodeAttributes objectForKey:@"RED"], 
									*greenString = [nodeAttributes objectForKey:@"GREEN"], 
									*blueString = [nodeAttributes objectForKey:@"BLUE"];
						
						newObject = [NSColor colorWithCalibratedRed:[redString floatValue] 
															  green:[greenString floatValue] 
															   blue:[blueString floatValue] 
															  alpha:1.0];
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
											   forKey:@"Element Text"];
					break;
				
				default:
					;
		//			NSLog(@"Ignoring %d", CFXMLNodeGetTypeCode(node));
			}
			
			if (newObject)
				[stack addObject:newObject];
	}
	NS_HANDLER
		CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, 
						 (CFStringRef)[NSString stringWithFormat:NSLocalizedString(@"Could not create structure (%@)", @""), [localException reason]]);
	NS_ENDHANDLER
	
	[pool release];
	
		// Return the object that will be passed to the addChild and endStructure callbacks.
    return (void *)newObject;
}


void addChild(CFXMLParserRef parser, void *parent, void *child, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
//	MacOSaiXDocument	*document = [stack objectAtIndex:0];	// unused in this method
	MacOSaiXMosaic		*mosaic = [stack objectAtIndex:1];

	if ([(id)parent conformsToProtocol:@protocol(MacOSaiXTileShapesDeprecated)] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a setting on to the tile shapes instance.
		[(id<MacOSaiXTileShapesDeprecated>)parent useSavedSetting:(NSDictionary *)child];
	}
	else if ([(id)parent conformsToProtocol:@protocol(MacOSaiXImageSourceDeprecated)] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a setting on to one of the image sources.
		[(id<MacOSaiXImageSourceDeprecated>)parent useSavedSetting:(NSDictionary *)child];
	}
	else if ([(id)parent isKindOfClass:[NSDictionary class]] && [(id)child isKindOfClass:[NSDictionary class]])
	{
			// Pass a nested setting on to either the tile shapes instance or one of the image source instances.
		NSEnumerator	*stackEnumerator = [stack reverseObjectEnumerator];
		id				stackObject = nil;
		while (stackObject = [stackEnumerator nextObject])
			if ([stackObject conformsToProtocol:@protocol(MacOSaiXTileShapesDeprecated)] || 
				[stackObject conformsToProtocol:@protocol(MacOSaiXImageSourceDeprecated)])
			{
				[stackObject addSavedChildSetting:(NSDictionary *)child toParent:(NSDictionary *)parent];
				break;
			}
	}
	else if (parent == [mosaic tileShapes] && [(id)child isKindOfClass:[MacOSaiXTile class]])
	{
			// Add a tile to the mosaic.
		[mosaic addTile:(MacOSaiXTile *)child];
	}
	else if ([(id)parent isKindOfClass:[MacOSaiXTile class]] && [(id)child isKindOfClass:[NSBezierPath class]])
	{
			// Add the bezier path outline for a tile.
		[(MacOSaiXTile *)parent setOutline:(NSBezierPath *)child];
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
		
		if ([matchType isEqualToString:@"Best"])
			[(MacOSaiXTile *)parent setBestImageMatch:match];
		else if ([matchType isEqualToString:@"Unique"])
			[(MacOSaiXTile *)parent setUniqueImageMatch:match];
		else if ([matchType isEqualToString:@"User Chosen"])
			[(MacOSaiXTile *)parent setUserChosenImageMatch:match];
		
		[(MacOSaiXImageMatch *)child setTile:(MacOSaiXTile *)parent];
	}
	else if ([(id)parent isKindOfClass:[MacOSaiXTile class]] && [(id)child isKindOfClass:[NSColor class]])
		[(MacOSaiXTile *)parent setFillColor:child];
	
//	NSLog(@"Parent <%@: %p> added child <%@: %p>", NSStringFromClass([parent class]), (void *)parent, NSStringFromClass([child class]), (void *)child);

	[pool release];
}


void endStructure(CFXMLParserRef parser, void *newObject, void *info)
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray		*stack = [(NSArray *)info objectAtIndex:0];
	MacOSaiXDocument	*document = [stack objectAtIndex:0];

	if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXTileShapes)])
	{
		[(id)newObject release];
	}
	else if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXImageOrientations)])
	{
		[(id)newObject release];
	}
	else if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXImageSource)])
	{
		[(id)newObject release];
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
		[document setProgressPercentComplete:percentComplete];
		[(NSMutableArray *)info replaceObjectAtIndex:2 withObject:percentComplete];
	}
	
	[pool release];
}


- (void)presentFailedLoadSheet:(id)errorMessage
{
	NSBeginAlertSheet(NSLocalizedString(@"The mosaic could not be opened.", @""), 
					  NSLocalizedString(@"Close", @""), nil, nil, 
					  [mainWindowController window], 
					  self, nil, @selector(failedLoadSheetDidDismiss:returnCode:contextInfo:), nil, 
					  errorMessage);
}


- (void)failedLoadSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[self close];
}


- (void)presentTargetImageIsMissingSheet
{
	NSBeginAlertSheet(NSLocalizedString(@"The mosaic's target image could not be opened.", @""), 
					  NSLocalizedString(@"Close", @""), NSLocalizedString(@"Open", @""), nil, [mainWindowController window], 
					  self, nil, @selector(targetMissingSheetDidDismiss:returnCode:contextInfo:), nil, 
					  NSLocalizedString(@"You can open the project and save it in another format but you will not be able to " \
					  @"make any changes until you switch to another target image.", @""));
}


- (void)targetMissingSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
		[self close];
}


#pragma mark -


- (void)canCloseDocumentWithDelegate:(id)delegate 
				 shouldCloseSelector:(SEL)shouldCloseSelector
						 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (![[self mosaic] isPaused])
		[[self mosaic] pause];
    
	if ([self isDocumentEdited])
	{
			// Present a sheet that allows the user to save, cancel or not save.
			// TODO: get the localized versions of these strings
		NSString		*title = [NSString stringWithFormat:NSLocalizedString(@"Do you want to save the changes you made in document \"%@\"?", @""), [[self fileName] lastPathComponent]], 
						*saveString = NSLocalizedString(@"Save", @""),
						*dontSaveString = NSLocalizedString(@"Don't Save", @""), 
						*cancelString = NSLocalizedString(@"Cancel", @""), 
						*message = NSLocalizedString(@"Your changes will be lost if you don't save them.", @"");
		NSDictionary	*metaContextInfo = [[NSDictionary dictionaryWithObjectsAndKeys:
												delegate, @"Should Close Delegate", 
												NSStringFromSelector(shouldCloseSelector), @"Should Close Selector", 
												[NSValue valueWithPointer:contextInfo], @"Context Info",
												nil] retain];
		
		NSBeginAlertSheet(title, saveString, dontSaveString, cancelString, 
						  [[self mainWindowController] window],
						  self, nil, @selector(shouldCloseSheetDidDismiss:returnCode:contextInfo:), metaContextInfo, 
						  message);
	}
	else
		[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector 
					contextInfo:contextInfo];
}


- (void)shouldCloseSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)metaContextInfo
{
	BOOL	shouldClose = NO;
	
	switch (returnCode)
	{
		case NSAlertDefaultReturn:
				// The user chose to save.  When the save is complete it will call back to our
				// method which will then call back to the close initiator.
			[self saveDocumentWithDelegate:self 
						   didSaveSelector:@selector(closeAfterDocument:didSave:contextInfo:) 
							   contextInfo:metaContextInfo];
			break;

			// The user chose to cancel or not to save.  Immediately call back to the close initiator,
			// returning NO if they cancelled or YES if they chose not to save.
		case NSAlertAlternateReturn:
			shouldClose = YES;
		case NSAlertOtherReturn:
		{
			id		shouldCloseDelegate = [(NSDictionary *)metaContextInfo objectForKey:@"Should Close Delegate"];
			SEL		shouldCloseSelector = NSSelectorFromString([(NSDictionary *)metaContextInfo objectForKey:@"Should Close Selector"]);
			void	*contextInfo = nil;
			if ([(NSDictionary *)metaContextInfo objectForKey:@"Context Info"])
				contextInfo = [(NSValue *)[(NSDictionary *)metaContextInfo objectForKey:@"Context Info"] pointerValue];
			
			if (shouldCloseDelegate && [shouldCloseDelegate respondsToSelector:shouldCloseSelector])
			{
					// Now that the save has completed (successfully or not) let the delegate know.
					// The delegate's selector has the signature:
					// - (void)document:(NSDocument *)doc shouldClose:(BOOL)didSave contextInfo:(void *)contextInfo
				NSMethodSignature	*signature = [[shouldCloseDelegate class] instanceMethodSignatureForSelector:shouldCloseSelector];
				NSInvocation		*shouldCloseCallback = [NSInvocation invocationWithMethodSignature:signature];
				
				[shouldCloseCallback setTarget:shouldCloseDelegate];
				[shouldCloseCallback setSelector:shouldCloseSelector];
				[shouldCloseCallback setArgument:&self atIndex:2];
				[shouldCloseCallback setArgument:&shouldClose atIndex:3];
				[shouldCloseCallback setArgument:&contextInfo atIndex:4];
				[shouldCloseCallback invoke];
			}
			
			[(id)metaContextInfo release];
			break;
		}
	}
}


- (void)closeAfterDocument:(NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)metaContextInfo
{
		// Wait for the save thread to complete.
		// TBD: is the method above necessary if we do this?
	while (saving)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	
		// The save has completed so call back to the close initiator.
	id		shouldCloseDelegate = [(NSDictionary *)metaContextInfo objectForKey:@"Should Close Delegate"];
	SEL		shouldCloseSelector = NSSelectorFromString([(NSDictionary *)metaContextInfo objectForKey:@"Should Close Selector"]);
	void	*contextInfo = nil;
	if ([(NSDictionary *)metaContextInfo objectForKey:@"Context Info"])
		contextInfo = [(NSValue *)[(NSDictionary *)metaContextInfo objectForKey:@"Context Info"] pointerValue];
	
	if (shouldCloseDelegate && [shouldCloseDelegate respondsToSelector:shouldCloseSelector])
	{
			// Now that the save has completed (successfully or not) let the delegate know.
			// The delegate's selector has the signature:
			// - (void)document:(NSDocument *)doc shouldClose:(BOOL)didSave contextInfo:(void *)contextInfo
		NSMethodSignature	*signature = [[shouldCloseDelegate class] instanceMethodSignatureForSelector:shouldCloseSelector];
		NSInvocation		*shouldCloseCallback = [NSInvocation invocationWithMethodSignature:signature];
		
		[shouldCloseCallback setTarget:shouldCloseDelegate];
		[shouldCloseCallback setSelector:shouldCloseSelector];
		[shouldCloseCallback setArgument:&self atIndex:2];
		[shouldCloseCallback setArgument:&didSave atIndex:3];
		[shouldCloseCallback setArgument:&contextInfo atIndex:4];
		[shouldCloseCallback invoke];
	}
	
	[(id)metaContextInfo release];
}


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
	[[self mosaic] pause];
	
	if ([autosaveTimer isValid])
	{
		[autosaveTimer invalidate];
		[autosaveTimer autorelease];
		autosaveTimer = nil;
	}
	
		// wait for the threads to shut down
    while ([[self mosaic] isBusy])
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	
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
