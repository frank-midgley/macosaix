//
//  MacOSaiXSpiralTileShapes.m
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Jan 23 2003.
//  Copyright (c) 2003-2004 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXSpiralTileShapes.h"
#import "MacOSaiXSpiralTileShapesEditor.h"


@implementation MacOSaiXSpiralTileShape


+ (MacOSaiXSpiralTileShape *)tileShapeWithOutline:(NSBezierPath *)inOutline orientation:(NSNumber *)angle
{
	return [[[MacOSaiXSpiralTileShape alloc] initWithOutline:inOutline orientation:angle] autorelease];
}


- (id)initWithOutline:(NSBezierPath *)inOutline orientation:(NSNumber *)angle
{
	if (self = [super init])
	{
		outline = [inOutline retain];
		orientation = [angle retain];
	}
	
	return self;
}


- (NSBezierPath *)outline
{
	return outline;
}


- (NSNumber *)imageOrientation
{
	return orientation;
}


- (void)dealloc
{
	[outline release];
	[orientation release];
	
	[super dealloc];
}


@end


@implementation MacOSaiXSpiralTileShapes


- (id)init
{
	if (self = [super init])
	{
		NSDictionary	*plugInDefaults = [[NSUserDefaults standardUserDefaults] objectForKey:@"Spiral Tile Shapes"];
		
		if (plugInDefaults)
		{
			[self setSpiralTightness:[[plugInDefaults objectForKey:@"Spiral Tightness"] floatValue]];
			[self setTileAspectRatio:[[plugInDefaults objectForKey:@"Tile Aspect Ratio"] floatValue]];
			[self setImagesFollowSpiral:[[plugInDefaults objectForKey:@"Images Follow Spiral"] boolValue]];
		}
		else
		{
			[self setSpiralTightness:0.03];
			[self setTileAspectRatio:4.0 / 3.0];
			[self setImagesFollowSpiral:YES];
		}
	}
	
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
	MacOSaiXSpiralTileShapes	*copy = [[MacOSaiXSpiralTileShapes allocWithZone:zone] init];
	
	[copy setSpiralTightness:[self spiralTightness]];
	[copy setTileAspectRatio:[self tileAspectRatio]];
	
	return copy;
}


- (NSImage *)image
{
	return [[self class] image];
}


- (void)setSpiralTightness:(float)count
{
	spiralTightness = count;
}


- (float)spiralTightness
{
	return spiralTightness;
}


- (void)setTileAspectRatio:(float)aspectRatio
{
	tileAspectRatio = aspectRatio;
}


- (float)tileAspectRatio
{
	return tileAspectRatio;
}


- (void)setImagesFollowSpiral:(BOOL)flag
{
	imagesFollowSpiral = flag;
}


- (BOOL)imagesFollowSpiral
{
	return imagesFollowSpiral;
}


- (id)briefDescription
{
	return NSLocalizedString(@"spiral tiles", @"");
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
	NSMutableDictionary	*settings =[NSMutableDictionary dictionary];
	
	[settings setObject:[NSNumber numberWithFloat:[self spiralTightness]] forKey:@"Spiral Tightness"];
	[settings setObject:[NSNumber numberWithFloat:[self tileAspectRatio]] forKey:@"Tile Aspect Ratio"];
	[settings setObject:[NSNumber numberWithBool:[self imagesFollowSpiral]] forKey:@"Images Follow Spiral"];

	return [settings writeToFile:path atomically:NO];
}


- (BOOL)loadSettingsFromFileAtPath:(NSString *)path
{
	NSDictionary	*settings = [NSDictionary dictionaryWithContentsOfFile:path];

	[self setSpiralTightness:[[settings objectForKey:@"Spiral Tightness"] floatValue]];
	[self setTileAspectRatio:[[settings objectForKey:@"Tile Aspect Ratio"] floatValue]];
	[self setImagesFollowSpiral:[[settings objectForKey:@"Images Follow Spiral"] boolValue]];

	return YES;
}


