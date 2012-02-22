//
//  WAOpenGraphElement+WAAdditions.h
//  wammer
//
//  Created by Evadne Wu on 2/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOpenGraphElement.h"

@interface WAOpenGraphElement (WAAdditions)

@property (nonatomic, readonly, retain) UIImage *thumbnail;
@property (nonatomic, readonly, retain) NSString *thumbnailURL DEPRECATED_ATTRIBUTE;
@property (nonatomic, readonly, retain) NSString *thumbnailFilePath DEPRECATED_ATTRIBUTE;

@end