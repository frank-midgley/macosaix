/*
	MacOSaiXRadialImageOrientations.h
	MacOSaiX

	Created by Frank Midgley on 6/13/07.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/


@interface MacOSaiXRadialImageOrientations : NSObject <MacOSaiXImageOrientations>
{
	NSString	*name;
	NSPoint		focusPoint;
	float		offsetAngle;
}

+ (NSArray *)presetOrientations;

+ (MacOSaiXRadialImageOrientations *)imageOrientationsWithName:(NSString *)name
													focusPoint:(NSPoint)focusPoint 
												   offsetAngle:(float)offsetAngle;

- (void)setName:(NSString *)name;
- (NSString *)name;

- (void)setFocusPoint:(NSPoint)point;
- (NSPoint)focusPoint;

- (void)setOffsetAngle:(float)angle;
- (float)offsetAngle;

@end
