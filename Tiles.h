//
//  Tiles.h
//  MacOSaiX
//
//  Created by fmidgley on Mon Apr 11 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface Tile : NSObject
{
    NSBezierPath	*_outline;
    NSBitmapImageRep	*_bitmapRep;
    NSMutableArray	*_matches;
}

- (void)setOutline:(NSBezierPath *)outline;
- (NSBezierPath *)outline;
- (void)setBitmapRep:(NSBitmapImageRep *)data;
- (NSBitmapImageRep *)bitmapRep;
- (void)addMatchingFile:(NSString *)filePath withValue:(double)matchValue;

@end
