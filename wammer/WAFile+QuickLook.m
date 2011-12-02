//
//  WAFile+QuickLook.m
//  wammer
//
//  Created by Evadne Wu on 12/2/11.
//  Copyright (c) 2011 Waveface. All rights reserved.
//

#import "WAFile+QuickLook.h"

@implementation WAFile (QuickLook)

- (NSString *) previewItemTitle {

  return @"File";

}

- (NSURL *) previewItemURL {

  return self.resourceFilePath ? [NSURL fileURLWithPath:self.resourceFilePath] : nil;

}

@end
