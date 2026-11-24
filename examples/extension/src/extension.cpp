#include <curl/curl.h>

#include <chrono>
#include <future>
#include <string>
#include <utility>
#include <vector>

#include "smsdk_ext.h"

namespace {

struct PendingCheck {
  int user_id;
  std::future<bool> allowed;
};

std::vector<PendingCheck> g_pending;

size_t DiscardBody(char*, size_t size, size_t nmemb, void*) {
  return size * nmemb;
}

// Runs on a background thread, so it must not call into SourceMod.
bool RequestSucceeds(const std::string& url) {
  CURL* curl = curl_easy_init();
  if (curl == nullptr) {
    return false;
  }
  curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
  curl_easy_setopt(curl, CURLOPT_PROTOCOLS_STR, "https");
  curl_easy_setopt(curl, CURLOPT_FAILONERROR, 1L);
  curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT, 10L);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, DiscardBody);
  CURLcode code = curl_easy_perform(curl);
  curl_easy_cleanup(curl);
  return code == CURLE_OK;
}

cell_t Check(IPluginContext* context, const cell_t* params) {
  IGamePlayer* player = playerhelpers->GetGamePlayer(params[1]);
  if (player == nullptr || !player->IsConnected()) {
    return context->ThrowNativeError("Client %d is not connected", params[1]);
  }

  char* url;
  context->LocalToString(params[2], &url);

  g_pending.push_back({player->GetUserId(),
                       std::async(std::launch::async, RequestSucceeds,
                                  std::string(url))});
  return 0;
}

// Kicks players on the main thread once their request has finished.
void OnGameFrame(bool simulating) {
  for (auto it = g_pending.begin(); it != g_pending.end();) {
    if (it->allowed.wait_for(std::chrono::seconds(0)) !=
        std::future_status::ready) {
      ++it;
      continue;
    }

    bool allowed = it->allowed.get();
    int client = playerhelpers->GetClientOfUserId(it->user_id);
    it = g_pending.erase(it);
    if (!allowed && client != 0) {
      playerhelpers->GetGamePlayer(client)->Kick(
          "You are not allowed to join this server");
    }
  }
}

const sp_nativeinfo_t kNatives[] = {
    {"AuthByUrl_Check", Check},
    {nullptr, nullptr},
};

class AuthByUrl : public SDKExtension {
 public:
  bool SDK_OnLoad(char* error, size_t maxlength, bool late) override {
    if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) {
      smutils->Format(error, maxlength, "Could not initialize libcurl");
      return false;
    }
    sharesys->AddNatives(myself, kNatives);
    smutils->AddGameFrameHook(OnGameFrame);
    return true;
  }

  void SDK_OnUnload() override {
    smutils->RemoveGameFrameHook(OnGameFrame);
    // Waits for outstanding requests.
    g_pending.clear();
    curl_global_cleanup();
  }
};

AuthByUrl g_auth_by_url;

}  // namespace

SMEXT_LINK(&g_auth_by_url);
