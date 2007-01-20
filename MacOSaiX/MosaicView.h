//
//  MosaicView.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001-5 Frank M. Midgley.  All rights reserved.
//

@class MacOSaiXMosaic, MacOSaiXTile, MacOSaiXEditor;


typedef enum { clearMode, blackMode, targetMode } MacOSaiXBackgroundMode;


@interface MosaicView : NSView
{
	MacOSaiXMosaic			*mosaic;
	NSImage					*mainImage, 
							*backgroundImage;
	NSSize					mainImageSize;
	NSLock					*mainImageLock, 
							*backgroundImageLock;
	NSAffineTransform		*mainImageTransform;
	float					targetImageFraction, 
							targetFadeTime;
	BOOL					inLiveRedraw;
	
		// Target image fading
	NSImage					*previousTargetImage;
	NSDate					*targetFadeStartTime;
	NSTimer					*targetFadeTimer;
	
	MacOSaiXEditor			*activeEditor;
	
	BOOL					showNonUniqueMatches;
	
	IBOutlet NSMenu			*contextualMenu;
	
		// Tile refreshing
	NSMutableArray			*tilesToRefresh, 
							*tileMatchTypesToRefresh;
	NSLock					*tileRefreshLock;
	BOOL					refreshingTiles;
	
		// Queued tile view invalidation
	NSMutableArray			*tilesNeedingDisplay;
	NSLock					*tilesNeedDisplayLock;
	NSTimer					*tilesNeedDisplayTimer;
	
	MacOSaiXBackgroundMode	backgroundMode;
	
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
- (void)setBackgroundImage:(NSImage *)image;
- (NSImage *)backgroundImage;

- (void)setTargetImageFraction:(float)fraction;
- (float)targetImageFraction;

- (void)setTargetFadeTime:(float)seconds;

- (void)setInLiveRedraw:(NSNumber *)flag;

- (void)setActiveEditor:(MacOSaiXEditor *)editor;
- (MacOSaiXEditor *)activeEditor;

- (void)setShowNonUniqueMatches:(BOOL)flag;
- (BOOL)showNonUniqueMatches;

- (void)setBackgroundMode:(MacOSaiXBackgroundMode)mode;
- (MacOSaiXBackgroundMode)backgroundMode;

- (MacOSaiXTile *)tileAtPoint:(NSPoint)thePoint;

- (NSImage *)image;

- (BOOL)isBusy;
- (NSString *)busyStatus;

@end


// Notifications
extern NSString	*MacOSaiXMosaicViewDidChangeBusyStateNotification;
