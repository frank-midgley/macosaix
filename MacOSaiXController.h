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
    int				imageCount, maxImages, matcherThreadCount;
    BOOL			inProgress, somethingChanged;
//    id <MatcherMethods>		matcher;	// proxy to the matcher object in the detached thread
    NSString			*pixPath;
    NSLock			*mosaicLock, *threadCountLock;
}

- (void)startMosaic:(id)sender;
- (void)updateDisplay:(id)timer;
- (void)feedMatcher:(id)timer;
- (void)calculateMatchesWithNextFile:(id)foo;
- (float)computeMatch:(Tile *)tile with:(NSBitmapImageRep *)imageRep previousBest:(float)prevBest;

// application delegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)note;

// window delegate methods
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
- (void)windowDidResize:(NSNotification *)notification;

@end
