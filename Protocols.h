#import "Tiles.h"

@protocol MatcherMethods
//- (oneway void)calculateMatches:(bycopy in NSMutableArray *)tileImages withFile:(NSString*)filePath;
//- (oneway void)calculateMatches:(bycopy NSBitmapImageRep *[])tileImages count:(int)tileCount withFile:(NSString*)filePath;
//- (void)calculateMatches:(void *)tileImages withFile:(NSString *)filePath;
- (void)setTileCollection:(TileCollection *)tiles;
//- (void)calculateMatchesWithFile:(NSString *)filePath;
- (oneway void)calculateMatchesWithFile:(NSString*)filePath connection:(id)connection;
@end

@protocol ControllerMethods
- (void)setServer:(id)anObject;
- (void *)getTileImages;
- (NSBitmapImageRep *)getTileImageRep:(int)index;
- (void)checkInMatch:(float)matchValue atIndex:(int)index forFile:(NSString *)filePath;
@end

