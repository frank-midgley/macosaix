/*
	MacOSaiXWindowController.h
	MacOSaiX
 
	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004-2006 Frank M. Midgley. All rights reserved.
 */

@class MacOSaiXMosaic, MosaicView, Tiles, MacOSaiXEditorsView, MacOSaiXExportController, MacOSaiXImageSource, MacOSaiXTileShapes, 
       MacOSaiXPopUpButton, MacOSaiXDocument, MacOSaiXSplitView, MacOSaiXTilesSetupController, MacOSaiXImageSourceEditor;
@protocol MacOSaiXImageSource;


@interface MacOSaiXWindowController : NSWindowController 
{
	MacOSaiXMosaic						*mosaic;
	
		// Views shared between layouts
	IBOutlet NSScrollView				*mosaicScrollView;
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSButton					*pauseButton;
	IBOutlet NSTextField				*statusField, 
										*imagesFoundField;
	
		// Minimal layout
	IBOutlet NSView						*minimalContentView;
	
		// Editing layout
	IBOutlet NSView						*editingContentView;
	IBOutlet MacOSaiXSplitView			*editingSplitView;
	IBOutlet MacOSaiXEditorsView		*editorsView;
	IBOutlet NSBox						*editingView;
	IBOutlet NSSlider					*blendSlider, 
										*zoomSlider;
	
	BOOL								windowLayoutIsMinimal;
	NSSize								minEditorsViewSize;
	MacOSaiXExportController			*exportController;
	NSImage								*targetToolbarImage,
										*mosaicToolbarImage;
    float								overallMatch, 
										lastDisplayMatch, 
										zoom;
    NSWindow							*mainWindow, 
										*mosaicImageDrawWindow;
    NSMutableArray						*tileImages;
	id<MacOSaiXImageSource>				*manualImageSource;
	
	NSDate								*windowResizeStartTime;
	NSSize								windowResizeTargetSize, 
										windowResizeDifference;
	
	NSTrackingRectTag					mosaicTrackingRectTag;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

	// View methods
- (void)setWindowLayoutIsMinimal:(BOOL)flag;
- (BOOL)windowLayoutIsMinimal;
- (IBAction)setZoom:(id)sender;
- (IBAction)setMinimumZoom:(id)sender;
- (IBAction)setMaximumZoom:(id)sender;
- (IBAction)setBlend:(id)sender;
- (IBAction)togglePause:(id)sender;
- (IBAction)viewFullScreen:(id)sender;
- (void)setMinimumEditorsViewSize:(NSSize)minSize;

	// Save As methods
- (IBAction)saveMosaicAs:(id)sender;

@end
