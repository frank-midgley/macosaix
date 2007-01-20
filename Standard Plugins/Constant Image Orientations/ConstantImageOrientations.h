/*
	ConstantImageOrientations.h
	MacOSaiX

	Created by Frank Midgley on Dec 07 2006.
	Copyright (c) 2006 Frank M. Midgley. All rights reserved.
*/


@interface MacOSaiXConstantImageOrientations : NSObject <MacOSaiXImageOrientations>
{
	float	constantAngle;
}

- (void)setConstantAngle:(float)angle;
- (float)constantAngle;

@end
