#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Tiles.h"

@interface MacOSaiXController : NSObject 
{
    IBOutlet id			window;
    IBOutlet id			mosaicView;
    IBOutlet id			originalView;
    IBOutlet id			imagesMatched;
    IBOutlet id			goButton;
    id				timer;
    NSImage			*originalImage, *mosaicImage;
    NSMutableArray		*tileOutlines;
    NSMutableArray		*_tiles;
    float			*bestMatch;
    NSDirectoryEnumerator	*enumerator;
    int				imageCount, maxImages;
    BOOL			inProgress, somethingChanged;
//    id <MatcherMethods>		matcher;	// proxy to the matcher object in the detached thread
    NSString			*pixPath;
    NSLock			*mosaicLock;
}

- (void)startMosaic:(id)sender;
- (void)updateDisplay:(id)timer;
- (void)processAFile:(id)timer;
- (void)calculateMatchesWithFile:(id)filePath;
- (float)computeMatch:(Tile *)tile with:(NSBitmapImageRep *)imageRep;

// application delegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)note;

@end
