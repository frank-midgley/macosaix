//
//  MacOSaiXFlickrCategory.h
//  MacOSaiX
//
//  Created by Frank Midgley on 4/29/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MacOSaiXFlickrGroup;


@interface MacOSaiXFlickrCategory : NSObject
{
	NSString		*name, 
					*catID;
	NSMutableArray	*subCategories, 
					*groups;
	BOOL			childrenFetched;
}

+ (MacOSaiXFlickrCategory *)categoryWithName:(NSString *)name catID:(NSString *)catID;

- (id)initWithName:(NSString *)name catID:(NSString *)catID;

- (NSString *)name;
- (NSString *)catID;

- (void)addSubCategory:(MacOSaiXFlickrCategory *)subCategory;
- (NSArray *)subCategories;

- (void)addGroup:(MacOSaiXFlickrGroup *)group;
- (NSArray *)groups;
- (void)removeAllGroups;

- (NSArray *)children;

@end
