//
//  NSFileManager+MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on 9/24/05.
//  Copyright 2005 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiXDirectoryEnumerator : NSDirectoryEnumerator
{
@private
	NSString		*rootPath;
	BOOL			followAliases;
	
	NSString		*lastNextObject;
	
	NSMutableArray	*subPathQueue, 
					*visitedRootPaths;
}

@end


@interface NSFileManager (MacOSaiXAliasResolution)

- (NSString *)pathByResolvingAliasesInPath:(NSString *)path;
- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)path followAliases:(BOOL)flag;

@end


@interface NSFileManager (MacOSaiXAttributedPaths)

- (NSAttributedString *)attributedPath:(NSString *)path;

@end
