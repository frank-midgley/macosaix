//
//  iPhotoImageSourcePlugIn.h
//  MacOSaiX
//
//  Created by Frank Midgley on 7/23/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXiPhotoImageSourcePlugIn : NSObject <MacOSaiXPlugIn>
{

}

+ (NSImage *)albumImage;
+ (NSImage *)keywordImage;

@end
