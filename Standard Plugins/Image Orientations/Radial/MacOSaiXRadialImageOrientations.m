/*
	MacOSaiXRadialImageOrientations.m
	MacOSaiX

	Created by Frank Midgley on 6/13/07.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/

#import "MacOSaiXRadialImageOrientations.h"
#import "MacOSaiXRadialImageOrientationsEditor.h"


@implementation MacOSaiXRadialImageOrientations


+ (NSArray *)presetOrientations
{
	return [NSArray arrayWithObjects:
						[self imageOrientationsWithName:@"Explosion" 
											 focusPoint:NSMakePoint(0.5, 0.5) 
											offsetAngle:0.0], 
						[self imageOrientationsWithName:@"Implosion" 
											 focusPoint:NSMakePoint(0.5, 0.5) 
											offsetAngle:180.0], 
						[self imageOrientationsWithName:@"Sunrise" 
											 focusPoint:NSMakePoint(0.5, 0.0) 
											offsetAngle:0.0], 
						[self imageOrientationsWithName:@"Spiral" 
											 focusPoint:NSMakePoint(0.5, 0.5) 
											offsetAngle:-45.0], 
						nil];
}


+ (MacOSaiXRadialImageOrientations *)imageOrientationsWithName:(NSString *)presetName
													focusPoint:(NSPoint)point 
												   offsetAngle:(float)angle
{
	MacOSaiXRadialImageOrientations	*imageOrientations = [[self alloc] init];
	
	[imageOrientations setName:presetName];
	[imageOrientations setFocusPoint:point];
	[imageOrientations setOffsetAngle:angle];
	
	return [imageOrientations autorelease];
}


- (id)init
{
	if (self = [super init])
	{
		[self setName:@"Explosion"];
		[self setFocusPoint:NSMakePoint(0.5, 0.5)];
	}
	
	return self;
}


- (BOOL)settingsAreValid
{
	return YES;
}


+ (NSString *)settingsExtension
{
	return @"plist";
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithFloat:focusPoint.x], @"Focus Point X", 
								[NSNumber numberWithFloat:focusPoint.y], @"Focus Point Y", 
								[NSNumber numberWithFloat:[self offsetAngle]], @"Offset Angle", 
								[self name], @"Name", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	float			focusPointX = [[settings objectForKey:@"Focus Point X"] floatValue], 
					focusPointY = [[settings objectForKey:@"Focus Point Y"] floatValue];

// TBD: restrict the focus point to be inside the mosaic?
//	if (focusPointX >= 0.0 && focusPointX <= 1.0 && focusPointY >= 0.0 && focusPointY <= 1.0)
		[self setFocusPoint:NSMakePoint(focusPointX, focusPointY)];
	
	[self setOffsetAngle:[[settings objectForKey:@"Offset Angle"] floatValue]];
	
	[self setName:[settings objectForKey:@"Name"]];
	
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
	return NSLocalizedString([self name], @"");
}


- (void)setName:(NSString *)string
{
	[name release];
	name = [string retain];
}


- (NSString *)name
{
	return name;
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


- (void)setNameFocusPointAngle:(NSDictionary *)dictionary
{
	[self setName:[dictionary objectForKey:@"Name"]];
	[self setFocusPoint:[[dictionary objectForKey:@"Focus Point"] pointValue]];
	[self setOffsetAngle:[[dictionary objectForKey:@"Offset Angle"] floatValue]];
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
