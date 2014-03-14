//
//  MacOSaiXDLShelf.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/15/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "MacOSaiXDLShelf.h"


@implementation MacOSaiXDLShelf


+ (MacOSaiXDLShelf *)shelfWithName:(NSString *)inName UUID:(NSString *)inUUID isSmart:(BOOL)flag
{
	return [[[self alloc] initWithName:inName UUID:inUUID isSmart:flag] autorelease];
}


- (id)initWithName:(NSString *)inName UUID:(NSString *)inUUID isSmart:(BOOL)flag
{
	if (self = [super init])
	{
		name = [inName retain];
		UUID = [inUUID retain];
		isSmart = flag;
		items = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (NSString *)name
{
	return name;
}


- (NSString *)UUID
{
	return UUID;
}


- (BOOL)isSmart
{
	return isSmart;
}


- (void)addItem:(MacOSaiXDLItem *)item
{
	[items addObject:item];
}


- (NSArray *)items
{
	return [NSArray arrayWithArray:items];
}


- (NSComparisonResult)compare:(MacOSaiXDLShelf *)otherObject
{
	return [[self name] compare:[otherObject name]];
}


- (void)dealloc
{
	[name release];
	[UUID release];
	[items release];
	
	[super dealloc];
}


@end
