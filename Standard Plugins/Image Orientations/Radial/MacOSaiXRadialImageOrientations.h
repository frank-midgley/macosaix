/*
	MacOSaiXRadialImageOrientations.h
	MacOSaiX

	Created by Frank Midgley on 6/13/07.
	Copyright (c) 2007 Frank M. Midgley. All rights reserved.
*/


@interface MacOSaiXRadialImageOrientations : NSObject <MacOSaiXImageOrientations>
{
	NSPoint	focusPoint;
	float	offsetAngle;
}

- (void)setFocusPoint:(NSPoint)point;
- (NSPoint)focusPoint;

- (void)setOffsetAngle:(float)angle;
- (float)offsetAngle;

@end
