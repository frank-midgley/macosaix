#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "MosaicView.h"
#import "OriginalView.h"
#import "Tiles.h"
#import "ImageSource.h"

typedef enum {viewMosaicAndOriginal, viewMosaicAlone, viewMosaicEditor} MacOSaiXDocumentViewMode;
typedef enum {threadUnborn, threadIdle, threadWorking, threadTerminated} MacOSaiXDocumentThreadState;

@interface MacOSaiXDocument : NSDocument 
{
    IBOutlet id			window;
    IBOutlet id			tabView;
    IBOutlet id			mosaicView;
    IBOutlet OriginalView	*originalView;
    IBOutlet id			showOutlinesSwitch, statusMessageView;
    IBOutlet id			viewToolbarView, viewToolbarMenu;
    IBOutlet id			viewCompareButton, viewAloneButton, viewEditorButton;
    IBOutlet id			exportProgressPanel, exportProgressLabel, exportProgressIndicator;
    IBOutlet id			imageSourcesDrawer, imageSourcesTable;
    IBOutlet id			statusBarView;
    IBOutlet id			_editorLabel, editorUseCustomImage, editorUseBestUniqueMatch;
    IBOutlet id			editorUserChosenImage, editorChooseImage, editorTable, editorUseSelectedImage;
    IBOutlet id			zoomToolbarView, zoomSlider;
    IBOutlet id			googleTermPanel, googleTermField;
    IBOutlet NSMenu		*zoomToolbarSubmenu, *viewToolbarSubmenu;
    IBOutlet id			_exportPanelAccessoryView, _exportWidth, _exportHeight;
    
    NSURL			*_originalImageURL;
    NSImage			*_originalImage, *_mosaicImage, *_mosaicUpdateImage;
    NSLock			*_mosaicImageLock, *_refindUniqueTilesLock, *_imageQueueLock;
    NSTimer			*_updateDisplayTimer, *_animateTileTimer;
    NSMutableArray		*_imageSources, *_tileOutlines, *_tiles, *_imageQueue, *_selectedTileImages;
    NSMutableDictionary		*_toolbarItems;
    NSToolbarItem		*_viewToolbarItem, *_pauseToolbarItem;
    BOOL			_stillAlive,	// flag set to false when document is closing
				_refindUniqueTiles,	// 
				_paused, _statusBarShowing,
				_viewIsChanging, // flag used to handle animated resizing
				_updateTilesFlag, _mosaicImageUpdated,
				_windowFinishedLoading,	// flag to indicate nib was loaded
				_finishLoading,	// flag to indicate doc was not new,
						// so perform second phase of initializing
				_applicationIsTerminating;
    long			_imagesMatched;
    NSArray			*_removedSubviews;
    NSMenu			*_viewMenu, *_fileMenu;
    MacOSaiXDocumentViewMode	_viewMode;
    MacOSaiXDocumentThreadState	_createTilesThreadStatus, _enumerateImageSourcesThreadStatus, 
				_processImagesThreadStatus, _integrateMatchesThreadStatus,
				_exportImageThreadStatus;
    float			_overallMatch, _lastDisplayMatch, _zoom;
    Tile			*_selectedTile;
    NSWindow			*_mainWindow, *_mosaicImageDrawWindow;
    NSBezierPath		*_combinedOutlines;
    NSMenuItem			*_zoomToolbarMenuItem, *_viewToolbarMenuItem;
    NSDate			*_lastSaved;
    int				_autosaveFrequency,	// in minutes
				_exportProgressTileCount;
    NSRect			_storedWindowFrame;
    NSMutableArray		*_tileImages;
    NSLock			*_tileImagesLock;
    TileImage			*_unusedTileImage;
    NSBitmapImageFileType	_exportFormat;
    NSSavePanel			*_savePanel;
}

- (void)setOriginalImage:(NSImage *)image fromURL:(NSURL *)imageURL;
- (void)setTileOutlines:(NSMutableArray *)tileOutlines;
- (void)setImageSources:(NSMutableArray *)imageSources;
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
- (void)addDirectoryImageSource:(id)sender;
- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)addGoogleImageSource:(id)sender;
- (void)cancelAddGoogleImageSource:(id)sender;
- (void)okAddGoogleImageSource:(id)sender;
- (void)addGlyphImageSource:(id)sender;

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
