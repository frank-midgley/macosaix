#import "MosaicView.h"
#import "Tiles.h"

@implementation MosaicView

- (id)init
{
    [super init];
    _highlightedTile = nil;
    return self;
}


- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    NSPoint mouseLoc;

    while (keepOn) {
        theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask];

        if ([theEvent type] == NSLeftMouseUp)
	{
	    mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	    if ([self mouse:mouseLoc inRect:[self bounds]])
		[[[self window] delegate] selectTileAtPoint:mouseLoc];
	    keepOn = NO;
        }

    };

    return;
}


- (void)highlightTile:(Tile *)tile
{
    _highlightedTile = tile;
}


- (void)drawRect:(NSRect)theRect
{
    [super drawRect:theRect];
    [[NSColor blackColor] set];
    [[_highlightedTile outline] setLineWidth:4.0];
    [[_highlightedTile outline] stroke];
}

@end
