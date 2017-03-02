//
//  AKDownloadManager.m
//  Pods
//
//  Created by 李翔宇 on 16/5/23.
//
//

#import "AKDownloadManager.h"
#import "AKDownloader.h"
#import "AKDownloadManagerMacro.h"

@interface AKDownloadManager ()<NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSURLSession *downloadSession;
@property (nonatomic, strong) NSMutableDictionary<id, AKDownloader *> *downloaderDicM;
@property (nonatomic, strong) dispatch_queue_t serialQueue;

@end

@implementation AKDownloadManager

+ (AKDownloadManager *)manager {
    static AKDownloadManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[super allocWithZone:NULL] init];
        [sharedInstance makeDownloadSession];
    });
    return sharedInstance;
}

+ (id)alloc {
    return [self manager];
}

+ (id)allocWithZone:(NSZone * _Nullable)zone {
    return [self manager];
}

- (id)copy {
    return self;
}

- (id)copyWithZone:(NSZone * _Nullable)zone {
    return self;
}

#pragma mark- 私有方法
- (NSMutableDictionary *)downloaderDicM {
    if (!_downloaderDicM) {
        _downloaderDicM = [NSMutableDictionary dictionary];
    }
    return _downloaderDicM;
}

- (void)makeDownloadSession {
    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 1;
    
    NSURLSessionConfiguration *configuration = nil;
    self.sessionIdentifier = [NSString stringWithFormat:@"com.artisankid.session.%@", NSStringFromClass(AKDownloadManager.class)];
    configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.sessionIdentifier];
    configuration.timeoutIntervalForRequest = 8.f;
    //configuration.timeoutIntervalForResource = 60.f;//设置timeoutIntervalForResource会导致频繁超时
    configuration.allowsCellularAccess = YES;
    
    //backgroundSession不要设置discretionary=YES，不要设置discretionary=YES，不要设置discretionary=YES
    //因为系统会自动管理“大数据”传输，“大数据”没有给出明确定义，但是我们的离线包貌似已经认为是大数据了
    //实际测试表明，discretionary = YES在“4G且慢速”的情况下，数据下载会直接被delay，延迟时间不确定，但是4G且网速正常的情况下，下载仍然正常开始（我日Apple开发NSURLSession的工程师...）
    //如果不想做更多的提示，那么不要设置discretionary=YES！！！
    //http://stackoverflow.com/questions/27067728/nsurlsession-background-download-over-cellular-possible-in-ios-8
    configuration.discretionary = NO;
    configuration.HTTPShouldSetCookies = YES;
    configuration.HTTPMaximumConnectionsPerHost = 8;
    configuration.HTTPCookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    
    self.downloadSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:self.queue];
}

#pragma mark- 公开方法
- (void)startDownloadWithURL:(NSString *)url savePath:(NSString *)path progress:(void (^)(CGFloat progress))progress success:(void (^)(NSString *tmpFilePath))success failure:(void (^)(NSError *error))failure {
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        if (!url.length) {
            AKDownloadManagerLog(@"文件url为空");
            !failure ? :  failure(nil);
            return;
        }
        
        if (!path.length) {
            AKDownloadManagerLog(@"文件保存路径为空");
            !failure ? :  failure(nil);
            return;
        }
        
        AKDownloadManagerLog(@"准备下载URL:%@", url);
        
        AKDownloader *downloader = self.downloaderDicM[url];
        if (!downloader) {
            downloader = [[AKDownloader alloc] init];
            downloader.url = url;
            downloader.savePath = path;
            downloader.progressBlock = progress;
            downloader.successBlock = success;
            downloader.failureBlock = failure;
            
            NSData *resumeData = [NSData dataWithContentsOfFile:path];
            if (resumeData) {
                downloader.task = [self.downloadSession downloadTaskWithResumeData:resumeData];
                downloader.resume = YES;
            } else {
                downloader.task = [self.downloadSession downloadTaskWithURL:[NSURL URLWithString:url]];
            }
            downloader.task.taskDescription = url;
            self.downloaderDicM[url] = downloader;
        } else if (downloader.task.state == NSURLSessionTaskStateRunning) {
            AKDownloadManagerLog(@"下载任务状态:NSURLSessionTaskStateRunning");
            return;
        } else if (downloader.task.state == NSURLSessionTaskStateSuspended) {
            AKDownloadManagerLog(@"下载任务状态:NSURLSessionTaskStateSuspended");
        } else if (downloader.task.state == NSURLSessionTaskStateCanceling) {
            AKDownloadManagerLog(@"下载任务状态:NSURLSessionTaskStateCanceling");
            return;
        } else if (downloader.task.state == NSURLSessionTaskStateCompleted) {
            AKDownloadManagerLog(@"下载任务状态:NSURLSessionTaskStateCompleted");
            return;
        }
        
        [downloader.task resume];
    }]];
}

