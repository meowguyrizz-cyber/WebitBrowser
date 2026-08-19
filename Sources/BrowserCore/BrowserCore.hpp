#pragma once

#include <functional>
#include <string>
#include <vector>

extern "C" {
    char* rust_filter_url(const char* raw_input);
    unsigned char rust_should_block_url(const char* raw_input);
}

namespace webit {

enum class ThreatLevel {
    None,
    Suspicious,
    Malicious
};

struct SecurityVerdict {
    ThreatLevel level = ThreatLevel::None;
    std::string reason;
    bool should_block = false;
};

struct DownloadItem {
    std::string url;
    std::string file_name;
    std::string destination_path;
    long long bytes_received = 0;
    long long total_bytes = 0;
    bool is_complete = false;
    bool is_blocked = false;
    std::string status = "queued";
};

class BrowserCore {
public:
    BrowserCore();
    ~BrowserCore();

    bool loadURL(const std::string& url);
    bool goBack();
    bool goForward();
    bool reload();

    std::string normalizeURL(const std::string& input) const;
    std::string searchQueryToURL(const std::string& query) const;
    std::string resolveNavigationTarget(const std::string& raw_input) const;
    SecurityVerdict analyzeURL(const std::string& url) const;
    bool isURLSafe(const std::string& url) const;
    void setPageLoadedCallback(std::function<void(const std::string&)> callback);
    void setDownloadProgressCallback(std::function<void(const DownloadItem&)> callback);
    void handleDownload(const std::string& url, const std::string& file_name);

private:
    class Impl;
    Impl* impl_;
};

} // namespace webit
