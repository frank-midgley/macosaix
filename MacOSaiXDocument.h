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
    IBOutlet id			mosaicView;
    IBOutlet OriginalView	*originalView;
    IBOutlet id			showOutlinesSwitch, statusMessageView;
    IBOutlet id			viewToolbarView, viewToolbarMenu;
    IBOutlet id			viewCompareButton, viewAloneButton, viewEditorButton;
    IBOutlet id			exportProgressPanel, exportProgressIndicator;
    IBOutlet id			imageSourcesDrawer, imageSourcesTable;
    IBOutlet id			statusBarView;
    IBOutlet id			editorLabel, editorTable;
    IBOutlet id			zoomToolbarView, zoomSlider;
    IBOutlet id			googleTermPanel, googleTermField;
    IBOutlet NSMenu		*zoomToolbarSubmenu, *viewToolbarSubmenu;
    NSURL			*_originalImageURL;
    NSImage			*_originalImage, *_mosaicImage;
    NSLock			*_tileMatchesLock, *_mosaicImageLock, *_lastBestMatchLock, *_imageQueueLock;
    NSTimer			*_updateDisplayTimer, *_animateTileTimer;
    NSMutableArray		*_imageSources, *_tileOutlines, *_tiles, *_imageQueue, *_selectedTileImages;
    NSMutableDictionary		*_toolbarItems;
    NSToolbarItem		*_pauseToolbarItem;
    BOOL			_stillAlive, _paused, _statusBarShowing, _viewIsChanging, 
				_updateTilesFlag, _mosaicImageUpdated, _finishLoading;
    long			_imagesMatched;
    NSArray			*_removedSubviews;
    NSMenu			*_viewMenu, *_fileMenu;
    MacOSaiXDocumentViewMode	_viewMode;
    MacOSaiXDocumentThreadState	_createTilesThreadStatus, _enumerateImageSourcesThreadStatus, 
				_processImagesThreadStatus, _integrateMatchesThreadStatus;
    float			_overallMatch, _lastDisplayMatch, _lastBestMatch, _zoom;
    Tile			*_selectedTile;
    NSWindow			*_mainWindow, *_mosaicImageDrawWindow;
    NSBezierPath		*_combinedOutlines;
    NSMenuItem			*_zoomToolbarMenuItem, *_viewToolbarMenuItem;
    NSDate			*_lastSaved;
    int				_autosaveFrequency;	// in minutes
    NSRect			_storedWindowFrame;
}

- (void)setOriginalImage:(NSImage *)image fromURL:(NSURL *)imageURL;
- (void)setTileOutlines:(NSMutableArray *)tileOutlines;
- (void)setImageSources:(NSMutableArray *)imageSources;
- (void)recalculateTileDisplayMatches:(id)object;
- (void)updateMosaicImage:(NSMutableArray *)updatedTiles;
- (void)enumerateImageSources:(id)object;
- (void)processImageURLQueue:(id)path;
- (void)createTileCollectionWithOutlines:(id)object;
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
- (void)addDirectoryImageSource:(id)sender;
- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)addGoogleImageSource:(id)sender;
- (void)cancelAddGoogleImageSource:(id)sender;
- (void)okAddGoogleImageSource:(id)sender;
- (void)addGlyphImageSource:(id)sender;
- (void)selectTileAtPoint:(NSPoint)thePoint;
- (void)exportMacOSaiXImage:(id)sender;
- (void)synchronizeViewMenu;

- (NSImage *)createEditorImage:(int)rowIndex;

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
