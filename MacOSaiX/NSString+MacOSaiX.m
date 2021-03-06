//
//  NSString+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/6/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "NSString+MacOSaiX.h"


@implementation NSString(MacOSaiX)


- (NSString *)stringByEscapingXMLEntites
{
	NSMutableString	*escapedString = [NSMutableString stringWithString:self];
	
	[escapedString replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [escapedString length])];
	
	return [NSString stringWithString:escapedString];
}


- (NSString *)stringByUnescapingXMLEntites
{
	NSMutableString	*unescapedString = [NSMutableString stringWithString:self];
	
	[unescapedString replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&apos;" withString:@"'" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&gt;" withString:@"<" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [unescapedString length])];
	
	return [NSString stringWithString:unescapedString];
}


+ (NSString *)stringWithAspectRatio:(float)aspectRatio
{
	int			xInt,
				yInt;
	float		minDiff = INFINITY;
	NSString	*ratioString = @"";
	
	for (xInt = 1; xInt < 10; xInt++)
	{
		yInt = (xInt / aspectRatio);
		
		if (fabsf(aspectRatio - (float)xInt / (float)yInt) > 
			fabsf(aspectRatio - (float)xInt / (float)(yInt + 1)))
			yInt++;
		
		if (yInt >= 1 && yInt <= 9)
		{
			float	curDiff = fabsf(aspectRatio - (float)xInt / (float)yInt);
			
			if (curDiff < minDiff)
			{
				minDiff = curDiff;
				ratioString = [NSString stringWithFormat:@"%@%d x %d", (curDiff > 0.01 ? @"~ " : @""), xInt, yInt];
			}
		}
	}
	
	return ratioString;
}


+ (NSString *)stringWithFloat:(float)floatValue
{
	NSString	*floatString = [NSString stringWithFormat:@"%f", floatValue];
	
	while ([floatString length] > 3 && 
		   [[floatString substringFromIndex:[floatString length] - 1] isEqualToString:@"0"] && 
		   ![[floatString substringFromIndex:[floatString length] - 2] isEqualToString:@".0"])
		floatString = [floatString substringToIndex:[floatString length] - 1];
	
	return floatString;
}


@end
