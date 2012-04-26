//
//  WAPreview+WAAdditions.m
//  wammer
//
//  Created by Evadne Wu on 2/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAPreview+WAAdditions.h"
#import "WAOpenGraphElement+WAAdditions.h"

@implementation WAPreview (WAAdditions)

+ (NSString *) keyPathHoldingUniqueValue {

	return @"url";

}

+ (NSSet *) keyPathsForValuesAffectingThumbnail {

	return [NSSet setWithObject:@"graphElement.thumbnail"];

}


- (UIImage *) thumbnail {

	return self.graphElement.thumbnail;

}

@end
