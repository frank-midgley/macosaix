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
    IBOutlet MosaicView			*_mosaicView;
	IBOutlet NSScrollView		*_mosaicScrollView;
	IBOutlet NSTextField		*_statusMessageView;
    IBOutlet NSDrawer			*_utilitiesDrawer;
    IBOutlet NSTabView			*_utilitiesTabView;
    IBOutlet NSView				*_statusBarView;
    IBOutlet id					_zoomToolbarView, _zoomSlider;
    IBOutlet NSMenu				*_zoomToolbarSubmenu;
	
		// Export panel
    IBOutlet id					_exportProgressPanel, _exportProgressLabel, _exportProgressIndicator;
    IBOutlet id					_exportPanelAccessoryView;
	IBOutlet NSTextField		*_exportWidth, *_exportHeight;
    
		// Tiles setup tab
	IBOutlet NSPopUpButton		*_tilesSetupPopUpButton;
	IBOutlet NSBox				*_tilesSetupView;
	IBOutlet NSTextField		*_totalTilesField;
	TilesSetupController		*_tilesSetupController;
	
		// Image sources tab
	IBOutlet NSPopUpButton		*_imageSourcesPopUpButton;
	IBOutlet NSTabView			*_imageSourcesTabView;
	IBOutlet NSTableView		*_imageSourcesTable;
	IBOutlet NSButton			*_imageSourcesRemoveButton;
	
		// Original tab
    IBOutlet OriginalView		*_originalView;
    IBOutlet id					_showOutlinesSwitch;
		
		// Tile editor tab
    IBOutlet NSTextField		*_editorLabel;
	IBOutlet NSButtonCell		*_editorUseCustomImage,
								*_editorUseBestUniqueMatch;
    IBOutlet NSImageView		*_editorUserChosenImage;
	IBOutlet NSButton			*_editorChooseImage,
								*_editorUseSelectedImage;
	IBOutlet NSTableView		*_editorTable;

    NSURL						*_originalImageURL;
    NSImage						*_originalImage, *_mosaicImage, *_mosaicUpdateImage;
    NSLock						*_mosaicImageLock, *_refindUniqueTilesLock, *_imageQueueLock;
    NSTimer						*_updateDisplayTimer, *_animateTileTimer;
    NSMutableArray				*_imageSources, *_tiles, *_imageQueue, *_selectedTileImages;
	NSArray						*_tileOutlines;
    NSMutableDictionary			*_toolbarItems;
    NSToolbarItem				*_viewToolbarItem, *_pauseToolbarItem;
    BOOL						_documentIsClosing,	// flag set to true when document is closing
								_mosaicStarted, _paused, _statusBarShowing,
								_updateTilesFlag, _mosaicImageUpdated,
								_windowFinishedLoading,	// flag to indicate nib was loaded
								_finishLoading;	// flag to indicate doc was not new,
												// so perform second phase of initializing
    long						_imagesMatched;
    NSArray						*_removedSubviews;
    NSMenu						*_viewMenu, *_fileMenu;
    MacOSaiXDocumentViewMode	_viewMode;
    BOOL						_createTilesThreadAlive,
								_enumerateImageSourcesThreadAlive, 
								_calculateImageMatchesThreadAlive,
								_exportImageThreadAlive;
    float						_overallMatch, _lastDisplayMatch, _zoom;
    Tile						*_selectedTile;
    NSWindow					*_mainWindow, *_mosaicImageDrawWindow;
    NSBezierPath				*_combinedOutlines;
    NSMenuItem					*_zoomToolbarMenuItem, *_viewToolbarMenuItem;
    NSDate						*_lastSaved;
    int							_autosaveFrequency,	// in minutes
								_exportProgressTileCount;
    NSRect						_storedWindowFrame;
    NSMutableArray				*_tileImages;
    NSLock						*_tileImagesLock,
								*_calculateImageMatchesThreadLock;
    TileImage					*_unusedTileImage;
    NSBitmapImageFileType		_exportFormat;
    NSSavePanel					*_savePanel;
	ImageSource					*_manualImageSource;
	
		// ivars for the calculate displayed images thread
	NSMutableSet				*_refreshTilesSet;
	NSLock						*_refreshTilesSetLock,
								*_calculateDisplayedImagesThreadLock;
	BOOL						_calculateDisplayedImagesThreadAlive;
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
- (BOOL)showTileMatchInEditor:(TileMatch *)tileMatch selecting:(BOOL)selecting;
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
