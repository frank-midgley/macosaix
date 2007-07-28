//
//  MacOSaiXExportController.m
//  MacOSaiX
//
//  Created by Frank Midgley on 2/4/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXExportController.h"

#import "MacOSaiX.h"
#import "MacOSaiXExporter.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatch.h"
#import "MacOSaiXImageSourceEnumerator.h"
#import "MacOSaiXMosaic.h"
#import "MacOSaiXProgressController.h"
#import "MacOSaiXSourceImage.h"
#import "NSImage+MacOSaiX.h"
#import "Tiles.h"


@implementation MacOSaiXExportController


- (void)exportMosaic:(MacOSaiXMosaic *)inMosaic
			withName:(NSString *)name 
  targetImageOpacity:(float)opacity
	  modalForWindow:(NSWindow *)window 
	   modalDelegate:(id)inDelegate
	  didEndSelector:(SEL)inDidEndSelector
{
	mosaic = inMosaic;
	targetImageOpacity = opacity;
	delegate = inDelegate;
	didEndSelector = ([delegate respondsToSelector:inDidEndSelector] ? inDidEndSelector : nil);
	
		// Pause the mosaic so we don't have a moving target.
//	BOOL		wasPaused = [mosaic isPaused];
    [mosaic pause];
	// TODO:
	//     Restore pause state:		if (wasPaused) [mosaic resume];
	
		// Work with a copy of the export settings in case the user cancels.
	exportSettings = [[mosaic exportSettings] copyWithZone:[self zone]];
	[exportSettings setTargetImage:[mosaic targetImage]];
	
		// Set up the save panel for exporting.
    savePanel = [NSSavePanel savePanel];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setDelegate:self];
	
	[NSBundle loadNibNamed:@"Export" owner:self];
	
		// Populate the format pop-up with the list of the current exporter plug-ins.
	[formatPopUp removeAllItems];
	NSMenu			*formatMenu = [formatPopUp menu];
	NSEnumerator	*plugInEnumerator = [[[NSApp delegate] exporterPlugIns] objectEnumerator];
	Class			exporterPlugIn = nil, 
					currentClass = [exportSettings class];
	NSMenuItem		*currentItem = nil;
	while (exporterPlugIn = [plugInEnumerator nextObject])
	{
		NSBundle		*plugInBundle = [NSBundle bundleForClass:exporterPlugIn];
		NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
		NSMenuItem		*menuItem = [[[NSMenuItem alloc] initWithTitle:plugInName action:@selector(addImageSource:) keyEquivalent:@""] autorelease];
		
		[menuItem setImage:[[[exporterPlugIn image] copyWithLargestDimension:32] autorelease]];
		[menuItem setRepresentedObject:exporterPlugIn];
		[menuItem setTarget:self];
		[menuItem setAction:@selector(setFormat:)];
		
		[formatMenu addItem:menuItem];
		
		if ((!currentClass && !currentItem) || [exporterPlugIn dataSourceClass] == currentClass)
			currentItem = menuItem;
	}
	
	[formatPopUp selectItem:currentItem];
	[self setFormat:currentItem];
	
	NSString	*exportExtension = [exportSettings exportExtension];
    [savePanel setRequiredFileType:exportExtension];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Open Exported File When Completed"])
		[openWhenCompletedButton setState:NSOnState];
	else
		[openWhenCompletedButton setState:NSOffState];
		
		// Ask the user where to export.
    [savePanel beginSheetForDirectory:nil 
								 file:(exportExtension ? [name stringByAppendingPathExtension:exportExtension] : name)
					   modalForWindow:window
						modalDelegate:self
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:)
						  contextInfo:window];
}


