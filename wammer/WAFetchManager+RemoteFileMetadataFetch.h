//
//  WAFetchManager+RemoteFileMetadataFetch.h
//  wammer
//
//  Created by kchiu on 12/12/27.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFetchManager.h"

@class IRAsyncOperation;
@interface WAFetchManager (RemoteFileMetadataFetch)

- (IRAsyncOperation *)remoteFileMetadataFetchOperationPrototype;

@end
