//
//  MacOSaiXImageUsageEditor.m
//  MacOSaiX
//
//  Created by Frank Midgley on 12/22/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXImageUsageEditor.h"

#import "MacOSaiXMosaic.h"


@implementation MacOSaiXImageUsageEditor


- (id)initWithDelegate:(id<MacOSaiXMosaicEditorDelegate>)delegate
{
	if (self = [super initWithDelegate:delegate])
	{
		startAngle = 0.0;
	}
	
	return self;
}


- (NSString *)editorNibName
{
	return @"Image Usage Editor";
}


- (NSString *)title
{
	return NSLocalizedString(@"Image Usage", @"");
}


- (NSSize)minimumViewSize
{
	return NSMakeSize(230.0, 269.0);
}


- (void)configureImageCropMatrix
{
	NSRect	matrixBounds = [imageCropMatrix bounds];
	int		cellCount = (NSWidth(matrixBounds) + 2.0) / (16.0 + [imageCropMatrix intercellSpacing].width), 
			cellIndex;
	float	cellMidPoint = (cellCount + 1.0) / 2.0;
	
	[imageCropMatrix renewRows:1 columns:cellCount];
	
	for (cellIndex = 1; cellIndex <= cellCount; cellIndex++)
	{
		NSImage	*cropImage = [[[NSImage alloc] initWithSize:NSMakeSize(16.0, 16.0)] autorelease];
		float	cellCropAmount = fabsf(cellMidPoint - cellIndex) / cellMidPoint;
		
		[cropImage lockFocus];
			[[NSColor clearColor] set];
			NSRectFill(NSMakeRect(0.0, 0.0, 16.0, 16.0));
			[[NSColor darkGrayColor] set];
			NSRectFill(NSMakeRect(0.0, 2.0, 16.0, 12.0));
			
			[[NSColor lightGrayColor] set];
			
			if (cellIndex < cellMidPoint)
			{
				float	rectHeight = 12.0 * (1.0 - cellCropAmount);
				
				NSRectFill(NSMakeRect(0.0, 8.0 - rectHeight / 2.0, 16.0, rectHeight));
			}
			else
			{
				float	rectWidth = 16.0 * (1.0 - cellCropAmount);
				
				NSRectFill(NSMakeRect(8.0 - rectWidth / 2.0, 2.0, rectWidth, 12.0));
			}
			
//			NSBezierPath	*badgePath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8.0, 0.0, 8.0, 8.0)];
			NSBezierPath	*badgePath = [NSBezierPath bezierPath];
			[badgePath setLineCapStyle:NSRoundLineCapStyle];
			NSColor			*badgeColor = nil;
			if (cellCropAmount * 100.0 <= [[[self delegate] mosaic] imageCropLimit])
			{
//				[[[NSColor greenColor] highlightWithLevel:0.25] set];
//				[badgePath fill];
//				[[[NSColor greenColor] shadowWithLevel:0.75] set];
//				[badgePath stroke];
				[badgePath moveToPoint:NSMakePoint(6.0, 5.0)];
				[badgePath lineToPoint:NSMakePoint(9.0, 2.0)];
				[badgePath lineToPoint:NSMakePoint(14.0, 10.0)];
				badgeColor = [NSColor greenColor];
			}
			else
			{
//				[[[NSColor redColor] highlightWithLevel:0.25] set];
//				[badgePath fill];
//				[[[NSColor redColor] shadowWithLevel:0.75] set];
//				[badgePath stroke];
				[badgePath moveToPoint:NSMakePoint(7.0, 2.0)];
				[badgePath lineToPoint:NSMakePoint(14.0, 9.0)];
				[badgePath moveToPoint:NSMakePoint(7.0, 9.0)];
				[badgePath lineToPoint:NSMakePoint(14.0, 2.0)];
				badgeColor = [NSColor redColor];
			}
			[badgePath setLineWidth:3.0];
			[[badgeColor shadowWithLevel:0.75] set];
			[badgePath stroke];
			[badgePath setLineWidth:2.0];
			[[badgeColor highlightWithLevel:0.25] set];
			[badgePath stroke];
		[cropImage unlockFocus];
		
		NSImageCell	*imageCell = [imageCropMatrix cellAtRow:0 column:cellIndex - 1];
		[imageCell setImage:cropImage];
		[imageCropMatrix setToolTip:[NSString stringWithFormat:@"%.0f%%", cellCropAmount * 100.0] forCell:imageCell];
	}
}


- (void)matrixFrameDidChange:(NSNotification *)notification
{
	NSRect	matrixBounds = [imageCropMatrix bounds];
	int		cellCount = (NSWidth(matrixBounds) + 2.0) / (16.0 + [imageCropMatrix intercellSpacing].width);
	
	if (cellCount != [imageCropMatrix numberOfColumns])
		[self configureImageCropMatrix];
}


