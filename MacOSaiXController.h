#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Protocols.h"
#import "Tiles.h"

@interface MacOSaiXController : NSObject <ControllerMethods>
{
    IBOutlet id			mosaicView;
    IBOutlet id			originalView;
    IBOutlet id			imagesMatched;
    IBOutlet id			goButton;
    id				timer;
    NSImage			*originalImage, *mosaicImage;
//    ArrayTransporter		*tileImagesTransporter;
    NSMutableArray		*tileOutlines;
    NSMutableArray		*_tileImages;
    TileCollection		*_tiles;
    float			*bestMatch;
    NSDirectoryEnumerator	*enumerator;
    int				imageCount, maxImages;
    BOOL			inProgress, matcherIdle;
    id <MatcherMethods>		matcher;	// proxy to the matcher object in the detached thread
    NSString			*pixPath;
}

- (void)setServer:(id)anObject;
- (void)startMosaic:(id)sender;
- (void)processFiles:(id)timer;
- (void)setTileImages:(NSMutableArray *)tileImages;
- (void *)getTileImages;
- (NSBitmapImageRep *)getTileImageRep:(int)index;
- (void)checkInMatch:(float)matchValue atIndex:(int)index forFile:(NSString *)filePath;
//- (float)computeMatch:(NSBitmapImageRep *)imageRep1 with:(NSBitmapImageRep *)imageRep2;

// application delegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)note;

@end
