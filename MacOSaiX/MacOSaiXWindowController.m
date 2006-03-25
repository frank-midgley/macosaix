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
#import "MacOSaiXFullScreenController.h"
#import "MacOSaiXPopUpImageView.h"
#import "MacOSaiXWarningController.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"

#import <Carbon/Carbon.h>
#import <unistd.h>
#import <pthread.h>


#define	kMatchingMenuItemTag	1
#define kOriginalImageItemTag	2
#define kAddImageSourceItemTag	3


@interface MacOSaiXWindowController (PrivateMethods)
- (IBAction)setOriginalImageFromMenu:(id)sender;
- (void)populateOriginalImagesMenus;
- (void)mosaicDidChangeState:(NSNotification *)notification;
- (void)synchronizeMenus;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
@end


@implementation MacOSaiXWindowController


- (id)initWithWindow:(NSWindow *)window
{
    if (self = [super initWithWindow:window])
    {
		statusBarShowing = YES;
	}
	
    return self;
}


- (NSString *)windowNibName
{
    return @"MacOSaiXDocument";
}


- (void)populateOriginalImagesMenus
{
	if (!originalImagePopUpView)
		originalImagePopUpView = [[MacOSaiXPopUpImageView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 44.0, 32.0)];
	
		// Remove the previous original items from the main menu.
	NSMenu			*mainOriginalsMenu = [[mosaicMenu itemWithTag:kOriginalImageItemTag] submenu];
	while ([mainOriginalsMenu numberOfItems] > 4)
		[mainOriginalsMenu removeItemAtIndex:2];

	NSMenu			*originalsMenu = [[NSMenu alloc] initWithTitle:@"Original Images"];
	NSEnumerator	*originalEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Recent Originals"] reverseObjectEnumerator];
	NSDictionary	*originalDict = nil;
	while (originalDict = [originalEnumerator nextObject])
	{
		NSString	*originalImagePath = [originalDict objectForKey:@"Path"];
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:originalImagePath])
		{
			NSMenuItem	*originalItem = [[[NSMenuItem alloc] init] autorelease];
			[originalItem setTitle:[originalDict objectForKey:@"Name"]];
			[originalItem setRepresentedObject:originalImagePath];
			[originalItem setTarget:self];
			[originalItem setAction:@selector(setOriginalImageFromMenu:)];
			NSImage		*thumbnail = [[[NSImage alloc] initWithData:[originalDict objectForKey:@"Thumbnail Data"]] autorelease];
			[originalItem setImage:thumbnail];
			[originalsMenu insertItem:originalItem atIndex:0];
			[mainOriginalsMenu insertItem:[[originalItem copy] autorelease] atIndex:2];
		}
	}
	// TODO: add "choose new" item
	
	[originalImagePopUpView setMenu:originalsMenu];
	
	[originalsMenu release];
}