- (IBAction)setFormat:(id)sender
{
	Class			plugInClass = [sender representedObject];
	
	if (exporterEditor)
	{
		[exporterEditor editingDidComplete];
		[exporterEditor release];
	}
	
		// Create new settings for this format if necessary.
	if (![exportSettings isKindOfClass:[plugInClass dataSourceClass]])
	{
		[exportSettings release];
		exportSettings = [[[plugInClass dataSourceClass] alloc] init];
	}
	[exportSettings setTargetImage:[mosaic targetImage]];
	
		// Create an editor for this format's settings.
	exporterEditor = [[[plugInClass editorClass] alloc] initWithDelegate:self];
	
		// Add the editor's custom view to the save panel.
	NSView			*editorView = [exporterEditor editorView];
	NSRect			editorFrame = [editorView frame], 
					accessoryFrame = NSMakeRect(0.0, 0.0, NSWidth(editorFrame), NSHeight(editorFrame) + NSHeight([sharedView frame]));
	NSView			*accessoryView = [[[NSView alloc] initWithFrame:accessoryFrame] autorelease];
	[sharedView setFrame:NSMakeRect(0.0, NSHeight(editorFrame), NSWidth(accessoryFrame), NSHeight([sharedView frame]))];
	[accessoryView addSubview:sharedView];
	[accessoryView addSubview:editorView];
	[savePanel setAccessoryView:accessoryView];
	
		// Set the correct file extension.
    [savePanel setRequiredFileType:[exportSettings exportExtension]];
	
		// Tell the editor which settings to edit.
	[exporterEditor editDataSource:exportSettings];
}


- (IBAction)setOpenWhenCompleted:(id)sender
{
	openWhenCompleted = ([openWhenCompletedButton state] == NSOnState);
	
	[[NSUserDefaults standardUserDefaults] setBool:openWhenCompleted forKey:@"Open Exported File When Completed"];
}


- (NSImage *)targetImage
{
	return [mosaic targetImage];
}


- (void)dataSource:(id<MacOSaiXDataSource>)dataSource 
	  didChangeKey:(NSString *)key
		 fromValue:(id)previousValue 
		actionName:(NSString *)actionName;
{
    [savePanel setRequiredFileType:[exportSettings exportExtension]];
}


- (void)savePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSWindow					*window = (NSWindow *)contextInfo;
	
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
		[mosaic setExportSettings:exportSettings];
		
		progressController = [[MacOSaiXProgressController alloc] initWithWindow:nil];
		[progressController setCancelTarget:self action:@selector(cancelExport:)];
		[progressController displayPanelWithMessage:[NSString stringWithFormat:NSLocalizedString(@"Saving the mosaic in %@ format...", @""), 
																			   [exportSettings exportFormat]]
									 modalForWindow:window];
		
			// Spawn a thread to do the export so the GUI doesn't get tied up.
		NSDictionary	*threadParameters = [NSDictionary dictionaryWithObjectsAndKeys:
												[savePanel URL], @"Export URL", 
												nil];
		[NSApplication detachDrawingThread:@selector(exportMosaic:)
								  toTarget:self 
								withObject:threadParameters];
	}
	
	savePanel = nil;
}


