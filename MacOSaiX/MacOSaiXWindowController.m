/*
	MacOSaiXWindowController.m
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXWindowController.h"

#import "MacOSaiX.h"
#import "MacOSaiXEditorsView.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXExportController.h"
#import "MacOSaiXImageCache.h"
#import "MacOSaiXImageMatcher.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXFullScreenController.h"
#import "MacOSaiXPopUpButton.h"
//#import "MacOSaiXTileEditor.h"
#import "MacOSaiXTileShapes.h"
//#import "MacOSaiXTilesSetupController.h"
#import "MacOSaiXWarningController.h"
#import "MosaicView.h"
#import "NSImage+MacOSaiX.h"
#import "NSString+MacOSaiX.h"
#import "Tiles.h"

#import "MacOSaiXImageOrientationsEditor.h"
#import "MacOSaiXImageSourcesEditor.h"
#import "MacOSaiXImageUsageEditor.h"
#import "MacOSaiXTargetImageEditor.h"
#import "MacOSaiXTileShapesEditor.h"
#import "MacOSaiXTileEditor.h"

#import <Carbon/Carbon.h>
#import <unistd.h>
#import <pthread.h>


#define	kMatchingMenuItemTag	1
#define kTargetImageItemTag	2
#define kAddImageSourceItemTag	3


NSString	*MacOSaiXRecentTargetImagesDidChangeNotification = @"MacOSaiXRecentTargetImagesDidChangeNotification";


@interface MacOSaiXWindowController (PrivateMethods)
- (void)updateStatus;
- (IBAction)setTargetImageFromMenu:(id)sender;
- (void)updateRecentTargetImages;
- (void)mosaicDidChangeState:(NSNotification *)notification;
- (void)synchronizeMenus;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(MacOSaiXImageMatch *)tileMatch selecting:(BOOL)selecting;
- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)setProgressCancelAction:(SEL)cancelAction;
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


- (void)awakeFromNib
{
    viewMenu = [[NSApp delegate] valueForKey:@"viewMenu"];
    mosaicMenu = [[NSApp delegate] valueForKey:@"mosaicMenu"];

		// set up the toolbar
	targetImageToolbarView = [[MacOSaiXPopUpButton alloc] initWithFrame:NSMakeRect(0.0, 0.0, 44.0, 32.0)];
	[targetImageToolbarView setBordered:NO];
	[targetImageToolbarView setImagePosition:NSImageOnly];
	[targetImageToolbarView setMenu:recentTargetsMenu];
	[targetImageToolbarView setImage:[NSImage imageNamed:@"NoTarget"]];
    zoomToolbarMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Zoom", @"") action:nil keyEquivalent:@""];
    [zoomToolbarMenuItem setSubmenu:zoomToolbarSubmenu];
    toolbarItems = [[NSMutableDictionary dictionary] retain];
    NSToolbar   *toolbar = [[[NSToolbar alloc] initWithIdentifier:@"MacOSaiXDocument"] autorelease];
    [toolbar setDelegate:self];
    [toolbar setAllowsUserCustomization:YES];
    [[self window] setToolbar:toolbar];
    
	[self updateStatus];

	{
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
//			[tileShapesDescriptionField setStringValue:NSLocalizedString(@"No description available", @"")];
	}
	
	[mosaicScrollView setDrawsBackground:NO];
	[[mosaicScrollView contentView] setDrawsBackground:NO];
	[mosaicView setMosaic:[self mosaic]];
	[mosaicView setTargetFadeTime:0.5];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(mosaicViewDidChangeBusyState:) 
												 name:MacOSaiXMosaicViewDidChangeBusyStateNotification 
											   object:mosaicView];
    
	if (![[self document] fileName])
	{
			// Default to the most recently used target or prompt to choose one if no previous target was found.
		NSString	*lastPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"Last Chosen Target Image Path"];
		NSImage		*lastImage = [[NSImage alloc] initWithContentsOfFile:lastPath];
		if (lastImage)
		{
			[[self mosaic] setTargetImagePath:lastPath];
			[[self mosaic] setTargetImage:lastImage];
			[lastImage release];
		}
		else if ([[targetImageToolbarView menu] numberOfItems] > 4)
		{
				// The last chosen image is not available, pick the first recent target in the list.
			[self setTargetImageFromMenu:[[targetImageToolbarView menu] itemAtIndex:2]];
		}
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(recentTargetImagesDidChange:) 
												 name:MacOSaiXRecentTargetImagesDidChangeNotification 
											   object:nil];
	
	mosaicTrackingRectTag = [[[self window] contentView] addTrackingRect:[mosaicScrollView frame] 
																   owner:mosaicView 
																userData:nil 
															assumeInside:NO];
	[[self window] setAcceptsMouseMovedEvents:YES];
	
	[self mosaicDidChangeState:nil];
	
	[editorsView setMosaicView:mosaicView];
	
		// Add the editors.
	targetImageEditor = [[MacOSaiXTargetImageEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:targetImageEditor];
	tileShapesEditor = [[MacOSaiXTileShapesEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:tileShapesEditor];
	imageSourcesEditor = [[MacOSaiXImageSourcesEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:imageSourcesEditor];
	imageUsageEditor = [[MacOSaiXImageUsageEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:imageUsageEditor];
	imageOrientationsEditor = [[MacOSaiXImageOrientationsEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:imageOrientationsEditor];
	tileEditor = [[MacOSaiXTileEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:tileEditor];
}


#pragma mark
#pragma mark Target image management


// TBD: is this needed anymore?
//- (void)targetImageDidChange:(NSNotification *)notification
//{
//	if (!pthread_main_np())
//		[self performSelectorOnMainThread:@selector(targetImageDidChange:) 
//							   withObject:notification 
//							waitUntilDone:YES];
//	else
//	{
//		NSImage			*targetImage = [[self mosaic] targetImage];
//		
//		if (targetImage)
//		{
//			[self window];	// Make sure the nib is loaded.
//			
//			[targetImageToolbarView setImage:targetImage];
//		}
//		
//			// Set the zoom so that all of the new image is displayed.
//		[zoomSlider setFloatValue:0.0];
//		[self setZoom:self];
//		
//		[self mosaicDidChangeState:nil];
//		
//			// Resize the window to respect the target image's aspect ratio
//		NSSize		currentWindowSize = [[self window] frame].size;
//		windowResizeTargetSize = [self windowWillResize:[self window] toSize:currentWindowSize];
//		windowResizeStartTime = [[NSDate date] retain];
//		windowResizeDifference = NSMakeSize(windowResizeTargetSize.width - currentWindowSize.width,
//											windowResizeTargetSize.height - currentWindowSize.height);
//		[mosaicView setInLiveRedraw:[NSNumber numberWithBool:YES]];
//		[NSTimer scheduledTimerWithTimeInterval:0.01 
//										 target:self 
//									   selector:@selector(animateWindowResize:) 
//									   userInfo:nil 
//										repeats:YES];
//	}
//}
//
//
//- (void)animateWindowResize:(NSTimer *)timer
//{
//	float	resizePhase = 1.0;
//	
//	if (windowResizeStartTime)
//	{
//		resizePhase = [[NSDate date] timeIntervalSinceDate:windowResizeStartTime] * 2.0;
//		if (resizePhase > 1.0)
//			resizePhase = 1.0;
//		
//		NSSize	newSize = NSMakeSize(windowResizeTargetSize.width - windowResizeDifference.width * (1.0 - resizePhase), 
//									 windowResizeTargetSize.height - windowResizeDifference.height * (1.0 - resizePhase));
//		NSRect	currentFrame = [[self window] frame];
//		
//		[[self window] setFrame:NSMakeRect(NSMinX(currentFrame), 
//										   NSMinY(currentFrame) + NSHeight(currentFrame) - newSize.height, 
//										   newSize.width, 
//										   newSize.height)
//						display:YES
//						animate:NO];
//	}
//	
//	if (resizePhase == 1.0)
//	{
//		[timer invalidate];
//		[windowResizeStartTime release];
//		windowResizeStartTime = nil;
//		
//		[mosaicView setInLiveRedraw:[NSNumber numberWithBool:NO]];
//	}
//}


#pragma mark -
#pragma mark Miscellaneous


- (void)updateStatus
{
	NSString	*status = @"";
	BOOL		busy = NO;
	
	if (![[self mosaic] targetImage])
		status = NSLocalizedString(@"You have not chosen a target image", @"");
	else if ([[[self mosaic] tiles] count] == 0)
		status = NSLocalizedString(@"You have not set the tile shapes", @"");
	else if ([[[self mosaic] imageSources] count] == 0)
		status = NSLocalizedString(@"You have not added any image sources", @"");
	else if (![[self mosaic] wasStarted] && ![[self mosaic] imageSourcesExhausted])
		status = NSLocalizedString(@"Click the Start button in the toolbar to begin.", @"");
	else if ([[self mosaic] isBusy])
	{
		status = [[self mosaic] busyStatus];
		busy = YES;
	}
	else if ([mosaicView isBusy])
	{
		status = [mosaicView busyStatus];
		busy = YES;
	}
	else if ([[self mosaic] isPaused])
		status = NSLocalizedString(@"Paused", @"");
	[statusField setStringValue:status];
	
	if (busy)
		[statusProgressIndicator startAnimation:self];
	else
		[statusProgressIndicator stopAnimation:self];
	
}


- (void)setMosaic:(MacOSaiXMosaic *)inMosaic
{
	if (inMosaic != mosaic)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mosaic];
		
		[mosaic autorelease];
		mosaic = [inMosaic retain];
		
// TBD: needed anymore?
//		[[NSNotificationCenter defaultCenter] addObserver:self 
//												 selector:@selector(targetImageDidChange:) 
//													 name:MacOSaiXTargetImageDidChangeNotification 
//												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeStateNotification 
												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(mosaicDidChangeState:) 
													 name:MacOSaiXMosaicDidChangeBusyStateNotification 
												   object:mosaic];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(tileShapesDidChange:) 
													 name:MacOSaiXTileShapesDidChangeStateNotification 
												   object:mosaic];
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
		[self updateStatus];
		
			// Update the menus.
		[self synchronizeMenus];
		
			// Update the toolbar.
		if (![[self mosaic] wasStarted])
		{
			[pauseToolbarItem setLabel:NSLocalizedString(@"Start", @"")];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		}
		else if ([[self mosaic] isPaused])
		{
			[pauseToolbarItem setLabel:NSLocalizedString(@"Resume", @"")];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Resume"]];
		}
		else
		{
			[pauseToolbarItem setLabel:NSLocalizedString(@"Pause", @"")];
			[pauseToolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		}
	}
}


- (void)mosaicViewDidChangeBusyState:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:notification waitUntilDone:NO];
	else
		[self updateStatus];
}


- (void)synchronizeMenus
{
	if ([[self mosaic] isPaused])
		[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:NSLocalizedString(@"Resume Matching", @"")];
	else if ([[self mosaic] wasStarted])
		[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:NSLocalizedString(@"Pause Matching", @"")];
	else
		[[mosaicMenu itemWithTag:kMatchingMenuItemTag] setTitle:NSLocalizedString(@"Start Matching", @"")];

	[[viewMenu itemWithTag:0] setState:([mosaicView targetImageFraction] == 0.0 ? NSOnState : NSOffState)];
	[[viewMenu itemWithTag:1] setState:([mosaicView targetImageFraction] == 1.0 ? NSOnState : NSOffState)];

	[[viewMenu itemAtIndex:[viewMenu indexOfItemWithTarget:nil andAction:@selector(toggleStatusBar:)]] 
		setTitle:(statusBarShowing ? NSLocalizedString(@"Hide Status Bar", @"") : 
								     NSLocalizedString(@"Show Status Bar", @""))];
}


#pragma mark -
#pragma mark Tiles setup


- (IBAction)setupTiles:(id)sender
{
//	if (!tilesSetupController)
//		tilesSetupController = [[MacOSaiXTilesSetupController alloc] initWithWindow:nil];
	
//	[tilesSetupController setupTilesForMosaic:[self mosaic] 
//							   modalForWindow:[self window] 
//								modalDelegate:nil 
//							   didEndSelector:nil];
}


- (void)tileShapesDidChange:(NSNotification *)notification
{
	NSImage	*shapesImage = [[[self mosaic] tileShapes] image];
	
	[setupTilesToolbarItem setImage:(shapesImage ? shapesImage : [NSImage imageNamed:@"Tiles Setup"])];
	[setupTilesToolbarItem setToolTip:[[[self mosaic] tileShapes] briefDescription]];
		
	[self mosaicDidChangeState:nil];
}


#pragma mark -
#pragma mark View methods


- (IBAction)setZoom:(id)sender
{
		// Calculate the currently centered point of the mosaic image independent of the zoom factor.
	NSRect	frame = [[mosaicScrollView contentView] frame],
			visibleRect = [mosaicView visibleRect];
	NSPoint	centerPoint = NSMakePoint(NSMidX(visibleRect) / zoom, NSMidY(visibleRect) / zoom);
	
		// Update the zoom factor based on who called this method.
    if ([sender isKindOfClass:[NSMenuItem class]])
		zoom = ([zoomSlider maxValue] - [zoomSlider minValue]) * [sender tag] / 100.0;
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
	[mosaicView performSelector:@selector(setInLiveRedraw:) withObject:[NSNumber numberWithBool:NO] afterDelay:0.0];
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


#pragma mark -
#pragma mark Utility methods


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL		actionToValidate = [menuItem action];
	BOOL	valid = YES;
	
	if (actionToValidate == @selector(togglePause:))
		valid = ([[[self mosaic] imageSources] count] > 0);
	
	return valid;
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
					didEndSelector:@selector(saveAsDidComplete:)];
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
		
		if (errorString)
			NSBeginAlertSheet(NSLocalizedString(@"The mosaic could not be saved.", @""), 
							  NSLocalizedString(@"OK", @""), nil, nil, [self window], 
							  self, nil, @selector(errorSheetDidDismiss:), nil, errorString);
		else
			[(MacOSaiXDocument *)[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
	}
}


- (IBAction)cancelSaveAs:(id)sender
{
	[exportController cancelExport:self];
}


- (void)errorSheetDidDismiss:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[(MacOSaiXDocument *)[self document] setAutoSaveEnabled:YES];	// Re-enable auto saving.
}


#pragma mark -
#pragma mark Window delegate methods


- (void)windowDidBecomeMain:(NSNotification *)aNotification
{
    [self synchronizeMenus];
}


- (NSSize)windowWillResize:(NSWindow *)resizingWindow toSize:(NSSize)proposedFrameSize
{
//	if (resizingWindow == [self window])
//	{
//		float	aspectRatio = [[self mosaic] aspectRatio],
//				windowTop = NSMaxY([resizingWindow frame]), 
//				minHeight = 200;	// TODO: get this from nib setting
//		NSSize	diff = NSMakeSize([resizingWindow frame].size.width - [[resizingWindow contentView] frame].size.width, 
//								  [resizingWindow frame].size.height - [[resizingWindow contentView] frame].size.height);
//		NSRect	screenFrame = [[resizingWindow screen] frame];
//		
//		proposedFrameSize.width = MIN(MAX(proposedFrameSize.width, 132),
//									  screenFrame.size.width - [resizingWindow frame].origin.x) - diff.width;
//		windowTop -= diff.height + 16 + (statusBarShowing ? [statusBarView frame].size.height : 0);
//		
//			// Calculate the height of the window based on the proposed width
//			//   and preserve the aspect ratio of the mosaic image.
//			// If the height is too big for the screen, lower the width.
//		proposedFrameSize.height = (proposedFrameSize.width - 16) / aspectRatio;
//		if (proposedFrameSize.height > windowTop || proposedFrameSize.height < minHeight)
//		{
//			proposedFrameSize.height = (proposedFrameSize.height < minHeight) ? minHeight : windowTop;
//			proposedFrameSize.width = proposedFrameSize.height * aspectRatio + 16;
//		}
//		
//			// Add height of scroll bar and status bar (if showing)
//		proposedFrameSize.height += 16 + (statusBarShowing ? [statusBarView frame].size.height : 0);
//		
//		proposedFrameSize.height += diff.height;
//		proposedFrameSize.width += diff.width;
//	}

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
		
		[[[self window] contentView] removeTrackingRect:mosaicTrackingRectTag];
		mosaicTrackingRectTag = [[[self window] contentView] addTrackingRect:[mosaicScrollView frame] 
																	   owner:mosaicView 
																	userData:nil 
																assumeInside:NO];
	}
}


- (void)windowWillClose:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTargetImageDidChangeNotification object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXMosaicDidChangeStateNotification object:[self mosaic]];
		[[NSNotificationCenter defaultCenter] removeObserver:self name:MacOSaiXTileShapesDidChangeStateNotification object:[self mosaic]];
		
		[self setMosaic:nil];
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
    
	if ([itemIdentifier isEqualToString:@"Target"])
    {
		[toolbarItem setMinSize:NSMakeSize(44.0, 32.0)];
		[toolbarItem setMaxSize:NSMakeSize(44.0, 32.0)];
		[toolbarItem setLabel:NSLocalizedString(@"Target", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:targetImageToolbarView];
// TODO:		[toolbarItem setMenuFormRepresentation:[targetImagePopUpButton menu]];
    }
	else if ([itemIdentifier isEqualToString:@"Tiles"])
    {
		NSImage	*shapesImage = [[[self mosaic] tileShapes] image];
		if (shapesImage)
			[toolbarItem setImage:shapesImage];
		[toolbarItem setLabel:NSLocalizedString(@"Tiles", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(setupTiles:)];
		[toolbarItem setToolTip:NSLocalizedString(@"Change the tile shapes or image use rules", @"")];
		setupTilesToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Full Screen"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"FullScreen"]];
		[toolbarItem setLabel:NSLocalizedString(@"Full Screen", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(viewFullScreen:)];
		[toolbarItem setToolTip:NSLocalizedString(@"View the mosaic in full screen mode", @"")];
    }
	else if ([itemIdentifier isEqualToString:@"Save As"])
    {
		[toolbarItem setImage:[[NSWorkspace sharedWorkspace] iconForFileType:@"jpg"]];
		[toolbarItem setLabel:NSLocalizedString(@"Save As", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(saveMosaicAs:)];
		[toolbarItem setToolTip:NSLocalizedString(@"Save the mosaic as an image or web page", @"")];
		saveAsToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Pause"])
    {
		[toolbarItem setImage:[NSImage imageNamed:@"Pause"]];
		[toolbarItem setLabel:NSLocalizedString(([[self mosaic] isPaused] ? @"Resume" : @"Pause"), @"")];
		[toolbarItem setPaletteLabel:NSLocalizedString(@"Pause/Resume", @"")];
		[toolbarItem setTarget:self];
		[toolbarItem setAction:@selector(togglePause:)];
		pauseToolbarItem = toolbarItem;
    }
	else if ([itemIdentifier isEqualToString:@"Fade"])
    {
		[toolbarItem setMinSize:[fadeToolbarView frame].size];
		[toolbarItem setMaxSize:[fadeToolbarView frame].size];
		[toolbarItem setLabel:NSLocalizedString(@"Fade", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
		[toolbarItem setView:fadeToolbarView];
// TODO:		[toolbarItem setMenuFormRepresentation:zoomToolbarMenuItem];
    }
    else if ([itemIdentifier isEqualToString:@"Zoom"])
    {
		[toolbarItem setMinSize:[zoomToolbarView frame].size];
		[toolbarItem setMaxSize:[zoomToolbarView frame].size];
		[toolbarItem setLabel:NSLocalizedString(@"Zoom", @"")];
		[toolbarItem setPaletteLabel:[toolbarItem label]];
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
    return [NSArray arrayWithObjects:@"Target", @"Tiles", @"Pause", @"Full Screen", 
									 @"Fade", @"Zoom", @"Save As", 
									 NSToolbarCustomizeToolbarItemIdentifier, NSToolbarSpaceItemIdentifier,
									 NSToolbarFlexibleSpaceItemIdentifier, NSToolbarSeparatorItemIdentifier,
									 nil];
}


- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
{
    return [NSArray arrayWithObjects:@"Target", @"Tiles", 
									 NSToolbarFlexibleSpaceItemIdentifier, @"Pause", 
									 NSToolbarFlexibleSpaceItemIdentifier, @"Zoom", @"Fade", nil];
}


#pragma mark


- (void)dealloc
{
	[[[self window] contentView] removeTrackingRect:mosaicTrackingRectTag];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [toolbarItems release];
	[mosaicToolbarImage release];
    [removedSubviews release];
    [zoomToolbarMenuItem release];
    [viewToolbarMenuItem release];
    [tileImages release];
    
	[tilesSetupController release];
	[exportController release];
	
	[targetImageEditor release];
	[tileShapesEditor release];
	[imageUsageEditor release];
	[imageSourcesEditor release];
	[imageOrientationsEditor release];
	[tileEditor release];
	
    [super dealloc];
}


@end
