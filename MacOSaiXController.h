#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Tiles.h"

@interface MacOSaiXController : NSObject 
{
    IBOutlet id			window;
    IBOutlet id			mosaicView;
    IBOutlet id			originalView;
    IBOutlet id			selectedTileFilePath;
    IBOutlet id			openButton, saveButton;
    IBOutlet id			progressIndicator;
    NSImage			*originalImage, *mosaicImage;
    NSMutableArray		*_tiles, *_updatedTiles;
    NSDirectoryEnumerator	*enumerator;
    BOOL			somethingChanged;
    NSString			*pixPath;
    NSLock			*mosaicLock, *_updatedTilesLock;
    Tile			*_selectedTile;
}

- (void)startMosaic:(id)sender;
- (void)updateDisplay:(id)timer;
- (void)enumerateAndMatchFiles:(id)foo;
- (NSMutableArray *)createTileOutlinesForImage:(NSImage *)image;
- (void)createTileCollectionWithOutlines:(NSMutableArray *)outlines fromImage:(NSImage *)image;
- (void)selectTileAtPoint:(NSPoint)thePoint;
- (void)saveMosaicImage:(id)sender;

// application delegate methods
- (void)applicationDidFinishLaunching:(NSNotification *)note;

// window delegate methods
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
- (void)windowDidResize:(NSNotification *)notification;

@end
