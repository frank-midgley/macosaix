//
//  Matcher.h
//  MacOSaiX
//
//  Created by fmidgley on Tue Mar 20 2001.
//  Copyright (c) 2001 __CompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "Protocols.h"
#import "Tiles.h"

@interface Matcher : NSObject <MatcherMethods>
{
    id <ControllerMethods>	clientProxy;
    TileCollection		*_tiles;
}

+ (void)connectWithPorts:(NSArray *)portArray;
- (id)initWithProxy:(id)proxyObject;
//- (oneway void)calculateMatches:(bycopy in NSMutableArray*)tileImages withFile:(NSString*)filePath;
//- (oneway void)calculateMatches:(bycopy NSBitmapImageRep *[])tileImages count:(int)tileCount withFile:(NSString*)filePath;
//- (oneway void)calculateMatches:(void *)tileImages withFile:(NSString*)filePath;
- (void)setTileCollection:(TileCollection *)tiles;
//- (oneway void)calculateMatchesWithFile:(NSString*)filePath;
- (oneway void)calculateMatchesWithFile:(NSString*)filePath connection:(id)connection;
- (float)computeMatch:(Tile *)imageRep1 with:(NSBitmapImageRep *)imageRep2;

@end
