#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"

typedef enum
{
	nascentState, runningState, pausedState, savingState, exportingState
} MacOSaiXDocumentState;

typedef enum
{
	viewMosaicAndTilesSetup, viewMosaicAndOriginal, viewMosaicAlone, viewMosaicAndRegions, viewMosaicEditor
} MacOSaiXDocumentViewMode;


@interface MacOSaiXDocument : NSDocument 
{
    IBOutlet NSWindow		*window;
    IBOutlet NSTabView		*tabView;
    IBOutlet id				mosaicView;
    IBOutlet OriginalView	*_originalView;
    IBOutlet id				_showOutlinesSwitch, statusMessageView;
    IBOutlet id				viewToolbarView, viewToolbarMenu;
    IBOutlet NSButton		*viewCompareButton, *viewTilesSetupButton, *viewRegionsButton, *viewAloneButton, 
							*viewEditorButton;
    IBOutlet id				exportProgressPanel, exportProgressLabel, exportProgressIndicator;
    IBOutlet id				_utilitiesDrawer, _imageSourcesTable;
    IBOutlet id				statusBarView;
    IBOutlet id				_editorLabel, _editorUseCustomImage, _editorUseBestUniqueMatch;
    IBOutlet id				_editorUserChosenImage, _editorChooseImage, _editorTable, _editorUseSelectedImage;
    IBOutlet id				zoomToolbarView, zoomSlider;
    IBOutlet NSMenu			*zoomToolbarSubmenu, *viewToolbarSubmenu;
    IBOutlet id				_exportPanelAccessoryView, _exportWidth, _exportHeight;
    
		// tile setup pane
	IBOutlet NSPopUpButton	*_tilePopUpButton;
	IBOutlet id				_tileSetupView;
	IBOutlet NSButton		*_startMosaicButton;
	
    NSURL						*_originalImageURL;
    NSImage						*_originalImage, *_mosaicImage, *_mosaicUpdateImage;
    NSLock						*_mosaicImageLock, *_refindUniqueTilesLock, *_imageQueueLock;
    NSTimer						*_updateDisplayTimer, *_animateTileTimer;
    NSMutableArray				*_imageSources, *_tileOutlines, *_tiles, *_imageQueue, *_selectedTileImages;
    NSMutableDictionary			*_toolbarItems;
    NSToolbarItem				*_viewToolbarItem, *_pauseToolbarItem;
    BOOL						_documentIsClosing,	// flag set to true when document is closing
								_refindUniqueTiles,	// 
								_paused, _statusBarShowing,
								_viewIsChanging, // flag used to handle animated resizing
								_updateTilesFlag, _mosaicImageUpdated,
								_windowFinishedLoading,	// flag to indicate nib was loaded
								_finishLoading;	// flag to indicate doc was not new,
												// so perform second phase of initializing
    long						_imagesMatched;
    NSArray						*_removedSubviews;
    NSMenu						*_viewMenu, *_fileMenu;
	MacOSaiXDocumentState		_documentState;
    MacOSaiXDocumentViewMode	_viewMode;
    BOOL						_createTilesThreadAlive,
								_enumerateImageSourcesThreadAlive, 
								_processImagesThreadAlive,
								_integrateMatchesThreadAlive,
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
    NSLock						*_tileImagesLock;
    TileImage					*_unusedTileImage;
    NSBitmapImageFileType		_exportFormat;
    NSSavePanel					*_savePanel;
}

- (void)chooseOriginalImage;
- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)setDocumentState:(MacOSaiXDocumentState)state;
- (void)startMosaic:(id)sender;

- (void)setTileOutlines:(NSMutableArray *)tileOutlines;
- (void)synchronizeMenus;
- (void)recalculateTileDisplayMatches:(id)object;
- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;
- (void)enumerateImageSources:(id)object;
- (void)processImageURLQueue:(id)path;
- (void)createTileCollectionWithOutlines:(id)object;

	// Tile image methods
- (long)addTileImage:(TileImage *)tileImage;
- (void)tileImageIndexInUse:(long)index;
- (void)tileImageIndexNotInUse:(long)index;
- (void)removeTileImage:(TileImage *)tileImage;

	// View methods
- (void)setViewCompareMode:(id)sender;
- (void)setViewTileSetupMode:(id)sender;
- (void)setViewRegionsMode:(id)sender;
- (void)setViewAloneMode:(id)sender;
- (void)setViewEditMode:(id)sender;
- (void)setViewMode:(int)mode;
- (void)setZoom:(id)sender;
- (void)calculateFramesFromSize:(NSSize)frameSize;
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
