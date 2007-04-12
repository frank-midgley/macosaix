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
#import "MacOSaiXTileShapes.h"
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
	[editingContentView retain];
	[minimalViewBox setContentView:minimalContentView];
	
	[[self window] setToolbar:[[[NSToolbar alloc] initWithIdentifier:@"Mosaic"] autorelease]];
	[[self window] toggleToolbarShown:self];
	
	NSButton	*toolbarButton = [[self window] standardWindowButton:NSWindowToolbarButton];
	[toolbarButton setTarget:self];
	[toolbarButton setAction:@selector(toggleMinimalView:)];
//	NSButton	*toolbarButton = [NSWindow standardWindowButton:NSWindowToolbarButton forStyleMask:[[self window] styleMask]], 
//				*closeButton = [[self window] standardWindowButton:NSWindowCloseButton];
//	[toolbarButton setTarget:self];
//	[toolbarButton setAction:@selector(toggleMinimalView:)];
//	NSRect		frame = [toolbarButton frame];
//	frame.origin.y = NSMinY([closeButton frame]);
//	frame.origin.x = NSMaxX([[closeButton superview] frame]) - NSWidth(frame) - ;
//	[[closeButton superview] addSubview:toolbarButton];
	
	[self updateStatus];

	{
			// Fill in the description of the current tile shapes.
			// TBD: show in tooltip over closed editor?
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
	
	[[mosaicView enclosingScrollView] setDrawsBackground:NO];
	[[[mosaicView enclosingScrollView] contentView] setDrawsBackground:NO];
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
		
		// FMM TODO: The last chosen image is not available, pick the first recent target in the list.
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(recentTargetImagesDidChange:) 
												 name:MacOSaiXRecentTargetImagesDidChangeNotification 
											   object:nil];
	
	mosaicTrackingRectTag = [[[self window] contentView] addTrackingRect:[[mosaicView enclosingScrollView] frame] 
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
	tileContentEditor = [[MacOSaiXTileContentEditor alloc] initWithMosaicView:mosaicView];
	[editorsView addEditor:tileContentEditor];
}


// TBD: is this needed anymore?
//#pragma mark
//#pragma mark Target image management
//
//
//- (void)targetImageDidChange:(NSNotification *)notification
//{
//	if (!pthread_main_np())
//		[self performSelectorOnMainThread:@selector(targetImageDidChange:) 
//							   withObject:notification 
//							waitUntilDone:YES];
//	else
//	{
//			// Set the zoom so that all of the new image is displayed.
//		[zoomSlider setFloatValue:0.0];
//		[self setZoom:self];
//		
//		[self mosaicDidChangeState:nil];
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
	else
		status = NSLocalizedString(@"Done", @"");
	
	[statusField setStringValue:status];
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
		
			// Update the toolbar.
		if (![[self mosaic] wasStarted] || [[self mosaic] isPaused])
			[pauseButton setImage:[NSImage imageNamed:@"Resume"]];
		else
			[pauseButton setImage:[NSImage imageNamed:@"Pause"]];
	}
}


- (void)mosaicViewDidChangeBusyState:(NSNotification *)notification
{
	if (!pthread_main_np())
		[self performSelectorOnMainThread:_cmd withObject:notification waitUntilDone:NO];
	else
		[self updateStatus];
}


#pragma mark -
#pragma mark Minimal view methods


- (void)setViewIsMinimal:(BOOL)flag
{
	if (viewIsMinimal != flag)
	{
		if (viewIsMinimal)
		{
			[[self window] setContentView:editingContentView];
			[minimalViewBox setContentView:minimalContentView];
		}
		else
		{
			[minimalViewBox setContentView:nil];
			[[self window] setContentView:minimalContentView];
		}
		
		viewIsMinimal = flag;
	}
}


- (BOOL)viewIsMinimal
{
	return viewIsMinimal;
}


- (IBAction)toggleMinimalView:(id)sender
{
	[self setViewIsMinimal:![self viewIsMinimal]];
}


#pragma mark -
#pragma mark Editor methods


- (IBAction)editTargetImage:(id)sender
{
	[editorsView setActiveEditor:targetImageEditor];
}


