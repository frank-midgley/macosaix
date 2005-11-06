//
//  MacOSaiXMosaic.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXHandPickedImageSource.h"
#import "MacOSaiXImageSource.h"
#import "MacOSaiXTileShapes.h"
#import "Tiles.h"


@interface MacOSaiXMosaic : NSObject
{
    NSImage							*originalImage;
	float							originalImageAspectRatio;
    NSMutableArray					*imageSources,
									*tiles;
	NSLock							*imageSourcesLock;
	id<MacOSaiXTileShapes>			tileShapes;
	NSSize							averageUnitTileSize;
	
	BOOL							displayNonUniqueMatches;
	
	int								imageUseCount,
									imageReuseDistance,
									imageCropLimit;
	
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
	
    BOOL							mosaicStarted, 
									paused, 
									pausing;
    float							overallMatch,
									lastDisplayMatch;
}

- (void)setOriginalImage:(NSImage *)image;
- (NSImage *)originalImage;

- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes creatingTiles:(BOOL)createTiles;
- (id<MacOSaiXTileShapes>)tileShapes;
- (NSSize)averageUnitTileSize;

- (void)setDisplayNonUniqueMatches:(BOOL)flag;
- (BOOL)displayNonUniqueMatches;

- (int)imageUseCount;
- (void)setImageUseCount:(int)count;
- (int)imageReuseDistance;
- (void)setImageReuseDistance:(int)distance;
- (int)imageCropLimit;
- (void)setImageCropLimit:(int)cropLimit;

- (NSArray *)tiles;

- (BOOL)isBusy;
- (NSString *)status;
- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource;
- (unsigned long)imagesMatched;

- (NSArray *)imageSources;
- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;

- (MacOSaiXHandPickedImageSource *)handPickedImageSource;
- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile;
- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile;

- (BOOL)wasStarted;
- (BOOL)isPaused;
- (void)pause;
- (void)resume;

@end


	// Notifications
extern NSString	*MacOSaiXMosaicDidChangeStateNotification;
extern NSString	*MacOSaiXOriginalImageDidChangeNotification;
extern NSString *MacOSaiXTileImageDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
