//
//  NSData+MacOSaiX.m
//  MacOSaiX
//
//  Created by Frank Midgley on 3/18/08.
//  Copyright 2008 Frank M. Midgley. All rights reserved.
//

#import "NSData+MacOSaiX.h"

#import <openssl/evp.h>


@implementation NSData (MacOSaiX)


- (NSString *)checksum
{
	// TBD: use the following instead to avoid libcrypto?  (from <http://www.cocoabuilder.com/archive/message/xcode/2008/3/18/20296>)
	//	extern int CC_MD5_Init(CC_MD5_CTX *c);
	//	extern int CC_MD5_Update(CC_MD5_CTX *c, const void *data, CC_LONG len);
	//	extern int CC_MD5_Final(unsigned char *md, CC_MD5_CTX *c);
	
	NSString	*checksum = nil;
	EVP_MD_CTX	context;
	
	if (EVP_DigestInit(&context, EVP_md5()))
	{
		unsigned		byteCount = [self length], 
						offset = 0, 
						offsetLimit = (byteCount > 4096 ? byteCount - 4096 : 0);
		unsigned char	md5[EVP_MAX_MD_SIZE];
		BOOL			keepGoing = YES;
		
		while (keepGoing && offset < offsetLimit)
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
				[(NSMutableString *)checksum appendString:[NSString stringWithFormat:@"%02x", md5[i]]];
			
			checksum = [NSString stringWithString:checksum];	// de-mutify
		}
	}
	
	return checksum;
}

@end
