#import "NewMacOSaiXDocument.h"
#import "MacOSaiXDocument.h"
#import "DirectoryImageSource.h"
#import "GoogleImageSource.h"

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
    _tilesWide = [tilesAcrossStepper intValue];
    _tilesHigh = [tilesDownStepper intValue];
    [self createTileOutlines];

    _previewImage = [[NSImage alloc] initWithSize:[previewView bounds].size];
    [self updatePreview];

    _imageSources = [[NSMutableArray arrayWithCapacity:0] retain];
    [_imageSources addObject:[[DirectoryImageSource alloc]
			      initWithObject:[NSHomeDirectory() stringByAppendingString:@"/Pictures"]]];
    
    [imageSourcesView setDataSource:self];
    [[imageSourcesView tableColumnWithIdentifier:@"type"] setDataCell:[[NSImageCell alloc] init]];
}


- (void)chooseOriginalImage:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:YES];
    [oPanel setCanChooseDirectories:NO];
    // prompt the user for the image to make a mosaic from
    [oPanel beginSheetForDirectory:[NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"]
			      file:nil
			     types:[NSImage imageFileTypes]
		    modalForWindow:[self window]
		     modalDelegate:self
		    didEndSelector:@selector(chooseOriginalImageOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)chooseOriginalImageOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    if (returnCode != NSOKButton) return;

    _originalImage = [[NSImage alloc] initWithContentsOfFile: [[sheet filenames] objectAtIndex:0]];
    NSAssert([_originalImage isValid], @"Original image invalid");
    [_originalImage setDataRetained:YES];
    [_originalImage setScalesWhenResized:YES];
    
    [self updatePreview];
    
    [goButton setEnabled:YES];
}


- (void)addDirectoryImageSource:(id)sender
{
    NSOpenPanel		*oPanel = [NSOpenPanel openPanel];
    
    [oPanel setCanChooseFiles:NO];
    [oPanel setCanChooseDirectories:YES];
    [oPanel beginSheetForDirectory:NSHomeDirectory()
			      file:nil
			     types:nil
		    modalForWindow:[self window]
		     modalDelegate:self
		    didEndSelector:@selector(addDirectoryImageSourceOpenPanelDidEnd:returnCode:contextInfo:)
		       contextInfo:nil];
}


- (void)addDirectoryImageSourceOpenPanelDidEnd:(NSOpenPanel *)sheet returnCode:(int)returnCode
    contextInfo:(void *)context
{
    if (returnCode != NSOKButton) return;

    [_imageSources addObject:[[DirectoryImageSource alloc]
			      initWithObject:[[sheet filenames] objectAtIndex:0]]];
}


- (void)addGoogleImageSource:(id)sender
{
    [NSApp beginSheet:googleTermPanel
       modalForWindow:[self window]
	modalDelegate:nil
       didEndSelector:nil
	  contextInfo:nil];
}


- (void)cancelAddGoogleImageSource:(id)sender;
{
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
}


- (void)okAddGoogleImageSource:(id)sender;
{
    [_imageSources addObject:[[GoogleImageSource alloc] initWithObject:[googleTermField stringValue]]];
    [NSApp endSheet:googleTermPanel];
    [googleTermPanel orderOut:nil];
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
    NSString	*title = [tileShapesPopup titleOfSelectedItem];
    int		i;
    
    if ([title isEqualToString:@"Rectangles"])
        [self createRectangleTiles];
    else if ([title isEqualToString:@"Hexagons"])
        [self createHexagonalTiles];
    if (_mergedOutlines != nil) [_mergedOutlines release];
    _mergedOutlines = [[NSBezierPath bezierPath] retain];
    for (i = 0; i < [_tileOutlines count]; i++)
	[_mergedOutlines appendBezierPath:[_tileOutlines objectAtIndex:i]];
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
	    [tileOutline moveToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
						 MIN(MAX(originY, 0) , 1))];
	    [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
						 MIN(MAX(originY, 0) , 1))];
	    [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize * 4 / 3, 0) , 1),
						 MIN(MAX(originY + ySize / 2, 0) , 1))];
	    [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize, 0) , 1),
						 MIN(MAX(originY + ySize, 0) , 1))];
	    [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX + xSize / 3, 0) , 1),
						 MIN(MAX(originY + ySize, 0) , 1))];
	    [tileOutline lineToPoint:NSMakePoint(MIN(MAX(originX, 0) , 1),
						 MIN(MAX(originY + ySize / 2, 0) , 1))];
	    [tileOutline closePath];
	    [_tileOutlines addObject:tileOutline];
	}
    
}


- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [_imageSources count];
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn
	    row:(int)rowIndex
{
    if ([[aTableColumn identifier] isEqualToString:@"type"])
	return [[_imageSources objectAtIndex:rowIndex] typeImage];
    else
	return [[_imageSources objectAtIndex:rowIndex] descriptor];
}


- (void)removeImageSource:(id)sender
{
    int		i;
    
    for (i = [_imageSources count] - 1; i >= 0; i--)
	if ([imageSourcesView isRowSelected:i])
	    [_imageSources removeObjectAtIndex:i];
    [imageSourcesView reloadData];
}


- (void)setCropLimit:(id)sender
{
    
}


- (void)updatePreview
{
    NSAffineTransform	*transform;
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
    [[NSColor colorWithCalibratedWhite:1.0 alpha: 0.5] set];
//    for (i = 0; i < [_tileOutlines count]; i++)
//    	[[transform transformBezierPath:[_tileOutlines objectAtIndex:i]] stroke];
    [[transform transformBezierPath:_mergedOutlines] stroke];
    [NSGraphicsContext restoreGraphicsState];

    [_previewImage unlockFocus];
    
    [previewView setImage:nil];
    [previewView setImage:_previewImage];
    
}


- (void)userCancelled:(id)sender
{
    [self close];
}


- (void)beginMacOSaiX:(id)sender
{
    MacOSaiXDocument	*newDoc;
    
    newDoc = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MacOSaiXProject"
										 display:YES];
    [newDoc setOriginalImage:_originalImage];
    [newDoc setTileOutlines:_tileOutlines];
    [newDoc setImageSources:_imageSources];
    [newDoc startMosaic:self];
    [self close];
}


- (void)dealloc
{
    if (_originalImage != nil) [_originalImage release];
    if (_previewImage != nil) [_previewImage release];
    if (_tileOutlines != nil) [_tileOutlines release];
    if (_imageSources != nil) [_imageSources release];
    [super dealloc];
}

@end
