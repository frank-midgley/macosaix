//
//  NSString+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/6/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "NSString+MacOSaiX.h"


@implementation NSString(MacOSaiX)


+ (NSString *)stringByEscapingXMLEntites:(NSString *)string
{
	NSMutableString	*escapedString = [NSMutableString stringWithString:(string ? string : @"")];
	
	[escapedString replaceOccurrencesOfString:@"&" withString:@"&amp;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"<" withString:@"&lt;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@">" withString:@"&gt;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"'" withString:@"&apos;" options:0 range:NSMakeRange(0, [escapedString length])];
	[escapedString replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:0 range:NSMakeRange(0, [escapedString length])];
	
	return [NSString stringWithString:escapedString];
}


+ (NSString *)stringByUnescapingXMLEntites:(NSString *)string
{
	NSMutableString	*unescapedString = [NSMutableString stringWithString:(string ? string : @"")];
	
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
		
		float	curDiff = fabsf(aspectRatio - (float)xInt / (float)yInt);
		
		if (curDiff < minDiff)
		{
			minDiff = curDiff;
			ratioString = [NSString stringWithFormat:@"%dx%d", xInt, yInt];
		}
	}
	
	return ratioString;
}


@end