- (void)exportMosaic:(NSDictionary *)threadParameters
{
    NSAutoreleasePool		*pool = [[NSAutoreleasePool alloc] init];
	unsigned long			tileCount = [[mosaic tiles] count],
							tilesExported = 0;
	NSURL					*exportURL = [threadParameters objectForKey:@"Export URL"];
	Class					exporterPlugInClass = [[NSApp delegate] plugInForDataSourceClass:[exportSettings class]];
	id<MacOSaiXExporter>	exporter = [[[exporterPlugInClass exporterClass] alloc] init];
	id						exportError = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];
	
	exportWasCancelled = NO;
	
	NS_DURING
		exportError = [exporter createFileAtURL:exportURL withSettings:exportSettings];
	NS_HANDLER
		exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not open the save file.  (%@)", @""), 
												 [localException reason]];
	NS_ENDHANDLER
	
	if (exportError)
	{
		// TODO: check the error
	}
	else
	{
			// Export the contents of each tile.
		NSEnumerator		*tileEnumerator = [[mosaic tiles] objectEnumerator];
		MacOSaiXTile		*tile = nil;
		while (!exportWasCancelled && !exportError && (tile = [tileEnumerator nextObject]))
		{
			NSAutoreleasePool		*tilePool = [[NSAutoreleasePool alloc] init];
			MacOSaiXTileFillStyle	fillStyle = [tile fillStyle];
			
//			[progressController setMessage:NSLocalizedString(@"Saving tile %d of %d...", @""), tilesExported + 1, tileCount];
			[progressController setPercentComplete:[NSNumber numberWithDouble:(100.0 * tilesExported / tileCount)]];
			
			if (fillStyle == fillWithColor || fillStyle == fillWithAverageTargetColor)
			{
				NS_DURING
					exportError = [exporter fillTileWithColor:[tile fillColor] clippedToPath:[tile outline]];
				NS_HANDLER
					exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
															 [localException reason]];
				NS_ENDHANDLER
			}
			else if (fillStyle == fillWithTargetImage)
			{
				NSImage	*targetImage = [mosaic targetImage];
				
				NS_DURING
					exportError = [exporter fillTileWithImage:targetImage 
											   withIdentifier:[mosaic targetImageIdentifier] 
												   fromSource:[mosaic targetImageSource] 
											  centeredAtPoint:NSMakePoint([targetImage size].width / 2.0, 
																		  [targetImage size].height / 2.0) 
													 rotation:0.0 
												clippedToPath:[tile outline] 
													  opacity:1.0];
				NS_HANDLER
					exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
						[localException reason]];
				NS_ENDHANDLER
			}
			else
			{
				MacOSaiXSourceImage	*tileSourceImage = nil;
				
					// Get the identifier and source of the image with which to fill the tile.
				if (fillStyle == fillWithUniqueMatch)
					tileSourceImage = [[tile uniqueImageMatch] sourceImage];
				else if (fillStyle == fillWithHandPicked)
					tileSourceImage = [[tile userChosenImageMatch] sourceImage];
				
				if (tileSourceImage)
				{
						// Fetch the appropriate image from the cache.
						// TBD: Is there some way to avoid having to pull the full sized image when it's not needed?  
						//      Additional exporter API that lets us know the rendered size of the tile?
					NSSize				nativeSize = [tileSourceImage nativeSize];
					NSImageRep			*tileImageRep = [tileSourceImage imageRepAtSize:nativeSize];
					NSImage				*tileImage = [[NSImage alloc] initWithSize:[tileImageRep size]];
					[tileImage addRepresentation:tileImageRep];
					[tileImage setScalesWhenResized:NO];
					
						// Size the image to fit this tile, accounting for the orientation.  The bitmap rep will not be resized.  The image's size tells the exporter how big the bitmap should be rendered (in the target image's space).
					NSBezierPath		*targetOutline = [tile outline];
					NSRect				targetBounds = [targetOutline bounds];
					NSAffineTransform	*transform = [NSAffineTransform transform];
					[transform translateXBy:NSMidX(targetBounds) yBy:NSMidY(targetBounds)];
					[transform rotateByDegrees:-[tile imageOrientation]];
					[transform translateXBy:-NSMidX(targetBounds) yBy:-NSMidY(targetBounds)];
					NSBezierPath		*rotatedOutline = [transform transformBezierPath:targetOutline];
					NSRect				rotatedBounds = [rotatedOutline bounds];
					BOOL				widthLimited = ((nativeSize.width / NSWidth(rotatedBounds)) < 
														(nativeSize.height / NSHeight(rotatedBounds)));
					float				scale = (widthLimited ? NSWidth(rotatedBounds) / nativeSize.width : NSHeight(rotatedBounds) / nativeSize.height);
					[tileImage setSize:NSMakeSize(nativeSize.width * scale, nativeSize.height * scale)];
					
						// Tell the exporter where and how to draw the image.
					NS_DURING
						exportError = [exporter fillTileWithImage:tileImage 
												   withIdentifier:[tileSourceImage imageIdentifier] 
													   fromSource:[[tileSourceImage enumerator] imageSource] 
												  centeredAtPoint:NSMakePoint(NSMidX(targetBounds), NSMidY(targetBounds)) 
														 rotation:[tile imageOrientation] 
													clippedToPath:[tile outline] 
														  opacity:1.0];
					NS_HANDLER
						exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
																 [localException reason]];
					NS_ENDHANDLER
					
					[tileImage release];
				}
			}
			
			tilesExported++;
			
			[tilePool release];
		}
		
		if (!exportWasCancelled && !exportError && targetImageOpacity > 0.0)
		{
			// Blend in the target image.
			
			NSImage	*targetImage = [mosaic targetImage];
			NSRect	targetImageRect = NSMakeRect(0.0, 0.0, [targetImage size].width, [targetImage size].height);
			
			NS_DURING
				exportError = [exporter fillTileWithImage:targetImage 
										   withIdentifier:[mosaic targetImageIdentifier] 
											   fromSource:[mosaic targetImageSource] 
										  centeredAtPoint:NSMakePoint([targetImage size].width / 2.0, 
																	  [targetImage size].height / 2.0) 
												 rotation:0.0 
											clippedToPath:[NSBezierPath bezierPathWithRect:targetImageRect] 
												  opacity:targetImageOpacity];
			NS_HANDLER
				exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not save one of the tiles.  (%@)", @""), 
					[localException reason]];
			NS_ENDHANDLER
		}
		
		if (!exportWasCancelled && !exportError)
		{
			[progressController setMessage:NSLocalizedString(@"Finishing the save...", @"")];
			[progressController setPercentComplete:[NSNumber numberWithInt:-1]];
			NS_DURING
				exportError = [exporter closeFile];
			NS_HANDLER
				exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not finish saving the mosaic.  (%@)", @""), 
														 [localException reason]];
			NS_ENDHANDLER
			
			if (exportError)
				;	// TODO
		}
		
		if (!exportWasCancelled && !exportError && openWhenCompleted)
		{
			[progressController setMessage:NSLocalizedString(@"Opening the file...", @"")];
			NS_DURING
				exportError = [exporter openFileInExternalViewer:exportURL];
			NS_HANDLER
				exportError = [NSString stringWithFormat:NSLocalizedString(@"Could not open the file.  (%@)", @""), 
														 [localException reason]];
			NS_ENDHANDLER
			
			if (exportError)
				;	// TODO
		}
	}
	
	[progressController closePanel];
	
	if (didEndSelector)
		[delegate performSelector:didEndSelector withObject:exportError];
	
    [pool release];
}


