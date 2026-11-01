#include "clash_adapter.h"

#include <dlfcn.h>
#include <hilog/log.h>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <cstring>
#include <vector>

#undef LOG_TAG
#define LOG_TAG "ClashAdapter"

typedef const char *c_string;

typedef void (*coreInit_t)(c_string, c_string, c_string, int);
typedef void (*reset_t)();
typedef void (*load_t)(void *, c_string);
typedef char *(*clashLoad_t)(c_string);
typedef void (*fetch_t)(void *, c_string, c_string, int);
typedef char *(*queryStr_t)();
typedef void (*queryNow_t)(uint64_t *, uint64_t *);
typedef char *(*queryGroupNames_t)(int);
typedef char *(*queryGroup_t)(c_string, c_string);
typedef int (*patch_t)(c_string, c_string);
typedef int (*startTun_t)(int, c_string, c_string, c_string, c_string, void *);
typedef void (*stopTun_t)();
typedef char *(*queryProviders_t)();
typedef void (*updateProvider_t)(void *, c_string, c_string);
typedef void (*healthCheck_t)(void *, c_string);
typedef void (*healthCheckAll_t)();
typedef char *(*readOverride_t)(int);
typedef void (*writeOverride_t)(int, c_string);
typedef void (*clearOverride_t)(int);
typedef void (*subscribeLogcat_t)(void *);

static void *gHandle = nullptr;
static bool gLoaded = false;
static std::mutex gMu;
static std::string gLastError = "not attempted";

static coreInit_t p_coreInit = nullptr;
static reset_t p_reset = nullptr;
static load_t p_load = nullptr;
static clashLoad_t p_clashLoad = nullptr;
static fetch_t p_fetch = nullptr;
static queryStr_t p_queryTunnel = nullptr;
static queryNow_t p_queryNow = nullptr;
static queryNow_t p_queryTotal = nullptr;
static queryGroupNames_t p_names = nullptr;
static queryGroup_t p_group = nullptr;
static patch_t p_patch = nullptr;
static startTun_t p_startTun = nullptr;
static stopTun_t p_stopTun = nullptr;
static queryProviders_t p_providers = nullptr;
static updateProvider_t p_update = nullptr;
static healthCheck_t p_health = nullptr;
static healthCheckAll_t p_healthAll = nullptr;
static readOverride_t p_readOv = nullptr;
static writeOverride_t p_writeOv = nullptr;
static clearOverride_t p_clearOv = nullptr;
static subscribeLogcat_t p_subLog = nullptr;

static int gMarkLogs = 0;
static void (*gProtectWait)(int fd) = nullptr;
static std::mutex gProtectCallMu;
static std::mutex gProtectDoneMu;
static std::condition_variable gProtectDoneCv;
static bool gProtectDone = false;

void AdapterRegisterProtectWait(void (*fn)(int fd))
{
    gProtectWait = fn;
}

void AdapterProtectDone()
{
    std::lock_guard<std::mutex> lock(gProtectDoneMu);
    gProtectDone = true;
    gProtectDoneCv.notify_all();
}

static void MarkSocketImpl(void *tun, int fd)
{
    (void)tun;
    if (gMarkLogs < 8) {
        gMarkLogs++;
        OH_LOG_INFO(LOG_APP, "mark_socket fd=%{public}d wait=%{public}d", fd, gProtectWait ? 1 : 0);
    }
    if (gProtectWait) {
        std::lock_guard<std::mutex> callLock(gProtectCallMu);
        {
            std::lock_guard<std::mutex> lock(gProtectDoneMu);
            gProtectDone = false;
        }
        gProtectWait(fd);
        std::unique_lock<std::mutex> lock(gProtectDoneMu);
        gProtectDoneCv.wait_for(lock, std::chrono::milliseconds(400), [] { return gProtectDone; });
    }
}

static int QueryUidImpl(void *tun, int protocol, const char *source, const char *target)
{
    (void)tun;
    (void)protocol;
    (void)source;
    (void)target;
    return -1;
}

static void CompleteImpl(void *obj, const char *exception)
{
    auto *fn = static_cast<CompleteFn *>(obj);
    if (fn) {
        (*fn)(exception ? exception : "");
        delete fn;
    }
}

static void FetchReportImpl(void *cb, const char *json)
{
    (void)cb;
    OH_LOG_INFO(LOG_APP, "fetch report %{public}s", json ? json : "");
}

