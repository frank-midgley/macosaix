#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import "MacOSaiXExportController.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXPopUpImageView.h"
#import "MacOSaiXDocument.h"
#import "MacOSaiXTilesSetupController.h"


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
	MacOSaiXPopUpImageView				*originalImagePopUpView;
	
	MacOSaiXTilesSetupController		*tilesSetupController;
	
		// Image Sources
    IBOutlet NSDrawer					*imageSourcesDrawer;
	IBOutlet NSTableView				*imageSourcesTableView;
	IBOutlet NSPopUpButton				*imageSourcesPopUpButton;
	IBOutlet NSButton					*imageSourcesRemoveButton;
	
		// Image source editor
	IBOutlet NSPanel					*imageSourceEditorPanel;
	IBOutlet NSBox						*imageSourceEditorBox;
	IBOutlet NSButton					*imageSourceEditorCancelButton, 
										*imageSourceEditorOKButton;
	id<MacOSaiXImageSourceController>	imageSourceEditorController;
		
		// Selected tile editor
	IBOutlet NSView						*editorAccessoryView;
	IBOutlet NSBox						*editorChosenImageBox;
	IBOutlet NSImageView				*editorOriginalImageView,
										*editorCurrentImageView, 
										*editorChosenImageView;
	IBOutlet NSTextField				*editorCurrentPercentCroppedTextField, 
										*editorCurrentMatchQualityTextField,
										*editorChosenPercentCroppedTextField, 
										*editorChosenMatchQualityTextField;
	float								editorChosenMatchValue;
	
		// Progress panel
    IBOutlet NSPanel					*progressPanel;
	IBOutlet NSTextField				*progressPanelLabel;
	IBOutlet NSProgressIndicator		*progressPanelIndicator;
	IBOutlet NSButton					*progressPanelCancelButton;
	
	MacOSaiXExportController			*exportController;
    NSTimer								*fadeTimer,
										*animateTileTimer;
    NSMutableArray						*selectedTileImages;
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
    MacOSaiXTile						*selectedTile;
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

	// Image source editor
- (IBAction)saveImageSource:(id)sender;
- (IBAction)cancelImageSource:(id)sender;

	// Tile editor
- (IBAction)selectTileAtPoint:(NSPoint)thePoint;
- (IBAction)chooseImageForSelectedTile:(id)sender;
- (IBAction)removeChosenImageForSelectedTile:(id)sender;

	// Save As methods
- (IBAction)saveMosaicAs:(id)sender;

	// Progress panel methods
- (void)displayProgressPanelWithMessage:(NSString *)message;
- (void)setProgressPercentComplete:(NSNumber *)percentComplete;
- (void)setProgressMessage:(NSString *)message;
- (void)closeProgressPanel;

@end


extern NSString	*MacOSaiXRecentOriginalImagesDidChangeNotification;
