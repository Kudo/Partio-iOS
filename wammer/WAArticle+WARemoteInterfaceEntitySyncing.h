//
//  WAArticle+WARemoteInterfaceEntitySyncing.h
//  wammer
//
//  Created by Evadne Wu on 11/9/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAArticle.h"
#import "WARemoteInterfaceEntitySyncing.h"


#ifndef __WAArticle_EntitySyncing__
#define __WAArticle_EntitySyncing__

extern NSString * const kWAArticleSyncStrategy; //  key
typedef NSString * const WAArticleSyncStrategy;

extern NSString * const kWAArticleSyncDefaultStrategy;
extern NSString * const kWAArticleSyncFullyFetchOnlyStrategy;
extern NSString * const kWAArticleSyncMergeLastBatchStrategy;

extern NSString * const kWAArticleSyncRangeStart;
//  Object identifier — if exist, fetch only things newer than this object identifier, including the mentioned identifier

extern NSString * const kWAArticleSyncRangeEnd;
//  Same, but only older than this identifier

#endif


@interface WAArticle (WARemoteInterfaceEntitySyncing) <WARemoteInterfaceEntitySyncing>

@end
