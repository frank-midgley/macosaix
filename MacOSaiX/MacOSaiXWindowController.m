/*
	MacOSaiXWindowController.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

//#import <HIToolbox/MacWindows.h>
#import "MacOSaiX.h"
#import "MacOSaiXWindowController.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXImageCache.h"
#import "Tiles.h"
#import "MosaicView.h"
#import "OriginalView.h"
#import "NSImage+MacOSaiX.h"
#import <unistd.h>
#import <pthread.h>


@interface MacOSaiXWindowController (PrivateMethods)
- (void)updateStatus:(NSTimer *)timer;
- (void)synchronizeMenus;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (NSImage *)createEditorImage:(int)rowIndex;
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
	}
	
    return self;
}


- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)awakeFromNib
{
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
//			[originalThumbnail setCacheMode:NSImageCacheNever];
			
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
		
		[[self document] setTileShapes:[[[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init] autorelease]];
		
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
		
			// Set the image use count and neighborhood size pop-ups.
		int				popUpIndex = [imageUseCountPopUpButton indexOfItemWithTag:[[self document] imageUseCount]];
		[imageUseCountPopUpButton selectItemAtIndex:popUpIndex];
		popUpIndex = [[self document] neighborhoodSize] - 1;
		if (popUpIndex >= 0 && popUpIndex < [neighborhoodSizePopUpButton numberOfItems])
			[neighborhoodSizePopUpButton selectItemAtIndex:popUpIndex];
		
			// Set up the "Image Sources" tab
		[imageSourcesTableView setDoubleAction:@selector(editImageSource:)];

		[[imageSourcesTableView tableColumnWithIdentifier:@"Image Source Type"]
			setDataCell:[[[NSImageCell alloc] init] autorelease]];
		[imageSourcesRemoveButton setEnabled:NO];	// temporarily disabled for 2.0a1
	
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
	
	[tileShapesBox setContentViewMargins:NSMakeSize(16.0, 16.0)];
	
	{	// Set up the "Editor" tab
		[[editorTable tableColumnWithIdentifier:@"image"] setDataCell:[[[NSImageCell alloc] init] autorelease]];
	}
	
	[mosaicView setDocument:[self document]];
	[self setViewOriginalImage:self];
	
		// For some reason IB insists on setting the drawer width to 200.  Have to set the size in code instead.
	[settingsDrawer setContentSize:NSMakeSize(400, [settingsDrawer contentSize].height)];
	[settingsDrawer open:self];
	
    selectedTile = nil;
    
//    NSRect		windowFrame;
//    if (finishLoading)
//    {
//		//	[self setViewMode:viewMode];
//		
//			// this doc was opened from a file
//		if ([[self document] isPaused])
//		{
//			[pauseToolbarItem setLabel:@"Resume"];
//			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
//			[[fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
//		}
//	
//			//	broken & disabled until next version
//		//	[self windowWillResize:[self window] toSize:storedWindowFrame.size];
//		//	[[self window] setFrame:storedWindowFrame display:YES];
//		windowFrame = [[self window] frame];
//		windowFrame.size = [self windowWillResize:[self window] toSize:windowFrame.size];
//		[[self window] setFrame:windowFrame display:YES animate:YES];
//    }
//    else
//    {
//			// this doc is new
//		windowFrame = [[self window] frame];
//		windowFrame.size = [self windowWillResize:[self window] toSize:windowFrame.size];
//		[[self window] setFrame:windowFrame display:YES animate:YES];
//    }
//	[pauseToolbarItem setLabel:@"Start Mosaic"];
	
	[self updateStatus:nil];
	
		// Default to the most recently used original or prompt to choose one
		// if no previous original was found.
	[self performSelector:@selector(chooseOriginalImage:) withObject:self afterDelay:0.0];
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
	{
		NSString	*imagePath = [[sheet filenames] objectAtIndex:0];
		[[self document] setOriginalImagePath:imagePath];
		
			// Remember this original in the user's defaults so they can easily re-choose it for future mosaics.
		NSImage			*originalImage = [[self document] originalImage];
		NSImage			*thumbnailImage = [originalImage copyWithLargestDimension:32.0];
		NSMutableArray	*originals = [[[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Originals"] mutableCopy] autorelease];
		if (originals)
		{
				// Remove any previous entry from the defaults for the image at this path.
			NSEnumerator	*originalEnumerator = [originals objectEnumerator];
			NSDictionary	*originalDict = nil;
			while (originalDict = [originalEnumerator nextObject])
				if ([[originalDict objectForKey:@"Path"] isEqualToString:imagePath])
				{
					[originals removeObject:originalDict];
					break;
				}
		}
		else
			originals = [NSMutableArray array];
		[originals insertObject:[NSDictionary dictionaryWithObjectsAndKeys:
									imagePath, @"Path", 
									[[imagePath lastPathComponent] stringByDeletingPathExtension], @"Name", 
									[thumbnailImage TIFFRepresentation], @"Thumbnail Data",
									nil]
						atIndex:0];
		[[NSUserDefaults standardUserDefaults] setObject:originals forKey:@"Recent Originals"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		
			// Update the original image pop-up menu.
		NSEnumerator	*itemEnumerator = [[[originalImagePopUpButton menu] itemArray] objectEnumerator];
		NSMenuItem		*item = nil;
		while (item = [itemEnumerator nextObject])
			if ([[item representedObject] isEqualToString:imagePath])
			{
				[[originalImagePopUpButton menu] removeItem:item];
				break;
			}
		NSMenuItem	*originalItem = [[[NSMenuItem alloc] init] autorelease];
		[originalItem setTitle:[[imagePath lastPathComponent] stringByDeletingPathExtension]];
		[originalItem setRepresentedObject:imagePath];
		[originalImageThumbView setImage:thumbnailImage];
		[[originalImagePopUpButton menu] insertItem:originalItem atIndex:0];
		[originalImagePopUpButton selectItemAtIndex:0];
		
		[thumbnailImage release];
	}
}


- (void)originalImageDidChange:(NSNotification *)notification
{
		// Set the zoom so that all of the new image is displayed.
    [zoomSlider setFloatValue:0.0];
    [self setZoom:self];
	
		// Resize the window to respect the original's aspect ratio
	NSRect	curFrame = [[self window] frame];
	NSSize	newSize = [self windowWillResize:[self window] toSize:curFrame.size];
	[[self window] setFrame:NSMakeRect(NSMinX(curFrame), NSMaxY(curFrame) - newSize.height, newSize.width, newSize.height)
					display:YES
					animate:YES];
	
	[self updateStatus:nil];
	
		// Create the toolbar icons for the View Original/View Mosaic item.  Toolbar item images 
		// must be 32x32 so we center the thumbnail in an image of the correct size.
	[originalToolbarImage release];
	originalToolbarImage = [[NSImage alloc] initWithSize:NSMakeSize(32.0, 32.0)];
	NSImage	*thumbnailImage = [[[[self document] originalImage] copyWithLargestDimension:32.0] autorelease];
	NSSize	thumbSize = [thumbnailImage size];
	[originalToolbarImage lockFocus];
		if (thumbSize.width > thumbSize.height)
			[thumbnailImage compositeToPoint:NSMakePoint(0.0, (32.0 - thumbSize.height) / 2.0) operation:NSCompositeCopy];
		else
			[thumbnailImage compositeToPoint:NSMakePoint((32.0 - thumbSize.width) / 2.0, 0.0) operation:NSCompositeCopy];
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


#pragma mark


- (void)pause
{
	if (![[self document] isPaused])
	{
			// Update the toolbar.
		[pauseToolbarItem setLabel:@"Resume"];
		[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		
			// Update the menu bar.
		[[fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
		
		[[self document] pause];
	}
}


- (void)resume
{
	if ([[self document] isPaused])
	{
		if ([[self document] wasStarted])
		{
				// Make sure the tiles can't be tweaked now that the mosaic was started.
			[originalImagePopUpButton setEnabled:NO];
			[changeTileShapesButton setEnabled:NO];
			[imageUseCountPopUpButton setEnabled:NO];
			[neighborhoodSizePopUpButton setEnabled:NO];
		}
		else
		{
				// Update the toolbar
			[pauseToolbarItem setLabel:@"Pause"];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
			
				// Update the menu bar
			[[fileMenu itemWithTitle:@"Resume Matching"] setTitle:@"Pause Matching"];
		}
		
		[[self document] resume];
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
	[self performSelectorOnMainThread:@selector(updateStatus:) withObject:nil waitUntilDone:NO];
}


//- (void)documentDidChangeState:(NSNotification *)notification
//{
//	[statusUpdateTimerLock lock];
//		if (![statusUpdateTimer isValid])
//		{
//			[statusUpdateTimer release];
//			statusUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.5 
//																  target:self 
//																selector:@selector(updateStatus:) 
//																userInfo:nil 
//																 repeats:NO] retain];
//		}
//	[statusUpdateTimerLock unlock];
//}


- (void)updateStatus:(NSTimer *)timer
{
    NSString	*statusMessage = nil;
    
    // update the status bar
	if (![[self document] originalImage])
		statusMessage = @"You have not chosen the original image";
	else if ([[[self document] tiles] count] == 0)
		statusMessage = @"You have not set the tile shapes";
	else if ([[[self document] imageSources] count] == 0)
		statusMessage = @"You have not added any image sources";
	else if ([[self document] isExtractingTileImagesFromOriginal])
		statusMessage = [NSString stringWithFormat:@"Extracting tile images (%.0f%%)", 
												   [[self document] tileCreationPercentComplete]];
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
	
    [statusMessageView setStringValue:[NSString stringWithFormat:@"Images: %d     Quality: %2.1f%%     Status: %@",
																 [[self document] imagesMatched], 
																 overallMatch, 
																 statusMessage]];
    
		// update the image sources table
    [imageSourcesTableView reloadData];
    
    // autosave if it's time
//    if ([lastSaved timeIntervalSinceNow] < autosaveFrequency * -60)
//    {
//		[self saveDocument:self];
//		[lastSaved autorelease];
//		lastSaved = [[NSDate date] retain];
//    }
    
    // 
}


- (void)synchronizeMenus
{
	[[fileMenu itemWithTag:1] setTitle:([[self document] isPaused] ? @"Resume Matching" : @"Pause Matching")];

	[[viewMenu itemWithTag:0] setState:([mosaicView viewOriginal] ? NSOnState : NSOffState)];
	[[viewMenu itemWithTag:1] setState:([mosaicView viewOriginal] ? NSOffState : NSOnState)];

	[[viewMenu itemWithTitle:@"Show Status Bar"] setTitle:(statusBarShowing ? @"Hide Status Bar" : @"Show Status Bar")];
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
		
			// Swap in the view of the new editor.
		[[tileShapesEditor editorView] setFrame:[[tileShapesBox contentView] frame]];
		[[tileShapesEditor editorView] setAutoresizingMask:[[tileShapesBox contentView] autoresizingMask]];
		[tileShapesBox setContentView:[tileShapesEditor editorView]];
		
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

	[imageSourceEditorBox setContentView:nil];
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	[tileShapesDescriptionField setStringValue:[[[self document] tileShapes] briefDescription]];
	[totalTilesField setIntValue:[[[self document] tiles] count]];
	
	if (selectedTile)
		[self selectTileAtPoint:tileSelectionPoint];
	
	[self updateStatus:nil];
}


- (IBAction)setImageUseCount:(id)sender
{
	[[self document] setImageUseCount:[[imageUseCountPopUpButton selectedItem] tag]];
}


- (IBAction)setNeighborhoodSize:(id)sender
{
	[[self document] setNeighborhoodSize:[neighborhoodSizePopUpButton indexOfSelectedItem] + 1];
	
	if (selectedTile)
		[mosaicView highlightTile:selectedTile];
}


#pragma mark -
#pragma mark Image Sources tab methods


- (void)addNewImageSource:(id)sender
{
	if ([imageSourcesPopUpButton indexOfSelectedItem] > 0)
	{
		Class								imageSourceClass = [[imageSourcesPopUpButton selectedItem] representedObject];
		id<MacOSaiXImageSource>				newSource = [[[imageSourceClass alloc] init] autorelease];
		id<MacOSaiXImageSourceController>	controller = [[[[imageSourceClass editorClass] alloc] init] autorelease];
		
		[imageSourceEditorBox setContentView:[controller imageSourceView]];
		[controller setOKButton:imageSourceEditorOKButton];
		[controller editImageSource:newSource];
		
		[NSApp beginSheet:imageSourceEditorPanel 
		   modalForWindow:[self window]
		    modalDelegate:self 
		   didEndSelector:@selector(imageSourceEditorDidEnd:returnCode:contextInfo:) 
			  contextInfo:[[NSArray arrayWithObjects:newSource, controller, nil] retain]];
	}
}


- (IBAction)editImageSource:(id)sender
{
	// TBD: check if sheet already displayed?
	
	if (sender == imageSourcesTableView)
	{
		id<MacOSaiXImageSource>				originalSource = [[[self document] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]],
											newSource = [[originalSource copyWithZone:[self zone]] autorelease];
		id<MacOSaiXImageSourceController>	controller = [[[[[newSource class] editorClass] alloc] init] autorelease];
		
		[imageSourceEditorBox setContentView:[controller imageSourceView]];
		[controller editImageSource:newSource];
		
		[NSApp beginSheet:imageSourceEditorPanel 
		   modalForWindow:[self window]
		    modalDelegate:self 
		   didEndSelector:@selector(imageSourceEditorDidEnd:returnCode:contextInfo:) 
			  contextInfo:[[NSArray arrayWithObjects:newSource, controller, originalSource, nil] retain]];
	}
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
										originalImageSource = ([parameters count] == 3 ? [parameters lastObject] : nil);
//	id<MacOSaiXImageSourceController>	controller = [parameters objectAtIndex:1];
	
	[sheet orderOut:self];
	
		// Do this before adding the source so we don't run into thread safety issues with QuickTime.
	[imageSourceEditorBox setContentView:nil];
	
	if (returnCode == NSOKButton)
	{
		[[self document] removeImageSource:originalImageSource];
		[[self document] addImageSource:editedImageSource];
	
			// TODO: we don't always want to resume automatically...
		if ([[self document] tileShapes])
			[[self document] resume];
		
		[imageSourcesTableView reloadData];
	}
	
	[(id)contextInfo release];
}


- (IBAction)removeImageSource:(id)sender
{
	id<MacOSaiXImageSource>	imageSource = [[[self document] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]];
	
	[[self document] removeImageSource:imageSource];
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
				selectedTile = nil;
				
					// Get rid of the timer when no tile is selected.
				[animateTileTimer invalidate];
				[animateTileTimer release];
				animateTileTimer = nil;
			}
			else
			{
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
			
			[mosaicView highlightTile:selectedTile];
			
//			if ([mosaicView viewMode] == viewHighlightedTile)
//			{
//					// Populate the editor with this tile.
//				[editorLabel setStringValue:@"Image to use for selected tile:"];
//				[editorUseCustomImage setEnabled:YES];
//				[editorUseBestUniqueMatch setEnabled:YES];
//				
//				[editorTable scrollRowToVisible:0];
//				[self updateEditor];
//            }
			
			break;
        }
}


- (void)animateSelectedTile:(id)timer
{
    if (![[self document] isClosing])
        [mosaicView animateHighlight];
}


- (void)updateEditor
{
    [selectedTileImages release];
    
    if (selectedTile)
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
            [editorUseCustomImage setState:NSOffState];	// NSOnState];	temp for 2.0a1
            [editorUseBestUniqueMatch setState:NSOffState];
// TODO:            [editorUserChosenImage setImage:[[selectedTile userChosenImageMatch] image]];
        }
        else
        {
            [editorUseCustomImage setState:NSOffState];
            [editorUseBestUniqueMatch setState:NSOffState];	// NSOnState];	temp for 2.0a1
            [editorUserChosenImage setImage:nil];
            
            NSImage	*image = [[[NSImage alloc] initWithSize:[[selectedTile bitmapRep] size]] autorelease];
            [image addRepresentation:[selectedTile bitmapRep]];
            [editorUserChosenImage setImage:image];
        }
    
        [editorChooseImage setEnabled:NO];	// YES];	temp for 2.0a1
        [editorUseSelectedImage setEnabled:NO];	// YES];	temp for 2.0a1
        
//        selectedTileImages = [[NSMutableArray arrayWithCapacity:[selectedTile matchCount]] retain];
//        int	i;
//        for (i = 0; i < [selectedTile matchCount]; i++)
//            [selectedTileImages addObject:[NSNull null]];
    }
    
    [editorTable reloadData];
}


- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting
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
/*
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSSize				tileSize = [[selectedTile outline] bounds].size;
    float				scale;
    NSPoint				origin;
    NSBezierPath		*bezierPath = [NSBezierPath bezierPath];
    
	MacOSaiXImageMatch	*imageMatch = [[selectedTile matches] objectAtIndex:rowIndex];
	image = [[[self document] imageCache] imageForIdentifier:[imageMatch imageIdentifier] 
												  fromSource:[imageMatch imageSource]];
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
*/
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
		    modalForWindow:[self window]
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


