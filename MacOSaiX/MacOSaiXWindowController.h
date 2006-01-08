#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXPopUpImageView.h"
#import "MacOSaiXDocument.h"


@interface MacOSaiXWindowController : NSWindowController 
{
	MacOSaiXMosaic						*mosaic;
	
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSScrollView				*mosaicScrollView;
	
	IBOutlet NSTextField				*statusMessageView;
	
    IBOutlet NSView						*statusBarView;
	
	IBOutlet NSView						*fadeToolbarView;
	IBOutlet NSButton					*fadeOriginalButton,
										*fadeMosaicButton;
	IBOutlet NSSlider					*fadeSlider;
	
    IBOutlet NSView						*zoomToolbarView;
	IBOutlet NSSlider					*zoomSlider;
    IBOutlet NSMenu						*zoomToolbarSubmenu;
	
	IBOutlet NSView						*openOriginalAccessoryView;
	MacOSaiXPopUpImageView				*originalImagePopUpView;
	
		// Image Sources
    IBOutlet NSDrawer					*imageSourcesDrawer;
	IBOutlet NSTableView				*imageSourcesTableView;
	IBOutlet NSPopUpButton				*imageSourcesPopUpButton;
	IBOutlet NSButton					*imageSourcesRemoveButton;
	
		// Tiles setup
	IBOutlet NSPanel					*setupTilesPanel;
	IBOutlet NSPopUpButton				*tileShapesPopUpButton;
	IBOutlet NSBox						*tileShapesBox;
	IBOutlet NSImageView				*tileShapesPreviewImageView;
	id<MacOSaiXTileShapesEditor>		tileShapesEditor;
	id<MacOSaiXTileShapes>				tileShapesBeingEdited;
	IBOutlet NSTextField				*tileShapesCountField,
										*tileShapesAverageSizeField;
	IBOutlet NSPopUpButton				*imageUseCountPopUpButton,
										*imageReuseDistancePopUpButton,
										*imageCropLimitPopUpButton;
	IBOutlet NSButton					*cancelTilesSetupButton,
										*okTilesSetupButton;
	
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
	
		// Export panel
    IBOutlet NSView						*exportPanelAccessoryView;
	IBOutlet NSImageView				*exportFadedImageView;
	IBOutlet NSSlider					*exportFadeSlider;
	IBOutlet NSTextField				*exportWidth, *exportHeight;
	unsigned long						exportProgressTileCount;
	
    NSTimer								*fadeTimer,
										*animateTileTimer;
    NSMutableArray						*selectedTileImages;
    NSMutableDictionary					*toolbarItems;
    NSToolbarItem						*toggleOriginalToolbarItem, 
										*pauseToolbarItem, 
										*setupTilesToolbarItem;
	NSImage								*originalToolbarImage,
										*mosaicToolbarImage;
    BOOL								statusBarShowing,
										updateTilesFlag, 
										windowFinishedLoading,	// flag to indicate nib was loaded
										finishLoading;	// flag to indicate doc was not new,
														// so perform second phase of initializing
    NSArray								*removedSubviews;
    NSMenu								*viewMenu, *fileMenu;
    float								overallMatch, lastDisplayMatch, zoom;
    MacOSaiXTile						*selectedTile;
	NSPoint								tileSelectionPoint;
    NSWindow							*mainWindow, *mosaicImageDrawWindow;
    NSMenuItem							*zoomToolbarMenuItem, *viewToolbarMenuItem;
    NSMutableArray						*tileImages;
    NSBitmapImageFileType				exportFormat;
	id<MacOSaiXImageSource>				*manualImageSource;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

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

	// Image sources drawer
- (IBAction)addNewImageSource:(id)sender;
- (IBAction)removeImageSource:(id)sender;

	// Setup tiles
- (IBAction)setTileShapesPlugIn:(id)sender;
- (IBAction)setImageUseCount:(id)sender;
- (IBAction)setImageReuseDistance:(id)sender;
- (IBAction)setImageCropLimit:(id)sender;
- (IBAction)cancelSetupTiles:(id)sender;
- (IBAction)okSetupTiles:(id)sender;

	// Image source editor
- (IBAction)saveImageSource:(id)sender;
- (IBAction)cancelImageSource:(id)sender;

	// Tile editor
- (IBAction)selectTileAtPoint:(NSPoint)thePoint;
- (IBAction)chooseImageForSelectedTile:(id)sender;
- (IBAction)removeChosenImageForSelectedTile:(id)sender;

	// Export image methods
- (IBAction)beginExportImage:(id)sender;
- (IBAction)setExportFade:(id)sender;
- (IBAction)setJPEGExport:(id)sender;
- (IBAction)setTIFFExport:(id)sender;

	// Progress panel methods
- (void)displayProgressPanelWithMessage:(NSString *)message;
- (void)setProgressPercentComplete:(NSNumber *)percentComplete;
- (void)setProgressMessage:(NSString *)message;
- (void)closeProgressPanel;

@end
