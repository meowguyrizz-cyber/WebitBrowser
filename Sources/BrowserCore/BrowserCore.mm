#import <WebKit/WebKit.h>

#import "BrowserCore.hpp"

#include <algorithm>
#include <sstream>
#include <string>
#include <vector>

using namespace webit;

@interface BrowserHost : NSObject <WKNavigationDelegate, NSURLSessionDownloadDelegate> {
    WKWebView* webView_;
    NSURLSession* downloadSession_;
    std::function<void(const std::string&)> pageLoadedCallback_;
    std::function<void(const DownloadItem&)> downloadProgressCallback_;
}

@property (nonatomic, strong) WKWebView* webView;
@property (nonatomic, copy) NSString* currentURL;

- (instancetype)initWithFrame:(CGRect)frame;
- (BOOL)loadURL:(NSString*)urlString;
- (BOOL)goBack;
- (BOOL)goForward;
- (BOOL)reload;
- (void)setPageLoadedCallback:(std::function<void(const std::string&)>)callback;
- (void)setDownloadProgressCallback:(std::function<void(const DownloadItem&)>)callback;
- (void)handleDownload:(NSString*)urlString fileName:(NSString*)fileName;

@end

@implementation BrowserHost

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super init];
    if (self) {
        WKWebViewConfiguration* config = [[WKWebViewConfiguration alloc] init];
        config.allowsInlineMediaPlayback = YES;
        config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
        _webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
        _webView.navigationDelegate = self;
        _webView.allowsBackForwardNavigationGestures = YES;

        NSURLSessionConfiguration* sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        downloadSession_ = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (BOOL)loadURL:(NSString*)urlString {
    if (urlString.length == 0) {
        return NO;
    }

    NSString* trimmed = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0) {
        return NO;
    }

    NSURL* url = nil;
    if ([trimmed containsString:@"://"]) {
        url = [NSURL URLWithString:trimmed];
    } else if ([trimmed containsString:@"."] || [trimmed containsString:@"/"]) {
        NSString* normalized = [NSString stringWithFormat:@"https://%@", trimmed];
        url = [NSURL URLWithString:normalized];
    } else {
        NSString* escaped = [trimmed stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString* queryURL = [NSString stringWithFormat:@"https://www.google.com/search?q=%@", escaped ?: trimmed];
        url = [NSURL URLWithString:queryURL];
    }

    if (!url) {
        return NO;
    }

    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    [_webView loadRequest:request];
    return YES;
}

- (BOOL)goBack {
    if ([_webView canGoBack]) {
        [_webView goBack];
        return YES;
    }
    return NO;
}

- (BOOL)goForward {
    if ([_webView canGoForward]) {
        [_webView goForward];
        return YES;
    }
    return NO;
}

- (BOOL)reload {
    [_webView reload];
    return YES;
}

- (void)setPageLoadedCallback:(std::function<void(const std::string&)>)callback {
    pageLoadedCallback_ = std::move(callback);
}

- (void)setDownloadProgressCallback:(std::function<void(const DownloadItem&)>)callback {
    downloadProgressCallback_ = std::move(callback);
}

- (void)handleDownload:(NSString*)urlString fileName:(NSString*)fileName {
    NSURL* url = [NSURL URLWithString:urlString];
    if (!url) {
        return;
    }

    NSString* safeFileName = fileName ?: @"download.bin";
    DownloadItem item;
    item.url = [urlString UTF8String];
    item.file_name = [safeFileName UTF8String];
    item.destination_path = "/var/mobile/Downloads/";
    item.total_bytes = 0;
    item.bytes_received = 0;
    item.is_complete = false;
    item.status = "downloading";
    if (downloadProgressCallback_) {
        downloadProgressCallback_(item);
    }

    NSURLSessionDownloadTask* task = [downloadSession_ downloadTaskWithURL:url];
    [task resume];
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    if (!downloadProgressCallback_) {
        return;
    }

    DownloadItem item;
    item.url = [[downloadTask.originalRequest.URL absoluteString] UTF8String];
    item.file_name = [[downloadTask.response.suggestedFilename ?: @"download.bin" ] UTF8String];
    item.total_bytes = totalBytesExpectedToWrite;
    item.bytes_received = totalBytesWritten;
    item.is_complete = false;
    item.status = "downloading";
    downloadProgressCallback_(item);
}

- (void)URLSession:(NSURLSession*)session downloadTask:(NSURLSessionDownloadTask*)downloadTask didFinishDownloadingToURL:(NSURL*)location {
    NSString* docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString* destinationName = downloadTask.response.suggestedFilename ?: @"download.bin";
    NSString* destination = [docsPath stringByAppendingPathComponent:destinationName];
    NSURL* destinationURL = [NSURL fileURLWithPath:destination];
    [[NSFileManager defaultManager] removeItemAtURL:destinationURL error:nil];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:nil];

    DownloadItem completed;
    completed.url = [[downloadTask.originalRequest.URL absoluteString] UTF8String];
    completed.file_name = [destinationName UTF8String];
    completed.destination_path = [destination UTF8String];
    completed.total_bytes = [downloadTask.response expectedContentLength];
    completed.bytes_received = [downloadTask.response expectedContentLength];
    completed.is_complete = true;
    completed.status = "complete";
    if (downloadProgressCallback_) {
        downloadProgressCallback_(completed);
    }
}