- (void)awakeFromNib
{
    viewMenu = [[NSApp delegate] valueForKey:@"viewMenu"];
    mosaicMenu = [[NSApp delegate] valueForKey:@"mosaicMenu"];

		// set up the toolbar
	[self populateOriginalImagesMenus];
    zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:@"Zoom" action:nil keyEquivalent:@""];
    [zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    toolbarItems = [[NSMutableDictionary dictionary] retain];
    NSToolbar   *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [[self window] setToolbar:toolbar];
    
		// Make sure we have the latest and greatest list of plug-ins.
	[[NSApp delegate] discoverPlugIns];

	{
		// Set up the settings drawer
		
//		[[self mosaic] setTileShapes:[[[NSClassFromString(@"MacOSaiXRectangularTileShapes") alloc] init] autorelease]];
		
			// Fill in the description of the current tile shapes.
			// TBD: move description to toolbar icon's tooltip?
//		id	tileShapesDescription = [[[self mosaic] tileShapes] briefDescription];
//		if ([tileShapesDescription isKindOfClass:[NSString class]])
//			[tileShapesDescriptionField setStringValue:tileShapesDescription];
//		else if ([tileShapesDescription isKindOfClass:[NSAttributedString class]])
//			[tileShapesDescriptionField setAttributedStringValue:tileShapesDescription];
//		else if ([tileShapesDescription isKindOfClass:[NSString class]])
//		{
//			NSTextAttachment	*imageTA = [[[NSTextAttachment alloc] init] autorelease];
//			[(NSTextAttachmentCell *)[imageTA attachmentCell] setImage:tileShapesDescription];
//			[tileShapesDescriptionField setAttributedStringValue:[NSAttributedString attributedStringWithAttachment:imageTA]];
//		}
//		else
//			[tileShapesDescriptionField setStringValue:@"No description available"];
		
			// Set up the "Image Sources" 
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
			NSBundle		*plugInBundle = [NSBundle bundleForClass:imageSourceClass];
			NSString		*plugInName = [plugInBundle objectForInfoDictionaryKey:@"CFBundleName"];
			[imageSourcesPopUpButton addItemWithTitle:[NSString stringWithFormat:@"%@...", plugInName]];
			[[imageSourcesPopUpButton lastItem] setRepresentedObject:imageSourceClass];
			
			NSImage	*image = [[[imageSourceClass image] copy] autorelease];
			[image setScalesWhenResized:YES];
			if ([image size].width > [image size].height)
				[image setSize:NSMakeSize(16.0, 16.0 * [image size].height / [image size].width)];
			else
				[image setSize:NSMakeSize(16.0 * [image size].width / [image size].height, 16.0)];
			[image lockFocus];	// force the image to be scaled
			[image unlockFocus];
			[[imageSourcesPopUpButton lastItem] setImage:image];
		}
	}
	
	[mosaicScrollView setDrawsBackground:NO];
	[[mosaicScrollView contentView] setDrawsBackground:NO];
	[mosaicView setMosaic:[self mosaic]];
	[mosaicView setOriginalFadeTime:0.5];
	
		// For some reason IB insists on setting the drawer width to 200.  Have to set the size in code instead.
	[imageSourcesDrawer setContentSize:NSMakeSize(250, [imageSourcesDrawer contentSize].height)];
	[imageSourcesDrawer open:self];
    
	[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
	if ([[self document] fileName])
	{
		[pauseToolbarItem setLabel:@"Resume"];
		[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Resume Matching"];
	}
	else
	{
		[pauseToolbarItem setLabel:@"Start Mosaic"];
		[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:@"Start Mosaic"];
		
			// Default to the most recently used original or prompt to choose one
			// if no previous original was found.
		if ([[originalImagePopUpView menu] numberOfItems] == 0)
			[self performSelector:@selector(chooseOriginalImage:) withObject:self afterDelay:0.0];
		else
			[self setOriginalImageFromMenu:[[originalImagePopUpView menu] itemAtIndex:0]];
	}
	
	[self mosaicDidChangeState:nil];
}


#pragma mark
#pragma mark Original image management


- (IBAction)setOriginalImageFromMenu:(id)sender
{
	if (![[self mosaic] originalImage] ||
		![[self mosaic] wasStarted] || 
		![MacOSaiXWarningController warningIsEnabled:@"Changing Original Image"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Changing Original Image" 
												title:@"Do you wish to change the original image?" 
											  message:@"All work in the current mosaic will be lost." 
										 buttonTitles:[NSArray arrayWithObjects:@"Change", @"Cancel", nil]] == 0)
	{
		NSString	*originalImagePath = [sender representedObject];
		[[self document] setOriginalImagePath:originalImagePath];
		
		NSImage		*originalImage = [[NSImage alloc] initWithContentsOfFile:originalImagePath];
		[[self mosaic] setOriginalImage:originalImage];
		[originalImage release];
	}
}


- (IBAction)chooseOriginalImage:(id)sender
{
		// Prompt the user to choose an image from which to make a mosaic.
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


- (void)chooseOriginalImagePanelDidEnd:(NSOpenPanel *)sheet 
							returnCode:(int)returnCode
						   contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		NSString	*originalImagePath = [[sheet filenames] objectAtIndex:0];
		[[self document] setOriginalImagePath:originalImagePath];
		
		NSImage		*originalImage = [[NSImage alloc] initWithContentsOfFile:originalImagePath];
		[[self mosaic] setOriginalImage:originalImage];
		[originalImage release];
	}
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
		NSImage			*originalImage = [[self mosaic] originalImage];
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
		[thumbnailImage release];
		
			// Set the image in the toolbar item.
		[originalImagePopUpView setImage:originalImage];
		
			// Set the zoom so that all of the new image is displayed.
		[zoomSlider setFloatValue:0.0];
		[self setZoom:self];
		
		[self mosaicDidChangeState:nil];
		
			// Create the toolbar icons for the View Original/View Mosaic item.  Toolbar item images 
			// must be 32x32 so we center the thumbnail in an image of the correct size.
		[originalToolbarImage release];
		float	scaledWidth = [originalImage size].width * 16.0 / [originalImage size].height;
		originalToolbarImage = [[NSImage alloc] initWithSize:NSMakeSize(scaledWidth, 16.0)];
		[originalToolbarImage lockFocus];
			[originalImage drawInRect:NSMakeRect(0.0, 0.0, scaledWidth, 16.0) 
							 fromRect:NSZeroRect 
							operation:NSCompositeCopy 
							 fraction:1.0];
		[originalToolbarImage unlockFocus];
			// Create a version that looks like a 4x4 mosaic.
		[mosaicToolbarImage release];
		mosaicToolbarImage = [originalToolbarImage copy];
		NSSize	thumbSize = [originalToolbarImage size];
		[mosaicToolbarImage lockFocus];
			float	quarterWidth = thumbSize.width / 4.0,
					quarterHeight = thumbSize.height / 4.0,
					xStart = 0.0,
					yStart = 0.0;
			if (thumbSize.width > thumbSize.height)
				yStart = (16.0 - thumbSize.height) / 2.0;
			else
				xStart = (scaledWidth - thumbSize.width) / 2.0;
			
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
		[fadeOriginalButton setImage:originalToolbarImage];
		[fadeMosaicButton setImage:mosaicToolbarImage];
		
			// Resize the window to respect the original image's aspect ratio
		NSSize		currentWindowSize = [[self window] frame].size;
		windowResizeTargetSize = [self windowWillResize:[self window] toSize:currentWindowSize];
		windowResizeStartTime = [[NSDate date] retain];
		windowResizeDifference = NSMakeSize(windowResizeTargetSize.width - currentWindowSize.width,
											windowResizeTargetSize.height - currentWindowSize.height);
		[NSTimer scheduledTimerWithTimeInterval:0.01 
										 target:self 
									   selector:@selector(animateWindowResize:) 
									   userInfo:nil 
										repeats:YES];
	}
}