- (IBAction)editTileShapes:(id)sender
{
	[editorsView setActiveEditor:tileShapesEditor];
}


- (IBAction)editImageSources:(id)sender
{
	[editorsView setActiveEditor:imageSourcesEditor];
}


- (IBAction)editImageUsage:(id)sender
{
	[editorsView setActiveEditor:imageUsageEditor];
}


- (IBAction)editImageOrientations:(id)sender
{
	[editorsView setActiveEditor:imageOrientationsEditor];
}


- (IBAction)editTileContent:(id)sender
{
	[editorsView setActiveEditor:tileContentEditor];
}



#pragma mark -
#pragma mark View methods


- (IBAction)setZoom:(id)sender
{
		// Calculate the currently centered point of the mosaic image independent of the zoom factor.
	NSRect	frame = [[[mosaicView enclosingScrollView] contentView] frame],
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


- (IBAction)setBlend:(id)sender
{
	[mosaicView setTargetImageFraction:1.0 - [blendSlider floatValue]];
}


//- (void)toggleStatusBar:(id)sender
//{
//    NSRect	newFrame = [[self window] frame];
//    int		i;
//    
//    if (statusBarShowing)
//    {
//		statusBarShowing = NO;
//		removedSubviews = [[statusBarView subviews] copy];
//		for (i = 0; i < [removedSubviews count]; i++)
//			[[removedSubviews objectAtIndex:i] removeFromSuperview];
//		[statusBarView retain];
//		[statusBarView removeFromSuperview];
//		newFrame.origin.y += [statusBarView frame].size.height;
//		newFrame.size.height -= [statusBarView frame].size.height;
//		newFrame.size = [self windowWillResize:[self window] toSize:newFrame.size];
//		[[self window] setFrame:newFrame display:YES animate:YES];
//    }
//    else
//    {
//		statusBarShowing = YES;
//		newFrame.origin.y -= [statusBarView frame].size.height;
//		newFrame.size.height += [statusBarView frame].size.height;
//		newFrame.size = [self windowWillResize:[self window] toSize:newFrame.size];
//		[[self window] setFrame:newFrame display:YES animate:YES];
//	
//		[statusBarView setFrame:NSMakeRect(0, [[[mosaicView enclosingScrollView] superview] frame].size.height - [statusBarView frame].size.height, [[[mosaicView enclosingScrollView] superview] frame].size.width, [statusBarView frame].size.height)];
//		[[[mosaicView enclosingScrollView] superview] addSubview:statusBarView];
//		[statusBarView release];
//		for (i = 0; i < [removedSubviews count]; i++)
//		{
//			[[removedSubviews objectAtIndex:i] setFrameSize:NSMakeSize([statusBarView frame].size.width,[[removedSubviews objectAtIndex:i] frame].size.height)];
//			[statusBarView addSubview:[removedSubviews objectAtIndex:i]];
//		}
//		[removedSubviews release]; removedSubviews = nil;
//    }
//}


#pragma mark -
#pragma mark Full screen viewing


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
	[[mosaicView enclosingScrollView] setDocumentView:mosaicView];
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

		[[mosaicView enclosingScrollView] setNeedsDisplay:YES];
	}
    
    return defaultFrame;
}


- (void)windowDidResize:(NSNotification *)notification
{
	if ([notification object] == [self window])
	{
		[self setZoom:self];
		
		[[[self window] contentView] removeTrackingRect:mosaicTrackingRectTag];
		mosaicTrackingRectTag = [[[self window] contentView] addTrackingRect:[[mosaicView enclosingScrollView] frame] 
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
		
		[self setMosaic:nil];
	}
}


#pragma mark


- (void)dealloc
{
	[[[self window] contentView] removeTrackingRect:mosaicTrackingRectTag];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[mosaicToolbarImage release];
    [removedSubviews release];
    [tileImages release];
    
	[exportController release];
	
	[targetImageEditor release];
	[tileShapesEditor release];
	[imageUsageEditor release];
	[imageSourcesEditor release];
	[imageOrientationsEditor release];
	[tileContentEditor release];

	[editingContentView release];
	
    [super dealloc];
}


@end
