//
//  QuickTimeImageSource.h
//  MacOSaiX
//
//  Created by Frank Midgley on Wed Mar 13 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickTime/QuickTime.h>

#import <MacOSaiXPlugins/ImageSource.h>

@interface QuickTimeImageSource : ImageSource
{
    NSString	*_moviePath;
	Movie		_movie;
	TimeValue	_curTimeValue, _duration;
}

@end