#import "NewMacOSaiXDocument.h"
#import "MacOSaiXDocument.h"

@implementation NewMacOSaiXDocument

- (void)windowDidLoad
{
    NSBezierPath	*rectPath;
    
    // start with a flat black image
    _originalImage = [[NSImage alloc] initWithSize:NSMakeSize(200, 200)];
    [_originalImage lockFocus];
    [[NSColor blackColor] set];
    rectPath = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, 200, 200)];
    [rectPath fill];
    [_originalImage unlockFocus];
    
    // create the default tiles
    _tilesWide = _tilesHigh = 40;
    [self createTileOutlines];

    _previewImage = [[NSImage alloc] initWithSize:[previewView bounds].size];
    [self updatePreview];
}


- (void)chooseOriginalImage:(id)sender
{
    int			result;
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    // prompt the user for the image to make a mosaic from
    result = [oPanel runModalForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
	file:nil types:[NSImage imageFileTypes]];
    if (result != NSOKButton) return;

    //if (_originalImage != nil) [_originalImage release];
    _originalImage = [[NSImage alloc] initWithContentsOfFile: [[oPanel filenames] objectAtIndex:0]];
    NSAssert([_originalImage isValid], @"Original image invalid");
    [_originalImage setDataRetained:YES];
    [_originalImage setScalesWhenResized:YES];
    
    [self updatePreview];
    
    [goButton setEnabled:YES];
}


- (void)setTileShapes:(id)sender
{
    [self createTileOutlines];
    [self updatePreview];
}


- (void)setTilesAcross:(id)sender
{
    _tilesWide = [tilesAcrossStepper intValue];
    [tilesAcrossView setStringValue:[NSString stringWithFormat:@"%d", _tilesWide]];
    [self createTileOutlines];
    [self updatePreview];
}


- (void)setTilesDown:(id)sender
{
    _tilesHigh = [tilesDownStepper intValue];
    [tilesDownView setStringValue:[NSString stringWithFormat:@"%d", _tilesHigh]];
    [self createTileOutlines];
    [self updatePreview];
}


- (void)createTileOutlines
{
    NSString *title = [tileShapesPopup titleOfSelectedItem];
    
    if ([title isEqualToString:@"Rectangles"])
        [self createRectangleTiles];
    else if ([title isEqualToString:@"Hexagons"])
        [self createHexagonalTiles];
    [tilesTotal setStringValue:[NSString stringWithFormat:@"%d", [_tileOutlines count]]];
}


- (void)createRectangleTiles
{
    int			x, y;
    NSRect		tileRect = NSMakeRect(0, 0, 1.0 / _tilesWide, 1.0 / _tilesHigh);

    if (_tileOutlines != nil) [_tileOutlines release];
    _tileOutlines = [[NSMutableArray arrayWithCapacity:0] retain];
    
    for (x = 0; x < _tilesWide; x++)
	for (y = 0; y < _tilesHigh; y++)
	{
	    tileRect.origin.x = x * tileRect.size.width;
	    tileRect.origin.y = y * tileRect.size.height;
	    [_tileOutlines addObject:[[NSBezierPath bezierPathWithRect:tileRect] retain]];
	}
    
}


- (void)createHexagonalTiles
{
    int			x, y;
    float		xSize = 1.0 / (_tilesWide - 1.0/3.0), ySize = 1.0 / _tilesHigh, originX, originY;
    NSBezierPath	*tileOutline;
   
    if (_tileOutlines != nil) [_tileOutlines release];
    _tileOutlines = [[NSMutableArray arrayWithCapacity:0] retain];
    
    for (x = 0; x < _tilesWide; x++)
	for (y = 0; y < ((x % 2 == 0) ? _tilesHigh : _tilesHigh + 1); y++)
	{
	    originX = xSize * (x - 1.0/3.0);
	    originY = ySize * ((x % 2 == 0) ? y : y - 0.5);
	    tileOutline = [NSBezierPath bezierPath];
	    [tileOutline moveToPoint:NSMakePoint(originX + xSize / 3,		originY)];
	    [tileOutline lineToPoint:NSMakePoint(originX + xSize, 		originY)];
	    [tileOutline lineToPoint:NSMakePoint(originX + xSize * 4 / 3, 	originY + ySize / 2)];
	    [tileOutline lineToPoint:NSMakePoint(originX + xSize,		originY + ySize)];
	    [tileOutline lineToPoint:NSMakePoint(originX + xSize / 3,		originY + ySize)];
	    [tileOutline lineToPoint:NSMakePoint(originX,			originY + ySize / 2)];
	    [tileOutline closePath];
	    [_tileOutlines addObject:tileOutline];
	}
    
}


- (void)addImageSource:(id)sender
{
    
}


- (void)removeImageSource:(id)sender
{
    
}


- (void)setCropLimit:(id)sender
{
    
}


- (void)updatePreview
{
    NSAffineTransform	*transform, *t2;
    int			i;
    
    if ([_originalImage size].width > [_originalImage size].height)
	[_previewImage setSize:NSMakeSize([previewView bounds].size.width,
					  [previewView bounds].size.width *
					  [_originalImage size].height / [_originalImage size].width)];
    else
	[_previewImage setSize:NSMakeSize([previewView bounds].size.height *
					  [_originalImage size].width / [_originalImage size].height,
					  [previewView bounds].size.height)];

    [_previewImage lockFocus];

    // start with the original image
    [_originalImage drawInRect:NSMakeRect(0, 0, [_previewImage size].width, [_previewImage size].height)
		    fromRect:NSMakeRect(0, 0, [_originalImage size].width, [_originalImage size].height)
		    operation:NSCompositeCopy fraction:1.0];
    
    // now add the outlines of the tiles
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath setDefaultLineWidth:1.0];
    transform = [NSAffineTransform transform];
    [transform translateXBy:0.5 yBy:0.5];
    [transform scaleXBy:[_previewImage size].width yBy:[_previewImage size].height];
//    t2 = [NSAffineTransform transform];
//    [t2 scaleXBy:1.0/[_previewImage size].width yBy:1.0/[_previewImage size].height];
    [[NSColor whiteColor] set];
    for (i = 0; i < [_tileOutlines count]; i++)
    	[[transform transformBezierPath:[_tileOutlines objectAtIndex:i]] stroke];
//	[[_tileOutlines objectAtIndex:i] transformUsingAffineTransform:transform];
//	[[_tileOutlines objectAtIndex:i] stroke];
//	[[_tileOutlines objectAtIndex:i] transformUsingAffineTransform:t2];
    [NSGraphicsContext restoreGraphicsState];

    [_previewImage unlockFocus];
    
    [previewView setImage:nil];
    [previewView setImage:_previewImage];
    
}


- (void)userCancelled:(id)sender
{
    if (_originalImage != nil) [_originalImage release];
    if (_previewImage != nil) [_previewImage release];
    if (_tileOutlines != nil) [_tileOutlines release];
    [self close];
}


- (void)beginMacOSaiX:(id)sender
{
    MacOSaiXDocument	*newDoc;
    
    newDoc = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MacOSaiXProject"
										 display:YES];
    [newDoc setOriginalImage:_originalImage];
    [newDoc setTileOutlines:_tileOutlines];
//    [newDoc createTileCollectionWithOutlines:_tileOutlines fromImage:_originalImage];
    [newDoc startMosaic:self];
    [self close];
}

@end
