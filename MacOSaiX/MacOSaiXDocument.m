/*
	MacOSaiXDocument.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import "MacOSaiXDocument.h"

#import "MacOSaiX.h"
#import "Tiles.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"


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
		
		mosaic = [[MacOSaiXMosaic alloc] init];
	}
	
    return self;
}


- (void)makeWindowControllers
{
	if (![self fileName])
	{
		NSString	*defaultShapesClassString = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Chosen Tile Shapes Class"];
		
		[mosaic setTileShapes:[[[NSClassFromString(defaultShapesClassString) alloc] init] autorelease]
				creatingTiles:YES];
	}
	
	mainWindowController = [[[MacOSaiXWindowController alloc] initWithWindow:nil] autorelease];
	
	[mainWindowController setMosaic:mosaic];
	
	[self addWindowController:mainWindowController];
	[mainWindowController showWindow:self];
}


- (MacOSaiXWindowController *)mainWindowController
{
	return mainWindowController;
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	[mosaic autorelease];
	mosaic = [inMosaic retain];
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (void)mosaicDidChangeState:(NSNotification *)notification
{
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
	autosaveTimer = [[NSTimer scheduledTimerWithTimeInterval:autosaveInterval target:self selector:@selector(autoSave:) userInfo:nil repeats:NO] retain];
}


- (void)autoSave:(NSTimer *)timer
{
	if ([self autoSaveEnabled])
	{
		if ([self isDocumentEdited])
			[self saveDocument:self];
	}
	else
		missedAutoSave = YES;
}


#pragma mark -
#pragma mark Saving


- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	if (changeType == NSChangeDone && !autosaveTimer)
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


- (void)saveToFile:(NSString *)fileName 
	 saveOperation:(NSSaveOperationType)saveOperation 
		  delegate:(id)delegate 
   didSaveSelector:(SEL)didSaveSelector 
	   contextInfo:(void *)contextInfo;
{
	if (!fileName)
		return;	// the user cancelled the save
	
	[self setIsSaving:YES];
	
	BOOL			wasPaused = [mosaic isPaused];
	
		// Display a sheet while the save is underway
// TODO:	[[self mainWindowController] setCancelAction:@selector(cancelSave) andTarget:self];
	[[self mainWindowController] displayProgressPanelWithMessage:@"Saving mosaic project..."];
	
		// Pause the mosaic so that it is in a static state while saving.
	[mosaic pause];
	
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


- (BOOL)writeToFile:(NSString *)fullDocumentPath 
			 ofType:(NSString *)docType 
	   originalFile:(NSString *)fullOriginalDocumentPath 
	  saveOperation:(NSSaveOperationType)saveOperationType
{
	[self setIsSaving:YES];
	
	BOOL			wasPaused = [mosaic isPaused];
	
	[[self mainWindowController] displayProgressPanelWithMessage:@"Saving mosaic project..."];

		// Pause the mosaic so that it is in a static state while saving.
	[mosaic pause];

	NSMutableDictionary	*parameters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
											fullDocumentPath, @"Save Path", 
											[NSNumber numberWithInt:saveOperationType], @"Save Operation", 
											[NSNumber numberWithBool:wasPaused], @"Was Paused", 
											nil];
	[NSThread detachNewThreadSelector:@selector(threadedSaveWithParameters:) 
							 toTarget:self 
						   withObject:parameters];

	return YES;
}


- (void)cancelSave
{
	// TODO
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
//	NSSaveOperationType	saveOperation = [[parameters objectForKey:@"Save Operation"] intValue];
	id					didSaveDelegate = [parameters objectForKey:@"Did Save Delegate"];
	SEL					didSaveSelector = NSSelectorFromString([parameters objectForKey:@"Did Save Selector"]);
	void				*contextInfo = (void *)[[parameters objectForKey:@"Context Info"] unsignedLongValue];
	BOOL				wasPaused = [[parameters objectForKey:@"Was Paused"] boolValue];
	
	NS_DURING
		// TODO: take the save operation into account

			// Don't usurp the main thread.
		[NSThread setThreadPriority:0.1];
		
			// Create the wrapper directory if it doesn't already exist.
		NSFileManager	*fileManager = [NSFileManager defaultManager];
		BOOL			isDir;
		if (([fileManager fileExistsAtPath:savePath isDirectory:&isDir] && isDir) || 
			[fileManager createDirectoryAtPath:savePath attributes:nil])
		{
				// Make the folder a package.
			FSRef		folderRef;
			OSStatus	status = FSPathMakeRef([savePath UTF8String], &folderRef, NULL);
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

					// Write out the path to the original image
				[fileHandle writeData:[[NSString stringWithFormat:@"<ORIGINAL_IMAGE PATH=\"%@\"/>\n\n", 
													[NSString stringByEscapingXMLEntites:[self originalImagePath]]] 
													dataUsingEncoding:NSUTF8StringEncoding]];
				
					// Write out the tile shapes settings
				NSString		*className = NSStringFromClass([[mosaic tileShapes] class]);
				NSMutableString	*tileShapesXML = [NSMutableString stringWithString:
																[[[mosaic tileShapes] settingsAsXMLElement] stringByTrimmingCharactersInSet:
																	[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
				[tileShapesXML replaceOccurrencesOfString:@"\n" withString:@"\n\t" options:0 range:NSMakeRange(0, [tileShapesXML length])];
				[tileShapesXML insertString:@"\t" atIndex:0];
				[tileShapesXML appendString:@"\n"];
				[fileHandle writeData:[[NSString stringWithFormat:@"<TILE_SHAPES_SETTINGS CLASS=\"%@\">\n", className] dataUsingEncoding:NSUTF8StringEncoding]];
				[fileHandle writeData:[tileShapesXML dataUsingEncoding:NSUTF8StringEncoding]];
				[fileHandle writeData:[@"</TILE_SHAPES_SETTINGS>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
				
				[fileHandle writeData:[@"<IMAGE_USAGE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
				[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_REUSE COUNT=\"%d\" DISTANCE=\"%d\"/>\n", [mosaic imageUseCount], [mosaic imageReuseDistance]] dataUsingEncoding:NSUTF8StringEncoding]];
				[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_CROP LIMIT=\"%d\"/>\n", [mosaic imageCropLimit]] dataUsingEncoding:NSUTF8StringEncoding]];
				[fileHandle writeData:[@"</IMAGE_USAGE>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
				
					// Write out the image sources.
				[fileHandle writeData:[@"<IMAGE_SOURCES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
				NSArray	*imageSources = [mosaic imageSources];
				int		index;
				for (index = 0; index < [imageSources count]; index++)
				{
					id<MacOSaiXImageSource>	imageSource = [imageSources objectAtIndex:index];
					NSString				*className = NSStringFromClass([imageSource class]);
					[fileHandle writeData:[[NSString stringWithFormat:@"\t<IMAGE_SOURCE ID=\"%d\" CLASS=\"%@\" IMAGE_COUNT=\"%d\">\n", 
																	  index, className, [mosaic countOfImagesFromSource:imageSource]] 
												dataUsingEncoding:NSUTF8StringEncoding]];
					
						// Output the settings for this image source.
						// TODO: need to tag this element with the source's namespace
					NSMutableString			*imageSourceXML = [NSMutableString stringWithString:
																[[imageSource settingsAsXMLElement] stringByTrimmingCharactersInSet:
																	[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
					[imageSourceXML replaceOccurrencesOfString:@"\n" withString:@"\n\t\t" options:0 range:NSMakeRange(0, [imageSourceXML length])];
					[imageSourceXML insertString:@"\t\t" atIndex:0];
					[imageSourceXML appendString:@"\n"];
					[fileHandle writeData:[imageSourceXML dataUsingEncoding:NSUTF8StringEncoding]];
					
					[fileHandle writeData:[@"\t</IMAGE_SOURCE>\n" dataUsingEncoding:NSUTF8StringEncoding]];
				}
				[fileHandle writeData:[@"</IMAGE_SOURCES>\n\n" dataUsingEncoding:NSUTF8StringEncoding]];
				
					// Write out the tiles
				[fileHandle writeData:[@"<TILES>\n" dataUsingEncoding:NSUTF8StringEncoding]];
				NSMutableString	*buffer = [NSMutableString string];
				NSEnumerator	*tileEnumerator = [[mosaic tiles] objectEnumerator];
				MacOSaiXTile	*tile = nil;
				while (tile = [tileEnumerator nextObject])
				{
					NSAutoreleasePool	*tilePool = [[NSAutoreleasePool alloc] init];
					
					[buffer appendString:@"\t<TILE>\n"];
					
						// First write out the tile's outline
					[buffer appendString:@"\t\t<OUTLINE>\n"];
					int index;
					for (index = 0; index < [[tile outline] elementCount]; index++)
					{
						NSPoint points[3];
						switch ([[tile outline] elementAtIndex:index associatedPoints:points])
						{
							case NSMoveToBezierPathElement:
								[buffer appendString:[NSString stringWithFormat:@"\t\t\t<MOVE_TO X=\"%0.6f\" Y=\"%0.6f\"/>\n", 
																				points[0].x, points[0].y]];
								break;
							case NSLineToBezierPathElement:
								[buffer appendString:[NSString stringWithFormat:@"\t\t\t<LINE_TO X=\"%0.6f\" Y=\"%0.6f\"/>\n", 
																				points[0].x, points[0].y]];
								break;
							case NSCurveToBezierPathElement:
								[buffer appendString:[NSString stringWithFormat:@"\t\t\t<CURVE_TO X=\"%0.6f\" Y=\"%0.6f\" C1X=\"%0.6f\" C1Y=\"%0.6f\" C2X=\"%0.6f\" C2Y=\"%0.6f\"/>\n", 
																				points[2].x, points[2].y, 
																				points[0].x, points[0].y, 
																				points[1].x, points[1].y]];
								break;
							case NSClosePathBezierPathElement:
								[buffer appendString:@"\t\t\t<CLOSE_PATH/>\n"];
								break;
						}
					}
					[buffer appendString:@"\t\t</OUTLINE>\n"];
					
						// Now write out the tile's matches.
					MacOSaiXImageMatch	*uniqueMatch = [tile uniqueImageMatch];
					if (uniqueMatch)
					{
						int	sourceIndex = [imageSources indexOfObjectIdenticalTo:[uniqueMatch imageSource]];
							// Hack: this check shouldn't be necessary if the "Remove Image Source" code was 
							// fully working.
						if (sourceIndex != NSNotFound)
							[buffer appendString:[NSString stringWithFormat:@"\t\t<UNIQUE_MATCH SOURCE=\"%d\" ID=\"%@\" VALUE=\"%f\"/>\n", 
																			  sourceIndex,
																			  [NSString stringByEscapingXMLEntites:[uniqueMatch imageIdentifier]],
																			  [uniqueMatch matchValue]]];
					}
					MacOSaiXImageMatch	*userChosenMatch = [tile userChosenImageMatch];
					if (userChosenMatch)
						[buffer appendString:[NSString stringWithFormat:@"\t\t<USER_CHOSEN_MATCH ID=\"%@\" VALUE=\"%f\"/>\n", 
																		  [NSString stringByEscapingXMLEntites:[userChosenMatch imageIdentifier]],
																		  [userChosenMatch matchValue]]];
					
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
		}
	NS_HANDLER
		NSLog(@"Save failed %@", localException);
	NS_ENDHANDLER
	
		// Dismiss the "Saving..." sheet.
	[[self mainWindowController] closeProgressPanel];
	
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
		[self performSelectorOnMainThread:@selector(startAutosaveTimer:) withObject:nil waitUntilDone:NO];
		if (!wasPaused)
			[mosaic resume];
	}

	[pool release];
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
	
	[[self mainWindowController] displayProgressPanelWithMessage:@"Loading the mosaic..."];
	
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
	{
			// Let anyone who cares know that our tile shapes (and thus our tiles array) have changed.
		[[NSNotificationCenter defaultCenter] postNotificationName:MacOSaiXTileShapesDidChangeStateNotification 
															object:self 
														  userInfo:nil];
	}
	
	[[self mainWindowController] closeProgressPanel];
	
	loading = NO;
	
	if (errorMessage)
		[self performSelectorOnMainThread:@selector(presentFailedLoadSheet:) 
							   withObject:errorMessage 
						    waitUntilDone:NO];
	else
		[[self mainWindowController] performSelectorOnMainThread:@selector(synchronizeGUIWithDocument) 
													  withObject:nil 
												   waitUntilDone:NO];
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
				
				if ([elementType isEqualToString:@"MOSAIC"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"ORIGINAL_IMAGE"])
				{
					newObject = [NSString stringByUnescapingXMLEntites:[(NSDictionary *)(nodeInfo->attributes) objectForKey:@"PATH"]];
				}
				else if ([elementType isEqualToString:@"TILE_SHAPES_SETTINGS"])
				{
					NSString	*className = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"CLASS"];
					
					newObject = [[NSClassFromString(className) alloc] init];
				}
				else if ([elementType isEqualToString:@"IMAGE_USAGE"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_REUSE"])
				{
					NSString	*imageReuseCount = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"COUNT"],
								*imageReuseDistance = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"DISTANCE"];
					
					[mosaic setImageUseCount:[imageReuseCount intValue]];
					[mosaic setImageReuseDistance:[imageReuseDistance intValue]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_CROP"])
				{
					NSString	*cropLimitString = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"LIMIT"];
					
					[mosaic setImageCropLimit:[cropLimitString intValue]];
					
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_SOURCES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"IMAGE_SOURCE"])
				{
					NSString	*className = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"CLASS"],
								*imageCount = [(NSDictionary *)(nodeInfo->attributes) objectForKey:@"IMAGE_COUNT"];
					
					newObject = [[NSClassFromString(className) alloc] init];
					
					[mosaic setImageCount:[imageCount intValue] forImageSource:newObject];
				}
				else if ([elementType isEqualToString:@"TILES"])
				{
					newObject = mosaic;
				}
				else if ([elementType isEqualToString:@"TILE"])
				{
					newObject = [[MacOSaiXTile alloc] initWithOutline:nil fromMosaic:mosaic];
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
					newObject = [[NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)nodeInfo->attributes] retain];
					[(NSMutableDictionary *)newObject setObject:elementType forKey:@"Element Type"];
				}
				else if ([elementType isEqualToString:@"UNIQUE_MATCH"])
				{
					if ([[document mainWindowController] viewingOriginal])
						[[document mainWindowController] performSelectorOnMainThread:@selector(setViewMosaic:) 
																		  withObject:nil 
																	   waitUntilDone:NO];
					
					int					sourceIndex = [[(NSDictionary *)nodeInfo->attributes objectForKey:@"SOURCE"] intValue];
					if (sourceIndex >= 0 && sourceIndex < [[mosaic imageSources] count])
					{
						NSString			*imageIdentifier = [NSString stringByUnescapingXMLEntites:
																	[(NSDictionary *)nodeInfo->attributes objectForKey:@"ID"]];
						float				matchValue = [[(NSDictionary *)nodeInfo->attributes objectForKey:@"VALUE"] floatValue];
						
						newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
																forImageIdentifier:imageIdentifier 
																   fromImageSource:[[mosaic imageSources] objectAtIndex:sourceIndex] 
																		   forTile:nil];
					}
					else
						CFXMLParserAbort(parser,kCFXMLErrorMalformedStartTag, CFSTR("Tile is using an image from an unknown source."));
				}
				else if ([elementType isEqualToString:@"USER_CHOSEN_MATCH"])
				{
					NSString	*imageIdentifier = [NSString stringByUnescapingXMLEntites:
														[(NSDictionary *)nodeInfo->attributes objectForKey:@"ID"]];
					float		matchValue = [[(NSDictionary *)nodeInfo->attributes objectForKey:@"VALUE"] floatValue];
					
					newObject = [[MacOSaiXImageMatch alloc] initWithMatchValue:matchValue 
															forImageIdentifier:imageIdentifier 
															   fromImageSource:[mosaic handPickedImageSource] 
																	   forTile:nil];
				}
				else
				{
					newObject = [[NSMutableDictionary dictionaryWithDictionary:(NSDictionary *)nodeInfo->attributes] retain];
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
		
		if ([[match imageSource] isKindOfClass:[MacOSaiXHandPickedImageSource class]])
			[(MacOSaiXTile *)parent setUserChosenImageMatch:match];
		else
			[(MacOSaiXTile *)parent setUniqueImageMatch:match];
		
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

	if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXTileShapes)])
	{
		[mosaic setTileShapes:(id<MacOSaiXTileShapes>)newObject creatingTiles:NO];
		[(id)newObject release];
	}
	else if ([(id)newObject conformsToProtocol:@protocol(MacOSaiXImageSource)])
	{
		[mosaic addImageSource:(id<MacOSaiXImageSource>)newObject];
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


- (void)canCloseDocumentWithDelegate:(id)delegate 
				 shouldCloseSelector:(SEL)shouldCloseSelector
						 contextInfo:(void *)contextInfo
{
		// pause threads so document dirty state doesn't change
    if (![mosaic isPaused])
		[mosaic pause];
    
	if ([self isDocumentEdited])
	{
			// Present a sheet that allows the user to save, cancel or not save.
			// TODO: get the localized versions of these strings
		NSString		*title = [NSString stringWithFormat:@"Do you want to save the changes you made in document \"%@\"?",
															[[self fileName] lastPathComponent]], 
						*saveString = @"Save",
						*dontSaveString = @"Don't Save", 
						*cancelString = @"Cancel", 
						*message = @"Your changes will be lost if you don't save them.";
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
	[mosaic pause];
	
	if ([autosaveTimer isValid])
	{
		[autosaveTimer invalidate];
		[autosaveTimer autorelease];
		autosaveTimer = nil;
	}
	
		// wait for the threads to shut down
    while ([mosaic isBusy])
		[NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1.0]];
	
    [super close];
}


#pragma mark -

- (void)dealloc
{
    [lastSaved release];
	
    [super dealloc];
}

@end