- (void)animateWindowResize:(NSTimer *)timer
{
	float	resizePhase = [[NSDate date] timeIntervalSinceDate:windowResizeStartTime] * 2.0;
	if (resizePhase > 1.0)
		resizePhase = 1.0;
	
	NSSize	newSize = NSMakeSize(windowResizeTargetSize.width - windowResizeDifference.width * (1.0 - resizePhase), 
								 windowResizeTargetSize.height - windowResizeDifference.height * (1.0 - resizePhase));
	NSRect	currentFrame = [[self window] frame];
	
	[[self window] setFrame:NSMakeRect(NSMinX(currentFrame), 
									   NSMinY(currentFrame) + NSHeight(currentFrame) - newSize.height, 
									   newSize.width, 
									   newSize.height)
					display:YES
					animate:NO];
	
	if (resizePhase == 1.0)
	{
		[timer invalidate];
		[windowResizeStartTime release];
		windowResizeStartTime = nil;
	}
}


- (NSImage *)originalImage
{
	return [mosaic originalImage];
}


#pragma mark -
#pragma mark Miscellaneous


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (inMosaic != mosaic)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:[self mosaic]];
		
		[mosaic autorelease];
		mosaic = [inMosaic retain];
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(originalImageDidChange:) 
													 name:MacOSaiXOriginalImageDidChangeNotification 
												   object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeStateNotification 
												   object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeBusyStateNotification 
												   object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileShapesDidChange:) 
													 name:MacOSaiXTileShapesDidChangeStateNotification 
												   object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileImageDidChange:) 
													 name:MacOSaiXTileImageDidChangeNotification 
												   object:[self mosaic]];
	}
}


- (MacOSaiXMosaic *)mosaic
{
	return mosaic;
}


- (void)mosaicDidChangeState:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:notification waitUntilDone:NO];
	else
	{
			// Update the status bar.
		[imagesFoundField setIntValue:[[self mosaic] imagesFound]];
		[statusField setStringValue:[[self mosaic] status]];
		if ([[self mosaic] isBusy])
			[statusProgressIndicator startAnimation:self];
		else
			[statusProgressIndicator stopAnimation:self];
		
			// Update the image sources drawer.
		if ([imageSourcesDrawer state] != NSDrawerClosedState)
			[imageSourcesTableView reloadData];
		
			// Update the menus.
		[self synchronizeMenus];
		
			// Update the toolbar.
		if (![[self mosaic] wasStarted])
		{
			[pauseToolbarItem setLabel:@"Start Mosaic"];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		}
		else if ([[self mosaic] isPaused])
		{
			[pauseToolbarItem setLabel:@"Resume"];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		}
		else
		{
			[pauseToolbarItem setLabel:@"Pause"];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		}
		
			// Start the automatic fade to the mosaic if appropriate.
		if (!fadeTimer && !fadeWasAdjusted && [[self mosaic] allTilesHaveExtractedBitmaps])
			fadeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 
														  target:self 
														selector:@selector(fadeToMosaic:) 
														userInfo:[NSDate date] 
														 repeats:YES] retain];
	}
}



