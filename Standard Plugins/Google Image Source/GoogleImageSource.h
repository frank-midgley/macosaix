//
//  GoogleImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ImageSource.h"

@interface GoogleImageSource : ImageSource {
    NSString		*_query;
    NSURL			*_nextGooglePage;
    NSMutableArray	*_imageURLQueue;
}

@end
