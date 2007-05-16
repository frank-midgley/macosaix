//
//  NSImage+MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on 11/13/04.
//  Copyright 2004 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (MacOSaiX)

- (NSImage *)copyWithLargestDimension:(int)size;

@end
