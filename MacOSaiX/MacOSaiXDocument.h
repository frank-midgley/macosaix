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
    IBOutlet MosaicView			*mosaicView;
	IBOutlet NSScrollView		*mosaicScrollView;
	IBOutlet NSTextField		*statusMessageView;
    IBOutlet NSDrawer			*utilitiesDrawer;
    IBOutlet NSTabView			*utilitiesTabView;
    IBOutlet NSView				*statusBarView;
    IBOutlet id					zoomToolbarView, zoomSlider;
    IBOutlet NSMenu				*zoomToolbarSubmenu;
	
		// Export panel
    IBOutlet id					exportProgressPanel, exportProgressLabel, exportProgressIndicator;
    IBOutlet id					exportPanelAccessoryView;
	IBOutlet NSTextField		*exportWidth, *exportHeight;
    
		// Tiles setup tab
	IBOutlet NSPopUpButton		*tilesSetupPopUpButton;
	IBOutlet NSBox				*tilesSetupView;
	IBOutlet NSTextField		*totalTilesField;
	TilesSetupController		*tilesSetupController;
	
		// Image sources tab
	IBOutlet NSPopUpButton		*imageSourcesPopUpButton;
	IBOutlet NSTabView			*imageSourcesTabView;
	IBOutlet NSTableView		*imageSourcesTable;
	IBOutlet NSButton			*imageSourcesRemoveButton;
	
		// Original tab
    IBOutlet OriginalView		*originalView;
    IBOutlet id					showOutlinesSwitch;
		
		// Tile editor tab
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
    NSSavePanel					*savePanel;
	ImageSource					*manualImageSource;
	
		// ivars for the calculate displayed images thread
	NSMutableSet				*refreshTilesSet;
	NSLock						*refreshTilesSetLock,
								*calculateDisplayedImagesThreadLock;
	BOOL						calculateDisplayedImagesThreadAlive;
	
		// image cache
    NSLock						*cacheLock;
	NSMutableDictionary			*imageCache;
    NSMutableArray				*orderedCache;
}

- (void)chooseOriginalImage;
- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)startMosaic;

- (void)setTilesSetupPlugIn:(id)sender;
- (void)spawnImageSourceThreads;
- (void)synchronizeMenus;


- (void)recalculateTileDisplayMatches:(id)object;
- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;
- (void)calculateImageMatches:(id)path;
- (void)createTileCollectionWithOutlines:(id)object;

	// View methods
- (void)setViewCompareMode:(id)sender;
- (void)setViewTileSetupMode:(id)sender;
- (void)setViewRegionsMode:(id)sender;
- (void)setViewAloneMode:(id)sender;
- (void)setViewEditMode:(id)sender;
- (void)setViewMode:(int)mode;
- (void)setZoom:(id)sender;
- (void)toggleStatusBar:(id)sender;
- (void)setShowOutlines:(id)sender;
- (void)toggleImageSourcesDrawer:(id)sender;
- (void)togglePause:(id)sender;

	// Editor methods
- (void)selectTileAtPoint:(NSPoint)thePoint;
- (void)updateEditor;
- (BOOL)showTileMatchInEditor:(ImageMatch *)tileMatch selecting:(BOOL)selecting;
- (NSImage *)createEditorImage:(int)rowIndex;
- (void)useCustomImage:(id)sender;
- (void)useBestUniqueMatch:(id)sender;
- (void)allowUserToChooseImage:(id)sender;
- (void)allowUserToChooseImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)useSelectedImage:(id)sender;

// Image sources methods
- (void)addImageSource:(ImageSource *)imageSource;
- (void)showCurrentImageSources;
- (void)setImageSourcesPlugIn:(id)sender;

// Export image methods
- (void)beginExportImage:(id)sender;
- (void)setJPEGExport:(id)sender;
- (void)setTIFFExport:(id)sender;
- (void)setExportWidthFromHeight:(id)sender;
- (void)setExportHeightFromWidth:(id)sender;
- (void)exportImageSavePanelDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)savePanel;
- (void)exportImage:(id)exportFilename;

// window delegate methods
- (void)windowDidBecomeMain:(NSNotification *)aNotification;
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
- (void)windowDidResize:(NSNotification *)notification;

// toolbar delegate methods
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier
    willBeInsertedIntoToolbar:(BOOL)flag;
- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem;
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;

@end