- (NSArray *)shapesForMosaicOfSize:(NSSize)mosaicSize
{
	NSMutableArray	*tileOutlines = [NSMutableArray array];
	NSRect			mosaicBounds = NSMakeRect(0.0, 0.0, mosaicSize.width, mosaicSize.height);
	float			midX = mosaicSize.width / 2.0, 
					midY = mosaicSize.height / 2.0, 
					maxRadius = sqrtf(midX * midX + midY * midY), 
					radiusIncrement = maxRadius * [self spiralTightness], 
					radius = 0.0, 
					angle = 0.0;
	
		// Add the custom inner shape
	NSBezierPath	*innerShape = [NSBezierPath bezierPath];
	[innerShape moveToPoint:NSMakePoint(midX, midY)];
	while (angle <= 2.0 * M_PI)
	{
		float	radius = radiusIncrement * angle / 2.0 / M_PI;
		
		[innerShape lineToPoint:NSMakePoint(midX + radius * cos(angle), midY + radius * sin(angle))];
		
		angle += 2.0 * M_PI / 360.0;
	}
	[innerShape lineToPoint:NSMakePoint(midX, midY)];
	[tileOutlines addObject:[MacOSaiXSpiralTileShape tileShapeWithOutline:innerShape orientation:([self imagesFollowSpiral] ? [NSNumber numberWithFloat:0.0] : nil)]];
	
	radius = 0.0;
	angle = 0.0;
	while (radius < maxRadius)
	{
		// 2*pi    2*pi*r
		// ---- =? ------
		//  a       Rinc 
		
		float			tileAngle = (radius == 0.0 ? 2.0 * sqrtf(M_PI) : radiusIncrement / radius * tileAspectRatio), 
						nextRadius = radius + radiusIncrement * (tileAngle / 2 / M_PI), 
						nextAngle = angle + tileAngle, 
						midAngle = angle + tileAngle / 2.0;
		NSPoint			innerMidPoint = NSMakePoint(midX + (radius + nextRadius + radiusIncrement * .03)  / 2.0 * cos(midAngle), 
													midY + (radius + nextRadius + radiusIncrement * .03)  / 2.0 * sin(midAngle)), 
						outerMidPoint = NSMakePoint(midX + ((radius + nextRadius) / 2.0 + radiusIncrement * 1.03) * cos(midAngle), 
													midY + ((radius + nextRadius) / 2.0 + radiusIncrement * 1.03)  * sin(midAngle));
		NSBezierPath	*tileOutline = [NSBezierPath bezierPath];
		
		[tileOutline moveToPoint:NSMakePoint(midX + radius * cos(angle), midY + radius * sin(angle))];
		[tileOutline lineToPoint:NSMakePoint(midX + (radius + radiusIncrement) * cos(angle), midY + (radius + radiusIncrement) * sin(angle))];
		if (YES)
		{
			int		segments = tileAngle * 360.0 / 2.0 / M_PI;
			if (segments < 2)
				segments = 2;
			float	fractionIncrement = 1.0 / segments, 
					fraction;
			for (fraction = fractionIncrement; fraction <= 1.0 + fractionIncrement / 10.0; fraction += fractionIncrement)
			{
				float	segmentAngle = angle + tileAngle * fraction, 
						segmentRadius = (radius + radiusIncrement) + (nextRadius - radius) * fraction;
				
				[tileOutline lineToPoint:NSMakePoint(midX + segmentRadius * cos(segmentAngle), midY + segmentRadius * sin(segmentAngle))];
			}
		}
		else
			[tileOutline curveToPoint:NSMakePoint(midX + (nextRadius + radiusIncrement) * cos(nextAngle), midY + (nextRadius + radiusIncrement) * sin(nextAngle)) 
						controlPoint1:outerMidPoint
						controlPoint2:outerMidPoint];
		[tileOutline lineToPoint:NSMakePoint(midX + nextRadius * cos(nextAngle), midY + nextRadius * sin(nextAngle))];
		if (YES)
		{
			int		segments = tileAngle * 360.0 / 2.0 / M_PI;
			if (segments < 2)
				segments = 2;
			float	fractionIncrement = 1.0 / segments, 
					fraction;
			for (fraction = 1.0 - fractionIncrement; fraction >= 0.0; fraction -= fractionIncrement)
			{
				float	segmentAngle = angle + tileAngle * fraction, 
						segmentRadius = radius + (nextRadius - radius) * fraction;
				
				[tileOutline lineToPoint:NSMakePoint(midX + segmentRadius * cos(segmentAngle), midY + segmentRadius * sin(segmentAngle))];
			}
		}
		else
			[tileOutline curveToPoint:NSMakePoint(midX + radius * cos(angle), midY + radius * sin(angle)) 
						controlPoint1:innerMidPoint
						controlPoint2:innerMidPoint];
		[tileOutline closePath];
		
		float			orientation = midAngle / M_PI * -180.0 + 90.0;

		if (NSIntersectsRect([tileOutline bounds], mosaicBounds))
			[tileOutlines addObject:[MacOSaiXSpiralTileShape tileShapeWithOutline:tileOutline orientation:([self imagesFollowSpiral] ? [NSNumber numberWithFloat:orientation] : nil)]];
		
		radius = nextRadius;
		angle = nextAngle;
	}

	return tileOutlines;
}


@end
