//
//  NSData+MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on 5/17/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//


@interface NSData (MacOSaiX)

+ (NSData *)dataWithHexString:(NSString *)hexString;

- (NSString *)hexString;

- (NSString *)checksum;

@end
