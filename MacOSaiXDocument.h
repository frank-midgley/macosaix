#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Tiles.h"
#import "ImageSource.h"

typedef enum {viewMosaicAndOriginal, viewMosaicAlone, viewMosaicEditor} MacOSaiXDocumentViewMode;

@interface MacOSaiXDocument : NSDocument 
{
    IBOutlet id			window;
    IBOutlet id			mosaicView, originalView, showOutlinesSwitch;
    IBOutlet id			imagesMatchedView;
    IBOutlet id			mosaicQualityView;
    IBOutlet id			viewToolbarView, viewToolbarMenu;
    IBOutlet id			viewCompareButton, viewAloneButton, viewEditorButton;
    IBOutlet id			exportProgressPanel, exportProgressIndicator;
    IBOutlet id			imageSourcesDrawer, imageSourcesTable;
    IBOutlet id			statusBarView;
    IBOutlet id			editorLabel, editorTable;
    IBOutlet id			zoomToolbarView, zoomSlider;
    IBOutlet id			googleTermPanel, googleTermField;
    NSImage			*_originalImage, *_mosaicImage;
    NSLock			*_mosaicImageLock, *_lastBestMatchLock, *_imageQueueLock;
    NSMutableArray		*_imageSources, *_tileOutlines, *_tiles, *_imageQueue, *_selectedTileImages;
    NSMutableDictionary		*_toolbarItems;
    BOOL			_stillAlive, _paused, _statusBarShowing, _viewIsChanging, 
				_updateTilesFlag, _mosaicImageUpdated;
    long			_imagesMatched;
    NSArray			*_removedSubviews;
    NSMenu			*_viewMenu;
    MacOSaiXDocumentViewMode	_viewMode;
    float			_overallMatch, _lastDisplayMatch, _lastBestMatch;
    Tile			*_selectedTile;
    NSWindow			*_mosaicImageDrawWindow;
}

- (void)setOriginalImage:(NSImage *)image;
- (void)setTileOutlines:(NSMutableArray *)tileOutlines;
- (void)setImageSources:(NSMutableArray *)imageSources;
- (void)startMosaic:(id)sender;
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
- (void)calculateFrames;
- (void)toggleStatusBar:(id)sender;
- (void)addDirectoryImageSource:(id)sender;
- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context;
- (void)addGoogleImageSource:(id)sender;
- (void)cancelAddGoogleImageSource:(id)sender;
- (void)okAddGoogleImageSource:(id)sender;
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
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;

@end
