#import "MosaicView.h"
#import "Tiles.h"
#import "MacOSaiXDocument.h"

@implementation MosaicView

- (id)init
{
    [super init];
    _highlightedTile = nil;
    _phase = 0;
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
		[(MacOSaiXDocument *)[[self window] delegate] selectTileAtPoint:mouseLoc];
	    keepOn = NO;
        }

    };

    return;
}


- (void)highlightTile:(Tile *)tile
{
    _highlightedTile = tile;
}


- (void)animateHighlight
{
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSBezierPath	*bezierPath;
    
    _phase = (_phase + 1) % 10;
    [transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
    bezierPath = [transform transformBezierPath:[_highlightedTile outline]];
    [self setNeedsDisplayInRect:[bezierPath bounds]];
}


- (void)drawRect:(NSRect)theRect
{
    [[self image] drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [[self image] size].width,
							       [[self image] size].height)
		   operation:NSCompositeCopy fraction:1.0];

    if (_highlightedTile != nil)
    {
	NSAffineTransform	*transform = [NSAffineTransform transform];
	NSBezierPath		*bezierPath;
	float			dashes[2] = {5.0, 5.0};
	
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	bezierPath = [transform transformBezierPath:[_highlightedTile outline]];
	[bezierPath setLineWidth:2];
	
	[bezierPath setLineDash:dashes count:2 phase:_phase];
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.5] set];
	[bezierPath stroke];

	[bezierPath setLineDash:dashes count:2 phase:(_phase + 5) % 10];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.5] set];
	[bezierPath stroke];
    }
}

@end
