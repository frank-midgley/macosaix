/*
	MacOSaiXWindowController.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXWindowController.h"
#import "MacOSaiX.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatcher.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"
#import <unistd.h>
#import <pthread.h>


#define kMatchingMenuItemTag	1


#define MAX_REFRESH_THREAD_COUNT 1


@interface MacOSaiXWindowController (PrivateMethods)
- (void)documentDidChangeState:(NSNotification *)notification;
- (void)updateTileSizeFields;
- (void)synchronizeMenus;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)exportImage:(id)exportFilename;
@end


@implementation MacOSaiXWindowController


- (id)initWithWindow:(NSWindow *)window
{
    if (self = [super initWithWindow:window])
    {
		statusBarShowing = YES;
		exportFormat = NSJPEGFileType;
		
		tileRefreshLock = [[NSLock alloc] init];
		tilesToRefresh = [[NSMutableArray array] retain];
	}
	
    return self;
}


- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(originalImageDidChange:) 
												 name:MacOSaiXOriginalImageDidChangeNotification 
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(documentDidChangeState:) 
												 name:MacOSaiXDocumentDidChangeStateNotification 
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileShapesDidChange:) 
												 name:MacOSaiXTileShapesDidChangeStateNotification 
											   object:[self document]];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(tileImageDidChange:) 
												 name:MacOSaiXTileImageDidChangeNotification 
											   object:[self document]];
	
    viewMenu = [[[NSApp mainMenu] itemWithTitle:@"View"] submenu];
    fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];

		// set up the toolbar
    zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    toolbarItems = [[NSMutableDictionary dictionary] retain];
    NSToolbar   *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [[self window] setToolbar:toolbar];
    
		// Make sure we have the latest and greatest list of plug-ins
	[[NSApp delegate] discoverPlugIns];

	{
		// Set up the settings drawer
		
			// Populate the original image pop-up menu
		NSEnumerator	*originalEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Originals"] objectEnumerator];
		NSDictionary	*originalDict = nil;
		while (originalDict = [originalEnumerator nextObject])
		{
			NSString	*originalPath = [originalDict objectForKey:@"Path"],
						*originalName = [originalDict objectForKey:@"Name"];
			NSImage		*originalThumbnail = [[NSImage alloc] initWithData:[originalDict objectForKey:@"Thumbnail Data"]];
			[originalThumbnail setCachedSeparately:YES];
			[originalThumbnail setCacheMode:NSImageCacheNever];
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:originalPath])
			{
				if (!originalName)
					originalName = [[originalPath lastPathComponent] stringByDeletingPathExtension];
				
				NSMenuItem	*originalItem = [[[NSMenuItem alloc] init] autorelease];
				[originalItem setTitle:originalName];
				[originalItem setRepresentedObject:originalPath];
				[originalItem setImage:originalThumbnail];
				[[originalImagePopUpButton menu] insertItem:originalItem
													atIndex:[originalImagePopUpButton numberOfItems] - 1];
			}
		}
		[originalImagePopUpButton selectItemAtIndex:0];
		
//		[[self document] setTileShapes:[[[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init] autorelease]];
		
			// Fill in the description of the current tile shapes.
		id	tileShapesDescription = [[[self document] tileShapes] briefDescription];
		if ([tileShapesDescription isKindOfClass:[NSString class]])
			[tileShapesDescriptionField setStringValue:tileShapesDescription];
		else if ([tileShapesDescription isKindOfClass:[NSAttributedString class]])
			[tileShapesDescriptionField setAttributedStringValue:tileShapesDescription];
		else if ([tileShapesDescription isKindOfClass:[NSString class]])
		{
			NSTextAttachment	*imageTA = [[[NSTextAttachment alloc] init] autorelease];
			[(NSTextAttachmentCell *)[imageTA attachmentCell] setImage:tileShapesDescription];
			[tileShapesDescriptionField setAttributedStringValue:[NSAttributedString attributedStringWithAttachment:imageTA]];
		}
		else
			[tileShapesDescriptionField setStringValue:@"No description available"];
		
			// Set up the "Image Sources" tab
		[imageSourcesTableView setDoubleAction:@selector(editImageSource:)];

		[[imageSourcesTableView tableColumnWithIdentifier:@"Image Source Type"]
			setDataCell:[[[NSImageCell alloc] init] autorelease]];
	
			// Populate the "Add New Source..." pop-up menu with the names of the image sources.
			// The represented object of each menu item will be the image source's class.
		NSEnumerator	*enumerator = [[[NSApp delegate] imageSourceClasses] objectEnumerator];
		Class			imageSourceClass;
		[imageSourcesPopUpButton removeAllItems];
		[imageSourcesPopUpButton addItemWithTitle:@"Add New Source..."];
		while (imageSourceClass = [enumerator nextObject])
		{
			[imageSourcesPopUpButton addItemWithTitle:[NSString stringWithFormat:@"%@...", [imageSourceClass name]]];
			[[imageSourcesPopUpButton lastItem] setRepresentedObject:imageSourceClass];
		}
	}
	
	[self synchronizeGUIWithDocument];
	
	[tileShapesBox setContentViewMargins:NSMakeSize(16.0, 16.0)];
	
	[mosaicView setDocument:[self document]];
	[self setViewOriginalImage:self];
	
		// For some reason IB insists on setting the drawer width to 200.  Have to set the size in code instead.
	[settingsDrawer setContentSize:NSMakeSize(350, [settingsDrawer contentSize].height)];
	[settingsDrawer open:self];
    
	[self updateTileSizeFields];
	
	[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
	if ([[self document] fileName])
	{
		[pauseToolbarItem setLabel:@"Resume"];
		[[fileMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Resume Matching"];
	}
	else
	{
		[pauseToolbarItem setLabel:@"Start Mosaic"];
		[[fileMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Start Mosaic"];
		
			// Default to the most recently used original or prompt to choose one
			// if no previous original was found.
		[self performSelector:@selector(chooseOriginalImage:) withObject:self afterDelay:0.0];
	}
	
	[self documentDidChangeState:nil];
}


- (void)synchronizeGUIWithDocument
{
		// Set the image use count and reuse distance pop-ups.
	int				popUpIndex = [imageUseCountPopUpButton indexOfItemWithTag:[[self document] imageUseCount]];
	[imageUseCountPopUpButton selectItemAtIndex:popUpIndex];
	popUpIndex = [imageReuseDistancePopUpButton indexOfItemWithTag:[[self document] imageReuseDistance]];
	[imageReuseDistancePopUpButton selectItemAtIndex:popUpIndex];
	popUpIndex = [imageCropLimitPopUpButton indexOfItemWithTag:[[self document] imageCropLimit]];
	[imageCropLimitPopUpButton selectItemAtIndex:popUpIndex];
	
	[self updateTileSizeFields];
}


#pragma mark
#pragma mark Original image management


- (IBAction)chooseOriginalImage:(id)sender
{
	NSString	*originalPath = [[originalImagePopUpButton selectedItem] representedObject];
	
	if (originalPath)
	{
			// Return the currently displayed thumbnail to its menu item.
		if ([[self document] originalImagePath])
		{
			int	previousIndex = [originalImagePopUpButton indexOfItemWithRepresentedObject:[[self document] originalImagePath]];
			[[originalImagePopUpButton itemAtIndex:previousIndex] setImage:[originalImageThumbView image]];
		}
		
			// Move the newly chosen original's thumbnail to the image view.
		[originalImageThumbView setImage:[[originalImagePopUpButton selectedItem] image]];
		[[originalImagePopUpButton selectedItem] setImage:nil];
		
			// Update the document.
		[[self document] setOriginalImagePath:originalPath];
	}
	else
	{
			// Prompt the user to choose the image from which to make a mosaic.
		NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
		[oPanel setCanChooseFiles:YES];
		[oPanel setCanChooseDirectories:NO];
		[oPanel setAccessoryView:openOriginalAccessoryView];
		[oPanel beginSheetForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]
						modalForWindow:[self window]
						 modalDelegate:self
						didEndSelector:@selector(chooseOriginalImagePanelDidEnd:returnCode:contextInfo:)
						   contextInfo:nil];
	}
}


- (void)chooseOriginalImagePanelDidEnd:(NSOpenPanel *)sheet 
							returnCode:(int)returnCode
						   contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
		[[self document] setOriginalImagePath:[[sheet filenames] objectAtIndex:0]];
}


- (void)originalImageDidChange:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:@selector(originalImageDidChange:) 
							   withObject:notification 
							waitUntilDone:YES];
	else
	{
			// Remember this original in the user's defaults so they can easily re-choose it for future mosaics.
		NSString		*originalImagePath = [[self document] originalImagePath];
		NSImage			*originalImage = [[self document] originalImage];
		NSImage			*thumbnailImage = [originalImage copyWithLargestDimension:32.0];
		NSMutableArray	*originals = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Originals"] mutableCopy] autorelease];
		if (originals)
		{
				// Remove any previous entry from the defaults for the image at this path.
			NSEnumerator	*originalEnumerator = [originals objectEnumerator];
			NSDictionary	*originalDict = nil;
			while (originalDict = [originalEnumerator nextObject])
				if ([[originalDict objectForKey:@"Path"] isEqualToString:originalImagePath])
				{
					[originals removeObject:originalDict];
					break;
				}
		}
		else
			originals = [NSMutableArray array];
		[originals insertObject:[NSDictionary dictionaryWithObjectsAndKeys:
									originalImagePath, @"Path", 
									[[originalImagePath lastPathComponent] stringByDeletingPathExtension], @"Name", 
									[thumbnailImage TIFFRepresentation], @"Thumbnail Data",
									nil]
						atIndex:0];
		[[NSUserDefaults standardUserDefaults] setObject:originals forKey:@"Recent Originals"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
			// Update the original image pop-up menu.
		NSEnumerator	*itemEnumerator = [[[originalImagePopUpButton menu] itemArray] objectEnumerator];
		NSMenuItem		*item = nil;
		while (item = [itemEnumerator nextObject])
			if ([[item representedObject] isEqualToString:originalImagePath])
			{
				[[originalImagePopUpButton menu] removeItem:item];
				break;
			}
		NSMenuItem	*originalItem = [[[NSMenuItem alloc] init] autorelease];
		[originalItem setTitle:[[originalImagePath lastPathComponent] stringByDeletingPathExtension]];
		[originalItem setRepresentedObject:originalImagePath];
		[originalImageThumbView setImage:thumbnailImage];
		[[originalImagePopUpButton menu] insertItem:originalItem atIndex:0];
		[originalImagePopUpButton selectItemAtIndex:0];
		
		[thumbnailImage release];
		
			// Set the zoom so that all of the new image is displayed.
		[zoomSlider setFloatValue:0.0];
		[self setZoom:self];
		
			// Resize the window to respect the original's aspect ratio
		NSRect	curFrame = [[self window] frame];
		NSSize	newSize = [self windowWillResize:[self window] toSize:curFrame.size];
		[[self window] setFrame:NSMakeRect(NSMinX(curFrame), NSMaxY(curFrame) - newSize.height, newSize.width, newSize.height)
						display:YES
						animate:YES];
		
		[self documentDidChangeState:nil];
		
			// Create the toolbar icons for the View Original/View Mosaic item.  Toolbar item images 
			// must be 32x32 so we center the thumbnail in an image of the correct size.
		[originalToolbarImage release];
		originalToolbarImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
		NSImage	*newToolbarImage = [[[[self document] originalImage] copyWithLargestDimension:32.0] autorelease];
		NSSize	thumbSize = [newToolbarImage size];
		[originalToolbarImage lockFocus];
			if (thumbSize.width > thumbSize.height)
				[newToolbarImage compositeToPoint:NSMakePoint(0.0, (32.0 - thumbSize.height) / 2.0) operation:NSCompositeCopy];
			else
				[newToolbarImage compositeToPoint:NSMakePoint((32.0 - thumbSize.width) / 2.0, 0.0) operation:NSCompositeCopy];
		[originalToolbarImage unlockFocus];
			// Create a version that looks like a 4x4 mosaic.
		[mosaicToolbarImage release];
		mosaicToolbarImage = [originalToolbarImage copy];
		[mosaicToolbarImage lockFocus];
			float	quarterWidth = thumbSize.width / 4.0,
					quarterHeight = thumbSize.height / 4.0,
					xStart = 0.0,
					yStart = 0.0;
			if (thumbSize.width > thumbSize.height)
				yStart = (32.0 - thumbSize.height) / 2.0;
			else
				xStart = (32.0 - thumbSize.width) / 2.0;
			
				// Lighten the top and left edges.
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
			int	i;
			for (i = 0; i < 4; i++)
			{
				[NSBezierPath strokeLineFromPoint:NSMakePoint(xStart + 0.0, 
															  yStart + (i + 1) * quarterHeight - 0.5)
										  toPoint:NSMakePoint(xStart + quarterWidth * 4.0 - 0.5, 
															  yStart + (i + 1) * quarterHeight - 0.5)];
				[NSBezierPath strokeLineFromPoint:NSMakePoint(xStart + i * quarterWidth + 0.5, 
															  yStart + 0.0)
										  toPoint:NSMakePoint(xStart + i * quarterWidth + 0.5, 
															  yStart + quarterHeight * 4.0 - 0.5)];
			}
			
				// Darken the bottom and right edges.
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
			for (i = 0; i < 4; i++)
			{
				[NSBezierPath strokeLineFromPoint:NSMakePoint(xStart + 0.5, 
															  yStart + i * quarterHeight + 0.5)
										  toPoint:NSMakePoint(xStart + quarterWidth * 4.0, 
															  yStart + i * quarterHeight + 0.5)];
				[NSBezierPath strokeLineFromPoint:NSMakePoint(xStart + (i + 1) * quarterWidth - 0.5, 
															  yStart + 0.0)
										  toPoint:NSMakePoint(xStart + (i + 1) * quarterWidth - 0.5, 
															  yStart + quarterHeight * 4.0 - 0.5)];
			}
		[mosaicToolbarImage unlockFocus];
		
			// Update the toolbar item.
		if ([mosaicView viewOriginal])
			[toggleOriginalToolbarItem setImage:mosaicToolbarImage];
		else
			[toggleOriginalToolbarItem setImage:originalToolbarImage];
	}
}


#pragma mark


- (void)pause
{
	if (![[self document] isPaused])
	{
		[self displayProgressPanelWithMessage:@"Pausing..."];
		[[self document] pause];
		[self closeProgressPanel];
		
			// Update the toolbar.
		[pauseToolbarItem setLabel:@"Resume"];
		[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		
			// Update the menu bar.
		[[fileMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Resume Matching"];
	}
}


- (void)resume
{
	if ([[self document] isPaused])
	{
		[[self document] resume];
		
		//if ([[self document] wasStarted])
		{
				// Make sure the tiles can't be tweaked now that the mosaic was started.
			[originalImagePopUpButton setEnabled:NO];
			[changeTileShapesButton setEnabled:NO];
			[imageUseCountPopUpButton setEnabled:NO];
			[imageReuseDistancePopUpButton setEnabled:NO];
		}
		
			// Update the toolbar
		[pauseToolbarItem setLabel:@"Pause"];
		[pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		
			// Update the menu bar
		[[fileMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Pause Matching"];
	}
}


#pragma mark -
#pragma mark ???


- (MacOSaiXDocument *)document
{
	return (MacOSaiXDocument *)[super document];
}


- (void)documentDidChangeState:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:@selector(documentDidChangeState:) withObject:notification waitUntilDone:NO];
	else
	{
		NSString	*statusMessage = nil;
		
		// update the status bar
		if (![[self document] originalImage])
			statusMessage = @"You have not chosen the original image";
		else if ([[[self document] tiles] count] == 0)
			statusMessage = @"You have not set the tile shapes";
		else if ([[[self document] imageSources] count] == 0)
			statusMessage = @"You have not added any image sources";
//		else if ([[self document] isExtractingTileImagesFromOriginal])
//			statusMessage = [NSString stringWithFormat:@"Extracting tile images (%.0f%%)", 
//													   [[self document] tileCreationPercentComplete]];
		else if (![[self document] wasStarted])
			statusMessage = @"Ready to begin.  Click the Start Mosaic button in the toolbar.";
		else if ([[self document] isCalculatingImageMatches])
			statusMessage = [NSString stringWithString:@"Matching images..."];
		else if ([[self document] isPaused])
			statusMessage = [NSString stringWithString:@"Paused"];
		else if ([[self document] isEnumeratingImageSources])
			statusMessage = [NSString stringWithString:@"Looking for new images..."];
		else
			statusMessage = [NSString stringWithString:@"Done"];
		
//		[statusMessageView setStringValue:[NSString stringWithFormat:@"Images: %d     Quality: %2.1f%%     Status: %@",
//																	 [[self document] imagesMatched], 
//																	 overallMatch, 
//																	 statusMessage]];
		[statusMessageView setStringValue:[NSString stringWithFormat:@"Images: %d     Status: %@",
																	 [[self document] imagesMatched], 
																	 statusMessage]];
		
		[imageSourcesTableView reloadData];
		[totalTilesField setIntValue:[[[self document] tiles] count]];
		[self updateTileSizeFields];
	}
}



- (void)synchronizeMenus
{
	[[fileMenu itemWithTag:kMatchingMenuItemTag] setTitle:([[self document] isPaused] ? @"Resume Matching" : @"Pause Matching")];

	[[viewMenu itemWithTag:0] setState:([mosaicView viewOriginal] ? NSOnState : NSOffState)];
	[[viewMenu itemWithTag:1] setState:([mosaicView viewOriginal] ? NSOffState : NSOnState)];

	[[viewMenu itemAtIndex:[viewMenu indexOfItemWithTarget:nil andAction:@selector(toggleTileOutlines:)]] setTitle:([mosaicView viewTileOutlines] ? @"Hide Tile Outlines" : @"Show Tile Outlines")];
	[[viewMenu itemAtIndex:[viewMenu indexOfItemWithTarget:nil andAction:@selector(toggleStatusBar:)]] setTitle:(statusBarShowing ? @"Hide Status Bar" : @"Show Status Bar")];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	MacOSaiXTile		*tile = [[notification userInfo] objectForKey:@"Tile"];
	
	[tileRefreshLock lock];
		if ([tilesToRefresh indexOfObjectIdenticalTo:tile] == NSNotFound)
			[tilesToRefresh addObject:tile];
		
		if (refreshTilesThreadCount == 0)
			[NSApplication detachDrawingThread:@selector(refreshTiles:) toTarget:self withObject:nil];
	[tileRefreshLock unlock];
	
	// TODO: update the editor if this tile is selected (if it still exists...)
}


- (void)refreshTiles:(id)dummy
{
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	MacOSaiXTile		*tileToRefresh = nil;

        // Make sure only one copy of this thread runs at any time.
	[tileRefreshLock lock];
		if (refreshTilesThreadCount >= MAX_REFRESH_THREAD_COUNT)
		{
                // Not allowed to run any more threads, just exit.
			[tileRefreshLock unlock];
			[pool release];
			return;
		}
		refreshTilesThreadCount++;
	[tileRefreshLock unlock];
	
	do
	{
		NSAutoreleasePool	*innerPool = [[NSAutoreleasePool alloc] init];
		
		tileToRefresh = nil;
		[tileRefreshLock lock];
			if ([tilesToRefresh count] > 0)
			{
				tileToRefresh = [[[tilesToRefresh objectAtIndex:0] retain] autorelease];
				[tilesToRefresh removeObjectAtIndex:0];
			}
		[tileRefreshLock unlock];
		
		if (tileToRefresh)
			[mosaicView refreshTile:tileToRefresh];
		
		[innerPool release];
	} while (tileToRefresh);
	
	[tileRefreshLock lock];
		refreshTilesThreadCount--;
	[tileRefreshLock unlock];
	
	[pool release];
}


#pragma mark -
#pragma mark Tile shapes methods


- (IBAction)changeTileShapes:(id)sender
{
			// Populate the tile shapes pop-up with the names of the currently available plug-ins.
		[(MacOSaiX *)[NSApp delegate] discoverPlugIns];
		NSEnumerator	*enumerator = [[(MacOSaiX *)[NSApp delegate] tileShapesClasses] objectEnumerator];
		Class			tileShapesClass = nil;
		int				currentlyUsedClassIndex = -1;
		float			maxWidth = 0.0;
		NSString		*titleFormat = @"%@ Tile Shapes";
		[tileShapesPopUpButton removeAllItems];
		while (tileShapesClass = [enumerator nextObject])
		{
			[tileShapesPopUpButton addItemWithTitle:[NSString stringWithFormat:titleFormat, [tileShapesClass name]]];
			[[tileShapesPopUpButton lastItem] setRepresentedObject:tileShapesClass];
			
			[tileShapesPopUpButton selectItemAtIndex:[tileShapesPopUpButton numberOfItems] - 1];
			[tileShapesPopUpButton sizeToFit];
			maxWidth = MAX(maxWidth, [tileShapesPopUpButton frame].size.width);
			
			if ([[[self document] tileShapes] isKindOfClass:tileShapesClass])
				currentlyUsedClassIndex = [tileShapesPopUpButton numberOfItems] - 1;
		}
		[tileShapesPopUpButton setFrameSize:NSMakeSize(maxWidth, [tileShapesPopUpButton frame].size.height)];
		[tileShapesPopUpButton selectItemAtIndex:currentlyUsedClassIndex];
		
			// Populate the GUI with the current shape settings.
		[self setTileShapesPlugIn:self];
		
			// Present a sheet to let the user modify the shape settings.
		[NSApp beginSheet:tileShapesPanel 
		   modalForWindow:[self window]
		    modalDelegate:self 
		   didEndSelector:@selector(tileShapesEditorDidEnd:returnCode:contextInfo:) 
			  contextInfo:nil];
}


- (IBAction)setTileShapesPlugIn:(id)sender
{
	Class			tileShapesClass = [[tileShapesPopUpButton selectedItem] representedObject],
					tileShapesEditorClass = [tileShapesClass editorClass];
	
	if (tileShapesEditorClass)
	{
			// Release any previous editor and create a new one using the selected class.
		[tileShapesEditor release];
		tileShapesEditor = [[tileShapesEditorClass alloc] init];
		
			// Swap in the view of the new editor.  Make sure the panel is big enough to contain the view's minimum size.
		float	widthDiff = MAX(0.0, [tileShapesEditor editorViewMinimumSize].width - [[tileShapesBox contentView] frame].size.width),
				heightDiff = MAX(0.0, [tileShapesEditor editorViewMinimumSize].height - [[tileShapesBox contentView] frame].size.height);
		NSSize	currentPanelSize = [[tileShapesPanel contentView] frame].size;
		[tileShapesPanel setContentSize:NSMakeSize(currentPanelSize.width + widthDiff, currentPanelSize.height + heightDiff)];
		[[tileShapesEditor editorView] setFrame:[[tileShapesBox contentView] frame]];
		[[tileShapesEditor editorView] setAutoresizingMask:[[tileShapesBox contentView] autoresizingMask]];
		[tileShapesBox setContentView:[tileShapesEditor editorView]];
		
			// Re-establish the key view loop:
			// 1. Focus on the editor view's first responder.
			// 2. Set the next key view of the last view in the editor's loop to the cancel button.
			// 3. Set the next key view of the OK button to the first view in the editor's loop.
		[tileShapesPanel setInitialFirstResponder:(NSView *)[tileShapesEditor editorViewFirstResponder]];
		NSView	*lastKeyView = (NSView *)[tileShapesEditor editorViewFirstResponder];
		while ([lastKeyView nextKeyView] && 
				[[lastKeyView nextKeyView] isDescendantOf:[tileShapesEditor editorView]] &&
				[lastKeyView nextKeyView] != [tileShapesEditor editorViewFirstResponder])
			lastKeyView = [lastKeyView nextKeyView];
		[lastKeyView setNextKeyView:cancelTileShapesButton];
		[setTileShapesButton setNextKeyView:(NSView *)[tileShapesEditor editorViewFirstResponder]];
		
			// Get the existing tile shapes from our document.
			// If they are not of the class the user just chose then create a new one with default settings.
		if ([[[self document] tileShapes] class] == tileShapesClass)
			tileShapesBeingEdited = [[[self document] tileShapes] copyWithZone:[self zone]];
		else
			tileShapesBeingEdited = [[tileShapesClass alloc] init];
		
		[tileShapesEditor editTileShapes:tileShapesBeingEdited forOriginalImage:[[self document] originalImage]];
	}
	else
	{
		NSTextField	*errorView = [[[NSTextField alloc] initWithFrame:[[tileShapesBox contentView] frame]] autorelease];
		
		[errorView setStringValue:@"Could not load the plug-in"];
		[errorView setEditable:NO];
	}
}


- (IBAction)setTileShapes:(id)sender;
{
	[NSApp endSheet:tileShapesPanel returnCode:NSOKButton];
}


- (IBAction)cancelChangingTileShapes:(id)sender
{
	[NSApp endSheet:tileShapesPanel returnCode:NSCancelButton];
}


- (void)tileShapesEditorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
	if (returnCode == NSOKButton)
		[[self document] setTileShapes:tileShapesBeingEdited];
	
	[tileShapesBeingEdited release];
	tileShapesBeingEdited = nil;

	[tileShapesBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
}


- (void)updateTileSizeFields
{
	NSSize	tileUnitSize = (selectedTile ? [[selectedTile outline] bounds].size : [[self document] averageUnitTileSize]),
			originalSize = [[[self document] originalImage] size];
	float	aspectRatio = (tileUnitSize.width * originalSize.width) / 
						  (tileUnitSize.height * originalSize.height);
	[tileSizeLabelField setStringValue:(selectedTile ? @"Selected tile size:" : @"Average tile size:")];
	[tileSizeField setStringValue:[NSString stringWithAspectRatio:aspectRatio]];
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	NSString	*tileShapesDescription = [[[self document] tileShapes] briefDescription];
	if (tileShapesDescription)
		[tileShapesDescriptionField setStringValue:tileShapesDescription];
	else
		[tileShapesDescriptionField setStringValue:@"No description available"];
	[totalTilesField setIntValue:[[[self document] tiles] count]];
	
	if (selectedTile)
		[self selectTileAtPoint:tileSelectionPoint];
	
	[self documentDidChangeState:nil];

	[self updateTileSizeFields];
}


- (IBAction)setImageUseCount:(id)sender
{
	[[self document] setImageUseCount:[[imageUseCountPopUpButton selectedItem] tag]];
}


- (IBAction)setImageReuseDistance:(id)sender
{
	[[self document] setImageReuseDistance:[[imageReuseDistancePopUpButton selectedItem] tag]];
}


- (IBAction)setImageCropLimit:(id)sender
{
	[[self document] setImageCropLimit:[[imageCropLimitPopUpButton selectedItem] tag]];
}


#pragma mark -
#pragma mark Image Sources methods


- (void)editImageSourceInSheet:(id<MacOSaiXImageSource>)originalImageSource
{
	id<MacOSaiXImageSource>				editableSource = [[originalImageSource copyWithZone:[self zone]] autorelease];
	
	imageSourceEditorController = [[[[originalImageSource class] editorClass] alloc] init];
	
		// Make sure the panel is big enough to contain the view's minimum size.
	float	widthDiff = MAX(0.0, [imageSourceEditorController editorViewMinimumSize].width - [[imageSourceEditorBox contentView] frame].size.width),
			heightDiff = MAX(0.0, [imageSourceEditorController editorViewMinimumSize].height - [[imageSourceEditorBox contentView] frame].size.height);
	NSSize	currentPanelSize = [[imageSourceEditorPanel contentView] frame].size;
	[imageSourceEditorPanel setContentSize:NSMakeSize(currentPanelSize.width + widthDiff, currentPanelSize.height + heightDiff)];
	[[imageSourceEditorController editorView] setFrame:[[imageSourceEditorBox contentView] frame]];
	[[imageSourceEditorController editorView] setAutoresizingMask:[[imageSourceEditorBox contentView] autoresizingMask]];
	
		// Now that the sheet is big enough we can swap in the controller's editor view.
	[imageSourceEditorBox setContentView:[imageSourceEditorController editorView]];

	[imageSourceEditorController setOKButton:imageSourceEditorOKButton];	// so the controller can disable it for invalid settings
	[imageSourceEditorController editImageSource:editableSource];
	
		// Re-establish the key view loop:
		// 1. Focus on the editor view's first responder.
		// 2. Set the next key view of the last view in the editor's loop to the cancel button.
		// 3. Set the next key view of the OK button to the first view in the editor's loop.
	[imageSourceEditorPanel setInitialFirstResponder:(NSView *)[imageSourceEditorController editorViewFirstResponder]];
	NSView	*lastKeyView = (NSView *)[imageSourceEditorController editorViewFirstResponder];
	while ([lastKeyView nextKeyView] && 
			[[lastKeyView nextKeyView] isDescendantOf:[imageSourceEditorController editorView]] &&
			[lastKeyView nextKeyView] != [imageSourceEditorController editorViewFirstResponder])
		lastKeyView = [lastKeyView nextKeyView];
	[lastKeyView setNextKeyView:imageSourceEditorCancelButton];
	[imageSourceEditorOKButton setNextKeyView:(NSView *)[imageSourceEditorController editorViewFirstResponder]];
	
	[NSApp beginSheet:imageSourceEditorPanel 
	   modalForWindow:[self window]
		modalDelegate:self 
	   didEndSelector:@selector(imageSourceEditorDidEnd:returnCode:contextInfo:) 
		  contextInfo:[[NSArray arrayWithObjects:editableSource, originalImageSource, nil] retain]];
}


- (void)addNewImageSource:(id)sender
{
	if ([imageSourcesPopUpButton indexOfSelectedItem] > 0)
	{
		Class	imageSourceClass = [[imageSourcesPopUpButton selectedItem] representedObject];
		
		[self editImageSourceInSheet:[[[imageSourceClass alloc] init] autorelease]];
	}
}


- (IBAction)editImageSource:(id)sender
{
	if (sender == imageSourcesTableView)
		[self editImageSourceInSheet:[[[self document] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]]];
}


- (IBAction)saveImageSource:(id)sender;
{
	[NSApp endSheet:imageSourceEditorPanel returnCode:NSOKButton];
}


- (IBAction)cancelImageSource:(id)sender
{
	[NSApp endSheet:imageSourceEditorPanel returnCode:NSCancelButton];
}


- (void)imageSourceEditorDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	NSArray								*parameters = (NSArray *)contextInfo;
	id<MacOSaiXImageSource>				editedImageSource = [parameters objectAtIndex:0],
										originalImageSource = [parameters objectAtIndex:1];
	
	[sheet orderOut:self];
	
		// Do this before adding the source so we don't run into thread safety issues with QuickTime.
	[imageSourceEditorBox setContentView:[[[NSView alloc] initWithFrame:NSZeroRect] autorelease]];
	
	if (returnCode == NSOKButton)
	{
		[[self document] removeImageSource:originalImageSource];
		[[self document] addImageSource:editedImageSource];
	
			// Auto start the mosaic if possible and the user wants to.
		if ([[self document] tileShapes] && 
			[[NSUserDefaults standardUserDefaults] boolForKey:@"Automatically Start Mosaics"])
			[self resume];
		
		[imageSourcesTableView reloadData];
	}
	
	[imageSourceEditorController editImageSource:nil];
	[imageSourceEditorController release];
	imageSourceEditorController = nil;
	[(id)contextInfo release];
}


- (IBAction)removeImageSource:(id)sender
{
	if (NSRunAlertPanel(@"Are you sure you wish to remove the selected image source?", 
						@"All tiles that were using images from this source will be changed to black.", 
						@"Remove", @"Cancel", nil) == NSAlertDefaultReturn)
	{
		id<MacOSaiXImageSource>	imageSource = [[[self document] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]];
		
		[[self document] removeImageSource:imageSource];
	}
}


#pragma mark -
#pragma mark Editor methods


- (void)selectTileAtPoint:(NSPoint)thePoint
{
	tileSelectionPoint = thePoint;
	
    thePoint.x = thePoint.x / [mosaicView frame].size.width;
    thePoint.y = thePoint.y / [mosaicView frame].size.height;
    
        // TBD: this isn't terribly efficient...
	NSEnumerator	*tileEnumerator = [[[self document] tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
        if ([[tile outline] containsPoint:thePoint])
        {
			[selectedTile autorelease];
			
			if (tile == selectedTile)
			{
					// The selected tile was clicked so unselect it.
				selectedTile = nil;
				
					// Get rid of the timer when no tile is selected.
				[animateTileTimer invalidate];
				[animateTileTimer release];
				animateTileTimer = nil;
			}
			else
			{
					// Select a new tile.
				if (!selectedTile)
				{
						// Create a timer to animate the selected tile ten times per second.
					animateTileTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1
											 target:(id)self
											   selector:@selector(animateSelectedTile:)
											   userInfo:nil
											repeats:YES] retain];
				}
				
				selectedTile = [tile retain];
			}
			
			[self updateTileSizeFields];
			
			[mosaicView highlightTile:selectedTile];
			
			break;
        }
}


- (void)animateSelectedTile:(id)timer
{
    if (![[self document] isClosing])
        [mosaicView animateHighlight];
}


- (NSImage *)highlightTileOutline:(NSBezierPath *)tileOutline inImage:(NSImage *)image croppedPercentage:(float *)croppedPercentage
{
		// Scale the image to at most 128 pixels.
    NSImage				*highlightedImage = [[[NSImage alloc] initWithSize:[image size]] autorelease];
//    if ([image size].width > [image size].height)
//        highlightedImage = [[[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0 / [image size].width * [image size].height)] autorelease];
//    else
//        highlightedImage = [[[NSImage alloc] initWithSize:NSMakeSize(128.0 / [image size].height * [image size].width, 128.0)] autorelease];
	
		// Figure out how to scale and translate the tile to fit within the image.
    NSSize				tileSize = [tileOutline bounds].size,
						originalSize = [[[self document] originalImage] size], 
						denormalizedTileSize = NSMakeSize(tileSize.width * originalSize.width, 
														  tileSize.height * originalSize.height);
    float				xScale, yScale;
    NSPoint				origin;
    if (([image size].width / denormalizedTileSize.width) < ([image size].height / denormalizedTileSize.height))
    {
			// Width is the limiting dimension.
		float	scaledHeight = [image size].width * denormalizedTileSize.height / denormalizedTileSize.width, 
				heightDiff = [image size].height - scaledHeight;
		xScale = [image size].width / tileSize.width;
		yScale = scaledHeight / tileSize.height;
		origin = NSMakePoint(0.0, heightDiff / 2.0);
		if (croppedPercentage)
			*croppedPercentage = ([image size].width * heightDiff) / 
								 ([image size].width * [image size].height) * 100.0;
    }
    else
    {
			// Height is the limiting dimension.
		float	scaledWidth = [image size].height * denormalizedTileSize.width / denormalizedTileSize.height, 
				widthDiff = [image size].width - scaledWidth;
		xScale = scaledWidth / tileSize.width;
		yScale = [image size].height / tileSize.height;
		origin = NSMakePoint(widthDiff / 2.0, 0.0);
		if (croppedPercentage)
			*croppedPercentage = (widthDiff * [image size].height) / 
								 ([image size].width * [image size].height) * 100.0;
    }
	
		// Create a transform to scale and translate the tile outline.
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform translateXBy:origin.x yBy:origin.y];
    [transform scaleXBy:xScale yBy:yScale];
    [transform translateXBy:-[tileOutline bounds].origin.x yBy:-[tileOutline bounds].origin.y];
	NSBezierPath	*transformedTileOutline = [transform transformBezierPath:tileOutline];
    
	NS_DURING
		[highlightedImage lockFocus];
				// Start with the original image.
			[image compositeToPoint:NSZeroPoint operation:NSCompositeCopy];
			
				// Lighten the area outside of the tile.
			NSBezierPath	*lightenOutline = [NSBezierPath bezierPath];
			[lightenOutline moveToPoint:NSMakePoint(0, 0)];
			[lightenOutline lineToPoint:NSMakePoint(0, [highlightedImage size].height)];
			[lightenOutline lineToPoint:NSMakePoint([highlightedImage size].width, [highlightedImage size].height)];
			[lightenOutline lineToPoint:NSMakePoint([highlightedImage size].width, 0)];
			[lightenOutline closePath];
			[lightenOutline appendBezierPath:transformedTileOutline];
			[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
			[lightenOutline fill];
			
				// Darken the outline of the tile.
			[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
			[transformedTileOutline stroke];
		[highlightedImage unlockFocus];
	NS_HANDLER
		NSLog(@"Could not lock focus on editor image");
	NS_ENDHANDLER
	
    return highlightedImage;
}


- (IBAction)chooseImageForSelectedTile:(id)sender
{
		// Create the image for the "Original Image" view of the accessory view.
	NSRect		originalImageViewFrame = NSMakeRect(0.0, 0.0, [editorOriginalImageView frame].size.width, 
															   [editorOriginalImageView frame].size.height);
	NSImage		*originalImageForTile = [[[NSImage alloc] initWithSize:originalImageViewFrame.size] autorelease];
	NS_DURING
		[originalImageForTile lockFocus];
		
			// Start with a black background.
		[[NSColor blackColor] set];
		NSRectFill(originalImageViewFrame);
		
			// Determine the bounds of the tile in the original image and in the scratch window.
		NSBezierPath	*tileOutline = [selectedTile outline];
		NSImage			*originalImage = [[self document] originalImage];
		NSRect			origRect = NSMakeRect([tileOutline bounds].origin.x * [originalImage size].width,
											  [tileOutline bounds].origin.y * [originalImage size].height,
											  [tileOutline bounds].size.width * [originalImage size].width,
											  [tileOutline bounds].size.height * [originalImage size].height);
		
			// Expand the rectangle so that it's square.
		if (origRect.size.width > origRect.size.height)
			origRect = NSInsetRect(origRect, 0.0, (origRect.size.height - origRect.size.width) / 2.0);
		else
			origRect = NSInsetRect(origRect, (origRect.size.width - origRect.size.height) / 2.0, 0.0);
		
			// Copy out the portion of the original image contained by the tile's outline.
		[originalImage drawInRect:originalImageViewFrame fromRect:origRect operation:NSCompositeCopy fraction:1.0];
		[originalImageForTile unlockFocus];
	NS_HANDLER
		NSLog(@"Exception raised while extracting tile images: %@", [localException name]);
	NS_ENDHANDLER
	[editorOriginalImageView setImage:[self highlightTileOutline:[selectedTile outline] inImage:originalImageForTile croppedPercentage:nil]];
	
		// Set up the current image box
	MacOSaiXImageMatch	*currentMatch = [selectedTile imageMatch];
	if (currentMatch)
	{
		NSSize				currentSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfImageWithIdentifier:[currentMatch imageIdentifier] 
																									  fromSource:[currentMatch imageSource]];
		
		if (NSEqualSizes(currentSize, NSZeroSize))
		{
				// The image is not in the cache so request a random sized rep to get it loaded.
			[[MacOSaiXImageCache sharedImageCache] imageRepAtSize:NSMakeSize(1.0, 1.0) 
													forIdentifier:[currentMatch imageIdentifier] 
													   fromSource:[currentMatch imageSource]];
			currentSize = [[MacOSaiXImageCache sharedImageCache] nativeSizeOfImageWithIdentifier:[currentMatch imageIdentifier] 
																					  fromSource:[currentMatch imageSource]];
		}
		
//		float				currentImageViewWidth = [editorCurrentImageView bounds].size.width;
//		if (currentSize.width > currentSize.height)
//			currentSize = NSMakeSize(currentImageViewWidth, currentImageViewWidth * currentSize.height / currentSize.width);
//		else
//			currentSize = NSMakeSize(currentImageViewWidth * currentSize.width / currentSize.height, currentImageViewWidth);
		NSBitmapImageRep	*currentRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:currentSize 
																				  forIdentifier:[currentMatch imageIdentifier] 
																					 fromSource:[currentMatch imageSource]];
		NSImage				*currentImage = [[[NSImage alloc] initWithSize:currentSize] autorelease];
		[currentImage addRepresentation:currentRep];
		float				croppedPercentage = 0.0;
		[editorCurrentImageView setImage:[self highlightTileOutline:[selectedTile outline] inImage:currentImage croppedPercentage:&croppedPercentage]];
//		float				worstCaseMatch = sqrtf([selectedTile worstCaseMatchValue]), 
//							matchPercentage = (worstCaseMatch - sqrtf([currentMatch matchValue])) / worstCaseMatch * 100.0;
		[editorCurrentMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - [currentMatch matchValue] * 100.0]];
		[editorCurrentPercentCroppedTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", croppedPercentage]];
	}
	else
	{
		[editorCurrentImageView setImage:nil];
		[editorCurrentMatchQualityTextField setStringValue:@"--"];
		[editorCurrentPercentCroppedTextField setStringValue:@"--"];
	}
	
		// Set up the chosen image box.
	[editorChosenImageBox setTitle:@"No Image Selected"];
	[editorChosenImageView setImage:nil];
	[editorChosenMatchQualityTextField setStringValue:@"--"];
	[editorChosenPercentCroppedTextField setStringValue:@"--"];

		// Prompt the user to choose the image from which to make a mosaic.
	NSOpenPanel	*oPanel = [NSOpenPanel openPanel];
	[oPanel setCanChooseFiles:YES];
	[oPanel setCanChooseDirectories:NO];
	[oPanel setAccessoryView:editorAccessoryView];
	[oPanel setDelegate:self];
	[oPanel beginSheetForDirectory:nil
							  file:nil
							 types:[NSImage imageFileTypes]
					modalForWindow:[self window]
					 modalDelegate:self
					didEndSelector:@selector(chooseImageForSelectedTilePanelDidEnd:returnCode:contextInfo:)
					   contextInfo:nil];
}


- (void)panelSelectionDidChange:(id)sender
{
	if ([[sender URLs] count] == 0)
	{
		[editorChosenImageBox setTitle:@"No Image Selected"];
		[editorChosenImageView setImage:nil];
		[editorChosenMatchQualityTextField setStringValue:@"--"];
		[editorChosenPercentCroppedTextField setStringValue:@"--"];
	}
	else
	{
		NSString			*chosenImageIdentifier = [[sender filenames] objectAtIndex:0];
		[editorChosenImageBox setTitle:[[NSFileManager defaultManager] displayNameAtPath:chosenImageIdentifier]];
		
		NSImage				*chosenImage = [[[NSImage alloc] initWithContentsOfFile:chosenImageIdentifier] autorelease];
		
		if (chosenImage)
		{
			NSImageRep			*originalRep = [[chosenImage representations] objectAtIndex:0];
			NSSize				imageSize = NSMakeSize([originalRep pixelsWide], [originalRep pixelsHigh]);
//			if (imageSize.width > imageSize.height)
//				imageSize = NSMakeSize(128.0, 128.0 * imageSize.height/imageSize.width);
//			else
//				imageSize = NSMakeSize(128.0 * imageSize.width/imageSize.height, 128.0);
			[originalRep setSize:imageSize];
			[chosenImage setSize:imageSize];
			
			float				croppedPercentage = 0.0;
			[editorChosenImageView setImage:[self highlightTileOutline:[selectedTile outline] inImage:chosenImage croppedPercentage:&croppedPercentage]];

			[editorChosenPercentCroppedTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", croppedPercentage]];
			
				// Calculate how well the chosen image matches the selected tile.
			[[MacOSaiXImageCache sharedImageCache] cacheImage:chosenImage withIdentifier:chosenImageIdentifier fromSource:nil];
			NSBitmapImageRep	*chosenImageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:[[selectedTile bitmapRep] size] 
																						  forIdentifier:chosenImageIdentifier 
																							 fromSource:nil];
			float				matchValue = [[MacOSaiXImageMatcher sharedMatcher] compareImageRep:[selectedTile bitmapRep]  
																						  withMask:[selectedTile maskRep] 
																						toImageRep:chosenImageRep
																					  previousBest:1.0];
			[editorChosenMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - matchValue * 100.0]];
		}
	}
}


- (void)chooseImageForSelectedTilePanelDidEnd:(NSOpenPanel *)sheet 
								   returnCode:(int)returnCode
							      contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		[[sheet filenames] objectAtIndex:0];
	}
}


#pragma mark -
#pragma mark View methods


- (IBAction)setViewOriginalImage:(id)sender
{
	[mosaicView setViewOriginal:YES];
	
	[[viewMenu itemWithTag:0] setState:NSOnState];
	[[viewMenu itemWithTag:1] setState:NSOffState];
	
	[toggleOriginalToolbarItem setLabel:@"Show Mosaic"];
	[toggleOriginalToolbarItem setImage:mosaicToolbarImage];
}


- (IBAction)setViewMosaic:(id)sender
{
	[mosaicView setViewOriginal:NO];
	
	[[viewMenu itemWithTag:0] setState:NSOffState];
	[[viewMenu itemWithTag:1] setState:NSOnState];
	
	[toggleOriginalToolbarItem setLabel:@"Show Original"];
	[toggleOriginalToolbarItem setImage:originalToolbarImage];
}


- (IBAction)toggleViewOriginal:(id)sender
{
	if ([mosaicView viewOriginal])
		[self setViewMosaic:self];
	else
		[self setViewOriginalImage:self];
}


- (BOOL)viewingOriginal
{
	return ([mosaicView viewOriginal]);
}


- (IBAction)toggleTileOutlines:(id)sender
{
	[mosaicView setViewTileOutlines:![mosaicView viewTileOutlines]];
	[self synchronizeMenus];
}


- (IBAction)setZoom:(id)sender
{
		// Calculate the currently centered point of the mosaic image independent of the zoom factor.
	NSRect	frame = [[mosaicScrollView contentView] frame],
			visibleRect = [mosaicView visibleRect];
	NSPoint	centerPoint = NSMakePoint(NSMidX(visibleRect) / zoom, NSMidY(visibleRect) / zoom);
	
		// Update the zoom factor based on who called this method.
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
		if ([[sender title] isEqualToString:@"Minimum"]) zoom = [zoomSlider minValue];
		if ([[sender title] isEqualToString:@"Medium"]) zoom = ([zoomSlider maxValue] - [zoomSlider minValue]) / 2.0;
		if ([[sender title] isEqualToString:@"Maximum"]) zoom = [zoomSlider maxValue];
    }
    else zoom = [zoomSlider floatValue];
    
		// Sync the slider with the current zoom setting.
    [zoomSlider setFloatValue:zoom];
    
		// Update the frame and bounds of the mosaic view.
	frame.size.width *= zoom;
	frame.size.height *= zoom;
	[mosaicView setFrame:frame];
	[mosaicView setBounds:frame];
	
		// Reset the scroll position so that the previous center point is as close to the center as possible.
	visibleRect = [mosaicView visibleRect];
	centerPoint.x *= zoom;
	centerPoint.y *= zoom;
	[mosaicView scrollPoint:NSMakePoint(centerPoint.x - NSWidth(visibleRect) / 2.0, 
										centerPoint.y - NSHeight(visibleRect) / 2.0)];
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
//    NSRect	orig, content,doc;
//    
//    if ([notification object] != mosaicScrollView) return;
//    
//    orig = [originalView bounds];
//    content = [[mosaicScrollView contentView] bounds];
//    doc = [mosaicView frame];
//    [originalView setFocusRect:NSMakeRect(content.origin.x * orig.size.width / doc.size.width,
//					  content.origin.y * orig.size.height / doc.size.height,
//					  content.size.width * orig.size.width / doc.size.width,
//					  content.size.height * orig.size.height / doc.size.height)];
//    [originalView setNeedsDisplay:YES];
}


- (void)toggleStatusBar:(id)sender
{
    NSRect	newFrame = [[self window] frame];
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
		newFrame.size = [self windowWillResize:[self window] toSize:newFrame.size];
		[[self window] setFrame:newFrame display:YES animate:YES];
    }
    else
    {
		statusBarShowing = YES;
		newFrame.origin.y -= [statusBarView frame].size.height;
		newFrame.size.height += [statusBarView frame].size.height;
		newFrame.size = [self windowWillResize:[self window] toSize:newFrame.size];
		[[self window] setFrame:newFrame display:YES animate:YES];
	
		[statusBarView setFrame:NSMakeRect(0, [[mosaicScrollView superview] frame].size.height - [statusBarView frame].size.height, [[mosaicScrollView superview] frame].size.width, [statusBarView frame].size.height)];
		[[mosaicScrollView superview] addSubview:statusBarView];
		[statusBarView release];
		for (i = 0; i < [removedSubviews count]; i++)
		{
			[[removedSubviews objectAtIndex:i] setFrameSize:NSMakeSize([statusBarView frame].size.width,[[removedSubviews objectAtIndex:i] frame].size.height)];
			[statusBarView addSubview:[removedSubviews objectAtIndex:i]];
		}
		[removedSubviews release]; removedSubviews = nil;
    }
	
	[self synchronizeMenus];
}


- (void)toggleImageSourcesDrawer:(id)sender
{
    [settingsDrawer toggle:(id)sender];
    if ([settingsDrawer state] == NSDrawerClosedState)
		[[viewMenu itemWithTitle:@"Show Image Sources"] setTitle:@"Hide Image Sources"];
    else
		[[viewMenu itemWithTitle:@"Hide Image Sources"] setTitle:@"Show Image Sources"];
}


#pragma mark -
#pragma mark Utility methods


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(centerViewOnSelectedTile:))
		return (selectedTile != nil && zoom != 0.0);
    else if ([menuItem action] == @selector(togglePause:))
		return ([[[self document] imageSources] count] > 0);
//	else
//		return [[self document] validateMenuItem:menuItem];

	return YES;
}


- (void)togglePause:(id)sender
{
	if ([[self document] isPaused])
		[self resume];
	else
		[self pause];
}


#pragma mark -
#pragma mark Export image methods

- (void)beginExportImage:(id)sender
{
		// Disable auto saving so it doesn't interfere with exporting.
	[[self document] setAutoSaveEnabled:NO];
	
		// Pause the mosaic so we don't have a moving target.
	BOOL		wasPaused = [[self document] isPaused];
    [self pause];
    
		// Set up the save panel for exporting.
	NSString	*defaultExtension = (exportFormat == NSJPEGFileType ? @"jpg" : @"tiff"),
				*defaultName = [[self document] displayName];
	if ([defaultName hasSuffix:@".mosaic"])
		defaultName = [defaultName stringByDeletingPathExtension];
	defaultName = [[defaultName stringByAppendingString:@" Export"] stringByAppendingPathExtension:defaultExtension];
    NSSavePanel	*savePanel = [NSSavePanel savePanel];
    if ([exportWidth intValue] == 0)
    {
		NSSize	originalSize = [[[self document] originalImage] size];
		float	scale = 4.0;
		
		if (originalSize.width * scale > 10000.0)
			scale = 10000.0 / originalSize.width;
		if (originalSize.height * scale > 10000.0)
			scale = 10000.0 / originalSize.height;
			
        [exportWidth setIntValue:(int)(originalSize.width * scale + 0.5)];
        [exportHeight setIntValue:(int)(originalSize.height * scale + 0.5)];
    }
	[savePanel setCanSelectHiddenExtension:YES];
    [savePanel setRequiredFileType:defaultExtension];
    [savePanel setAccessoryView:exportPanelAccessoryView];
	
		// Ask the user where to export the image.
    [savePanel beginSheetForDirectory:NSHomeDirectory()
				 file:defaultName
		       modalForWindow:[self window]
			modalDelegate:self
		       didEndSelector:@selector(exportImageSavePanelDidEnd:returnCode:contextInfo:)
			  contextInfo:[NSNumber numberWithBool:wasPaused]];
}


- (IBAction)setJPEGExport:(id)sender
{
    exportFormat = NSJPEGFileType;
    [(NSSavePanel *)[sender window] setRequiredFileType:@"jpg"];
}


- (IBAction)setTIFFExport:(id)sender;
{
    exportFormat = NSTIFFFileType;
    [(NSSavePanel *)[sender window] setRequiredFileType:@"tiff"];
}


- (void)exportImageSavePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[sheet orderOut:self];
	
    if (returnCode == NSOKButton)
    {
			// Display a progress panel while the export is underway.
		[self displayProgressPanelWithMessage:@"Exporting mosaic image..."];
		
			// Spawn a thread to do the export so the GUI doesn't get tied up.
		[NSApplication detachDrawingThread:@selector(exportImage:)
								  toTarget:self 
								withObject:[(NSSavePanel *)sheet filename]];
	}
	else
			// Re-enable auto saving.
		[[self document] setAutoSaveEnabled:YES];
}


- (void)exportImage:(NSString *)exportFilename
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*exportError = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

    NSImage		*exportImage = [[NSImage alloc] initWithSize:NSMakeSize([exportWidth intValue], [exportHeight intValue])];
	[exportImage setCachedSeparately:YES];
	[exportImage setCacheMode:NSImageCacheNever];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		exportError = [NSString stringWithFormat:@"Could not draw images into the mosaic.  (%@)", [localException reason]];
	NS_ENDHANDLER
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
	
	unsigned long		tileCount = [[[self document] tiles] count],
						tilesExported = 0;
	
	NSEnumerator		*tileEnumerator = [[[self document] tiles] objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (tile = [tileEnumerator nextObject])
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
		
			// Get the image in use by this tile.
		MacOSaiXImageMatch	*match = [tile displayedImageMatch];
		
		if (match)
		{
			NS_DURING
					// Clip the tile's image to the outline of the tile.
				NSBezierPath	*clipPath = [transform transformBezierPath:[tile outline]];
				[NSGraphicsContext saveGraphicsState];
				[clipPath addClip];
				
					// Get the image for this tile from the cache.
				NSImageRep			*pixletImageRep = [[MacOSaiXImageCache sharedImageCache] imageRepAtSize:[clipPath bounds].size 
																							  forIdentifier:[match imageIdentifier] 
																								 fromSource:[match imageSource]];
				
					// Translate the tile's outline (in unit space) to the size of the exported image.
				NSRect		drawRect;
				if ([clipPath bounds].size.width / [pixletImageRep size].width <
					[clipPath bounds].size.height / [pixletImageRep size].height)
				{
					drawRect.size = NSMakeSize([clipPath bounds].size.height * [pixletImageRep size].width /
								[pixletImageRep size].height,
								[clipPath bounds].size.height);
					drawRect.origin = NSMakePoint([clipPath bounds].origin.x - 
									(drawRect.size.width - [clipPath bounds].size.width) / 2.0,
								[clipPath bounds].origin.y);
				}
				else
				{
					drawRect.size = NSMakeSize([clipPath bounds].size.width,
								[clipPath bounds].size.width * [pixletImageRep size].height /
								[pixletImageRep size].width);
					drawRect.origin = NSMakePoint([clipPath bounds].origin.x,
								[clipPath bounds].origin.y - 
									(drawRect.size.height - [clipPath bounds].size.height) / 2.0);
				}
				
					// Finally, draw the tile's image.
				[pixletImageRep drawInRect:drawRect];
				
					// Clean up.
				[NSGraphicsContext restoreGraphicsState];
			NS_HANDLER
				NSLog(@"Exception during export: %@", localException);
				[NSGraphicsContext restoreGraphicsState];
			NS_ENDHANDLER
		}
		
        [pool2 release];
		
		[self setProgressPercentComplete:[NSNumber numberWithDouble:((double)++tilesExported / (double)tileCount * 100.0)] ];
    }
	
		// Now convert the image into the desired output format.
    NSBitmapImageRep	*exportRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, [exportImage size].width, 
									     [exportImage size].height)];
	NS_DURING
		[exportImage unlockFocus];

		NSData		*bitmapData = (exportFormat == NSJPEGFileType) ? 
										[exportRep representationUsingType:NSJPEGFileType properties:nil] :
										[exportRep TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:1.0];
		[bitmapData writeToFile:exportFilename atomically:YES];
	NS_HANDLER
		exportError = [NSString stringWithFormat:@"Could not convert the mosaic to the requested format.  (%@)",
												 [localException reason]];
	NS_ENDHANDLER
	
    [pool release];
    [exportRep release];
    [exportImage release];
	
	[self closeProgressPanel];
	
	if (exportError)
		[self performSelectorOnMainThread:@selector(displayExportErrorSheet:) withObject:exportError waitUntilDone:NO];
	else
		[[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
}


- (void)displayExportErrorSheet:(NSString *)errorString
{
	NSBeginAlertSheet(@"The mosaic could not be exported.", @"OK", nil, nil, [self window], 
					  self, nil, @selector(exportErrorSheetDidDismiss:), nil, errorString);
}


- (void)exportErrorSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
}


#pragma mark -
#pragma mark Progress panel


- (void)displayProgressPanelWithMessage:(NSString *)message
{
	if (pthread_main_np())
	{
		[progressPanelLabel setStringValue:(message ? message : @"Please wait...")];
		[progressPanelIndicator setDoubleValue:0.0];
		[progressPanelIndicator setIndeterminate:YES];
		[progressPanelIndicator startAnimation:self];
		[progressPanelCancelButton setEnabled:NO];
		
		[NSApp beginSheet:progressPanel
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:nil
			  contextInfo:nil];
	}
	else
		[self performSelectorOnMainThread:@selector(displayProgressPanelWithMessage:) 
							   withObject:message 
							waitUntilDone:YES];
}


- (void)setProgressPercentComplete:(NSNumber *)percentComplete
{
	if (pthread_main_np())
	{
		[progressPanelIndicator setIndeterminate:NO];
		[progressPanelIndicator setDoubleValue:[percentComplete doubleValue]];
	}
	else
		[self performSelectorOnMainThread:@selector(setProgressPercentComplete:) 
							   withObject:percentComplete 
							waitUntilDone:YES];
}


- (void)setProgressMessage:(NSString *)message
{
	if (pthread_main_np())
		[progressPanelLabel setStringValue:message];
	else
		[self performSelectorOnMainThread:@selector(setProgressMessage:) 
							   withObject:message 
							waitUntilDone:YES];
}


- (void)closeProgressPanel
{
	if (pthread_main_np())
	{
		[NSApp endSheet:progressPanel];
		[progressPanelIndicator stopAnimation:self];
		[progressPanel orderOut:nil];
	}
	else
		[self performSelectorOnMainThread:@selector(closeProgressPanel) 
							   withObject:nil 
							waitUntilDone:NO];
}


// window delegate methods

#pragma mark -
#pragma mark Window delegate methods


- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
    [self synchronizeMenus];
}


- (NSSize)windowWillResize:(NSWindow *)resizingWindow toSize:(NSSize)proposedFrameSize
{
	if (resizingWindow == [self window])
	{
		float	aspectRatio = [[[self document] originalImage] size].width / [[[self document] originalImage] size].height,
				windowTop = NSMaxY([resizingWindow frame]), 
				minHeight = 413;	// TODO: get this from nib setting
		NSSize	diff;
		NSRect	screenFrame = [[resizingWindow screen] frame];
		
		proposedFrameSize.width = MIN(MAX(proposedFrameSize.width, 132),
									  screenFrame.size.width - [resizingWindow frame].origin.x);
		diff.width = [resizingWindow frame].size.width - [[resizingWindow contentView] frame].size.width;
		diff.height = [resizingWindow frame].size.height - [[resizingWindow contentView] frame].size.height;
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
	}
	else if (resizingWindow == tileShapesPanel)
	{
		NSSize	panelSize = [tileShapesPanel frame].size,
				editorBoxSize = [[tileShapesBox contentView] frame].size;
		float	minWidth = (panelSize.width - editorBoxSize.width) + [tileShapesEditor editorViewMinimumSize].width,
				minHeight = (panelSize.height - editorBoxSize.height) + [tileShapesEditor editorViewMinimumSize].height;
		
		proposedFrameSize.width = MAX(proposedFrameSize.width, minWidth);
		proposedFrameSize.height = MAX(proposedFrameSize.height, minHeight);
	}
	else if (resizingWindow == imageSourceEditorPanel)
	{
		NSSize	panelSize = [imageSourceEditorPanel frame].size,
				editorBoxSize = [[imageSourceEditorBox contentView] frame].size;
		float	minWidth = (panelSize.width - editorBoxSize.width) + [imageSourceEditorController editorViewMinimumSize].width,
				minHeight = (panelSize.height - editorBoxSize.height) + [imageSourceEditorController editorViewMinimumSize].height;
		
		proposedFrameSize.width = MAX(proposedFrameSize.width, minWidth);
		proposedFrameSize.height = MAX(proposedFrameSize.height, minHeight);
	}

    return proposedFrameSize;
}


- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)defaultFrame
{
	if (window == [self window])
	{
		NSSize	size = [self windowWillResize:window toSize:defaultFrame.size];
		defaultFrame.origin = [window frame].origin;
		defaultFrame.origin.y += NSHeight(defaultFrame) - size.height;
		defaultFrame.size = size;

		[mosaicScrollView setNeedsDisplay:YES];
	}
    
    return defaultFrame;
}


- (void)windowDidResize:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
			// this method is called during animated window resizing, not windowWillResize
		[self setZoom:self];
	}
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXOriginalImageDidChangeNotification object:[self document]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXDocumentDidChangeStateNotification object:[self document]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTileShapesDidChangeStateNotification object:[self document]];
		
		[tileRefreshLock lock];
			[tilesToRefresh release];
			tilesToRefresh = nil;
		[tileRefreshLock unlock];
		
		while (refreshTilesThreadCount > 0)
			[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	}
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
    
	if ([itemIdentifier isEqualToString:@"Export Image"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"ExportImage"]];
		[toolbarItem setLabel:@"Export Image"];
		[toolbarItem setPaletteLabel:@"Export Image"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(beginExportImage:)];
		[toolbarItem setToolTip:@"Export an image of the mosaic"];
    }
	else if ([itemIdentifier isEqualToString:@"Pause"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[toolbarItem setLabel:[[self document] isPaused] ? @"Resume" : @"Pause"];
		[toolbarItem setPaletteLabel:[[self document] isPaused] ? @"Resume" : @"Pause"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(togglePause:)];
		pauseToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Settings Drawer"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Settings"]];
		[toolbarItem setLabel:@"Settings"];
		[toolbarItem setPaletteLabel:@"Settings"];
		[toolbarItem setTarget:settingsDrawer];
		[toolbarItem setAction:@selector(toggle:)];
		[toolbarItem setToolTip:@"Show/hide settings drawer"];
    }
	else if ([itemIdentifier isEqualToString:@"Toggle Original"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Toggle Original"]];
		[toolbarItem setLabel:[mosaicView viewOriginal] ? @"View Mosaic" : @"View Original"];
		[toolbarItem setPaletteLabel:[mosaicView viewOriginal] ? @"View Mosaic" : @"View Original"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(toggleViewOriginal:)];
		toggleOriginalToolbarItem = toolbarItem;
    }
    else if ([itemIdentifier isEqualToString:@"Zoom"])
    {
		[toolbarItem setMinSize:NSMakeSize(64, 14)];
		[toolbarItem setMaxSize:NSMakeSize(64, 14)];
		[toolbarItem setLabel:@"Zoom"];
		[toolbarItem setPaletteLabel:@"Zoom"];
		[toolbarItem setView:zoomToolbarView];
		[toolbarItem setMenuFormRepresentation:zoomToolbarMenuItem];
    }
    
    [toolbarItems setObject:toolbarItem forKey:itemIdentifier];
    
    return toolbarItem;
}


- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    if ([[theItem itemIdentifier] isEqualToString:@"Pause"])
		return ([[[self document] tiles] count] > 0 && [[[self document] imageSources] count] > 0);
    else
		return YES;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Export Image", @"Pause", @"Settings Drawer", @"Toggle Original", @"Zoom", 
				     NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSpaceItemIdentifier,
				     NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier,
				     nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Toggle Original", @"Zoom", @"Pause", @"Export Image", 
									 NSToolbarFlexibleSpaceItemIdentifier, @"Settings Drawer", nil];
}


#pragma mark -
#pragma mark Table delegate methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == imageSourcesTableView)
		return [[[self document] imageSources] count];
	
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (aTableView == imageSourcesTableView)
    {
		id<MacOSaiXImageSource>	imageSource = [[[self document] imageSources] objectAtIndex:rowIndex];
		
		if ([[aTableColumn identifier] isEqualToString:@"Image Source Type"])
			return [imageSource image];
		else
		{
				// TBD: this won't work once entries get removed from the dictionary...
			long	imageCount = [[self document] countOfImagesFromSource:imageSource];
			id		descriptor = [imageSource descriptor];
			
			if ([descriptor isKindOfClass:[NSString class]])
				return [NSString stringWithFormat:@"%@\n(%ld images found)", descriptor, imageCount];
			else if ([descriptor isKindOfClass:[NSAttributedString class]])
			{
				NSString	*stringToAppend = [NSString stringWithFormat:@"\n(%ld images found)", imageCount];
				descriptor = [descriptor mutableCopy];
				[(NSMutableAttributedString *)descriptor appendAttributedString:
					[[[NSAttributedString alloc] initWithString:stringToAppend] autorelease]];
				return descriptor;
			}
			else
				return nil;
		}
    }
	else
		return nil;
}


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if ([notification object] == imageSourcesTableView)
	{
		[imageSourcesRemoveButton setEnabled:([imageSourcesTableView selectedRow] != -1)];
	}
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


- (void)controlTextDidChange:(NSNotification *)notification
{
	NSSize	originalImageSize = [[[self document] originalImage] size];
	
	if ([notification object] == exportWidth)
		[exportHeight setIntValue:[exportWidth intValue] / originalImageSize.width * originalImageSize.height + 0.5];
	else if ([notification object] == exportHeight)
		[exportWidth setIntValue:[exportHeight intValue] / originalImageSize.height * originalImageSize.width + 0.5];
	
	NSButton	*saveButton = [self bottomRightButtonInWindow:[[notification object] window]];
	if ([exportWidth intValue] > 10000 || [exportHeight intValue] > 10000)
	{
		NSBeep();
		[saveButton setEnabled:NO];
	}
	else
		[saveButton setEnabled:YES];
}


#pragma mark


- (void)dealloc
{
	[selectedTile release];
    [selectedTileImages release];
    [toolbarItems release];
    [removedSubviews release];
    [zoomToolbarMenuItem release];
    [viewToolbarMenuItem release];
    [tileImages release];
    
	[tileShapesEditor release];
	[tileShapesBeingEdited release];
	
	[tileRefreshLock release];
	[tilesToRefresh release];
	
		// We are responsible for releasing any top-level objects in the nib file that we opened.
	// ???
	
    [super dealloc];
}


@end