- (void)pauseDownloadWithURL:(NSString *)url {
    __weak typeof(self) weak_self = self;
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(weak_self) strong_self = weak_self;
        NSURLSessionDownloadTask *task = strong_self.downloaderDicM[url].task;
        [task suspend];
    }]];
}

- (void)stopDownloadWithURL:(NSString *)url {
    __weak typeof(self) weak_self = self;
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        __strong typeof(weak_self) strong_self = weak_self;
        NSURLSessionDownloadTask *task = strong_self.downloaderDicM[url].task;
        [task cancel];
    }]];
}

#pragma mark- NSURLSession的委托方法
/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case the error parameter will be nil.
 */
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    if(error) {
        AKDownloadManagerLog(@"发生了系统错误：%@", error);
    } else {
        AKDownloadManagerLog(@"手动取消了Session");
    }
    
    [session.delegateQueue cancelAllOperations];
    [self makeDownloadSession];
}

/* If implemented, when a connection level authentication challenge
 * has occurred, this delegate will be given the opportunity to
 * provide authentication credentials to the underlying
 * connection. Some types of authentication will apply to more than
 * one request on a given connection to a server (SSL Server Trust
 * challenges).  If this delegate message is not implemented, the 
 * behavior will be to use the default handling, which may involve user
 * interaction. 
 */
//- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;

/* If an application has received an
 * -application:handleEventsForBackgroundURLSession:completionHandler:
 * message, the session delegate will receive this message to indicate
 * that all messages previously enqueued for this session have been
 * delivered.  At this time it is safe to invoke the previously stored
 * completion handler, or to begin any internal updates that will
 * result in invoking the completion handler.
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    AKDownloadManagerLog(@"全部package下载完成");
    !self.backgroundURLSessionCompletionHandler ? : self.backgroundURLSessionCompletionHandler();
}

#pragma mark- NSURLSessionTask的委托方法
/* An HTTP request is attempting to perform a redirection to a different
 * URL. You must invoke the completion routine to allow the
 * redirection, allow the redirection with a modified request, or
 * pass nil to the completionHandler to cause the body of the redirection 
 * response to be delivered as the payload of this request. The default
 * is to follow redirections. 
 *
 * For tasks in background sessions, redirections will always be followed and this method will not be called.
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler;

/* The task has received a request specific authentication challenge.
 * If this delegate is not implemented, the session specific authentication challenge
 * will *NOT* be called and the behavior will be the same as using the default handling
 * disposition. 
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;

/* Sent if a task requires a new, unopened body stream.  This may be
 * necessary when authentication has failed for any request that
 * involves a body stream. 
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler;

/* Sent periodically to notify the delegate of upload progress.  This
 * information is also available as properties of the task.
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)bytesSent totalBytesSent:(int64_t)totalBytesSent totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

/*
 * Sent when complete statistics information has been collected for the task.
 */
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics

