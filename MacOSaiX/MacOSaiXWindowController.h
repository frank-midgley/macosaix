#import <Cocoa/Cocoa.h>

#import "MosaicView.h"

@class OriginalView, Tiles, MacOSaiXExportController, MacOSaiXImageSource, MacOSaiXTileShapes, 
       MacOSaiXPopUpButton, MacOSaiXDocument, MacOSaiXTilesSetupController, MacOSaiXImageSourceEditor;


@interface MacOSaiXWindowController : NSWindowController 
{
	MacOSaiXMosaic						*mosaic;
	
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSScrollView				*mosaicScrollView;
	
    IBOutlet NSView						*statusBarView;
	IBOutlet NSTextField				*imagesFoundField, 
										*statusField;
	IBOutlet NSProgressIndicator		*statusProgressIndicator;
	
	IBOutlet NSMenu						*recentOriginalsMenu;
	
	IBOutlet NSView						*fadeToolbarView;
	IBOutlet NSButton					*fadeOriginalButton,
										*fadeMosaicButton;
	IBOutlet NSSlider					*fadeSlider;
	
    IBOutlet NSView						*zoomToolbarView;
	IBOutlet NSSlider					*zoomSlider;
    IBOutlet NSMenu						*zoomToolbarSubmenu;
	
	IBOutlet NSView						*openOriginalAccessoryView;
	MacOSaiXPopUpButton					*originalImageToolbarView;
	
	MacOSaiXTilesSetupController		*tilesSetupController;
	
		// Image Sources
    IBOutlet NSDrawer					*imageSourcesDrawer;
	IBOutlet NSTableView				*imageSourcesTableView;
	IBOutlet MacOSaiXPopUpButton		*imageSourcesPopUpButton;
	IBOutlet NSButton					*imageSourcesRemoveButton;
	MacOSaiXImageSourceEditor			*imageSourceEditor;
	
	MacOSaiXExportController			*exportController;
    NSTimer								*fadeTimer,
										*animateTileTimer;
    NSMutableDictionary					*toolbarItems;
    NSToolbarItem						*toggleOriginalToolbarItem, 
										*pauseToolbarItem, 
										*setupTilesToolbarItem, 
										*saveAsToolbarItem;
	NSImage								*originalToolbarImage,
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

	// Original image methods
- (IBAction)chooseOriginalImage:(id)sender;
- (IBAction)clearRecentOriginalImages:(id)sender;

	// View methods
- (IBAction)setViewOriginalImage:(id)sender;
- (IBAction)setViewMosaic:(id)sender;
- (IBAction)setViewFade:(id)sender;
- (BOOL)viewingOriginal;
- (IBAction)toggleTileOutlines:(id)sender;
- (IBAction)setZoom:(id)sender;
- (IBAction)setMinimumZoom:(id)sender;
- (IBAction)setMaximumZoom:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)toggleImageSourcesDrawer:(id)sender;
- (IBAction)togglePause:(id)sender;
- (IBAction)viewFullScreen:(id)sender;
- (void)setBackgroundMode:(MacOSaiXBackgroundMode)mode;
- (MacOSaiXBackgroundMode)backgroundMode;

	// Image sources drawer
- (IBAction)addNewImageSource:(id)sender;
- (IBAction)removeImageSource:(id)sender;

	// Tile editor
- (IBAction)chooseImageForSelectedTile:(id)sender;
- (IBAction)removeChosenImageForSelectedTile:(id)sender;

	// Save As methods
- (IBAction)saveMosaicAs:(id)sender;

@end


extern NSString	*MacOSaiXRecentOriginalImagesDidChangeNotification;
