#import <Cocoa/Cocoa.h>
#import "Tiles.h"
#import "MacOSaiXTileShapes.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXImageCache.h"


@interface MacOSaiXDocument : NSDocument 
{
	int							neighborhoodSize;
	NSMutableDictionary			*directNeighbors;

    NSString					*originalImagePath;
    NSImage						*originalImage;
    NSMutableArray				*imageSources,
								*tiles;
	id<MacOSaiXTileShapes>		tileShapes;
	MacOSaiXImageCache			*imageCache;
	
		// Document state
    BOOL						documentIsClosing,	// flag set to true when document is closing
								mosaicStarted, 
								paused;
	NSLock						*pauseLock;
    float						overallMatch, lastDisplayMatch;
	
		// Tile creation
	int							tileCreationPercentComplete;
    BOOL						createTilesThreadAlive;
    NSMutableArray				*tileImages;
    NSLock						*tileImagesLock;

		// Image source enumeration
    NSLock						*enumerationThreadCountLock;
	int							enumerationThreadCount;
	NSMutableDictionary			*enumerationCounts;
	NSLock						*enumerationCountsLock;
    NSMutableArray				*imageQueue;
    NSLock						*imageQueueLock;
	
		// Image matching
    NSLock						*calculateImageMatchesThreadLock;
	BOOL						calculateImageMatchesThreadAlive;
    long						imagesMatched;
	
		// Calculate displayed images
	NSMutableSet				*refreshTilesSet;
	NSLock						*refreshTilesSetLock,
								*calculateDisplayedImagesThreadLock;
	BOOL						calculateDisplayedImagesThreadAlive;
		
		// Saving
    NSDate						*lastSaved;
    int							autosaveFrequency;
	BOOL						saving;
}

- (void)setOriginalImagePath:(NSString *)path;
- (NSString *)originalImagePath;
- (NSImage *)originalImage;

- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes;
- (id<MacOSaiXTileShapes>)tileShapes;

- (int)neighborhoodSize;
- (void)setNeighborhoodSize:(int)size;

- (BOOL)wasStarted;
- (BOOL)isPaused;
- (void)pause;
- (void)resume;

- (BOOL)isSaving;
- (BOOL)isClosing;

- (BOOL)isExtractingTileImagesFromOriginal;
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
extern NSString *MacOSaiXDocumentDidSaveNotification;
extern NSString	*MacOSaiXOriginalImageDidChangeNotification;
extern NSString *MacOSaiXTileImageDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
