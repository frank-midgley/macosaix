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


- (void)setOriginalImage:(NSImage *)originalImage
{
	if (_originalImage != originalImage && _viewMode == _viewTilesOutline)
		[self setNeedsDisplay:YES];
	[originalImage retain];
	[_originalImage release];
	_originalImage = originalImage;
}


- (void)setMosaicImage:(NSImage *)mosaicImage
{
	if (_mosaicImage != mosaicImage && _viewMode != _viewTilesOutline)
		[self setNeedsDisplay:YES];
	[mosaicImage retain];
	[_mosaicImage release];
	_mosaicImage = mosaicImage;
}


- (void)setViewMode:(MosaicViewMode)mode
{
	if (_viewMode != mode)
		[self setNeedsDisplay:YES];
	_viewMode = mode;
}


- (MosaicViewMode)viewMode
{
    return _viewMode;
}


- (void)mouseDown:(NSEvent *)theEvent
{
    BOOL keepOn = YES;
    NSPoint mouseLoc;

	switch (_viewMode)
	{
		case _viewMosaic:
		case _viewTilesOutline:
		case _viewImageSources:
		case _viewImageRegions:
			break;
		case _viewHighlightedTile:
			while (keepOn)
			{
				theEvent = [[self window] nextEventMatchingMask: NSLeftMouseUpMask];
				if ([theEvent type] == NSLeftMouseUp)
				{
					mouseLoc = [self convertPoint:[theEvent locationInWindow] fromView:nil];
					if ([self mouse:mouseLoc inRect:[self bounds]])
						[(MacOSaiXDocument *)[[self window] delegate] selectTileAtPoint:mouseLoc];
					keepOn = NO;
				}
			}
			break;
	}
	
    return;
}


- (void)drawRect:(NSRect)theRect
{
	if (_viewMode == _viewTilesOutline || _viewMode == _viewImageRegions)
		[_originalImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [_originalImage size].width,
																	 [_originalImage size].height)
						 operation:NSCompositeCopy fraction:1.0];
	else
		[_mosaicImage drawInRect:[self bounds] fromRect:NSMakeRect(0, 0, [_mosaicImage size].width,
																   [_mosaicImage size].height)
					   operation:NSCompositeCopy fraction:1.0];
	
	switch (_viewMode)
	{
		case _viewMosaic:
			break;

		case _viewTilesOutline:
			if (_tilesOutline)
			{
				NSAffineTransform	*transform;
				
				transform = [NSAffineTransform transform];
				[transform translateXBy:0.5 yBy:-0.5];
				[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
				[[NSColor colorWithCalibratedWhite:0.0 alpha: 0.5] set];	// darken
				[[transform transformBezierPath:_tilesOutline] stroke];
			
				transform = [NSAffineTransform transform];
				[transform translateXBy:-0.5 yBy:0.5];
				[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
				[[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];	// lighten
				[[transform transformBezierPath:_tilesOutline] stroke];
			}
			break;
			
		case _viewImageSources:
		case _viewImageRegions:
			break;

		case _viewHighlightedTile:
			if (_highlightedTile != nil)
			{
				NSAffineTransform	*transform = [NSAffineTransform transform];
				NSBezierPath		*bezierPath;
				float				dashes[2] = {5.0, 5.0};
				
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
			break;
	}
}


#pragma mark Tile Setup methods

- (void)setTileOutlines:(NSArray *)tileOutlines;
{
	int	index;
	
	[_tilesOutline release];
	_tilesOutline = [[NSBezierPath bezierPath] retain];
	for (index = 0; index < [tileOutlines count]; index++)
	    [_tilesOutline appendBezierPath:[tileOutlines objectAtIndex:index]];
	[self setNeedsDisplay:YES];
}


#pragma mark Highlight Tile methods

- (void)highlightTile:(Tile *)tile
{
    if (_highlightedTile != nil)
    {
	// erase any previous highlight
	NSAffineTransform	*transform = [NSAffineTransform transform];
	NSBezierPath		*bezierPath;
	
	_phase = ++_phase % 10;
	[transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
	bezierPath = [transform transformBezierPath:[_highlightedTile outline]];
	[self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
										   [bezierPath bounds].origin.y - 1,
										   [bezierPath bounds].size.width + 2,
										   [bezierPath bounds].size.height + 2)];
    }
    
    _highlightedTile = tile;
}


- (void)animateHighlight
{
    NSAffineTransform	*transform = [NSAffineTransform transform];
    NSBezierPath	*bezierPath;
    
    _phase = ++_phase % 10;
    [transform scaleXBy:[self bounds].size.width yBy:[self bounds].size.height];
    bezierPath = [transform transformBezierPath:[_highlightedTile outline]];
    [self setNeedsDisplayInRect:NSMakeRect([bezierPath bounds].origin.x - 1,
					   [bezierPath bounds].origin.y - 1,
					   [bezierPath bounds].size.width + 2,
					   [bezierPath bounds].size.height + 2)];
}


@end