- (void)beginEditing
{
	[super beginEditing];
	
	MacOSaiXMosaic	*mosaic = [[self delegate] mosaic];
	
	[imageUseCountPopUp selectItemWithTag:[mosaic imageUseCount]];
	[imageReuseSlider setIntValue:[mosaic imageReuseDistance]];
	[imageCropLimitSlider setIntValue:[mosaic imageCropLimit]];
	
	samplePoint = NSMakePoint(0.5, 0.5);
	
	[self configureImageCropMatrix];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(matrixFrameDidChange:) 
												 name:NSViewFrameDidChangeNotification 
											   object:imageCropMatrix];
}


- (void)embellishMosaicView:(MosaicView *)mosaicView inRect:(NSRect)rect;
{
	[super embellishMosaicView:mosaicView inRect:rect];
	
	[[NSGraphicsContext currentContext] saveGraphicsState];
	
	NSRect				imageBounds = [mosaicView imageBounds];
	[[NSBezierPath bezierPathWithRect:imageBounds] addClip];
	
	float				radius = sqrtf(powf(NSWidth(imageBounds), 2.0) + powf(NSHeight(imageBounds), 2.0)) * [imageReuseSlider floatValue] / 100.0;
	NSPoint				scaledSamplePoint = NSMakePoint(samplePoint.x * NSWidth(imageBounds) + NSMinX(imageBounds), 
														samplePoint.y * NSHeight(imageBounds) + NSMinY(imageBounds));
	NSAffineTransform	*transform = [NSAffineTransform transform];
	[transform translateXBy:scaledSamplePoint.x yBy:scaledSamplePoint.y];
	[transform concat];
	
//	[[NSGraphicsContext currentContext] setPatternPhase:scaledSamplePoint];
	
	NSBezierPath		*uniquenessPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-radius, -radius, radius * 2.0, radius * 2.0)];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:0.25] set];
	[uniquenessPath fill];
//	[[NSColor colorWithPatternImage:[NSImage imageNamed:@"UniqueX"]] set];
//	[uniquenessPath fill];
	[[NSColor darkGrayColor] set];
	[uniquenessPath stroke];
		
//	NSBezierPath		*samplePointPath = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-5.0, -5.0, 10.0, 10.0)];
//	[[NSColor whiteColor] set];
//	[samplePointPath fill];
//	[[NSColor darkGrayColor] set];
//	[samplePointPath stroke];
	
	static	NSBezierPath	*vectorPath = nil;
	if (!vectorPath)
	{
		vectorPath = [[NSBezierPath bezierPath] retain];
		
		// Start with the head.
		//NSMakeRect(-4.0, -5.0, 8.0, 12.0)
		[vectorPath moveToPoint:NSMakePoint(0.0, -4.0)];
		[vectorPath curveToPoint:NSMakePoint(0.0, 7.0) controlPoint1:NSMakePoint(-5.0, -4.0) controlPoint2:NSMakePoint(-5.0, 7.0)];
		[vectorPath curveToPoint:NSMakePoint(0.0, -4.0) controlPoint1:NSMakePoint(5.0, 7.0) controlPoint2:NSMakePoint(5.0, -4.0)];
		
		// Then the shoulders.
		[vectorPath moveToPoint:NSMakePoint(-8.0, -7.0)];
		[vectorPath curveToPoint:NSMakePoint(8.0, -7.0) controlPoint1:NSMakePoint(-8.0, -2.0) controlPoint2:NSMakePoint(8.0, -2.0)];
		[vectorPath lineToPoint:NSMakePoint(-8.0, -7.0)];
		
		// Finish with the box outline.
		[vectorPath moveToPoint:NSMakePoint(-12.0, -8.0)];
		[vectorPath lineToPoint:NSMakePoint(12.0, -8.0)];
		[vectorPath lineToPoint:NSMakePoint(12.0, 8.0)];
		[vectorPath lineToPoint:NSMakePoint(-12.0, 8.0)];
		[vectorPath lineToPoint:NSMakePoint(-12.0, -8.0)];
	}
	
	float	angle = startAngle;
	while (angle < startAngle + M_PI * 2.0)
	{
		if (radius > 40.0)
		{
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:(radius - 15.0) * cosf(angle) yBy:(radius - 15.0) * sinf(angle)];
			[transform concat];
			
			[[NSColor whiteColor] set];
			[vectorPath fill];
			[[NSColor blackColor] set];
			[vectorPath stroke];
			
			NSBezierPath	*badgePath = [NSBezierPath bezierPath];
			[badgePath moveToPoint:NSMakePoint(4.0, -7.0)];
			[badgePath lineToPoint:NSMakePoint(11.0, 0.0)];
			[badgePath moveToPoint:NSMakePoint(4.0, 0.0)];
			[badgePath lineToPoint:NSMakePoint(11.0, -7.0)];
			[badgePath setLineWidth:3.0];
			[[[NSColor redColor] shadowWithLevel:0.75] set];
			[badgePath stroke];
			[badgePath setLineWidth:2.0];
			[[[NSColor redColor] highlightWithLevel:0.25] set];
			[badgePath stroke];

			[[NSGraphicsContext currentContext] restoreGraphicsState];
		}
		
		{
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
			NSAffineTransform	*transform = [NSAffineTransform transform];
			[transform translateXBy:(radius + 15.0) * cosf(angle) yBy:(radius + 15.0) * sinf(angle)];
			[transform concat];
			
			[[NSColor whiteColor] set];
			[vectorPath fill];
			[[NSColor blackColor] set];
			[vectorPath stroke];
			
			NSBezierPath	*badgePath = [NSBezierPath bezierPath];
			[badgePath moveToPoint:NSMakePoint(3.0, -4.0)];
			[badgePath lineToPoint:NSMakePoint(6.0, -7.0)];
			[badgePath lineToPoint:NSMakePoint(11.0, 1.0)];
			[badgePath setLineWidth:3.0];
			[[[NSColor greenColor] shadowWithLevel:0.75] set];
			[badgePath stroke];
			[badgePath setLineWidth:2.0];
			[[[NSColor greenColor] highlightWithLevel:0.25] set];
			[badgePath stroke];

			[[NSGraphicsContext currentContext] restoreGraphicsState];
		}
		
		angle += M_PI / 3.0;
	}
	
	[[NSColor whiteColor] set];
	[vectorPath fill];
	[[NSColor blackColor] set];
	[vectorPath stroke];
	
	[[NSGraphicsContext currentContext] restoreGraphicsState];
}