- (IBAction)cancelExport:(id)sender
{
	exportWasCancelled = YES;
}


#pragma mark -
#pragma mark Text field delegate methods


- (NSButton *)bottomRightButtonInWindow:(NSWindow *)window
{
	NSButton		*bottomRightButton = nil;
	NSMutableArray	*viewQueue = [NSMutableArray arrayWithObject:[window contentView]];
	NSPoint			maxOrigin = {0.0, 0.0};
	
	while ([viewQueue count] > 0)
	{
		NSView	*nextView = [viewQueue objectAtIndex:0];
		[viewQueue removeObjectAtIndex:0];
		if ([nextView isKindOfClass:[NSButton class]])	//&& [nextView frame].origin.y > 0.0)
		{
			//			NSLog(@"Checking \"%@\" at %f, %f", [(NSButton *)nextView title], [nextView frame].origin.x, [nextView frame].origin.y);
			if ([nextView frame].origin.x > maxOrigin.x)	//|| [nextView frame].origin.y < maxOrigin.y)
			{
				bottomRightButton = (NSButton *)nextView;
				maxOrigin = [nextView frame].origin;
			}
		}
		else
			[viewQueue addObjectsFromArray:[nextView subviews]];
	}
	
	return bottomRightButton;
}


- (void)dealloc
{
	[sharedView release];
	
	[super dealloc];
}


@end
