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

@class MacOSaiXSourceImage;


@interface MacOSaiXMosaic : NSObject
{
    NSImage							*originalImage;
	float							originalImageAspectRatio;
    NSMutableArray					*imageSources,
									*tiles;
	NSLock							*imageSourcesLock;
	id<MacOSaiXTileShapes>			tileShapes;
	NSSize							averageUnitTileSize;
	
	int								imageUseCount,
									imageReuseDistance,
									imageCropLimit, 
									betterMatchesLimit;
	float							minDistanceApart;
	
	NSMutableArray					*tilesWithoutBitmaps;
	NSLock							*tilesWithoutBitmapsLock;
	BOOL							tileBitmapExtractionThreadAlive;
	
	NSString						*diskCachePath;
	NSMutableDictionary				*diskCacheSubPaths;
	
		// Image source enumeration
    NSLock							*enumerationThreadCountLock;
	int								enumerationThreadCount;
	NSMutableDictionary				*enumerationCounts, 
									*nextImageErrors;
	unsigned long					imagesFoundCount;
	NSLock							*enumerationCountsLock;
    NSMutableArray					*newImageQueue, 
									*revisitImageQueue;
    NSLock							*imageQueueLock;
	BOOL							reenumerationNotificationWasSent;
	
		// Filler image sources
	NSMutableArray					*fillerImageSources;
	NSArray							*fillerImageSourcesCopy;
	BOOL							fillerImagesChanged;
	
		// Image matching
    NSLock							*calculateImageMatchesThreadLock;
	BOOL							calculateImageMatchesThreadAlive;
	int								placeImageThreadCount;
	NSMutableSet					*sourceImagesInUse;
	NSLock							*tilesUsingImageCacheLock, 
									*scrapLock, 
									*imagePlacementLock;
	NSMutableDictionary				*tilesUsingImageCache;
	NSMutableArray					*imageErrorQueue, 
									*scrapHeap;
	NSDate							*lastExceptionLogDate;
	
	NSLock							*imageSourcesThatHaveLostImagesLock;
	NSMutableSet					*imageSourcesThatHaveLostImages;
	
		// Image placement animation
	BOOL							animateImagePlacements, 
									animateAllImagePlacements, 
									includeSourceImageWithImagePlacementMessage;
	int								imagePlacementFullSizedDuration, 
									delayBetweenImagePlacements;
	NSString						*imagePlacementMessage;	
	
    BOOL							mosaicStarted, 
									paused, 
									pausing, 
                                    resetting, 
									documentIsClosing;
    float							overallMatch,
									lastDisplayMatch;
	int								newImageCount, 
									revisitImageCount, 
									imageErrorCount;
}

- (void)setOriginalImage:(NSImage *)image;
- (NSImage *)originalImage;

- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes creatingTiles:(BOOL)createTiles;
- (id<MacOSaiXTileShapes>)tileShapes;
- (NSSize)averageUnitTileSize;

- (int)imageUseCount;
- (void)setImageUseCount:(int)count;
- (int)imageReuseDistance;
- (void)setImageReuseDistance:(int)distance;
- (int)imageCropLimit;
- (void)setImageCropLimit:(int)cropLimit;

- (NSArray *)tiles;
- (NSArray *)tilesWithSubOptimalUniqueMatches;
- (void)clearTilesWithSubOptimalUniqueMatches;

- (BOOL)isBusy;
- (NSString *)statusAndTooltip:(NSMutableString *)tooltip;
- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource;
- (unsigned long)imagesFound;
- (void)setImageSource:(id<MacOSaiXImageSource>)imageSource hasLostImages:(BOOL)hasLostImages;
- (BOOL)imageSourceHasLostImages:(id<MacOSaiXImageSource>)imageSource;
- (BOOL)allImagesCanBeRevisited;
- (BOOL)allTilesHaveExtractedBitmaps;
- (float)tileBitmapExtractionFractionComplete;
- (NSError *)nextImageErrorForImageSource:(id<MacOSaiXImageSource>)imageSource;
- (float)averageMatchValue;

- (void)revisitSourceImage:(MacOSaiXSourceImage *)sourceImage;
- (void)addSourceImageToScrap:(MacOSaiXSourceImage *)sourceImage;
- (void)setImageMatchIsInUse:(MacOSaiXImageMatch *)match;

- (NSArray *)imageSources;
- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource isFiller:(BOOL)isFiller;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;
- (NSArray *)imagesQueuedForSource:(id<MacOSaiXImageSource>)imageSource;
- (NSArray *)scrapImagesForSource:(id<MacOSaiXImageSource>)imageSource;

- (void)enumerateImageSourceInNewThread:(id<MacOSaiXImageSource>)imageSource;
- (void)reenumerateImageSources;

	// Filler image sources
- (void)setImageSource:(id<MacOSaiXImageSource>)imageSource isFiller:(BOOL)isFiller;
- (BOOL)imageSourceIsFiller:(id<MacOSaiXImageSource>)imageSource;

- (NSString *)diskCachePath;
- (void)setDiskCachePath:(NSString *)path;
- (NSString *)diskCacheSubPathForImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)setDiskCacheSubPath:(NSString *)path forImageSource:(id<MacOSaiXImageSource>)imageSource;

- (MacOSaiXHandPickedImageSource *)handPickedImageSource;
- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile;
- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile;

- (void)setWasStarted:(BOOL)wasStarted;
- (BOOL)wasStarted;
- (BOOL)isPaused;
- (BOOL)isPausing;
- (void)pause;
- (void)resume;
- (void)documentIsClosing;

	// Image placement animation
- (void)setAnimateImagePlacements:(BOOL)flag;
- (BOOL)animateImagePlacements;
- (void)setAnimateAllImagePlacements:(BOOL)flag;
- (BOOL)animateAllImagePlacements;
- (void)setImagePlacementFullSizedDuration:(int)duration;
- (int)imagePlacementFullSizedDuration;
- (void)setDelayBetweenImagePlacements:(int)delay;
- (int)delayBetweenImagePlacements;
- (void)setImagePlacementMessage:(NSString *)message;
- (NSString *)imagePlacementMessage;
- (void)setIncludeSourceImageWithImagePlacementMessage:(BOOL)flag;
- (BOOL)includeSourceImageWithImagePlacementMessage;

@end


	// Notifications
extern NSString *MacOSaiXImageWasPlacedInMosaicNotification;
extern NSString	*MacOSaiXMosaicDidChangeStateNotification;
extern NSString	*MacOSaiXMosaicDidChangeBusyStateNotification;
extern NSString	*MacOSaiXOriginalImageDidChangeNotification;
extern NSString *MacOSaiXTileImageDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
extern NSString	*MacOSaiXMosaicDidChangeImageSourcesNotification;
extern NSString	*MacOSaiXMosaicImageSourcesNeedReenumerationNotification;
extern NSString *MacOSaiXMosaicDidExtractTileBitmapsNotification;
