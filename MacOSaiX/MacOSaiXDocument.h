#import <Cocoa/Cocoa.h>
#import "Tiles.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageCache.h"


@interface MacOSaiXDocument : NSDocument 
{
	int							neighborhoodSize;
	NSMutableDictionary			*directNeighbors;

    NSString					*originalImagePath;
    NSImage						*originalImage;
    NSLock						*refindUniqueTilesLock, *imageQueueLock;
    NSMutableArray				*imageSources, *tiles, *imageQueue;
	NSArray						*tileOutlines;
	NSBezierPath				*combinedOutlines;
    BOOL						documentIsClosing,	// flag set to true when document is closing
								mosaicStarted, 
								paused, 
								updateTilesFlag, 
								windowFinishedLoading,	// flag to indicate nib was loaded
								finishLoading;	// flag to indicate doc was not new,
												// so perform second phase of initializing
    long						imagesMatched;
	NSLock						*pauseLock;
	int							tileCreationPercentComplete;
    BOOL						createTilesThreadAlive,
								calculateImageMatchesThreadAlive;
								
	int							enumerationThreadCount;
	NSMutableDictionary			*enumerationCounts;
	NSLock						*enumerationCountsLock;
	
    float						overallMatch, lastDisplayMatch;
    NSDate						*lastSaved;
    int							autosaveFrequency;
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
- (NSString *)originalImagePath;
- (NSImage *)originalImage;

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


	// Notifications
extern NSString	*MacOSaiXDocumentDidChangeStateNotification;
extern NSString	*MacOSaiXOriginalImageDidChangeNotification;
