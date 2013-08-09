//
//  VideoFrameData.h
//  Pixtrain
//
//  Created by Evgeniy Gushchin on 4/25/12.
//  Copyright (c) 2012  Al Digit. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>

@interface VideoFrameData : NSObject

@property (nonatomic) CMTime presentationTime;
@property (nonatomic, strong)UIImage *img;
@property (nonatomic, strong)NSURL *libraryAssetURL;    // url of image in ALAssetsLibrary
@property (nonatomic, strong)NSString *imageLink;       // simple link on image file

@end
