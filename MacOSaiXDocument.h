#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Tiles.h"

@interface MacOSaiXDocument : NSDocument 
{
    IBOutlet id			window;
    IBOutlet id			mosaicView;
    IBOutlet id			originalView;
    IBOutlet id			selectedTileFilePath;
    IBOutlet id			progressIndicator;
    NSImage			*originalImage, *mosaicImage;
    NSMutableArray		*_imageSources, *_tileOutlines, *_tiles, *_updatedTiles;
    NSLock			*mosaicLock, *_updatedTilesLock;
    Tile			*_selectedTile;
}

- (void)setOriginalImage:(NSImage *)image;
- (void)setTileOutlines:(NSMutableArray *)tileOutlines;
- (void)setImageSources:(NSMutableArray *)imageSources;
- (void)startMosaic:(id)sender;
- (void)updateDisplay:(id)timer;
- (void)enumerateDirectory:(id)path;
- (void)createTileCollectionWithOutlines:(NSMutableArray *)outlines fromImage:(NSImage *)image;
- (void)selectTileAtPoint:(NSPoint)thePoint;
- (void)exportMacOSaiXImage:(id)sender;

// window delegate methods
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize;
- (void)windowDidResize:(NSNotification *)notification;

@end
