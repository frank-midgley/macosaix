/*
	MacOSaiXWindowController.h
	MacOSaiX
 
	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004-2006 Frank M. Midgley. All rights reserved.
 */

@class MacOSaiXMosaic, MosaicView, Tiles, MacOSaiXEditorsView, MacOSaiXExportController, MacOSaiXImageSource, MacOSaiXTileShapes, 
       MacOSaiXPopUpButton, MacOSaiXDocument, MacOSaiXTilesSetupController, MacOSaiXImageSourceEditor;
@class MacOSaiXTargetImageEditor, MacOSaiXTileShapesEditor, MacOSaiXImageUsageEditor, MacOSaiXImageSourcesEditor, 
       MacOSaiXImageOrientationsEditor, MacOSaiXTileEditor, MacOSaiXViewOptionsEditor;
@protocol MacOSaiXImageSource;


@interface MacOSaiXWindowController : NSWindowController 
{
	MacOSaiXMosaic						*mosaic;
	
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSScrollView				*mosaicScrollView;
	
    IBOutlet NSView						*statusBarView;
	IBOutlet NSTextField				*imagesFoundField, 
										*statusField;
	IBOutlet NSProgressIndicator		*statusProgressIndicator;
	
	IBOutlet NSMenu						*recentTargetsMenu;
	
	IBOutlet NSView						*fadeToolbarView;
	IBOutlet NSButton					*fadeTargetButton,
										*fadeMosaicButton;
	IBOutlet NSSlider					*fadeSlider;
	
    IBOutlet NSView						*zoomToolbarView;
	IBOutlet NSSlider					*zoomSlider;
    IBOutlet NSMenu						*zoomToolbarSubmenu;
	
	MacOSaiXPopUpButton					*targetImageToolbarView;
	
	id		tilesSetupController;
	
	IBOutlet MacOSaiXEditorsView		*editorsView;
	
		// Editors
	MacOSaiXTargetImageEditor			*targetImageEditor;
	MacOSaiXTileShapesEditor			*tileShapesEditor;
	MacOSaiXImageUsageEditor			*imageUsageEditor;
	MacOSaiXImageSourcesEditor			*imageSourcesEditor;
	MacOSaiXImageOrientationsEditor		*imageOrientationsEditor;
	MacOSaiXTileEditor					*tileEditor;
	MacOSaiXViewOptionsEditor			*viewOptionsEditor;
	
	MacOSaiXExportController			*exportController;
    NSTimer								*animateTileTimer;
    NSMutableDictionary					*toolbarItems;
    NSToolbarItem						*toggleTargetToolbarItem, 
										*pauseToolbarItem, 
										*setupTilesToolbarItem, 
										*saveAsToolbarItem;
	NSImage								*targetToolbarImage,
										*mosaicToolbarImage;
    BOOL								statusBarShowing,
										fadeWasAdjusted, 
										windowFinishedLoading,	// flag to indicate nib was loaded
										finishLoading;	// flag to indicate doc was not new,
														// so perform second phase of initializing
    NSArray								*removedSubviews;
    NSMenu								*mosaicMenu, 
										*viewMenu;
    float								overallMatch, 
										lastDisplayMatch, 
										zoom;
	NSPoint								tileSelectionPoint;
    NSWindow							*mainWindow, 
										*mosaicImageDrawWindow;
    NSMenuItem							*zoomToolbarMenuItem, 
										*viewToolbarMenuItem;
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
- (IBAction)setShowNonUniqueMatches:(id)sender;
- (IBAction)setZoom:(id)sender;
- (IBAction)setMinimumZoom:(id)sender;
- (IBAction)setMaximumZoom:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)togglePause:(id)sender;
- (IBAction)viewFullScreen:(id)sender;

	// Save As methods
- (IBAction)saveMosaicAs:(id)sender;

@end


extern NSString	*MacOSaiXRecentTargetImagesDidChangeNotification;
