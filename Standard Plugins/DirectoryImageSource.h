//
//  DirectoryImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MacOSaiXPlugins/ImageSource.h>

@interface DirectoryImageSource : ImageSource {
    NSDirectoryEnumerator	*_enumerator;
    NSString				*_directoryPath, *_nextFile;
}

@end
