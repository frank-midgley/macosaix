//
//  NSBezierPath+MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/9/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath (MacOSaiX)

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)rect radius:(float)radius;

- (CGPathRef)quartzPath;

@end
