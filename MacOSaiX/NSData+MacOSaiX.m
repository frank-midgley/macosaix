//
//  NSData+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 5/17/07.
//  Copyright 2007 Frank M. Midgley. All rights reserved.
//

#import "NSData+MacOSaiX.h"

#import <openssl/evp.h>


@implementation NSData (MacOSaiX)

- (NSString *)checksum
{
	NSString	*checksum = nil;
	EVP_MD_CTX	context;
	
	if (EVP_DigestInit(&context, EVP_md5()))
	{
		unsigned		byteCount = [self length], 
						offset = 0;
		unsigned char	md5[EVP_MAX_MD_SIZE];
		BOOL			keepGoing = YES;
		
		while (keepGoing && offset < byteCount - 4096)
		{
			if (EVP_DigestUpdate(&context, [self bytes] + offset, 4096))
				offset += 4096;
			else
				keepGoing = NO;
		}
		
		if (keepGoing && offset < byteCount)
			keepGoing = (EVP_DigestUpdate(&context, [self bytes] + offset, byteCount - offset) == 1);
		
		unsigned int	md5Size;
		if (EVP_DigestFinal(&context, md5, &md5Size) && keepGoing)
		{
			checksum = [NSMutableString string];
			
			int	i;
			for (i = 0; i < md5Size; i++)
				[(NSMutableString *)checksum appendString:[NSString stringWithFormat:@"%x", md5[i]]];
			
			checksum = [NSString stringWithString:checksum];	// de-mutify
		}
	}
	
	return checksum;
}

@end
