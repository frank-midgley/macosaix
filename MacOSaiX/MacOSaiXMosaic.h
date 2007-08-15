//
//  MacOSaiXMosaic.h
//  MacOSaiX
//
//  Created by Frank Midgley on 10/4/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXHandPickedImageSource, MacOSaiXImageQueue, MacOSaiXImageSourceEnumerator, MacOSaiXSourceImage, MacOSaiXTile;
@protocol MacOSaiXTileShapes, MacOSaiXImageOrientations, MacOSaiXImageSource, MacOSaiXExportSettings;


@interface MacOSaiXMosaic : NSObject
{
    NSImage							*targetImage;
	NSString						*targetImagePath, 
									*targetImageIdentifier;
	id<MacOSaiXImageSource>			targetImageSource;
	float							targetImageAspectRatio;
	
    NSMutableArray					*tiles;
	
	NSLock							*imageSourcesLock;
	
	id<MacOSaiXTileShapes>			tileShapes;
	id<MacOSaiXImageOrientations>	imageOrientations;
	id<MacOSaiXExportSettings>		exportSettings;
	
	NSSize							averageTileSize;
	
		// Image usage settings
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
	NSMutableArray					*imageSourceEnumerators;
	MacOSaiXImageQueue				*newImageQueue, 
									*revisitImageQueue;
	
		// Image matching
    NSLock							*calculateImageMatchesLock;
	BOOL							calculateImageMatchesThreadAlive;
	NSMutableDictionary				*betterMatchesCache, 
									*imageIdentifiersInUse;
	
    BOOL							paused, 
									pausing;
	NSTimer							*resumeTimer;
	
    float							overallMatch,
									lastDisplayMatch;
	
	NSMutableArray					*disallowedImages;
	
	BOOL							isBeingLoaded;
	
	NSUndoManager					*undoManager;
	
	NSMutableArray					*visibleEditorClasses;
	
	float							targetImageOpacity;
}

	// Target image
- (void)setTargetImage:(NSImage *)image;
- (NSImage *)targetImage;
- (void)setTargetImagePath:(NSString *)path;
- (NSString *)targetImagePath;
- (void)setTargetImageIdentifier:(NSString *)identifier source:(id<MacOSaiXImageSource>)source;
- (NSString *)targetImageIdentifier;
- (id<MacOSaiXImageSource>)targetImageSource;

- (void)setAspectRatio:(float)ratio;
- (float)aspectRatio;

	// Tile shapes
- (void)setTileShapes:(id<MacOSaiXTileShapes>)tileShapes;
- (id<MacOSaiXTileShapes>)tileShapes;
- (void)createTiles;
- (NSSize)averageTileSize;

	// Image orientations
- (void)setImageOrientations:(id<MacOSaiXImageOrientations>)imageOrientations;
- (id<MacOSaiXImageOrientations>)imageOrientations;

	// Export settings
- (void)setExportSettings:(id<MacOSaiXExportSettings>)exportSettings;
- (id<MacOSaiXExportSettings>)exportSettings;

	// Image usage
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

- (MacOSaiXImageQueue *)imageQueue;
- (void)addSourceImageToQueue:(MacOSaiXSourceImage *)sourceImage;

- (unsigned long)numberOfImagesFound;
- (unsigned long)numberOfImagesInUse;

	// Image sources methods
- (NSArray *)imageSourceEnumerators;
- (MacOSaiXImageSourceEnumerator *)addImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)imageSourceDidChange:(id<MacOSaiXImageSource>)imageSource;
- (void)removeImageSource:(id<MacOSaiXImageSource>)imageSource;

	// Disk cache paths
- (NSString *)diskCachePath;
- (void)setDiskCachePath:(NSString *)path;
- (NSString *)diskCacheSubPathForImageSource:(id<MacOSaiXImageSource>)imageSource;
- (void)setDiskCacheSubPath:(NSString *)path forImageSource:(id<MacOSaiXImageSource>)imageSource;

	// Pause/resume
- (BOOL)isPaused;
- (void)pause;
- (void)resume;

- (void)disallowImage:(MacOSaiXSourceImage *)image;
- (NSArray *)disallowedImages;

- (void)setIsBeingLoaded:(BOOL)flag;
- (BOOL)isBeingLoaded;

- (NSUndoManager *)undoManager;

- (void)setEditorClass:(Class)editorClass isVisible:(BOOL)isVisible;
- (BOOL)editorClassIsVisible:(Class)editorClass;

- (void)setTargetImageOpacity:(float)opacity;
- (float)targetImageOpacity;

@end


	// Notifications
extern NSString	*MacOSaiXTargetImageDidChangeNotification;
extern NSString *MacOSaiXTileShapesDidChangeStateNotification;
extern NSString	*MacOSaiXMosaicDidChangeImageSourcesNotification;
extern NSString *MacOSaiXImageOrientationsDidChangeStateNotification;
extern NSString *MacOSaiXTileContentsDidChangeNotification;
extern NSString	*MacOSaiXMosaicDidChangeBusyStateNotification;
extern NSString	*MacOSaiXMosaicDidChangeVisibleEditorsNotification;
