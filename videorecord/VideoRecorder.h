//
//  VideoRecorder.h
//  videorecord
//
//  Created by Evgeniy Gushchin on 7/19/13.
//  Copyright (c) 2013 Evgeniy Gushchin. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^RecordCompletionBlock)(BOOL succsess, NSError *error);

@protocol VideoRecorderProtocol;

@class ALAssetsLibrary;

@interface VideoRecorder : NSObject

@property (nonatomic)BOOL hdQuality; // if YES then frame size (1280, 720) else (640,480)
@property (nonatomic, strong) UIImage *watermarkImage; // this image will be added to the each frame (botttom right corner) as watermark
@property (nonatomic, strong) NSString *videoTitle;
@property (nonatomic, strong) NSString *albumName;     // album name in photo library
@property (nonatomic, weak) id <VideoRecorderProtocol> delegate;

// init with array of frames, where frame is an object of class VideoFrameData, and library
- (id)initWithFrames:(NSArray *)frames andLibrary:(ALAssetsLibrary *)library;

- (void)recordVideowithcmpletionBlock:(RecordCompletionBlock)completionBlock;
@end

@protocol VideoRecorderProtocol
- (void)updateProgressWithMessage:(NSString *)progressMsg;
@end;