//
//  AKDownloadManager.h
//  Pods
//
//  Created by 李翔宇 on 16/5/23.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AKDownloadManager : NSObject

+ (AKDownloadManager *)manager;

@property (nonatomic, copy) NSString *sessionIdentifier;
@property (nonatomic, strong) void (^backgroundURLSessionCompletionHandler)();

- (void)startDownloadWithURL:(NSString *)url
                    savePath:(NSString *)path
                    progress:(void(^)(CGFloat progress))progress
                     success:(void(^)(NSString *tmpFilePath))success
                     failure:(void(^)(NSError *error))failure;

- (void)pauseDownloadWithURL:(NSString *)url;
- (void)stopDownloadWithURL:(NSString *)url;

@end

NS_ASSUME_NONNULL_END