- (void)synchronizeMenus
{
	[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:([[self mosaic] isPaused] ? @"Resume Matching" : @"Pause Matching")];

	[[viewMenu itemWithTag:0] setState:([mosaicView fade] == 0.0 ? NSOnState : NSOffState)];
	[[viewMenu itemWithTag:1] setState:([mosaicView fade] == 1.0 ? NSOnState : NSOffState)];

	[[viewMenu itemAtIndex:[viewMenu indexOfItemWithTarget:nil andAction:@selector(toggleTileOutlines:)]] setTitle:([mosaicView viewTileOutlines] ? @"Hide Tile Outlines" : @"Show Tile Outlines")];
	[[viewMenu itemAtIndex:[viewMenu indexOfItemWithTarget:nil andAction:@selector(toggleStatusBar:)]] setTitle:(statusBarShowing ? @"Hide Status Bar" : @"Show Status Bar")];
}


- (void)tileImageDidChange:(NSNotification *)notification
{
	// TODO: update the "choose image" sheet if it's displaying the changed tile
}


#pragma mark -
#pragma mark Tiles setup


- (IBAction)setupTiles:(id)sender
{
	if (![[self mosaic] wasStarted] || 
		![MacOSaiXWarningController warningIsEnabled:@"Changing Tiles Setup"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Changing Tiles Setup" 
												title:@"Do you wish to change the tiles setup?" 
											  message:@"All work in the current mosaic will be lost." 
										 buttonTitles:[NSArray arrayWithObjects:@"Change", @"Cancel", nil]] == 0)
	{
		if (!tilesSetupController)
			tilesSetupController = [[MacOSaiXTilesSetupController alloc] initWithWindow:nil];
		
		[tilesSetupController setupTilesForMosaic:[self mosaic] 
								   modalForWindow:[self window] 
									modalDelegate:nil 
								   didEndSelector:nil];
	}
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	// TBD: Set toolbar icon's tooltip?  And handle non-string values like awakeFromNib does?
	NSImage	*shapesImage = [[[self mosaic] tileShapes] image];
	[setupTilesToolbarItem setImage:(shapesImage ? shapesImage : [NSImage imageNamed:@"Tiles Setup"])];
	
	if (selectedTile)
		[self selectTileAtPoint:tileSelectionPoint];
	
	[self mosaicDidChangeState:nil];
}


#pragma mark -
#pragma mark Image Sources methods


- (void)editImageSourceInSheet:(id<MacOSaiXImageSource>)originalImageSource
{
	id<MacOSaiXImageSource>				editableSource = [[originalImageSource copyWithZone:[self zone]] autorelease];
	
	imageSourceEditorController = [[[[originalImageSource class] editorClass] alloc] init];
	
		// Make sure the panel is big enough to contain the view's minimum size.
	float	widthDiff = MAX(0.0, [imageSourceEditorController minimumSize].width - [[imageSourceEditorBox contentView] frame].size.width),
			heightDiff = MAX(0.0, [imageSourceEditorController minimumSize].height - [[imageSourceEditorBox contentView] frame].size.height);
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
	[imageSourceEditorPanel setInitialFirstResponder:(NSView *)[imageSourceEditorController firstResponder]];
	NSView	*lastKeyView = (NSView *)[imageSourceEditorController firstResponder];
	while ([lastKeyView nextKeyView] && 
			[[lastKeyView nextKeyView] isDescendantOf:[imageSourceEditorController editorView]] &&
			[lastKeyView nextKeyView] != [imageSourceEditorController firstResponder])
		lastKeyView = [lastKeyView nextKeyView];
	[lastKeyView setNextKeyView:imageSourceEditorCancelButton];
	[imageSourceEditorOKButton setNextKeyView:(NSView *)[imageSourceEditorController firstResponder]];
	
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
		[self editImageSourceInSheet:[[[self mosaic] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]]];
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
		[[self mosaic] removeImageSource:originalImageSource];
		[[self mosaic] addImageSource:editedImageSource];
		
		[imageSourcesTableView reloadData];
	}
	
	[imageSourceEditorController editImageSource:nil];
	[imageSourceEditorController release];
	imageSourceEditorController = nil;
	[(id)contextInfo release];
}


