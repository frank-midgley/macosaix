#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import <MacOSaiXPlugins/TilesSetupController.h>
#import <MacOSaiXPlugins/ImageSourceController.h>

typedef enum
{
	viewMosaicAndTilesSetup, viewMosaicAndOriginal, viewMosaicAlone, viewMosaicAndRegions, viewMosaicEditor
} MacOSaiXDocumentViewMode;


@interface MacOSaiXDocument : NSDocument 
{
    IBOutlet MosaicView				*mosaicView;
	IBOutlet NSScrollView			*mosaicScrollView;
	IBOutlet NSTextField			*statusMessageView;
    IBOutlet NSDrawer				*utilitiesDrawer;
    IBOutlet NSTabView				*utilitiesTabView;
    IBOutlet NSView					*statusBarView;
    IBOutlet id						zoomToolbarView, zoomSlider;
    IBOutlet NSMenu					*zoomToolbarSubmenu;
	
		// Progress panel
    IBOutlet NSPanel				*progressPanel;
	IBOutlet NSTextField			*progressPanelLabel;
	IBOutlet NSProgressIndicator	*progressPanelIndicator;
	IBOutlet NSButton				*progressPanelCancelButton;
	
		// Export panel
    IBOutlet id						exportPanelAccessoryView;
	IBOutlet NSTextField			*exportWidth, *exportHeight;
    
		// Tiles tab
	IBOutlet NSPopUpButton			*tilesSetupPopUpButton;
	IBOutlet NSBox					*tilesSetupView;
	TilesSetupController			*tilesSetupController;
	IBOutlet NSTextField			*totalTilesField;
	IBOutlet NSPopUpButton			*neighborhoodSizePopUpButton;
	int								neighborhoodSize;
	NSMutableDictionary				*directNeighbors;
	
		// Images tab
	IBOutlet NSPopUpButton			*imageSourcesPopUpButton;
	IBOutlet NSTabView				*imageSourcesTabView;
	IBOutlet NSTableView			*imageSourcesTable;
	IBOutlet NSButton				*imageSourcesRemoveButton;
	
		// Original tab
    IBOutlet OriginalView			*originalView;
    IBOutlet id						showOutlinesSwitch;
		
		// Editor tab
    IBOutlet NSTextField		*editorLabel;
	IBOutlet NSButtonCell		*editorUseCustomImage,
								*editorUseBestUniqueMatch;
    IBOutlet NSImageView		*editorUserChosenImage;
	IBOutlet NSButton			*editorChooseImage,
								*editorUseSelectedImage;
	IBOutlet NSTableView		*editorTable;
    IBOutlet NSTextField		*matchValueTextField;

    NSURL						*originalImageURL;
    NSImage						*originalImage, *mosaicImage, *mosaicUpdateImage;
    NSLock						*mosaicImageLock, *refindUniqueTilesLock, *imageQueueLock;
    NSTimer						*updateDisplayTimer, *animateTileTimer;
    NSMutableArray				*imageSources, *tiles, *imageQueue, *selectedTileImages;
	NSArray						*tileOutlines;
    NSMutableDictionary			*toolbarItems;
    NSToolbarItem				*viewToolbarItem, *pauseToolbarItem;
    BOOL						documentIsClosing,	// flag set to true when document is closing
								mosaicStarted, paused, statusBarShowing,
								updateTilesFlag, mosaicImageUpdated,
								windowFinishedLoading,	// flag to indicate nib was loaded
								finishLoading;	// flag to indicate doc was not new,
												// so perform second phase of initializing
    long						imagesMatched,
								cachedImageCount;
	int							extractionPercentComplete;
	NSMutableDictionary			*cachedImagesDictionary;
	NSString					*cachedImagesPath;
	
    NSArray						*removedSubviews;
    NSMenu						*viewMenu, *fileMenu;
    MacOSaiXDocumentViewMode	viewMode;
    BOOL						createTilesThreadAlive,
								enumerateImageSourcesThreadAlive, 
								calculateImageMatchesThreadAlive,
								exportImageThreadAlive;
    float						overallMatch, lastDisplayMatch, zoom;
    Tile						*selectedTile;
	NSPoint						tileSelectionPoint;
    NSWindow					*mainWindow, *mosaicImageDrawWindow;
    NSBezierPath				*combinedOutlines;
    NSMenuItem					*zoomToolbarMenuItem, *viewToolbarMenuItem;
    NSDate						*lastSaved;
    int							autosaveFrequency,	// in minutes
								exportProgressTileCount;
    NSRect						storedWindowFrame;
    NSMutableArray				*tileImages;
    NSLock						*tileImagesLock,
								*calculateImageMatchesThreadLock;
    NSBitmapImageFileType		exportFormat;
	ImageSource					*manualImageSource;
	
		// ivars for the calculate displayed images thread
	NSMutableSet				*refreshTilesSet;
	NSLock						*refreshTilesSetLock,
								*calculateDisplayedImagesThreadLock;
	BOOL						calculateDisplayedImagesThreadAlive;
	
		// image cache
    NSLock						*cacheLock;
	NSMutableDictionary			*imageCache;
    NSMutableArray				*orderedCache,
                                *orderedCacheID;
}

	// View methods
- (IBAction)setViewCompareMode:(id)sender;
- (IBAction)setViewTileSetupMode:(id)sender;
- (IBAction)setViewRegionsMode:(id)sender;
- (IBAction)setViewAloneMode:(id)sender;
- (IBAction)setViewEditMode:(id)sender;
- (IBAction)setViewMode:(int)mode;
- (IBAction)setZoom:(id)sender;
- (IBAction)toggleStatusBar:(id)sender;
- (IBAction)setShowOutlines:(id)sender;
- (IBAction)toggleImageSourcesDrawer:(id)sender;
- (IBAction)togglePause:(id)sender;

- (IBAction)selectTileAtPoint:(NSPoint)thePoint;

	// Tiles tab methods
- (IBAction)setTilesSetupPlugIn:(id)sender;
- (IBAction)setNeighborhoodSize:(id)sender;

	// Images tab methods
- (IBAction)addImageSource:(ImageSource *)imageSource;
- (IBAction)showCurrentImageSources;
- (IBAction)setImageSourcesPlugIn:(id)sender;

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

@end
