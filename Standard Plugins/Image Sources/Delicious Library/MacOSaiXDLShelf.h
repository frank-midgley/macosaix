//
//  MacOSaiXDLShelf.h
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXDLItem;


@interface MacOSaiXDLShelf : NSObject
{
	NSString		*name, 
					*UUID;
	BOOL			isSmart;
	NSMutableArray	*items;
}

+ (MacOSaiXDLShelf *)shelfWithName:(NSString *)name UUID:(NSString *)UUID isSmart:(BOOL)flag;

- (id)initWithName:(NSString *)name UUID:(NSString *)UUID isSmart:(BOOL)flag;
- (NSString *)name;
- (NSString *)UUID;
- (BOOL)isSmart;

- (void)addItem:(MacOSaiXDLItem *)item;
- (NSArray *)items;

@end
