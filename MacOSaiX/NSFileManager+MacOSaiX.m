//
//  NSFileManager+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 9/24/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import "NSFileManager+MacOSaiX.h"


@implementation MacOSaiXDirectoryEnumerator


- (id)initWithPath:(NSString *)path followsAliases:(BOOL)flag
{
	if (self = [super init])
	{
		rootPath = [path copy];
		followAliases = flag;
		
			// Initialize the queue of sub-paths to enumarate.
		subPathQueue = [[NSMutableArray array] retain];
		NSArray			*topLevelItems = [[NSFileManager defaultManager] directoryContentsAtPath:rootPath];
		NSEnumerator	*itemEnumerator = [[topLevelItems sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] reverseObjectEnumerator];
		NSString		*item = nil;
		while (item = [itemEnumerator nextObject])
			[subPathQueue addObject:item];
		visitedRootPaths = [[NSMutableArray arrayWithObject:rootPath] retain];
	}
	
	return self;
}


- (id)nextObject
{
	NSString		*nextSubPath = nil;
	
	if ([subPathQueue count] > 0)
	{
			// Pull the next item from the queue.
		nextSubPath = [[[subPathQueue lastObject] retain] autorelease];
		[subPathQueue removeLastObject];
		
		NSString	*fullPath = [rootPath stringByAppendingPathComponent:nextSubPath];
		
		if (followAliases)
			fullPath = [[NSFileManager defaultManager] pathByResolvingAliasesInPath:fullPath];
		
			// Determine if the item is a file or a directory.
		NSString	*fileType = [[[NSFileManager defaultManager] fileAttributesAtPath:fullPath traverseLink:YES] fileType];
		BOOL		itemIsDirectory = [fileType isEqualToString:NSFileTypeDirectory];
		FSRef		itemRef;
		if (followAliases && !itemIsDirectory && CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:fullPath], &itemRef))
		{
				// Check if the item is an alias.
			Boolean	resolvesToFolder = NO,
					wasAlias = NO;
			OSErr	err = FSResolveAliasFile(&itemRef, true, &resolvesToFolder, &wasAlias);
			
			if (err == noErr && wasAlias)
			{
				UInt8		path[1024];
				OSStatus	status = FSRefMakePath(&itemRef, path, 1024);
				
				if (status == noErr)
				{
					fullPath = [NSString stringWithCString:path];
					itemIsDirectory = resolvesToFolder;
					
					if (itemIsDirectory)
					{
							// Check if the directory the alias resolved to was already handled or will be 
							// handled by another item in the queue.  If so then treat it as a file.
						NSEnumerator	*visitedRootEnumerator = [visitedRootPaths objectEnumerator];
						NSString		*visitedRoot = nil;
						while (itemIsDirectory && (visitedRoot = [visitedRootEnumerator nextObject]))
							if ([fullPath hasPrefix:visitedRoot])
								itemIsDirectory = NO;
						
							// This is a new directory to enumerate.
						if (itemIsDirectory)
							[visitedRootPaths addObject:fullPath];
					}
				}
			}
		}
		
		if (itemIsDirectory)
		{
				// Add the items in the directory to the queue.
			NSArray			*subItems = [[NSFileManager defaultManager] directoryContentsAtPath:fullPath];
			NSEnumerator	*subItemEnumerator = [[subItems sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] reverseObjectEnumerator];
			NSString		*subItem = nil;
			while (subItem = [subItemEnumerator nextObject])
				[subPathQueue addObject:[nextSubPath stringByAppendingPathComponent:subItem]];
		}
	}
	
	[lastNextObject release];
	lastNextObject = [nextSubPath retain];
	
	return nextSubPath;
}


- (NSDictionary *)fileAttributes
{
	return (lastNextObject ? [[NSFileManager defaultManager] fileAttributesAtPath:lastNextObject traverseLink:YES] : nil);
}


- (NSDictionary *)directoryAttributes
{
	return [[NSFileManager defaultManager] fileAttributesAtPath:rootPath traverseLink:YES];
}


- (void)skipDescendents
{
	while ([subPathQueue count] > 0 && [[subPathQueue objectAtIndex:0] hasPrefix:lastNextObject])
		[subPathQueue removeObjectAtIndex:0];
}


- (void)dealloc
{
	[rootPath release];
	[subPathQueue release];
	[visitedRootPaths release];
	
	[super dealloc];
}


@end


@implementation NSFileManager (MacOSaiXAliasResolution)


- (NSString *)pathByResolvingAliasesInPath:(NSString *)path
{
	NSString		*resolvedPath = @"";
	NSEnumerator	*componentEnumerator = [[path pathComponents] objectEnumerator];
	NSString		*pathComponent = nil;
	
	while (resolvedPath && (pathComponent = [componentEnumerator nextObject]))
	{
		resolvedPath = [resolvedPath stringByAppendingPathComponent:pathComponent];
		
			// Check if the item is an alias.
		FSRef		itemRef;
		if (CFURLGetFSRef((CFURLRef)[NSURL fileURLWithPath:resolvedPath], &itemRef))
		{
			Boolean	resolvesToFolder = NO,
					wasAlias = NO;
			OSErr	err = FSResolveAliasFile(&itemRef, true, &resolvesToFolder, &wasAlias);
			
			if (wasAlias)
			{
				UInt8		path[PATH_MAX];
				OSStatus	status = FSRefMakePath(&itemRef, path, PATH_MAX);
				
				if (status == noErr)
					resolvedPath = [NSString stringWithCString:path];
			}
			else if (err == fnfErr)
				resolvedPath = nil;	// the item the alias points to cannot be found
		}
		else
			resolvedPath = nil; // the item doesn't exist
	}
	
	return resolvedPath;
}


- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path followAliases:(BOOL)flag
{
	return [[[MacOSaiXDirectoryEnumerator alloc] initWithPath:path followsAliases:flag] autorelease];
}


@end