- (IBAction)removeImageSource:(id)sender
{
	if (![MacOSaiXWarningController warningIsEnabled:@"Removing Image Source"] || 
		[MacOSaiXWarningController runAlertForWarning:@"Removing Image Source" 
												title:@"Are you sure you wish to remove the selected image source?" 
											  message:@"Tiles that were displaying images from this source may no longer have an image." 
										 buttonTitles:[NSArray arrayWithObjects:@"Remove", @"Cancel", nil]] == 0)
	{
		id<MacOSaiXImageSource>	imageSource = [[[self mosaic] imageSources] objectAtIndex:[imageSourcesTableView selectedRow]];
		
		[[self mosaic] removeImageSource:imageSource];
		[[MacOSaiXImageCache sharedImageCache] removeCachedImagesFromSource:imageSource];
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
	NSEnumerator	*tileEnumerator = [[[self mosaic] tiles] objectEnumerator];
	MacOSaiXTile	*tile = nil;
	while (tile = [tileEnumerator nextObject])
        if ([[tile outline] containsPoint:thePoint])
        {
			if (tile == selectedTile)
			{
				if ([[NSApp currentEvent] clickCount] == 1)
				{
						// The selected tile was clicked so unselect it.
					[selectedTile autorelease];
					selectedTile = nil;
					
						// Get rid of the timer when no tile is selected.
					[animateTileTimer invalidate];
					[animateTileTimer release];
					animateTileTimer = nil;
				}
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
				
				[selectedTile autorelease];
				selectedTile = [tile retain];
			}
			
			[mosaicView highlightTile:selectedTile];
			
			break;
        }

	if ([[NSApp currentEvent] clickCount] == 2)
		[self chooseImageForSelectedTile:self];
}


- (void)animateSelectedTile:(id)timer
{
    if (![(MacOSaiXDocument *)[self document] isClosing])
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
						originalSize = [[[self mosaic] originalImage] size], 
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
		NSImage			*originalImage = [[self mosaic] originalImage];
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
	MacOSaiXImageMatch	*currentMatch = [selectedTile displayedImageMatch];
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
	if ([oPanel respondsToSelector:@selector(setMessage:)])
		[oPanel setMessage:@"Choose an image to be displayed in this tile:"];
	[oPanel setPrompt:@"Choose"];
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
			// This shouldn't be necessary but updating the views right away often crashes 
			// because of some interaction with the AppKit thread that is creating a preview 
			// of the selected image.
		[self performSelector:@selector(updateUserChosenViewsForImageAtPath:) withObject:[[sender filenames] objectAtIndex:0] afterDelay:0.0];
	}
}


- (void)updateUserChosenViewsForImageAtPath:(NSString *)imagePath
{
	NSString			*chosenImageIdentifier = imagePath;
	[editorChosenImageBox setTitle:[[NSFileManager defaultManager] displayNameAtPath:chosenImageIdentifier]];
	
	NSImage				*chosenImage = [[[NSImage alloc] initWithContentsOfFile:chosenImageIdentifier] autorelease];
	[chosenImage setCachedSeparately:YES];
	[chosenImage setCacheMode:NSImageCacheNever];
	
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
		editorChosenMatchValue = [[MacOSaiXImageMatcher sharedMatcher] compareImageRep:[selectedTile bitmapRep]  
																			  withMask:[selectedTile maskRep] 
																			toImageRep:chosenImageRep
																		  previousBest:1.0];
		[editorChosenMatchQualityTextField setStringValue:[NSString stringWithFormat:@"%.0f%%", 100.0 - editorChosenMatchValue * 100.0]];
	}
}


- (void)chooseImageForSelectedTilePanelDidEnd:(NSOpenPanel *)sheet 
								   returnCode:(int)returnCode
							      contextInfo:(void *)context
{
    if (returnCode == NSOKButton)
	{
		[[self mosaic] setHandPickedImageAtPath:[[sheet filenames] objectAtIndex:0]
								 withMatchValue:editorChosenMatchValue
										forTile:selectedTile];
		[imageSourcesTableView reloadData];
	}
	
	if ([sheet respondsToSelector:@selector(setMessage:)])
		[sheet setMessage:@""];
}


- (IBAction)removeChosenImageForSelectedTile:(id)sender
{
	if (selectedTile)
		[[self mosaic] removeHandPickedImageForTile:selectedTile];
}


#pragma mark -
#pragma mark View methods


- (IBAction)setViewOriginalImage:(id)sender
{
	[mosaicView setFade:0.0];
	[fadeSlider setFloatValue:0.0];
	
	fadeWasAdjusted = YES;
	
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = nil;
	
	[[viewMenu itemWithTag:0] setState:NSOnState];
	[[viewMenu itemWithTag:1] setState:NSOffState];
}


- (IBAction)setViewMosaic:(id)sender
{
	[mosaicView setFade:1.0];
	[fadeSlider setFloatValue:1.0];
	
	fadeWasAdjusted = YES;
	
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = nil;
	
	[[viewMenu itemWithTag:0] setState:NSOffState];
	[[viewMenu itemWithTag:1] setState:NSOnState];
}


