//
//  MacOSaiXMosaic.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXHandPickedImageSource, MacOSaiXTile;
@protocol MacOSaiXTileShapes, MacOSaiXImageOrientations, MacOSaiXImageSource, MacOSaiXExportSettings;


@interface MacOSaiXMosaic : NSObject
{
    NSImage							*targetImage;
	NSString						*targetImagePath, 
									*targetImageIdentifier;
	id<MacOSaiXImageSource>			targetImageSource;
	float							targetImageAspectRatio;
	
    NSMutableArray					*imageSources,
									*tiles;
	
	NSLock							*imageSourcesLock;
	
	id<MacOSaiXTileShapes>			tileShapes;
	id<MacOSaiXImageOrientations>	imageOrientations;
	id<MacOSaiXExportSettings>		exportSettings;
	
	NSSize							averageTileSize;
	
	int								imageUseCount,
									imageReuseDistance,
									imageCropLimit;
	
	NSLock							*tilesWithoutBitmapsLock;
	BOOL							tileBitmapExtractionThreadAlive;
	NSMutableArray					*tilesWithoutBitmaps;
	
	NSString						*diskCachePath;
	NSMutableDictionary				*diskCacheSubPaths;
	
		// Image source enumeration
    NSLock							*enumerationsLock;
	NSMutableArray					*imageSourceEnumerations;
	NSMutableDictionary				*enumerationCounts;
    NSMutableArray					*imageQueue, 
									*revisitQueue;
    NSLock							*imageQueueLock;
	
		// Image matching
    NSLock							*calculateImageMatchesThreadLock;
	BOOL							calculateImageMatchesThreadAlive;
	NSMutableDictionary				*betterMatchesCache;
	
    BOOL							paused, 
									pausing;
    float							overallMatch,
									lastDisplayMatch;
	
	id<MacOSaiXImageSource>			probationaryImageSource;
	NSMutableSet					*probationImageMorgue;
	NSDate							*probationStartDate;
	NSRecursiveLock					*probationLock;
}

- (void)setTargetImage:(NSImage *)image;
- (NSImage *)targetImage;

- (void)setTargetImagePath:(NSString *)path;
- (NSString *)targetImagePath;

- (void)setTargetImageIdentifier:(NSString *)identifier;
- (NSString *)targetImageIdentifier;
- (void)setTargetImageSource:(id<MacOSaiXImageSource>)source;
- (id<MacOSaiXImageSource>)targetImageSource;

- (void)setAspectRatio:(float)ratio;
- (float)aspectRatio;

- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes creatingTiles:(BOOL)createTiles;
- (id<MacOSaiXTileShapes>)tileShapes;
- (NSSize)averageTileSize;

- (void)setImageOrientations:(id<MacOSaiXImageOrientations>)imageOrientations;
- (id<MacOSaiXImageOrientations>)imageOrientations;

- (void)setExportSettings:(id<MacOSaiXExportSettings>)exportSettings;
- (id<MacOSaiXExportSettings>)exportSettings;

- (int)imageUseCount;
- (void)setImageUseCount:(int)count;
- (int)imageReuseDistance;
- (void)setImageReuseDistance:(int)distance;
- (int)imageCropLimit;
- (void)setImageCropLimit:(int)cropLimit;

- (NSArray *)tiles;
- (BOOL)allTilesHaveExtractedBitmaps;

- (BOOL)isBusy;
- (NSString *)busyStatus;

- (unsigned long)imagesFound;

- (NSArray *)imageSources;
- (void)addImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)imageSource:(id<MacOSaiXImageSource>)imageSource didChangeSettings:(NSString *)changeDescription;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;
- (BOOL)imageSourcesExhausted;
- (unsigned long)countOfImagesFromSource:(id<MacOSaiXImageSource>)imageSource;

- (NSString *)diskCachePath;
- (void)setDiskCachePath:(NSString *)path;
- (NSString *)diskCacheSubPathForImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)setDiskCacheSubPath:(NSString *)path forImageSource:(id<MacOSaiXImageSource>)imageSource;

- (MacOSaiXHandPickedImageSource *)handPickedImageSource;
- (void)setHandPickedImageAtPath:(NSString *)path withMatchValue:(float)matchValue forTile:(MacOSaiXTile *)tile;
- (void)removeHandPickedImageForTile:(MacOSaiXTile *)tile;

- (BOOL)isPaused;
- (void)pause;
- (void)resume;

@end


	// Notifications
extern NSString	*MacOSaiXMosaicDidChangeImageSourcesNotification;
extern NSString	*MacOSaiXMosaicDidChangeStateNotification;
extern NSString	*MacOSaiXMosaicDidChangeBusyStateNotification;
extern NSString	*MacOSaiXTargetImageDidChangeNotification;
extern NSString *MacOSaiXTileContentsDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
extern NSString *MacOSaiXImageOrientationsDidChangeStateNotification;
