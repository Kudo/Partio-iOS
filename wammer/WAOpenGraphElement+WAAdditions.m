//
//  WAOpenGraphElement+WAAdditions.m
//  wammer
//
//  Created by Evadne Wu on 2/17/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WAOpenGraphElement+WAAdditions.h"
#import "IRRemoteResourcesManager.h"
#import "WADataStore.h"
#import "CoreData+IRAdditions.h"
#import "WAOpenGraphElementImage.h"
#import "WAOpenGraphElementImage+WAAdditions.h"


@interface WAOpenGraphElement (WAAdditions_OrderedCollections)

- (WAOpenGraphElementImage *) openGraphElementImageAtIndex:(NSUInteger)anIndex;

@end

@implementation WAOpenGraphElement (WAAdditions_OrderedCollections)

- (WAOpenGraphElementImage *) openGraphElementImageAtIndex:(NSUInteger)anIndex {

	return (WAOpenGraphElementImage *)[self irObjectAtIndex:anIndex inArrayKeyed:@"imageOrder"];

}

@end


@implementation WAOpenGraphElement (WAAdditions)

+ (BOOL) automaticallyNotifiesObserversForKey:(NSString *)key {

	if ([super automaticallyNotifiesObserversForKey:key])
		return YES;
	
	if ([key isEqualToString:@"images"])
		return YES;
	
	return NO;

}

+ (NSSet *) keyPathsForValuesAffectingImages {

	return [NSSet setWithObjects:@"imageOrder", nil];

}

+ (NSSet *) keyPathsForValuesAffectingImageOrder {

	return [NSSet setWithObjects:@"images", nil];

}

- (void) irAwake {

	[super irAwake];
	[self irReconcileObjectOrderWithKey:@"images" usingArrayKeyed:@"imageOrder"];
	
}

- (NSArray *) imageOrder {

	return [self irBackingOrderArrayKeyed:@"imageOrder"];

}

- (void) didChangeValueForKey:(NSString *)inKey withSetMutation:(NSKeyValueSetMutationKind)inMutationKind usingObjects:(NSSet *)inObjects {

	if ([inKey isEqualToString:@"images"]) {
    
    [self irUpdateObjects:inObjects withRelationshipKey:@"images" usingOrderArray:@"imageOrder" withSetMutation:inMutationKind];
		return;
    
  }

	[super didChangeValueForKey:inKey withSetMutation:inMutationKind usingObjects:inObjects];
	
}

+ (BOOL) skipsNonexistantRemoteKey {

	return YES;
	
}

- (NSSet *) keyPathsForValuesAffectingRepresentedImage {

	return [NSSet setWithObjects:
	
		@"imageOrder.@count",
		
	nil];

}

- (WAOpenGraphElementImage *) representedImage {

	if (![self.imageOrder count])
		return nil;
	
	return [self openGraphElementImageAtIndex:0];

}

- (NSSet *) keyPathsForValuesAffectingThumbnail {

	return [NSSet setWithObjects:
	
		@"representedImage",
		@"representedImage.image",
				
	nil];

}

- (UIImage *) thumbnail {

	return [self representedImage].image;

}

- (NSSet *) keyPathsForValuesAffectingThumbnailURL {

	return [NSSet setWithObjects:
	
		@"representedImage",
		@"representedImage.imageRemoteURL",
				
	nil];

}

- (NSString *) thumbnailURL {

	return [self representedImage].imageRemoteURL;
}

- (NSSet *) keyPathsForValuesAffectingThumbnailFilePath {

	return [NSSet setWithObjects:
	
		@"representedImage",
		@"representedImage.imageFilePath",
		
	nil];

}

- (NSString *) thumbnailFilePath {

	return [self representedImage].imageFilePath;
	
}

@end