- (void)webView:(WKWebView*)webView decidePolicyForNavigationAction:(WKNavigationAction*)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    if (navigationAction.request.URL == nil) {
        decisionHandler(WKNavigationActionPolicyAllow);
        return;
    }

    NSString* urlString = navigationAction.request.URL.absoluteString;
    if ([urlString containsString:@"javascript:"] || [urlString containsString:@"data:"] || [urlString containsString:@"file:"]) {
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }

    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView*)webView didFinishNavigation:(WKNavigation*)navigation {
    NSString* currentURL = webView.URL.absoluteString ?: @"";
    if (pageLoadedCallback_) {
        pageLoadedCallback_([currentURL UTF8String]);
    }
}

@end

class BrowserCore::Impl {
public:
    BrowserHost* host;
};

BrowserCore::BrowserCore() : impl_(new Impl()) {
    CGRect frame = CGRectMake(0, 0, 0, 0);
    impl_->host = [[BrowserHost alloc] initWithFrame:frame];
}

BrowserCore::~BrowserCore() {
    impl_->host = nil;
    delete impl_;
}

bool BrowserCore::loadURL(const std::string& url) {
    NSString* input = [NSString stringWithUTF8String:url.c_str()];
    return [impl_->host loadURL:input];
}

bool BrowserCore::goBack() {
    return [impl_->host goBack];
}

bool BrowserCore::goForward() {
    return [impl_->host goForward];
}

bool BrowserCore::reload() {
    return [impl_->host reload];
}

std::string BrowserCore::normalizeURL(const std::string& input) const {
    std::string normalized = input;
    if (normalized.rfind("http://", 0) != 0 && normalized.rfind("https://", 0) != 0) {
        normalized = "https://" + normalized;
    }
    return normalized;
}

std::string BrowserCore::searchQueryToURL(const std::string& query) const {
    std::string safe = query;
    std::replace(safe.begin(), safe.end(), ' ', '+');
    return "https://www.google.com/search?q=" + safe;
}

SecurityVerdict BrowserCore::analyzeURL(const std::string& url) const {
    SecurityVerdict verdict;
    std::string lower = url;
    std::transform(lower.begin(), lower.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });

    if (rust_should_block_url(url.c_str())) {
        verdict.level = ThreatLevel::Malicious;
        verdict.reason = "Blocked by WebDefender: dangerous scheme";
        verdict.should_block = true;
        return verdict;
    }

    const std::vector<std::string> suspiciousPatterns = {
        ".exe", ".apk", ".msi", ".dmg", ".bat", ".cmd", ".scr", ".jar"
    };

    for (const auto& pattern : suspiciousPatterns) {
        if (lower.find(pattern) != std::string::npos) {
            verdict.level = ThreatLevel::Suspicious;
            verdict.reason = "Suspicious executable download pattern detected";
            verdict.should_block = true;
            return verdict;
        }
    }

    if (lower.find("javascript:") != std::string::npos || lower.find("data:") != std::string::npos || lower.find("file:") != std::string::npos) {
        verdict.level = ThreatLevel::Malicious;
        verdict.reason = "Dangerous URI scheme detected";
        verdict.should_block = true;
    }

    return verdict;
}

bool BrowserCore::isURLSafe(const std::string& url) const {
    return !analyzeURL(url).should_block;
}

std::string BrowserCore::resolveNavigationTarget(const std::string& raw_input) const {
    std::string input = raw_input;
    if (input.empty()) {
        return "https://www.google.com";
    }

    std::string trimmed = input;
    while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.front()))) {
        trimmed.erase(trimmed.begin());
    }
    while (!trimmed.empty() && std::isspace(static_cast<unsigned char>(trimmed.back()))) {
        trimmed.pop_back();
    }

    if (trimmed.find("://") != std::string::npos) {
        return trimmed;
    }

    if (trimmed.find('.') != std::string::npos || trimmed.find('/') != std::string::npos) {
        if (trimmed.rfind("http://", 0) != 0 && trimmed.rfind("https://", 0) != 0) {
            return "https://" + trimmed;
        }
        return trimmed;
    }

    return searchQueryToURL(trimmed);
}

void BrowserCore::setPageLoadedCallback(std::function<void(const std::string&)> callback) {
    [impl_->host setPageLoadedCallback:std::move(callback)];
}

void BrowserCore::setDownloadProgressCallback(std::function<void(const DownloadItem&)> callback) {
    [impl_->host setDownloadProgressCallback:std::move(callback)];
}

void BrowserCore::handleDownload(const std::string& url, const std::string& file_name) {
    NSString* urlString = [NSString stringWithUTF8String:url.c_str()];
    NSString* fileName = [NSString stringWithUTF8String:file_name.c_str()];
    [impl_->host handleDownload:urlString fileName:fileName];
}

extern "C" {
    char* rust_filter_url(const char* raw_input) {
        if (!raw_input) {
            return nullptr;
        }
        std::string input(raw_input);
        if (input.empty()) {
            return nullptr;
        }

        static std::string result;
        result = input;
        return const_cast<char*>(result.c_str());
    }
}
