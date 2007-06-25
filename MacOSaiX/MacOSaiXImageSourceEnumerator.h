//
//  MacOSaiXImageSourceEnumerator.h
//  MacOSaiX
//
//  Created by Frank Midgley on 6/21/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

@protocol MacOSaiXImageSource;
@class MacOSaiXImageQueue, MacOSaiXMosaic, MacOSaiXSourceImage;


@interface MacOSaiXImageSourceEnumerator : NSObject
{
	id<MacOSaiXImageSource>	imageSource, 
							workingImageSource;
	MacOSaiXMosaic			*mosaic;
	unsigned long			imagesFound, 
							imagesInUse;
	BOOL					pausing, 
							paused;
	NSLock					*inUseLock;
	NSMutableSet			*identifiersInUse;
	
		// Probation
	BOOL					onProbation;
	NSRecursiveLock			*probationLock;
	MacOSaiXImageQueue		*probationaryImageQueue;
	NSDate					*probationStartDate;
}

- (id)initWithImageSource:(id<MacOSaiXImageSource>)imageSource forMosaic:(MacOSaiXMosaic *)mosaic;

- (void)setImageSource:(id<MacOSaiXImageSource>)imageSource;
- (id<MacOSaiXImageSource>)imageSource;

- (id<MacOSaiXImageSource>)workingImageSource;

- (void)setNumberOfImagesFound:(unsigned long)count;
- (unsigned long)numberOfImagesFound;

- (void)setImageIdentifier:(NSString *)imageIdentifier isInUse:(BOOL)inUse;
- (NSArray *)imageIdentifiersInUse;

- (void)pause;
- (void)resume;
- (BOOL)isEnumerating;

- (void)setIsOnProbation:(BOOL)flag;
- (BOOL)isOnProbation;
- (void)rememberProbationaryImage:(MacOSaiXSourceImage *)image;
- (MacOSaiXImageQueue *)probationaryImageQueue;

- (void)reset;

@end


extern NSString *MacOSaiXImageSourceEnumeratorDidChangeCountNotification;
