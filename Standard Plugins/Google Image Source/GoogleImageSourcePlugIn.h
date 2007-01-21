//
//  GoogleImageSourcePlugIn.h
//  MacOSaiX
//
//  Created by Frank Midgley on 1/21/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface MacOSaiXGoogleImageSourcePlugIn : NSObject <MacOSaiXPlugIn>
{
}

+ (NSImage *)googleIcon;

+ (NSString *)imageCachePath;
+ (NSString *)cachedFileNameForIdentifier:(NSString *)identifier thumbnail:(BOOL)thumbnail;
+ (void)cacheImageData:(NSData *)imageData withIdentifier:(NSString *)identifier isThumbnail:(BOOL)isThumbnail;
+ (NSImage *)cachedImageWithIdentifier:(NSString *)identifier getThumbnail:(BOOL)thumbnail;
+ (void)pruneCache;
+ (void)purgeCache;

+ (void)setPreferredValue:(id)value forKey:(NSString *)key;
+ (id)preferredValueForKey:(NSString *)key;

+ (void)setMaxCacheSize:(unsigned long long)size;
+ (unsigned long long)maxCacheSize;
+ (void)setMinFreeSpace:(unsigned long long)space;
+ (unsigned long long)minFreeSpace;

@end
