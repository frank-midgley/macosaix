/*
	MacOSaiXRadialImageOrientations.m
	MacOSaiX

	Created by Frank Midgley on 6/13/07.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXRadialImageOrientations.h"
#import "MacOSaiXRadialImageOrientationsEditor.h"


@implementation MacOSaiXRadialImageOrientations


- (id)init
{
	if (self = [super init])
	{
		[self setFocusPoint:NSMakePoint(0.5, 0.5)];
	}
	
	return self;
}


- (BOOL)settingsAreValid
{
	return YES;
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithFloat:focusPoint.x], @"Focus Point X", 
								[NSNumber numberWithFloat:focusPoint.y], @"Focus Point Y", 
								[NSNumber numberWithFloat:[self offsetAngle]], @"Offset Angle", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	float			focusPointX = [[settings objectForKey:@"Focus Point X"] floatValue], 
					focusPointY = [[settings objectForKey:@"Focus Point Y"] floatValue];
	
	if (focusPointX >= 0.0 && focusPointX <= 1.0 && focusPointY >= 0.0 && focusPointY <= 1.0)
		[self setFocusPoint:NSMakePoint(focusPointX, focusPointY)];
	
	[self setOffsetAngle:[[settings objectForKey:@"Offset Angle"] floatValue]];
	
	return YES;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXRadialImageOrientations	*copy = [[MacOSaiXRadialImageOrientations allocWithZone:zone] init];
	
	[copy setFocusPoint:[self focusPoint]];
	[copy setOffsetAngle:[self offsetAngle]];
	
	return copy;
}


- (NSImage *)image;
{
	return nil;
}


- (id)briefDescription
{
	return nil;	// TBD: return preset name?
}


- (void)setFocusPoint:(NSPoint)point
{
	focusPoint = point;
}


- (NSPoint)focusPoint
{
	return focusPoint;
}


- (void)setOffsetAngle:(float)angle
{
	offsetAngle = angle;
}


- (float)offsetAngle
{
	return offsetAngle;
}


- (float)imageOrientationAtPoint:(NSPoint)point inRectOfSize:(NSSize)rectSize
{
	float	imageOrientation = 0.0;
	NSPoint	mappedFocusPoint = NSMakePoint([self focusPoint].x * rectSize.width, 
										   [self focusPoint].y * rectSize.height);
	
	if (point.x == mappedFocusPoint.x)
		imageOrientation = (point.y < mappedFocusPoint.y ? 180.0 : 0.0);
	else
	{
		imageOrientation = atanf((point.y - mappedFocusPoint.y) / (point.x - mappedFocusPoint.x));
	
		if (point.x < mappedFocusPoint.x)
			imageOrientation += M_PI;
		
		imageOrientation = imageOrientation / M_PI * -180.0 + 90.0;
	}
			
	return fmodf(imageOrientation + [self offsetAngle], 360.0);
}


@end
