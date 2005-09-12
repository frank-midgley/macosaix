/*
	MacOSaiXDocument.h
	MacOSaiX

	Created by Frank Midgley on Sun Oct 24 2004.
	Copyright (c) 2004 Frank M. Midgley. All rights reserved.
*/


#import <Cocoa/Cocoa.h>

#import "MacOSaiXHandPickedImageSource.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"
#import "Tiles.h"


@class MacOSaiXWindowController;


@interface MacOSaiXDocument : NSDocument 
{
	MacOSaiXWindowController		*mainWindowController;
    NSString						*originalImagePath;
    NSImage							*originalImage;
	float							originalImageAspectRatio;
    NSMutableArray					*imageSources,
									*tiles;
	id<MacOSaiXTileShapes>			tileShapes;
	NSSize							averageUnitTileSize;
	
	int								imageUseCount,
									imageReuseDistance,
									imageCropLimit;
		// Document state
    BOOL							documentIsClosing,	// flag set to true when document is closing
									mosaicStarted, 
									paused,
									autoSaveEnabled,
									missedAutoSave;
	NSLock							*pauseLock;
    float							overallMatch, lastDisplayMatch;
	
		// Tile creation
//	int								tileCreationPercentComplete;
//    BOOL							createTilesThreadAlive;

		// Image source enumeration
    NSLock							*enumerationThreadCountLock;
	int								enumerationThreadCount;
	NSMutableDictionary				*enumerationCounts;
	NSLock							*enumerationCountsLock;
    NSMutableArray					*imageQueue;
    NSLock							*imageQueueLock;
	
		// Image matching
    NSLock							*calculateImageMatchesThreadLock;
	BOOL							calculateImageMatchesThreadAlive;
    long							imagesMatched;
	NSMutableDictionary				*betterMatchesCache;
		
		// Saving
    NSDate							*lastSaved;
    NSTimer							*autosaveTimer;
	BOOL							saving,
									loading;
}

- (void)setOriginalImagePath:(NSString *)path;
- (NSString *)originalImagePath;
- (NSImage *)originalImage;

- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes;
- (id<MacOSaiXTileShapes>)tileShapes;
- (NSSize)averageUnitTileSize;

- (int)imageUseCount;
- (void)setImageUseCount:(int)count;
- (int)imageReuseDistance;
- (void)setImageReuseDistance:(int)distance;
- (int)imageCropLimit;
- (void)setImageCropLimit:(int)cropLimit;

- (BOOL)wasStarted;
- (BOOL)isPaused;
- (void)pause;
- (void)resume;

- (BOOL)isSaving;
- (BOOL)isClosing;

- (void)setAutoSaveEnabled:(BOOL)flag;
- (BOOL)autoSaveEnabled;

//- (BOOL)isExtractingTileImagesFromOriginal;
//- (float)tileCreationPercentComplete;
- (NSArray *)tiles;

- (BOOL)isEnumeratingImageSources;
- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource;

- (BOOL)isCalculatingImageMatches;
- (unsigned long)imagesMatched;

- (NSArray *)imageSources;
- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile;
- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile;

@end


	// Notifications
extern NSString	*MacOSaiXDocumentDidChangeStateNotification;
extern NSString *MacOSaiXDocumentDidSaveNotification;
extern NSString	*MacOSaiXOriginalImageDidChangeNotification;
extern NSString *MacOSaiXTileImageDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
