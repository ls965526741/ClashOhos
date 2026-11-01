#pragma once

#include <cstdint>
#include <string>
#include <functional>

struct TrafficPair {
    uint64_t upload;
    uint64_t download;
};

using CompleteFn = std::function<void(const std::string &error)>;

bool AdapterLoad();
std::string AdapterPing();
std::string AdapterLoadDir(const std::string &path);
std::string AdapterVersion();
void AdapterInit(const std::string &home, const std::string &version, int sdk);
void AdapterReset();
void AdapterLoadConfig(const std::string &path, CompleteFn done);
void AdapterFetch(const std::string &path, const std::string &url, bool force, CompleteFn done);
std::string AdapterTunnelState();
TrafficPair AdapterTrafficNow();
TrafficPair AdapterTrafficTotal();
std::string AdapterGroupNames(bool exclude);
std::string AdapterGroup(const std::string &name, const std::string &sort);
bool AdapterPatch(const std::string &group, const std::string &name);
int AdapterStartTun(int fd, const std::string &stack, const std::string &gateway,
                    const std::string &portal, const std::string &dns);
void AdapterStopTun();
std::string AdapterProviders();
void AdapterUpdateProvider(const std::string &type, const std::string &name, CompleteFn done);
void AdapterHealthCheck(const std::string &name, CompleteFn done);
void AdapterHealthCheckAll();
std::string AdapterReadOverride(int slot);
void AdapterWriteOverride(int slot, const std::string &content);
void AdapterClearOverride(int slot);
void AdapterSubscribeLogcat();
bool AdapterHasLibclash();
std::string AdapterLastError();
void AdapterRegisterProtectWait(void (*fn)(int fd));
void AdapterProtectDone();
