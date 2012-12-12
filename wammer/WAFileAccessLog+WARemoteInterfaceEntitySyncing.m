//
//  WAFileAccessLog+WARemoteInterfaceEntitySyncing.m
//  wammer
//
//  Created by kchiu on 12/12/12.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFileAccessLog+WARemoteInterfaceEntitySyncing.h"

@implementation WAFileAccessLog (WARemoteInterfaceEntitySyncing)

+ (NSString *) keyPathHoldingUniqueValue {
	
	return @"accessTime";

}

+ (NSDictionary *) defaultHierarchicalEntityMapping {
	
	return @{
		@"day": @"WADocumentDay",
	};
	
}

+ (NSDictionary *) remoteDictionaryConfigurationMapping {
	
	static NSDictionary *mapping = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
    
		mapping = @{
			@"accessTime": @"accessTime",
			@"filePath": @"filePath",
			@"day": @"day"
		};

	});
	
	return mapping;
	
}

@end
