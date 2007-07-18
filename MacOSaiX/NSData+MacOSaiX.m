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


+ (NSData *)dataWithHexString:(NSString *)hexString
{
	NSData			*data = nil;
	unsigned int	hexLength = [hexString length];
	
	if (hexLength % 2 == 0)
	{
		NSMutableData	*mutableData = [NSMutableData dataWithLength:hexLength / 2];
		unsigned int	charPos = 0;
		
		while (charPos < hexLength)
		{
			unsigned char	highByte = [hexString characterAtIndex:charPos], 
							lowByte = [hexString characterAtIndex:charPos + 1];
			
			if (highByte >= '0' && highByte <= '9')
				highByte -= '0';
			else if (highByte >= 'a' && highByte <= 'z')
				highByte -= 'a' - 10;
			else if (highByte >= 'A' && highByte <= 'Z')
				highByte -= 'A' - 10;
			if (lowByte >= '0' && lowByte <= '9')
				lowByte -= '0';
			else if (lowByte >= 'a' && lowByte <= 'z')
				lowByte -= 'a' - 10;
			else if (lowByte >= 'A' && lowByte <= 'Z')
				lowByte -= 'A' - 10;
			
			unsigned char	byte = highByte * 16 + lowByte;
			
			[mutableData replaceBytesInRange:NSMakeRange(charPos / 2, 1) withBytes:&byte];
			
			charPos += 2;
		}
		
		data = [NSData dataWithData:mutableData];
	}
	
	return data;
}


- (NSString *)hexString
{
	NSMutableString	*hexString = [NSMutableString string];
	unsigned char	*pointer = (unsigned char *)[self bytes], 
					*lastByte = pointer + [self length] - 1;
	
	while (pointer <= lastByte)
		[hexString appendFormat:@"%02x", *pointer++];
	
	return hexString;
}


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
				[(NSMutableString *)checksum appendString:[NSString stringWithFormat:@"%02x", md5[i]]];
			
			checksum = [NSString stringWithString:checksum];	// de-mutify
		}
	}
	
	return checksum;
}

@end
