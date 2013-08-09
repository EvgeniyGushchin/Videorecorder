//
//  ALAssetsLibrary category to handle a custom photo album
//
//  Created by Marin Todorov on 10/26/11.
//  Copyright (c) 2011 Marin Todorov. All rights reserved.
//

#import "ALAssetsLibrary+CustomPhotoAlbum.h"

@implementation ALAssetsLibrary(CustomPhotoAlbum)

-(void)saveImage:(UIImage*)image 
         toAlbum:(NSString*)albumName 
 withResultBlock:(SaveImageCompletion)completionBlock
    failureBlock:(SaveImageFailed)failureBlock
{
    //write the image data to the assets library (camera roll)
    [self writeImageToSavedPhotosAlbum:image.CGImage orientation:(ALAssetOrientation)image.imageOrientation 
                        completionBlock:^(NSURL* assetURL, NSError* error) {
                              
                          //error handling
                          if (error!=nil) {
                              completionBlock(assetURL, error);
                              return;
                          }

                          //add the asset to the custom photo album
                          [self addAssetURL: assetURL 
                                    toAlbum:albumName 
                            withResultBlock:completionBlock 
                               failureBlock:failureBlock];
                          
                      }];
}

-(void)saveVideoAPath:(NSURL*)videoUrl 
              toAlbum:(NSString*)albumName 
      withResultBlock:(SaveImageCompletion)completionBlock 
         failureBlock:(SaveImageFailed)failureBlock
{
    [self writeVideoAtPathToSavedPhotosAlbum:videoUrl completionBlock:^(NSURL* assetURL, NSError* error)
    {
        //error handling
        if (error != nil) 
        {
            failureBlock(error);
            return;
        }
        [self addAssetURL:assetURL 
                  toAlbum:albumName 
          withResultBlock:completionBlock 
             failureBlock:failureBlock];
        
    }];
}

-(void)addAssetURL:(NSURL*)assetURL 
           toAlbum:(NSString*)albumName 
   withResultBlock:(SaveImageCompletion)completionBlock
      failureBlock:(SaveImageFailed)failureBlock
{
    __block BOOL albumWasFound = NO;
    
    [self assetForURL: assetURL 
          resultBlock:^(ALAsset *asset) {
              
              //search all photo albums in the library
              [self enumerateGroupsWithTypes:ALAssetsGroupAlbum 
                                  usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                      
                                      //compare the names of the albums
                                      if ([albumName compare: [group valueForProperty:ALAssetsGroupPropertyName]]==NSOrderedSame) {
                                          
                                          //target album is found
                                          albumWasFound = YES;
                                          
                                          //add photo to the target album
                                          [group addAsset: asset];
                                          
                                          //run the completion block
                                          completionBlock(assetURL, nil);
                                          
                                          //album was found, bail out of the method
                                          return;
                                      }
                                      
                                      if (group==nil && albumWasFound==NO) {
                                          //photo albums are over, target album does not exist, thus create it
                                                                                    
                                          //create new assets album
                                          [self addAssetsGroupAlbumWithName:albumName 
                                                                resultBlock:^(ALAssetsGroup *group_) {
                                                                    
                                                                    //add photo to the newly created album
                                                                    BOOL result = [group_ addAsset: asset];
                                                                    
                                                                    NSError * error = nil;
                                                                    
                                                                    if(result == NO)
                                                                    {
                                                                        error = [NSError errorWithDomain:@"" code:1000 userInfo:nil];
                                                                    }
                                                                    //call the completion block
                                                                    completionBlock(assetURL, error);
                                                                    
                                                                    
                                                                } failureBlock: failureBlock];
                                          
                                          //should be the last iteration anyway, but just in case
                                          return;
                                      }
                                      
                                  } 
                                failureBlock: failureBlock];
          }
         failureBlock: failureBlock];
}

@end
