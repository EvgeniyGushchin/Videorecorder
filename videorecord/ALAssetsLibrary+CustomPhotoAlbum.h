//
//  ALAssetsLibrary category to handle a custom photo album
//
//  Created by Marin Todorov on 10/26/11.
//  Copyright (c) 2011 Marin Todorov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

typedef void(^SaveImageCompletion)(NSURL* assetURL, NSError* error);
typedef void(^SaveImageFailed)(NSError* error);

@interface ALAssetsLibrary(CustomPhotoAlbum)

-(void)saveImage:(UIImage*)image 
         toAlbum:(NSString*)albumName 
 withResultBlock:(SaveImageCompletion)completionBlock
    failureBlock:(SaveImageFailed)failureBlock;

-(void)saveVideoAPath:(NSURL*)videoUrl 
              toAlbum:(NSString*)albumName 
      withResultBlock:(SaveImageCompletion)completionBlock 
         failureBlock:(SaveImageFailed)failureBlock;

-(void)addAssetURL:(NSURL*)assetURL 
           toAlbum:(NSString*)albumName 
   withResultBlock:(SaveImageCompletion)completionBlock
      failureBlock:(SaveImageFailed)failureBlock;

@end