//
//  VideoFrameData.m
//  Pixtrain
//
//  Created by Evgeniy Gushchin on 4/25/12.
//  Copyright (c) 2012  Al Digit. All rights reserved.
//

#import "VideoFrameData.h"

@implementation VideoFrameData

@synthesize presentationTime;
@synthesize img,libraryAssetURL,imageLink;

-(id)copyWithZone:(NSZone *)zone {
    VideoFrameData *copy    = [[[self class]allocWithZone:zone]init];
    copy.presentationTime   = self.presentationTime;
    copy.img                = [self.img copy];
    copy.libraryAssetURL    = [self.libraryAssetURL copy];
    copy.imageLink          = [self.imageLink copy];
    return copy; 
}

@end
