//
//  MacOSaiXFlickrGroup.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/29/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXFlickrGroup : NSObject
{
	NSString	*name, 
				*groupID;
	BOOL		is18Plus;
}

+ (MacOSaiXFlickrGroup *)groupWithName:(NSString *)name groupID:(NSString *)groupID is18Plus:(BOOL)flag;

- (id)initWithName:(NSString *)name groupID:(NSString *)groupID is18Plus:(BOOL)flag;

- (NSError *)populate;

- (void)setName:(NSString *)name;
- (NSString *)name;
- (NSString *)groupID;
- (BOOL)is18Plus;

@end
