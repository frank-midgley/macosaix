//
//  TileMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface TileMatch : NSObject {
    NSString*		_filePath;	// where the file is located
    NSBitmapImageRep*	_bitmapRep;	// low res version of file's image
    double		_matchValue;	// how well this image matched the tile
}

- (id)init;
- (void)setFilePath:(NSString *)filePath;
- (NSString *)filePath;
- (void)setBitmapRep:(NSBitmapImageRep *)bitmapRep;
- (NSBitmapImageRep *)bitmapRep;
- (void)setMatchValue:(double)matchValue;
- (double)matchValue;
- (void)dealloc;

@end