- (IBAction)setViewFade:(id)sender
{
	fadeWasAdjusted = YES;
	
	[fadeTimer invalidate];
	[fadeTimer release];
	fadeTimer = nil;
	
	[mosaicView setFade:[fadeSlider floatValue]];
}


- (BOOL)viewingOriginal
{
	return ([mosaicView fade] == 0.0);
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
    else
		zoom = [zoomSlider floatValue];
    
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
	[mosaicView setInLiveRedraw:[NSNumber numberWithBool:YES]];
}


- (IBAction)setMinimumZoom:(id)sender;
{
	[zoomSlider setFloatValue:[zoomSlider minValue]];
	[self setZoom:self];
}


- (IBAction)setMaximumZoom:(id)sender
{
	[zoomSlider setFloatValue:[zoomSlider maxValue]];
	[self setZoom:self];
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
    [imageSourcesDrawer toggle:(id)sender];
    if ([imageSourcesDrawer state] == NSDrawerClosedState)
		[[viewMenu itemWithTitle:@"Show Image Sources"] setTitle:@"Hide Image Sources"];
    else
		[[viewMenu itemWithTitle:@"Hide Image Sources"] setTitle:@"Show Image Sources"];
}


- (IBAction)viewFullScreen:(id)sender
{
		// Hide the menu bar and dock if we're on the main screen.
	NSScreen	*windowScreen = [[self window] screen], 
				*menuBarScreen = [[NSScreen screens] objectAtIndex:0];
	if (windowScreen == menuBarScreen)
	{
		OSStatus	status = SetSystemUIMode(kUIModeAllHidden, 0);
		if (status == noErr)
			NSLog(@"Could not enter full screen mode");
	}
	
		// Open a new borderless window displaying just the mosaic.
	MacOSaiXFullScreenController	*controller = [(MacOSaiX *)[NSApp delegate] openMosaicWindowOnScreen:windowScreen];
 	[controller setMosaicView:mosaicView];
	[controller setClosesOnKeyPress:YES];
	[controller retain];
	[mosaicView retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(fullScreenWindowDidClose:) 
												 name:NSWindowWillCloseNotification 
											   object:[controller window]];
	[[self window] orderOut:self];
}


- (void)fullScreenWindowDidClose:(NSNotification *)notification
{
		// Switch back to the document window.
	[mosaicScrollView setDocumentView:mosaicView];
	[mosaicView release];
	[[(NSWindow *)[notification object] windowController] release];
	[self setZoom:self];
	[[self window] orderFront:self];
	
		// Restore the menu bar and dock if we're on the main screen.
	NSScreen	*windowScreen = [[self window] screen], 
				*menuBarScreen = [[NSScreen screens] objectAtIndex:0];
	if (windowScreen == menuBarScreen)
		SetSystemUIMode(kUIModeNormal, 0);
}


- (void)setBackgroundMode:(MacOSaiXBackgroundMode)mode
{
	[mosaicView setBackgroundMode:mode];
}


- (MacOSaiXBackgroundMode)backgroundMode
{
	return [mosaicView backgroundMode];
}


- (IBAction)setBackground:(id)sender
{
	if ([sender isKindOfClass:[NSMenuItem class]])
		[mosaicView setBackgroundMode:[(NSMenuItem *)sender tag]];
}


#pragma mark -
#pragma mark Utility methods


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL		actionToValidate = [menuItem action];
	BOOL	valid = YES;
	
    if (actionToValidate == @selector(chooseImageForSelectedTile:))
		valid = (selectedTile != nil);
	else if (actionToValidate == @selector(removeChosenImageForSelectedTile:))
		valid = (selectedTile != nil && [selectedTile userChosenImageMatch]);
    else if (actionToValidate == @selector(centerViewOnSelectedTile:))
		valid = (selectedTile != nil && zoom != 0.0);
    else if (actionToValidate == @selector(togglePause:))
		valid = ([[[self mosaic] imageSources] count] > 0);
	else if (actionToValidate == @selector(setBackground:))
		[menuItem setState:([menuItem tag] == [mosaicView backgroundMode] ? NSOnState : NSOffState)];

	return valid;
}


- (void)fadeToMosaic:(NSTimer *)timer
{
	float	fade = ([[NSDate date] timeIntervalSinceDate:[timer userInfo]] / 10.0);
	[mosaicView setFade:MIN(fade, 1.0)];
	[fadeSlider setFloatValue:[mosaicView fade]];
	
	fadeWasAdjusted = YES;
	
	if ([mosaicView fade] == 1.0)
	{
		[fadeTimer invalidate];
		[fadeTimer release];
		fadeTimer = nil;
	}
}