static void FetchCompleteImpl(void *cb, const char *error)
{
    auto *fn = static_cast<CompleteFn *>(cb);
    if (fn) {
        (*fn)(error ? error : "");
        delete fn;
    }
}

static int LogcatImpl(void *iface, const char *payload)
{
    (void)iface;
    OH_LOG_INFO(LOG_APP, "logcat %{public}s", payload ? payload : "");
    return 0;
}

static void ReleaseImpl(void *obj)
{
    (void)obj;
}

static int OpenContentImpl(const char *url, char *error, int error_length)
{
    (void)url;
    if (error && error_length > 0) {
        std::strncpy(error, "content uri unsupported on ohos", error_length - 1);
        error[error_length - 1] = 0;
    }
    return -1;
}

static void *MustSym(const char *name)
{
    void *s = dlsym(gHandle, name);
    if (!s) {
        OH_LOG_WARN(LOG_APP, "missing symbol %{public}s", name);
    }
    return s;
}

template <typename T>
static void SetPtr(const char *name, T value)
{
    auto **slot = reinterpret_cast<T *>(dlsym(gHandle, name));
    if (slot) {
        *slot = value;
    } else {
        OH_LOG_WARN(LOG_APP, "callback slot missing %{public}s", name);
    }
}

static void *TryOpen(const char *path)
{
    dlerror();
    void *h = dlopen(path, RTLD_NOW);
    const char *err = dlerror();
    if (h) {
        OH_LOG_INFO(LOG_APP, "dlopen ok %{public}s", path);
        gLastError = std::string("ok:") + path;
        return h;
    }
    std::string msg = path;
    msg += " -> ";
    msg += (err ? err : "null");
    OH_LOG_WARN(LOG_APP, "dlopen fail %{public}s", msg.c_str());
    if (gLastError == "not attempted" || gLastError.rfind("ok:", 0) != 0) {
        gLastError = msg;
    }
    return nullptr;
}

static std::string DirOf(const char *path)
{
    std::string p = path ? path : "";
    auto pos = p.find_last_of('/');
    if (pos == std::string::npos) {
        return "";
    }
    return p.substr(0, pos);
}

