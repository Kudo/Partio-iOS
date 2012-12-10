//
//  WADataStore+WASyncManagerAdditions.h
//  wammer
//
//  Created by Evadne Wu on 6/21/12.
//  Copyright (c) 2012 Waveface. All rights reserved.
//

#import "WADataStore.h"

@interface WADataStore (WASyncManagerAdditions)

- (void) enumerateFilesWithSyncableBlobsInContext:(NSManagedObjectContext *)context usingBlock:(void(^)(WAFile *aFile, NSUInteger index, BOOL *stop))block;

- (void) enumerateDirtyArticlesInContext:(NSManagedObjectContext *)context usingBlock:(void(^)(WAArticle *anArticle, NSUInteger index, BOOL *stop))block;

- (NSArray *) fetchFilesNeedingMetadataSyncUsingContext:(NSManagedObjectContext *)aContext;

@end
