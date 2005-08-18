#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXDocument.h"


@interface MacOSaiXWindowController : NSWindowController 
{
    IBOutlet MosaicView					*mosaicView;
	IBOutlet NSScrollView				*mosaicScrollView;
	
	IBOutlet NSTextField				*statusMessageView;
	
    IBOutlet NSView						*statusBarView;
	
    IBOutlet NSView						*zoomToolbarView;
	IBOutlet NSSlider					*zoomSlider;
    IBOutlet NSMenu						*zoomToolbarSubmenu;
	
		// Settings drawer
    IBOutlet NSDrawer					*settingsDrawer;
	IBOutlet NSImageView				*originalImageThumbView;
	IBOutlet NSPopUpButton				*originalImagePopUpButton;
	IBOutlet NSView						*openOriginalAccessoryView;
	IBOutlet NSTextField				*tileShapesDescriptionField,
										*totalTilesField,
										*tileSizeLabelField,
										*tileSizeField;
	IBOutlet NSButton					*changeTileShapesButton;
	IBOutlet NSPopUpButton				*imageUseCountPopUpButton,
										*imageReuseDistancePopUpButton;
	IBOutlet NSPopUpButton				*imageSourcesPopUpButton;
	IBOutlet NSTableView				*imageSourcesTableView;
	IBOutlet NSButton					*imageSourcesRemoveButton;
	
		// Tile shapes sheet
	IBOutlet NSPanel					*tileShapesPanel;
	IBOutlet NSPopUpButton				*tileShapesPopUpButton;
	IBOutlet NSBox						*tileShapesBox;
	id<MacOSaiXTileShapesEditor>		tileShapesEditor;
	id<MacOSaiXTileShapes>				tileShapesBeingEdited;
	IBOutlet NSButton					*cancelTileShapesButton,
										*setTileShapesButton;
	
		// Image source editor
	IBOutlet NSPanel					*imageSourceEditorPanel;
	IBOutlet NSBox						*imageSourceEditorBox;
	IBOutlet NSButton					*imageSourceEditorCancelButton, 
										*imageSourceEditorOKButton;
	id<MacOSaiXImageSourceController>	imageSourceEditorController;
		
		// Editor
	IBOutlet NSView						*editorAccessoryView;
	IBOutlet NSBox						*editorChosenImageBox;
	IBOutlet NSImageView				*editorOriginalImageView,
										*editorChosenImageView;
	IBOutlet NSTextField				*editorPercentCroppedTextField, 
										*editorMatchQualityTextField;
	IBOutlet NSProgressIndicator		*editorProgressIndicator;
	
		// Progress panel
    IBOutlet NSPanel					*progressPanel;
	IBOutlet NSTextField				*progressPanelLabel;
	IBOutlet NSProgressIndicator		*progressPanelIndicator;
	IBOutlet NSButton					*progressPanelCancelButton;
	
		// Export panel
    IBOutlet NSView						*exportPanelAccessoryView;
	IBOutlet NSTextField				*exportWidth, *exportHeight;
	unsigned long						exportProgressTileCount;
	
	NSMutableArray						*tilesToRefresh;
	NSLock								*tileRefreshLock;
	int									refreshTilesThreadCount;
	
    NSTimer								*animateTileTimer;
    NSMutableArray						*selectedTileImages;
    NSMutableDictionary					*toolbarItems;
    NSToolbarItem						*toggleOriginalToolbarItem, *pauseToolbarItem;
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

- (MacOSaiXDocument *)document;

- (void)synchronizeGUIWithDocument;

	// View methods
- (IBAction)setViewOriginalImage:(id)sender;
- (IBAction)setViewMosaic:(id)sender;
- (IBAction)toggleViewOriginal:(id)sender;
- (BOOL)viewingOriginal;
- (IBAction)toggleTileOutlines:(id)sender;
- (IBAction)setZoom:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)toggleImageSourcesDrawer:(id)sender;
- (IBAction)togglePause:(id)sender;

- (IBAction)selectTileAtPoint:(NSPoint)thePoint;
- (IBAction)chooseImageForSelectedTile:(id)sender;

	// Settings drawer
- (IBAction)chooseOriginalImage:(id)sender;
- (IBAction)changeTileShapes:(id)sender;
- (IBAction)setImageUseCount:(id)sender;
- (IBAction)setImageReuseDistance:(id)sender;
- (IBAction)addNewImageSource:(id)sender;
- (IBAction)removeImageSource:(id)sender;

	// Tile shapes sheet
- (IBAction)setTileShapesPlugIn:(id)sender;
- (IBAction)setTileShapes:(id)sender;
- (IBAction)cancelChangingTileShapes:(id)sender;

	// Image source editor methods
- (IBAction)saveImageSource:(id)sender;
- (IBAction)cancelImageSource:(id)sender;

	// Editor tab methods
- (IBAction)chooseImageForSelectedTile:(id)sender;

	// Export image methods
- (IBAction)beginExportImage:(id)sender;
- (IBAction)setJPEGExport:(id)sender;
- (IBAction)setTIFFExport:(id)sender;

	// Progress panel methods
- (void)displayProgressPanelWithMessage:(NSString *)message;
- (void)setProgressPercentComplete:(NSNumber *)percentComplete;
- (void)setProgressMessage:(NSString *)message;
- (void)closeProgressPanel;

@end
