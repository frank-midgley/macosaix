//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-5 Frank M. Midgley.  All rights reserved.
//

@class MacOSaiXMosaic, MacOSaiXTile, MacOSaiXMosaicEditor;


@interface MosaicView : NSView
{
	MacOSaiXMosaic			*mosaic;
	NSImage					*mainImage;
	NSSize					mainImageSize;
	NSLock					*mainImageLock;
	NSAffineTransform		*mainImageTransform;
	float					targetImageFraction, 
							targetFadeTime;
	BOOL					inLiveRedraw;
	
		// Target image fading
	NSImage					*previousTargetImage;
	NSDate					*targetFadeStartTime;
	NSTimer					*targetFadeTimer;
	
	MacOSaiXMosaicEditor	*activeEditor;
	
	BOOL					showNonUniqueMatches;
	
	IBOutlet NSMenu			*contextualMenu;
	
		// Tile refreshing
	NSMutableArray			*tilesToRefresh;
	NSLock					*tileRefreshLock;
	BOOL					refreshingTiles;
	
		// Queued tile view invalidation
	NSMutableArray			*tilesNeedingDisplay;
	NSLock					*tilesNeedDisplayLock;
	NSTimer					*tilesNeedDisplayTimer;
	
		// Custom tooltip window
	NSTimer					*tooltipTimer, 
							*tooltipHideTimer;
	IBOutlet NSWindow		*tooltipWindow;
	IBOutlet NSImageView	*tileImageView, 
							*imageSourceImageView;
	IBOutlet NSTextField	*imageSourceTextField, 
							*tileImageTextField;
	MacOSaiXTile			*tooltipTile;
}

- (void)setMosaic:(MacOSaiXMosaic *)inMosaic;
- (MacOSaiXMosaic *)mosaic;

- (NSRect)imageBounds;

- (void)setMainImage:(NSImage *)image;
- (NSImage *)mainImage;

- (void)setTargetImageFraction:(float)fraction;
- (float)targetImageFraction;

- (void)setTargetFadeTime:(float)seconds;

- (void)setInLiveRedraw:(NSNumber *)flag;

- (void)setActiveEditor:(MacOSaiXMosaicEditor *)editor;
- (MacOSaiXMosaicEditor *)activeEditor;

- (MacOSaiXTile *)tileAtPoint:(NSPoint)thePoint;

- (NSImage *)image;

- (BOOL)isBusy;
- (NSString *)busyStatus;

@end


// Notifications
extern NSString	*MacOSaiXMosaicViewDidChangeBusyStateNotification;