/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete. 
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    if (!error) {
        AKDownloadManagerLog(@"NSURLSessionTask正常完成");
        return;
    }
    
    AKDownloadManagerLog(@"NSURLSessionTask错误 error：%@", error);
    //此处不能使用task.originalRequest来获取url，
    //因为如果下载的url一致，但是下载内容更改(服务器内容更改)后会发生不可逆转的错误
    //NSString *key = task.originalRequest.URL.absoluteString.sjb_md5;
    AKDownloader *downloader = self.downloaderDicM[task.taskDescription];
    
    [self failure:task.taskDescription error:nil];
    
    if (!downloader.savePath.length) {
        return;
    }
    
    //如果当前error不是NSURLErrorCancelled(手动取消)
    if (error.code != NSURLErrorCancelled) {
        //如果当前task并非初始resume的类型(resume类型会在resume成功之后取消)
        if (downloader.isResume) {
            downloader.resume = NO;
            NSError *error = nil;
            BOOL result = [[NSFileManager defaultManager] removeItemAtPath:downloader.savePath error:&error];
            if(!result) {
                AKDownloadManagerLog(@"清理缓存的ResumeData错误 error：%@", error);
                return;
            }
            
            [self startDownloadWithURL:downloader.url
                              savePath:downloader.savePath
                              progress:downloader.progressBlock
                               success:downloader.successBlock
                               failure:downloader.failureBlock];
        }
        return;
    }
    
    [self saveResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData] savePath:downloader.savePath];
}

#pragma mark- NSURLSessionDownload的委托方法
/* Sent when a download task that has completed a download.  The delegate should 
 * copy or move the file at the given location to a new location as it will be 
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    NSString *key = downloadTask.originalRequest.URL.absoluteString;
    
    NSHTTPURLResponse *response = (NSHTTPURLResponse *)downloadTask.response;
    if ([response isKindOfClass:NSHTTPURLResponse.class]) {
        if (response.statusCode >= 400) {
            AKDownloadManagerLog(@"ERROR: HTTP status code %@", @(response.statusCode));
            [self failure:key error:nil];
            return;
        }
    }
    
    NSString *savePath = self.downloaderDicM[key].savePath;
    if (!savePath.length) {
        [self failure:key error:nil];
        return;
    }
    
    NSError *error = nil;
    [NSFileManager.defaultManager moveItemAtURL:location toURL:[NSURL fileURLWithPath:savePath] error:&error];
    if (error) {
        AKDownloadManagerLog(@"文件无法移动到指定路径:%@", error);
        [self failure:key error:error];
        return;
    }
    
    [self success:key];
}

/* Sent periodically to notify the delegate of download progress. */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    AKDownloadManagerLog(@"bytesWritten:%@ totalBytesWritten:%@ totalBytesExpectedToWrite:%@", @(bytesWritten), @(totalBytesWritten), @(totalBytesExpectedToWrite));
    void (^progressBlock)(CGFloat progress) = self.downloaderDicM[downloadTask.originalRequest.URL.absoluteString].progressBlock;
    !progressBlock ? : progressBlock((CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite);
}

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data. 
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    AKDownloadManagerLog(@"fileOffset:%@ expectedTotalBytes:%@", @(fileOffset), @(expectedTotalBytes));
    void (^progressBlock)(CGFloat progress) = self.downloaderDicM[downloadTask.originalRequest.URL.absoluteString].progressBlock;
    !progressBlock ? : progressBlock((CGFloat)fileOffset / (CGFloat)expectedTotalBytes);
}

#pragma mark- 私有方法
- (void)success:(NSString *)key {
    void (^success)(NSString *tmpFilePath) = self.downloaderDicM[key].successBlock;
    !success ? : success(self.downloaderDicM[key].savePath);
    [self.downloaderDicM removeObjectForKey:key];
}

- (void)failure:(NSString *)key error:(NSError *)error {
    void (^failure)(NSError *error) = self.downloaderDicM[key].failureBlock;
    !failure ? : failure(error);
    [self.downloaderDicM removeObjectForKey:key];
}

- (void)saveResumeData:(NSData *)resumeData savePath:(NSString *)savePath {
    if (!savePath.length) {
        return;
    }
    
    if (!resumeData.length) {
        return;
    }
    
    [NSKeyedArchiver archiveRootObject:resumeData toFile:savePath];
}

@end
