#import <Cocoa/Cocoa.h>
#import "Tiles.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageCache.h"


@interface MacOSaiXDocument : NSDocument 
{
	int							neighborhoodSize;
	NSMutableDictionary			*directNeighbors;

    NSString					*originalImagePath;
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
								unfetchableCount;
	NSLock						*pauseLock;
	int							tileCreationPercentComplete;
    NSArray						*removedSubviews;
    BOOL						createTilesThreadAlive,
								calculateImageMatchesThreadAlive,
								exportImageThreadAlive;
	int							enumerationThreadCount;
    float						overallMatch, lastDisplayMatch, zoom;
    Tile						*selectedTile;
    NSBezierPath				*combinedOutlines;
    NSDate						*lastSaved;
    int							autosaveFrequency;
    NSRect						storedWindowFrame;
    NSMutableArray				*tileImages;
    NSLock						*tileImagesLock,
								*calculateImageMatchesThreadLock,
								*enumerationThreadCountLock;
	
		// ivars for the calculate displayed images thread
	NSMutableSet				*refreshTilesSet;
	NSLock						*refreshTilesSetLock,
								*calculateDisplayedImagesThreadLock;
	BOOL						calculateDisplayedImagesThreadAlive;

	MacOSaiXImageCache			*imageCache;
}

- (void)setOriginalImagePath:(NSString *)path;
- (void)setTileOutlines:(NSArray *)tileOutlines;
- (void)setNeighborhoodSize:(int)size;

- (BOOL)isPaused;
- (void)pause;
- (void)resume;

- (BOOL)isClosing;

- (BOOL)isCreatingTiles;
- (float)tileCreationPercentComplete;
- (NSArray *)tiles;

- (BOOL)isEnumeratingImageSources;
- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource;

- (BOOL)isCalculatingImageMatches;
- (unsigned long)imagesMatched;

- (BOOL)isCalculatingDisplayedImages;

- (NSArray *)imageSources;
- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;

- (MacOSaiXImageCache *)imageCache;

@end
