/*
	DirectoryImageSource.m
	MacOSaiX

	Created by Frank Midgley on Wed Mar 13 2002.
	Copyright (c) 2002-2004 Frank M. Midgley. All rights reserved.
*/

#import "ConstantImageOrientations.h"
#import "ConstantImageOrientationsEditor.h"


@implementation MacOSaiXConstantImageOrientations


- (BOOL)settingsAreValid
{
	return YES;
}


- (BOOL)saveSettingsToFileAtPath:(NSString *)path
{
	return [[NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithFloat:[self constantAngle]], @"Constant Angle", 
								nil] 
				writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];
	
	[self setConstantAngle:[[settings objectForKey:@"Constant Angle"] floatValue]];
	
	return YES;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXConstantImageOrientations	*copy = [[MacOSaiXConstantImageOrientations allocWithZone:zone] init];
	
	[copy setConstantAngle:[self constantAngle]];
	
	return copy;
}


- (NSImage *)image;
{
	return nil;
}


- (id)briefDescription
{
	return [NSString stringWithFormat:@"%.0f degrees", [self constantAngle]];
}

- (void)setConstantAngle:(float)angle
{
	constantAngle = angle;
}


- (float)constantAngle
{
	return constantAngle;
}


- (float)imageOrientationAtPoint:(NSPoint)point inRectOfSize:(NSSize)rectSize
{
	return [self constantAngle];
}


@end