bool AdapterLoad()
{
    std::lock_guard<std::mutex> lock(gMu);
    if (gLoaded) {
        return gHandle != nullptr;
    }
    gLoaded = true;

    // libclash_ohos.so is NAPI-only. Go lives in libclash_core.so (c-archive
    // whole-linked). Try the NAPI directory first so :vpn sees the same folder.
    Dl_info info;
    memset(&info, 0, sizeof(info));
    std::string dir;
    if (dladdr(reinterpret_cast<void *>(&AdapterLoad), &info) && info.dli_fname) {
        OH_LOG_INFO(LOG_APP, "napi fname %{public}s", info.dli_fname);
        dir = DirOf(info.dli_fname);
    }
    if (!dir.empty()) {
        gHandle = TryOpen((dir + "/libclash_core.so").c_str());
    }
    if (!gHandle) {
        gHandle = TryOpen("libclash_core.so");
    }
    if (!gHandle) {
        gHandle = TryOpen("/data/storage/el1/bundle/libs/arm64/libclash_core.so");
    }
    if (!gHandle) {
        gHandle = TryOpen("/data/storage/el1/bundle/libs/arm64-v8a/libclash_core.so");
    }
    if (!gHandle) {
        gHandle = TryOpen("/data/storage/el1/bundle/libs/x86_64/libclash_core.so");
    }
    if (!gHandle && info.dli_fname) {
        gHandle = TryOpen(info.dli_fname);
    }
    if (!gHandle) {
        gHandle = dlopen(nullptr, RTLD_NOW);
        if (gHandle) {
            gLastError = "ok:RTLD_DEFAULT";
        }
    }
    if (!gHandle) {
        OH_LOG_ERROR(LOG_APP, "libclash unavailable: %{public}s", gLastError.c_str());
        return false;
    }
    if (dlsym(gHandle, "coreInit") == nullptr && dlsym(RTLD_DEFAULT, "coreInit") != nullptr) {
        gHandle = RTLD_DEFAULT;
        gLastError = "ok:RTLD_DEFAULT-sym";
    }
    p_coreInit = reinterpret_cast<coreInit_t>(MustSym("coreInit"));
    p_reset = reinterpret_cast<reset_t>(MustSym("reset"));
    p_load = reinterpret_cast<load_t>(MustSym("load"));
    p_clashLoad = reinterpret_cast<clashLoad_t>(MustSym("clashLoad"));
    if (p_coreInit == nullptr || p_load == nullptr) {
        gLastError = std::string("core symbols missing in ") + (info.dli_fname ? info.dli_fname : "unknown");
        OH_LOG_ERROR(LOG_APP, "%{public}s", gLastError.c_str());
        gHandle = nullptr;
        return false;
    }
    p_fetch = reinterpret_cast<fetch_t>(MustSym("fetchAndValid"));
    p_queryTunnel = reinterpret_cast<queryStr_t>(MustSym("queryTunnelState"));
    p_queryNow = reinterpret_cast<queryNow_t>(MustSym("queryNow"));
    p_queryTotal = reinterpret_cast<queryNow_t>(MustSym("queryTotal"));
    p_names = reinterpret_cast<queryGroupNames_t>(MustSym("queryGroupNames"));
    p_group = reinterpret_cast<queryGroup_t>(MustSym("queryGroup"));
    p_patch = reinterpret_cast<patch_t>(MustSym("patchSelector"));
    p_startTun = reinterpret_cast<startTun_t>(MustSym("startTun"));
    p_stopTun = reinterpret_cast<stopTun_t>(MustSym("stopTun"));
    p_providers = reinterpret_cast<queryProviders_t>(MustSym("queryProviders"));
    p_update = reinterpret_cast<updateProvider_t>(MustSym("updateProvider"));
    p_health = reinterpret_cast<healthCheck_t>(MustSym("healthCheck"));
    p_healthAll = reinterpret_cast<healthCheckAll_t>(MustSym("healthCheckAll"));
    p_readOv = reinterpret_cast<readOverride_t>(MustSym("readOverride"));
    p_writeOv = reinterpret_cast<writeOverride_t>(MustSym("writeOverride"));
    p_clearOv = reinterpret_cast<clearOverride_t>(MustSym("clearOverride"));
    p_subLog = reinterpret_cast<subscribeLogcat_t>(MustSym("subscribeLogcat"));

    SetPtr("mark_socket_func", &MarkSocketImpl);
    SetPtr("query_socket_uid_func", &QueryUidImpl);
    SetPtr("complete_func", &CompleteImpl);
    SetPtr("fetch_report_func", &FetchReportImpl);
    SetPtr("fetch_complete_func", &FetchCompleteImpl);
    SetPtr("logcat_received_func", &LogcatImpl);
    SetPtr("open_content_func", &OpenContentImpl);
    SetPtr("release_object_func", &ReleaseImpl);
    return true;
}

bool AdapterHasLibclash()
{
    AdapterLoad();
    return gHandle != nullptr && p_load != nullptr;
}

std::string AdapterLastError()
{
    AdapterLoad();
    return gLastError;
}

std::string AdapterPing()
{
    return "napi-ok";
}

std::string AdapterLoadDir(const std::string &path)
{
    AdapterLoad();
    if (p_clashLoad == nullptr) {
        return std::string("clashLoad symbol missing: ") + AdapterLastError();
    }
    OH_LOG_INFO(LOG_APP, "clashLoad start %{public}s", path.c_str());
    char *s = p_clashLoad(path.c_str());
    std::string out = s ? s : "";
    free(s);
    OH_LOG_INFO(LOG_APP, "clashLoad done err=%{public}s", out.empty() ? "ok" : out.c_str());
    return out;
}

std::string AdapterVersion()
{
    if (!AdapterHasLibclash()) {
        return std::string("stub-no-libclash ") + AdapterLastError();
    }
    return "libclash-ohos";
}

void AdapterInit(const std::string &home, const std::string &version, int sdk)
{
    AdapterLoad();
    if (p_coreInit) {
        p_coreInit(home.c_str(), version.c_str(), "ohos-g0", sdk);
    }
}

void AdapterReset()
{
    if (p_reset) {
        p_reset();
    }
}