- (IBAction)toggleTileOutlines:(id)sender
{
	[mosaicView setViewTileOutlines:![mosaicView viewTileOutlines]];
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
		[[viewMenu itemWithTitle:@"Hide Status Bar"] setTitle:@"Show Status Bar"];
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
	
		[[viewMenu itemWithTitle:@"Show Status Bar"] setTitle:@"Hide Status Bar"];
    }
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
    if ([[menuItem title] isEqualToString:@"Center on Selected Tile"])
		return (selectedTile != nil && zoom != 0.0);
    else
		return [[self document] validateMenuItem:menuItem];
}


- (void)togglePause:(id)sender
{
//	NSEnumerator			*imageSourceEnumerator = [imageSources objectEnumerator];
//	id<MacOSaiXImageSource>	imageSource;

	if ([[self document] isPaused])
		[self resume];
	else
	{
		[self pause];
//		[pauseToolbarItem setLabel:@"Resume"];
//		[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
//		[[fileMenu itemWithTitle:@"Pause Matching"] setTitle:@"Resume Matching"];
//		while (imageSource = [imageSourceEnumerator nextObject])
//			[imageSource pause];
//		paused = YES;
	}
}


#pragma mark -
#pragma mark Export image methods

- (void)beginExportImage:(id)sender
{
		// First pause the mosaic so we don't have a moving target.
	BOOL		wasPaused = [[self document] isPaused];
    [self pause];
    
		// Set up the save panel for exporting.
    NSSavePanel	*savePanel = [NSSavePanel savePanel];
    if ([exportWidth intValue] == 0)
    {
        [exportWidth setIntValue:[[[self document] originalImage] size].width * 4];
        [exportHeight setIntValue:[[[self document] originalImage] size].height * 4];
    }
    [savePanel setAccessoryView:exportPanelAccessoryView];
    
		// Ask the user where to export the image.
    [savePanel beginSheetForDirectory:NSHomeDirectory()
				 file:@"Mosaic.jpg"
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


- (IBAction)setExportWidthFromHeight:(id)sender
{
    [exportWidth setIntValue:[exportHeight intValue] / [[[self document] originalImage] size].height * 
							 [[[self document] originalImage] size].width + 0.5];
}


- (IBAction)setExportHeightFromWidth:(id)sender
{
    [exportHeight setIntValue:[exportWidth intValue] / [[[self document] originalImage] size].width * 
							  [[[self document] originalImage] size].height + 0.5];
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
}


- (void)exportImage:(NSString *)exportFilename
{
    NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	NSString			*exportError = nil;
	
		// Don't usurp the main thread.
	[NSThread setThreadPriority:0.1];

    NSImage		*exportImage = [[NSImage alloc] initWithSize:NSMakeSize([exportWidth intValue], [exportHeight intValue])];
	[exportImage setCachedSeparately:YES];
//	[exportImage setCacheMode:NSImageCacheNever];
	NS_DURING
		[exportImage lockFocus];
	NS_HANDLER
		exportError = [NSString stringWithFormat:@"Could not draw images into mosaic.  (%@)", [localException reason]];
	NS_ENDHANDLER
	
    NSAffineTransform	*transform = [NSAffineTransform transform];
    [transform scaleXBy:[exportImage size].width yBy:[exportImage size].height];
	
	unsigned long		tileCount = [[[self document] tiles] count],
						tilesExported = 0;
	
	NSEnumerator		*tileEnumerator = [[[self document] tiles] objectEnumerator];
	MacOSaiXTile		*tile = nil;
	while (tile = [tileEnumerator nextObject])
    {
        NSAutoreleasePool	*pool2 = [[NSAutoreleasePool alloc] init];
        NSBezierPath		*clipPath = [transform transformBezierPath:[tile outline]];
        
        tilesExported++;
        [NSGraphicsContext saveGraphicsState];
        [clipPath addClip];
		
			// Get the image in use by this tile.
		MacOSaiXImageMatch	*match = [tile displayedImageMatch];
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
		
			// Clean up
        [NSGraphicsContext restoreGraphicsState];
        [pool2 release];
		
		[self setProgressPercentComplete:[NSNumber numberWithDouble:(tilesExported / tileCount * 100.0)] ];
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
		;	// TODO: need to drop a sheet on the main thread...
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
							   withObject:nil 
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


- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
    float	aspectRatio = [[[self document] originalImage] size].width / [[[self document] originalImage] size].height,
			windowTop = [sender frame].origin.y + [sender frame].size.height,
			minHeight = 413;
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
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXOriginalImageDidChangeNotification object:[self document]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXDocumentDidChangeStateNotification object:[self document]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTileShapesDidChangeStateNotification object:[self document]];
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
		
    if (aTableView == editorTable)
		return 0;	// TODO: (selectedTile == nil ? 0 : [selectedTile matchCount]);
	
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
				// TODO: append attributed string
				return descriptor;
			}
			else
				return nil;
		}
    }
    else if (aTableView == editorTable)
    {
		NSImage	*image = nil;
		
		if (selectedTile)
		{
			image = [selectedTileImages objectAtIndex:rowIndex];
			if ([image isKindOfClass:[NSNull class]] && rowIndex != -1)
			{
				image = [self createEditorImage:rowIndex];
				[selectedTileImages replaceObjectAtIndex:rowIndex withObject:image];
			}
		}
		
		return image;
    }
	else
		return nil;
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


#pragma mark


- (void)dealloc
{
	NSLog(@"Dealloc'ing window controller");
	
	[selectedTile release];
    [selectedTileImages release];
    [toolbarItems release];
    [removedSubviews release];
    [zoomToolbarMenuItem release];
    [viewToolbarMenuItem release];
    [tileImages release];
    
	[tileShapesEditor release];
	[tileShapesBeingEdited release];
	
		// We are responsible for releasing any top-level objects in the nib file that we opened.
	// ???
	
    [super dealloc];
}


@end
