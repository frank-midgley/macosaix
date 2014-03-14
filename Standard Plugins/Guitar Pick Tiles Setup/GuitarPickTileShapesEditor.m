//
//  GuitarPickTileShapesController.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GuitarPickTileShapesEditor.h"
#import "NSString+MacOSaiX.h"


@implementation MacOSaiXGuitarPickTileShapesEditor


+ (NSString *)name
{
	return @"Guitar Picks";
}


- (id)initWithOriginalImage:(NSImage *)originalImage
{
	if (self = [super init])
	{
		originalImageSize = [originalImage size];
	}
	
	return self;
}


- (NSView *)editorView
{
	if (!editorView)
		[NSBundle loadNibNamed:@"GuitarPickTileShapes" owner:self];
	
	return editorView;
}


- (NSSize)minimumSize
{
	return NSMakeSize(270.0, 211.0);
}


- (NSResponder *)firstResponder
{
	return rowCountSlider;
}


- (void)updatePlugInDefaults
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionaryWithObjectsAndKeys:
														[NSNumber numberWithInt:[currentTileShapes rowCount]], @"Row Count", 
														nil]
											  forKey:@"Guitar Pick Tile Shapes"];
}


- (void)editTileShapes:(id<MacOSaiXTileShapes>)tilesSetup
{
	[currentTileShapes autorelease];
	currentTileShapes = [tilesSetup retain];
	
	// TODO: pass the original image aspect ratio to currentTileShapes?
}


- (IBAction)setRowCount:(id)sender
{
	int			rowCount = [sender intValue];
	
    [currentTileShapes setRowCount:rowCount aspectRatio:originalImageSize.width / originalImageSize.height];
    [rowCountTextField setIntValue:rowCount];
	if (sender == rowCountSlider)
		[rowCountStepper setIntValue:rowCount];
	else
		[rowCountSlider setIntValue:rowCount];
	
	[self updatePlugInDefaults];
	
	[[editorView window] sendEvent:nil];
}


- (BOOL)settingsAreValid
{
	return YES;
}


- (int)tileCount
{
	return [currentTileShapes rowCount] * [currentTileShapes aspectRatio] * 2;
}


- (NSBezierPath *)previewPath
{
	NSBezierPath	*downTilePath = [NSBezierPath bezierPath];
	float			unitSize = 1.0 / 7;
	
	[downTilePath moveToPoint:NSMakePoint(0.0            , 0.0)];
	[downTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 3.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(3.0 * unitSize , 6.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(0.0            , 7.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 6.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(-3.0 * unitSize, 3.0 * unitSize)];
	[downTilePath lineToPoint:NSMakePoint(0.0            , 0.0)];
	
	return downTilePath;
}


- (void)editingComplete
{
	[currentTileShapes release];
}


- (void)dealloc
{
	[editorView release];	// we are responsible for releasing any top-level objects in the nib
	
	[super dealloc];
}


@end