void AdapterLoadConfig(const std::string &path, CompleteFn done)
{
    AdapterLoad();
    if (!p_load) {
        done(std::string("libclash not loaded: ") + AdapterLastError());
        return;
    }
    OH_LOG_INFO(LOG_APP, "load start %{public}s", path.c_str());
    CompleteFn wrapped = [orig = std::move(done)](const std::string &err) {
        OH_LOG_INFO(LOG_APP, "load done err=%{public}s", err.empty() ? "ok" : err.c_str());
        orig(err);
    };
    p_load(new CompleteFn(std::move(wrapped)), path.c_str());
}

void AdapterFetch(const std::string &path, const std::string &url, bool force, CompleteFn done)
{
    if (!p_fetch) {
        done(std::string("libclash not loaded: ") + AdapterLastError());
        return;
    }
    p_fetch(new CompleteFn(std::move(done)), path.c_str(), url.c_str(), force ? 1 : 0);
}

std::string AdapterTunnelState()
{
    if (!p_queryTunnel) {
        return "{\"mode\":\"direct\"}";
    }
    char *s = p_queryTunnel();
    std::string out = s ? s : "{}";
    free(s);
    return out;
}

TrafficPair AdapterTrafficNow()
{
    TrafficPair t{0, 0};
    if (p_queryNow) {
        p_queryNow(&t.upload, &t.download);
    }
    return t;
}

TrafficPair AdapterTrafficTotal()
{
    TrafficPair t{0, 0};
    if (p_queryTotal) {
        p_queryTotal(&t.upload, &t.download);
    }
    return t;
}

std::string AdapterGroupNames(bool exclude)
{
    if (!p_names) {
        return "[]";
    }
    char *s = p_names(exclude ? 1 : 0);
    std::string out = s ? s : "[]";
    free(s);
    return out;
}

std::string AdapterGroup(const std::string &name, const std::string &sort)
{
    if (!p_group) {
        return "";
    }
    char *s = p_group(name.c_str(), sort.c_str());
    std::string out = s ? s : "";
    free(s);
    return out;
}

bool AdapterPatch(const std::string &group, const std::string &name)
{
    if (!p_patch) {
        return false;
    }
    return p_patch(group.c_str(), name.c_str()) != 0;
}

int AdapterStartTun(int fd, const std::string &stack, const std::string &gateway,
                    const std::string &portal, const std::string &dns)
{
    if (!p_startTun) {
        OH_LOG_ERROR(LOG_APP, "startTun skipped, no libclash, fd=%{public}d", fd);
        return 1;
    }
    OH_LOG_INFO(LOG_APP, "startTun fd=%{public}d stack=%{public}s gw=%{public}s portal=%{public}s dns=%{public}s",
                fd, stack.c_str(), gateway.c_str(), portal.c_str(), dns.c_str());
    int rc = p_startTun(fd, stack.c_str(), gateway.c_str(), portal.c_str(), dns.c_str(), nullptr);
    OH_LOG_INFO(LOG_APP, "startTun rc=%{public}d", rc);
    return rc;
}

void AdapterStopTun()
{
    if (p_stopTun) {
        p_stopTun();
    }
}

std::string AdapterProviders()
{
    if (!p_providers) {
        return "[]";
    }
    char *s = p_providers();
    std::string out = s ? s : "[]";
    free(s);
    return out;
}

void AdapterUpdateProvider(const std::string &type, const std::string &name, CompleteFn done)
{
    if (!p_update) {
        done("libclash not loaded");
        return;
    }
    p_update(new CompleteFn(std::move(done)), type.c_str(), name.c_str());
}

void AdapterHealthCheck(const std::string &name, CompleteFn done)
{
    if (!p_health) {
        done("libclash not loaded");
        return;
    }
    p_health(new CompleteFn(std::move(done)), name.c_str());
}

void AdapterHealthCheckAll()
{
    if (p_healthAll) {
        p_healthAll();
    }
}

std::string AdapterReadOverride(int slot)
{
    if (!p_readOv) {
        return "{}";
    }
    char *s = p_readOv(slot);
    std::string out = s ? s : "{}";
    free(s);
    return out;
}

void AdapterWriteOverride(int slot, const std::string &content)
{
    if (p_writeOv) {
        p_writeOv(slot, content.c_str());
    }
}

void AdapterClearOverride(int slot)
{
    if (p_clearOv) {
        p_clearOv(slot);
    }
}

void AdapterSubscribeLogcat()
{
    if (p_subLog) {
        p_subLog(nullptr);
    }
}
