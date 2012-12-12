//
//  WAFile.m
//  wammer
//
//  Created by kchiu on 12/12/12.
//  Copyright (c) 2012年 Waveface. All rights reserved.
//

#import "WAFile.h"
#import "WAArticle.h"
#import "WACache.h"
#import "WACollection.h"
#import "WAFileAccessLog.h"
#import "WAFileExif.h"
#import "WAFilePageElement.h"
#import "WAUser.h"


@implementation WAFile

@dynamic assetURL;
@dynamic codeName;
@dynamic created;
@dynamic creationDeviceIdentifier;
@dynamic dirty;
@dynamic extraSmallThumbnailFilePath;
@dynamic identifier;
@dynamic importTime;
@dynamic largeThumbnailFilePath;
@dynamic largeThumbnailURL;
@dynamic remoteFileName;
@dynamic remoteFileSize;
@dynamic remoteRepresentedImage;
@dynamic remoteResourceHash;
@dynamic remoteResourceType;
@dynamic resourceFilePath;
@dynamic resourceType;
@dynamic resourceURL;
@dynamic smallThumbnailFilePath;
@dynamic smallThumbnailURL;
@dynamic text;
@dynamic thumbnail;
@dynamic thumbnailFilePath;
@dynamic thumbnailURL;
@dynamic timestamp;
@dynamic title;
@dynamic webFaviconURL;
@dynamic webTitle;
@dynamic webURL;
@dynamic articles;
@dynamic caches;
@dynamic collections;
@dynamic accessLogs;
@dynamic exif;
@dynamic owner;
@dynamic pageElements;
@dynamic representedArticle;

@end
