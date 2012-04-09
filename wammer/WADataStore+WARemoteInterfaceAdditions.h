//
//  WADataStore+WARemoteInterfaceAdditions.h
//  wammer
//
//  Created by Evadne Wu on 11/4/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WADataStore.h"
#import "WARemoteInterfaceEntitySyncing.h"
#import "WAArticle+WARemoteInterfaceEntitySyncing.h"
#import "WAFile+WARemoteInterfaceEntitySyncing.h"


extern NSString * const kWADataStoreArticleUpdateShowsBezels;	//	pass kCFBooleanTrue or kCFBooleanFalse


@interface WADataStore (WARemoteInterfaceAdditions)

- (BOOL) hasDraftArticles;
- (void) updateArticlesOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(NSError *))failureBlock;

- (void) updateArticle:(NSURL *)articleURIF onSuccess:(void(^)(void))successBlock onFailure:(void(^)(NSError *error))failureBlock;
- (void) updateArticle:(NSURL *)articleURI withOptions:(NSDictionary *)options onSuccess:(void(^)(void))successBlock onFailure:(void(^)(NSError *error))failureBlock;

- (BOOL) isUpdatingArticle:(NSURL *)anObjectURI;	//	Really?

- (void) addComment:(NSString *)commentText onArticle:(NSURL *)anArticleURI onSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock;
- (void) updateCurrentUserOnSuccess:(void(^)(void))successBlock onFailure:(void(^)(void))failureBlock;

@end
