#include <curl/curl.h>
#include <stdio.h>

// No credentials or network traffic: force the linker to resolve the full archive
// and check that the deployed TLS/zlib backend is still available at runtime.
int main(void) {
    const curl_version_info_data *info = curl_version_info(CURLVERSION_NOW);
    if (!info || !(info->features & CURL_VERSION_SSL) || !(info->features & CURL_VERSION_LIBZ)) return 1;
    if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) return 2;
    CURL *handle = curl_easy_init();
    if (!handle) return 3;
    printf("PASS curl %s, TLS %s, zlib %s\n", info->version, info->ssl_version, info->libz_version);
    curl_easy_cleanup(handle);
    curl_global_cleanup();
    return 0;
}