- (void)handleEvent:(NSEvent *)event inMosaicView:(MosaicView *)mosaicView;
{
	NSRect	imageBounds = [mosaicView imageBounds];
	NSPoint	mouseLocation = [mosaicView convertPoint:[event locationInWindow] fromView:nil], 
			scaledSamplePoint = NSMakePoint(samplePoint.x * NSWidth(imageBounds), 
											samplePoint.y * NSHeight(imageBounds));
	
	if ([event type] == NSLeftMouseDown)
	{
		float	maxDragDistance = sqrtf(powf(NSWidth(imageBounds), 2.0) + 
										powf(NSHeight(imageBounds), 2.0)), 
				currentReuseDistance = [[[self delegate] mosaic] imageReuseDistance] / 100.0 * maxDragDistance, 
				clickDistance = sqrtf(powf(mouseLocation.x - NSMinX(imageBounds) - scaledSamplePoint.x, 2.0) + 
									  powf(mouseLocation.y - NSMinY(imageBounds) - scaledSamplePoint.y, 2.0));
		
		if (fabsf(clickDistance) < 5.0 || clickDistance < currentReuseDistance - 5.0)
			moving = YES;
		else if (fabsf(currentReuseDistance - clickDistance) < 5.0)
			resizing = YES;
	}
	else if ([event type] == NSLeftMouseDragged)
	{
		if (moving)
		{
			samplePoint = NSMakePoint((mouseLocation.x - NSMinX(imageBounds)) / NSWidth(imageBounds), 
									  (mouseLocation.y - NSMinY(imageBounds)) / NSHeight(imageBounds));
			
			if (samplePoint.x < 0.0)
				samplePoint.x = 0.0;
			if (samplePoint.x > 1.0)
				samplePoint.x = 1.0;
			if (samplePoint.y < 0.0)
				samplePoint.y = 0.0;
			if (samplePoint.y > 1.0)
				samplePoint.y = 1.0;
			
			[[self delegate] embellishmentNeedsDisplay];
		}
		else if (resizing)
		{
			float	dragX = mouseLocation.x - NSMinX(imageBounds) - scaledSamplePoint.x, 
					dragY = mouseLocation.y - NSMinY(imageBounds) - scaledSamplePoint.y, 
					dragDistance = sqrtf(powf(dragX, 2.0) + powf(dragY, 2.0)), 
					maxDragDistance = sqrtf(powf(NSWidth(imageBounds), 2.0) + 
											powf(NSHeight(imageBounds), 2.0));
			
			if (dragDistance >= maxDragDistance)
				[imageReuseSlider setFloatValue:100.0];
			else
				[imageReuseSlider setFloatValue:dragDistance / maxDragDistance * 100.0];
			
			startAngle = atanf(dragY / dragX);
			
			[self setImageReuseDistance:self];
		}
	}
	else if ([event type] == NSLeftMouseUp)
	{
		moving = NO;
		resizing = NO;
	}
}


- (IBAction)setImageUseCount:(id)sender
{
	[[[self delegate] mosaic] setImageUseCount:[[imageUseCountPopUp selectedItem] tag]];
	
	[[self delegate] embellishmentNeedsDisplay];
}


- (IBAction)setImageReuseDistance:(id)sender
{
	[[[self delegate] mosaic] setImageReuseDistance:[imageReuseSlider intValue]];
	
	[[self delegate] embellishmentNeedsDisplay];
}


- (IBAction)setImageCropLimit:(id)sender
{
	[[[self delegate] mosaic] setImageCropLimit:[imageCropLimitSlider intValue]];
	
	// TODO: if (the images are going to change)
	{
		[self configureImageCropMatrix];
		
		[imageCropMatrix setNeedsDisplay:YES];
	}
}


- (void)endEditing
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:imageCropMatrix];
	
	[super endEditing];
}


@end
