//
//  TileMatch.h
//  MacOSaiX
//
//  Created by Frank Midgley on Sat Feb 02 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface TileMatch : NSObject {
    NSString*	_filePath;
    double	_matchValue;
}

- (void)setFilePath:(NSString *)filePath;
- (NSString *)filePath;
- (void)setMatchValue:(double)matchValue;
- (double)matchValue;

@end
