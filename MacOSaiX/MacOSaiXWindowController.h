/*
	MacOSaiXWindowController.h
	MacOSaiX
 
	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004-2006 Frank M. Midgley. All rights reserved.
 */

@class MacOSaiXMosaic, MosaicView, Tiles, MacOSaiXEditorsView, MacOSaiXExportController, MacOSaiXImageSource, MacOSaiXTileShapes, 
       MacOSaiXPopUpButton, MacOSaiXDocument, MacOSaiXTilesSetupController, MacOSaiXImageSourceEditor;
@class MacOSaiXTargetImageEditor, MacOSaiXTileShapesEditor, MacOSaiXImageUsageEditor, MacOSaiXImageSourcesEditor, 
       MacOSaiXImageOrientationsEditor, MacOSaiXTileContentEditor;
@protocol MacOSaiXImageSource;


@interface MacOSaiXWindowController : NSWindowController 
{
	MacOSaiXMosaic						*mosaic;
	
		// Minimal view
	BOOL								viewIsMinimal;
	IBOutlet NSView						*minimalContentView;
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSButton					*pauseButton;
	IBOutlet NSTextField				*statusField, 
										*imagesFoundField;
	
		// Editing layout
	IBOutlet NSView						*editingContentView;
	IBOutlet MacOSaiXEditorsView		*editorsView;
	IBOutlet NSBox						*minimalViewBox;
	IBOutlet NSSlider					*blendSlider, 
										*zoomSlider;
	
		// Editors
	MacOSaiXTargetImageEditor			*targetImageEditor;
	MacOSaiXTileShapesEditor			*tileShapesEditor;
	MacOSaiXImageUsageEditor			*imageUsageEditor;
	MacOSaiXImageSourcesEditor			*imageSourcesEditor;
	MacOSaiXImageOrientationsEditor		*imageOrientationsEditor;
	MacOSaiXTileContentEditor			*tileContentEditor;
	
	MacOSaiXExportController			*exportController;
    NSTimer								*animateTileTimer;
	NSImage								*targetToolbarImage,
										*mosaicToolbarImage;
    BOOL								statusBarShowing,
										fadeWasAdjusted, 
										windowFinishedLoading,	// flag to indicate nib was loaded
										finishLoading;	// flag to indicate doc was not new,
														// so perform second phase of initializing
    NSArray								*removedSubviews;
    float								overallMatch, 
										lastDisplayMatch, 
										zoom;
	NSPoint								tileSelectionPoint;
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
- (void)setViewIsMinimal:(BOOL)flag;
- (BOOL)viewIsMinimal;
- (IBAction)setZoom:(id)sender;
- (IBAction)setMinimumZoom:(id)sender;
- (IBAction)setMaximumZoom:(id)sender;
- (IBAction)setBlend:(id)sender;
- (IBAction)togglePause:(id)sender;
- (IBAction)viewFullScreen:(id)sender;

	// Save As methods
- (IBAction)saveMosaicAs:(id)sender;

@end
