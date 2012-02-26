//
//  WAOpenGraphElementImage+WARemoteInterfaceEntitySyncing.m
//  wammer
//
//  Created by Evadne Wu on 2/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOpenGraphElementImage+WARemoteInterfaceEntitySyncing.h"

@implementation WAOpenGraphElementImage (WARemoteInterfaceEntitySyncing)

+ (NSString *) keyPathHoldingUniqueValue {

	return nil;

}

+ (NSDictionary *) remoteDictionaryConfigurationMapping {

	static NSDictionary *mapping = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    
		mapping = [NSDictionary dictionaryWithObjectsAndKeys:
			@"imageRemoteURL", @"url",
		nil];
		
		[mapping retain];
		
	});

	return mapping;

}

@end