- (void)togglePause:(id)sender
{
	if ([[self mosaic] isPaused])
		[[self mosaic] resume];
	else
		[[self mosaic] pause];
}


#pragma mark -
#pragma mark Save As methods


- (void)saveMosaicAs:(id)sender
{
		// Disable auto saving so it doesn't interfere with saving.
	[(MacOSaiXDocument *)[self document] setAutoSaveEnabled:NO];

	if (!exportController)
		exportController = [[MacOSaiXExportController alloc] init];
	
	[exportController exportMosaic:[self mosaic]
						  withName:[[[[self document] displayName] lastPathComponent] stringByDeletingPathExtension] 
						mosaicView:mosaicView 
					modalForWindow:[self window] 
					 modalDelegate:self 
				  progressSelector:@selector(saveAsDidProgress:message:) 
					didEndSelector:@selector(saveAsDidComplete:)];
}


- (void)saveAsDidProgress:(NSNumber *)percentComplete message:(NSString *)message
{
	[self performSelectorOnMainThread:@selector(updateSaveAsProgress:) 
						   withObject:[NSArray arrayWithObjects:percentComplete, message, nil] 
						waitUntilDone:NO];
}


- (void)updateSaveAsProgress:(NSArray *)parameters
{
	if ([[self window] attachedSheet] != progressPanel)
		[self displayProgressPanelWithMessage:[parameters objectAtIndex:1]];
	else
		[self setProgressMessage:[parameters objectAtIndex:1]];
	
	[self setProgressPercentComplete:[parameters objectAtIndex:0]];
}


- (void)saveAsDidComplete:(NSString *)errorString
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:errorString waitUntilDone:NO];
	else
	{
		NSString	*exportFormat = [exportController exportFormat];
		if (!exportFormat)
			exportFormat = @"html";
		[saveAsToolbarItem setImage:[[NSWorkspace sharedWorkspace] iconForFileType:exportFormat]];
		
		[self closeProgressPanel];
		
		if (errorString)
			NSBeginAlertSheet(@"The mosaic could not be saved.", @"OK", nil, nil, [self window], 
							  self, nil, @selector(errorSheetDidDismiss:), nil, errorString);
		else
			[(MacOSaiXDocument *)[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
	}
}


- (void)errorSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[(MacOSaiXDocument *)[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
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
		double	percent = [percentComplete doubleValue];
		[progressPanelIndicator setIndeterminate:(percent < 0.0 || percent > 100.0)];
		[progressPanelIndicator setDoubleValue:percent];
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
		float	aspectRatio = [[[self mosaic] originalImage] size].width / [[[self mosaic] originalImage] size].height,
				windowTop = NSMaxY([resizingWindow frame]), 
				minHeight = 200;	// TODO: get this from nib setting
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
		
		proposedFrameSize.height += diff.height;
		proposedFrameSize.width += diff.width;
	}
	else if (resizingWindow == imageSourceEditorPanel)
	{
//		NSSize	panelSize = [imageSourceEditorPanel frame].size,
//				editorBoxSize = [[imageSourceEditorBox contentView] frame].size;
//		float	minWidth = (panelSize.width - editorBoxSize.width) + [imageSourceEditorController minimumSize].width,
//				minHeight = (panelSize.height - editorBoxSize.height) + [imageSourceEditorController minimumSize].height;
//		
//		proposedFrameSize.width = MAX(proposedFrameSize.width, minWidth);
//		proposedFrameSize.height = MAX(proposedFrameSize.height, minHeight);
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
		[self setZoom:self];
	}
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXOriginalImageDidChangeNotification object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXMosaicDidChangeStateNotification object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTileShapesDidChangeStateNotification object:[self mosaic]];
		
		if ([fadeTimer isValid])
			[fadeTimer invalidate];
	}
}


#pragma mark -
#pragma mark Toolbar delegate methods


- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag;
{
    NSToolbarItem	*toolbarItem = [toolbarItems objectForKey:itemIdentifier];

    if (toolbarItem)
		return toolbarItem;
    
    toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier] autorelease];
    
	if ([itemIdentifier isEqualToString:@"Original Image"])
    {
		[toolbarItem setMinSize:NSMakeSize(44.0, 32.0)];
		[toolbarItem setMaxSize:NSMakeSize(44.0, 32.0)];
		[toolbarItem setLabel:@"Original Image"];
		[toolbarItem setPaletteLabel:@"Original Image"];
		[toolbarItem setView:originalImagePopUpView];
// TODO:		[toolbarItem setMenuFormRepresentation:[originalImagePopUpButton menu]];
    }
	else if ([itemIdentifier isEqualToString:@"Setup Tiles"])
    {
		NSImage	*shapesImage = [[[self mosaic] tileShapes] image];
		if (shapesImage)
			[toolbarItem setImage:shapesImage];
		[toolbarItem setLabel:@"Setup Tiles"];
		[toolbarItem setPaletteLabel:@"Setup Tiles"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(setupTiles:)];
		[toolbarItem setToolTip:@"Change the tile shapes or image use rules"];
		setupTilesToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Full Screen"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"FullScreen"]];
		[toolbarItem setLabel:@"Full Screen"];
		[toolbarItem setPaletteLabel:@"Full Screen"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewFullScreen:)];
		[toolbarItem setToolTip:@"View the mosaic in full screen mode"];
    }
	else if ([itemIdentifier isEqualToString:@"Save As"])
    {
		[toolbarItem setImage:[[NSWorkspace sharedWorkspace] iconForFileType:@"jpg"]];
		[toolbarItem setLabel:@"Save As"];
		[toolbarItem setPaletteLabel:@"Save As"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(saveMosaicAs:)];
		[toolbarItem setToolTip:@"Save the mosaic as an image or web page"];
		saveAsToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Pause"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[toolbarItem setLabel:[[self mosaic] isPaused] ? @"Resume" : @"Pause"];
		[toolbarItem setPaletteLabel:[[self mosaic] isPaused] ? @"Resume" : @"Pause"];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(togglePause:)];
		pauseToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Image Sources"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"ImageSources"]];
		[toolbarItem setLabel:@"Image Sources"];
		[toolbarItem setPaletteLabel:@"Image Sources"];
		[toolbarItem setTarget:imageSourcesDrawer];
		[toolbarItem setAction:@selector(toggle:)];
		[toolbarItem setToolTip:@"Show/hide image sources"];
    }
	else if ([itemIdentifier isEqualToString:@"Fade"])
    {
		[toolbarItem setMinSize:[fadeToolbarView frame].size];
		[toolbarItem setMaxSize:[fadeToolbarView frame].size];
		[toolbarItem setLabel:@"Fade"];
		[toolbarItem setPaletteLabel:@"Fade"];
		[toolbarItem setView:fadeToolbarView];
// TODO:		[toolbarItem setMenuFormRepresentation:zoomToolbarMenuItem];
    }
    else if ([itemIdentifier isEqualToString:@"Zoom"])
    {
		[toolbarItem setMinSize:[zoomToolbarView frame].size];
		[toolbarItem setMaxSize:[zoomToolbarView frame].size];
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
		return ([[[self mosaic] tiles] count] > 0 && [[[self mosaic] imageSources] count] > 0);
    else
		return YES;
}


- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Original Image", @"Setup Tiles", @"Full Screen", @"Fade", @"Zoom", 
									 @"Save As", @"Pause", @"Image Sources", 
									 NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSpaceItemIdentifier,
									 NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier,
									 nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Original Image", @"Setup Tiles", @"Fade", @"Zoom", @"Pause", 
									 NSToolbarFlexibleSpaceItemIdentifier, @"Image Sources", nil];
}


#pragma mark -
#pragma mark Table delegate methods


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    if (aTableView == imageSourcesTableView)
		return [[[self mosaic] imageSources] count];
	
	return 0;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
    if (aTableView == imageSourcesTableView)
    {
		id<MacOSaiXImageSource>	imageSource = [[[self mosaic] imageSources] objectAtIndex:rowIndex];
		
		if ([[aTableColumn identifier] isEqualToString:@"Image Source Type"])
			return [imageSource image];
		else
		{
				// TBD: this won't work once entries get removed from the dictionary...
			long	imageCount = [[self mosaic] countOfImagesFromSource:imageSource];
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
		NSMutableArray	*selectedImageSources = [NSMutableArray array];
		NSEnumerator	*selectedRowNumberEnumerator = [imageSourcesTableView selectedRowEnumerator];
		NSNumber		*selectedRowNumber = nil;
		while (selectedRowNumber = [selectedRowNumberEnumerator nextObject])
		{
			int	rowIndex = [selectedRowNumber intValue];
			[selectedImageSources addObject:[[[self mosaic] imageSources] objectAtIndex:rowIndex]];
		}
		
		[imageSourcesRemoveButton setEnabled:([selectedImageSources count] > 0)];
		
		if ([[[self mosaic] imageSources] count] > 1)
			[mosaicView highlightImageSources:selectedImageSources];
		else
			[mosaicView highlightImageSources:nil];
	}
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
    
	[tilesSetupController release];
	[exportController release];
	
	if ([fadeTimer isValid])
		[fadeTimer invalidate];
	[fadeTimer release];
	
    [super dealloc];
}


@end
