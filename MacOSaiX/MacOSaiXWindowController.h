#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import <MacOSaiXPlugins/TilesSetupController.h>
#import "MacOSaiXImageSource.h"
#import "MacOSaiXDocument.h"


typedef enum
{
	viewMosaicAndTilesSetup, viewMosaicAndOriginal, viewMosaicAlone, viewMosaicAndRegions, viewMosaicEditor
} MacOSaiXDocumentViewMode;


@interface MacOSaiXWindowController : NSWindowController 
{
    IBOutlet MosaicView				*mosaicView;
	IBOutlet NSScrollView			*mosaicScrollView;

	IBOutlet NSTextField			*statusMessageView;


    IBOutlet NSView					*statusBarView;
	
    IBOutlet NSView					*zoomToolbarView;
	IBOutlet NSSlider				*zoomSlider;
    IBOutlet NSMenu					*zoomToolbarSubmenu;
	
		// Settings drawer
    IBOutlet NSDrawer				*settingsDrawer;
	IBOutlet NSImageView			*originalImageThumbView;
	IBOutlet NSPopUpButton			*originalImagePopUpButton;
	IBOutlet NSTextField			*tileShapesDescriptionField,
									*totalTilesField;
	IBOutlet NSButton				*changeTileShapesButton;
	IBOutlet NSPopUpButton			*imageUseCountPopUpButton,
									*neighborhoodSizePopUpButton;
	IBOutlet NSPopUpButton			*imageSourcesPopUpButton;
	IBOutlet NSTableView			*imageSourcesTableView;
	IBOutlet NSButton				*imageSourcesRemoveButton;
	
		// Tile shapes sheet
	IBOutlet NSPanel				*tileShapesPanel;
	IBOutlet NSPopUpButton			*tileShapesPopUpButton;
	IBOutlet NSBox					*tileShapesBox;
	id<MacOSaiXTileShapesEditor>	tileShapesEditor;
	id<MacOSaiXTileShapes>			tileShapesBeingEdited;
	IBOutlet NSButton				*setTileShapesButton;
	
		// Image source editor
	IBOutlet NSPanel				*imageSourceEditorPanel;
	IBOutlet NSBox					*imageSourceEditorBox;
	IBOutlet NSButton				*imageSourceEditorOKButton;
		
		// Editor tab
    IBOutlet NSTextField			*editorLabel;
	IBOutlet NSButtonCell			*editorUseCustomImage,
									*editorUseBestUniqueMatch;
    IBOutlet NSImageView			*editorUserChosenImage;
	IBOutlet NSButton				*editorChooseImage,
									*editorUseSelectedImage;
	IBOutlet NSTableView			*editorTable;
//    IBOutlet NSTextField			*matchValueTextField;
	
		// Progress panel
    IBOutlet NSPanel				*progressPanel;
	IBOutlet NSTextField			*progressPanelLabel;
	IBOutlet NSProgressIndicator	*progressPanelIndicator;
	IBOutlet NSButton				*progressPanelCancelButton;
	
		// Export panel
    IBOutlet NSView					*exportPanelAccessoryView;
	IBOutlet NSTextField			*exportWidth, *exportHeight;
	unsigned long					exportProgressTileCount;

    NSString						*originalImagePath;
    NSTimer							*animateTileTimer;
    NSMutableArray					*selectedTileImages;
    NSMutableDictionary				*toolbarItems;
    NSToolbarItem					*viewToolbarItem, *pauseToolbarItem;
    BOOL							statusBarShowing,
									updateTilesFlag, 
									windowFinishedLoading,	// flag to indicate nib was loaded
									finishLoading;	// flag to indicate doc was not new,
													// so perform second phase of initializing
    NSArray							*removedSubviews;
    NSMenu							*viewMenu, *fileMenu;
    MacOSaiXDocumentViewMode		viewMode;
    float							overallMatch, lastDisplayMatch, zoom;
    Tile							*selectedTile;
	NSPoint							tileSelectionPoint;
    NSWindow						*mainWindow, *mosaicImageDrawWindow;
    NSMenuItem						*zoomToolbarMenuItem, *viewToolbarMenuItem;
    NSMutableArray					*tileImages;
    NSBitmapImageFileType			exportFormat;
	id<MacOSaiXImageSource>			*manualImageSource;
}

- (MacOSaiXDocument *)document;

	// View methods
- (IBAction)setViewCompareMode:(id)sender;
- (IBAction)setViewTileSetupMode:(id)sender;
- (IBAction)setViewRegionsMode:(id)sender;
- (IBAction)setViewAloneMode:(id)sender;
- (IBAction)setViewEditMode:(id)sender;
- (IBAction)setViewMode:(int)mode;
- (IBAction)setZoom:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)toggleImageSourcesDrawer:(id)sender;
- (IBAction)togglePause:(id)sender;

- (IBAction)selectTileAtPoint:(NSPoint)thePoint;

	// Settings drawer
- (IBAction)chooseOriginalImage:(id)sender;
- (IBAction)changeTileShapes:(id)sender;
- (IBAction)setNeighborhoodSize:(id)sender;
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
- (IBAction)useCustomImage:(id)sender;
- (IBAction)useBestUniqueMatch:(id)sender;
- (IBAction)allowUserToChooseImage:(id)sender;
- (IBAction)useSelectedImage:(id)sender;

	// Export image methods
- (IBAction)beginExportImage:(id)sender;
- (IBAction)setJPEGExport:(id)sender;
- (IBAction)setTIFFExport:(id)sender;
- (IBAction)setExportWidthFromHeight:(id)sender;
- (IBAction)setExportHeightFromWidth:(id)sender;

	// Progress panel methods
- (void)displayProgressPanelWithMessage:(NSString *)message;
- (void)setProgressPercentComplete:(NSNumber *)percentComplete;
- (void)closeProgressPanel;

@end
