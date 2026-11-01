#include "clash_adapter.h"

#include <hilog/log.h>
#include <napi/native_api.h>
#include <unistd.h>

#undef LOG_TAG
#define LOG_TAG "ClashNapi"
#include <condition_variable>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

static std::string GetString(napi_env env, napi_value v)
{
    size_t len = 0;
    napi_get_value_string_utf8(env, v, nullptr, 0, &len);
    std::vector<char> buf(len + 1);
    napi_get_value_string_utf8(env, v, buf.data(), len + 1, &len);
    return std::string(buf.data(), len);
}

static napi_threadsafe_function gProtectTsfn = nullptr;

static void ProtectJs(napi_env env, napi_value jsCb, void *ctx, void *data)
{
    (void)ctx;
    int fd = static_cast<int>(reinterpret_cast<intptr_t>(data));
    if (env == nullptr || jsCb == nullptr) {
        AdapterProtectDone();
        return;
    }
    napi_value undefined;
    napi_value fdv;
    napi_value result;
    napi_get_undefined(env, &undefined);
    napi_create_int32(env, fd, &fdv);
    napi_status st = napi_call_function(env, undefined, jsCb, 1, &fdv, &result);
    if (st != napi_ok) {
        AdapterProtectDone();
    }
}

static void ProtectWait(int fd)
{
    if (gProtectTsfn == nullptr) {
        AdapterProtectDone();
        return;
    }
    napi_status st = napi_call_threadsafe_function(gProtectTsfn,
        reinterpret_cast<void *>(static_cast<intptr_t>(fd)), napi_tsfn_blocking);
    if (st != napi_ok) {
        AdapterProtectDone();
    }
}

static napi_value JsSetSocketProtect(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    if (gProtectTsfn != nullptr) {
        napi_release_threadsafe_function(gProtectTsfn, napi_tsfn_abort);
        gProtectTsfn = nullptr;
    }
    napi_value name;
    napi_create_string_utf8(env, "clash_protect", NAPI_AUTO_LENGTH, &name);
    napi_status st = napi_create_threadsafe_function(env, args[0], nullptr, name, 0, 1, nullptr, nullptr, nullptr,
        ProtectJs, &gProtectTsfn);
    if (st == napi_ok) {
        AdapterRegisterProtectWait(&ProtectWait);
    }
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsProtectDone(napi_env env, napi_callback_info info)
{
    (void)env;
    (void)info;
    AdapterProtectDone();
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsPing(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value ret;
    auto s = AdapterPing();
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsVersion(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value ret;
    auto s = AdapterVersion();
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsInit(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t sdk = 22;
    napi_get_value_int32(env, args[2], &sdk);
    AdapterInit(GetString(env, args[0]), GetString(env, args[1]), sdk);
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsReset(napi_env env, napi_callback_info info)
{
    (void)info;
    AdapterReset();
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value MakePromise(napi_env env, napi_deferred *deferred)
{
    napi_value promise;
    napi_create_promise(env, deferred, &promise);
    return promise;
}

static void ResolveStr(napi_env env, napi_deferred deferred, const std::string &err)
{
    napi_value v;
    napi_create_string_utf8(env, err.c_str(), err.size(), &v);
    napi_resolve_deferred(env, deferred, v);
}

struct WaitWork {
    std::function<void(CompleteFn)> job;
    std::string err;
    napi_deferred deferred;
    napi_async_work work;
    std::mutex mu;
    std::condition_variable cv;
    bool done = false;
};

static void WaitExecute(napi_env env, void *data)
{
    (void)env;
    auto *w = static_cast<WaitWork *>(data);
    w->job([w](const std::string &err) {
        w->err = err;
        {
            std::lock_guard<std::mutex> lock(w->mu);
            w->done = true;
        }
        w->cv.notify_one();
    });
    std::unique_lock<std::mutex> lock(w->mu);
    w->cv.wait(lock, [w] { return w->done; });
}

static void WaitComplete(napi_env env, napi_status status, void *data)
{
    (void)status;
    auto *w = static_cast<WaitWork *>(data);
    ResolveStr(env, w->deferred, w->err);
    napi_delete_async_work(env, w->work);
    delete w;
}

static napi_value StartWait(napi_env env, std::function<void(CompleteFn)> job)
{
    napi_deferred deferred;
    napi_value promise = MakePromise(env, &deferred);
    auto *w = new WaitWork();
    w->job = std::move(job);
    w->deferred = deferred;
    napi_value name;
    napi_create_string_utf8(env, "clash_wait", NAPI_AUTO_LENGTH, &name);
    napi_status st = napi_create_async_work(env, nullptr, name, WaitExecute, WaitComplete, w, &w->work);
    if (st != napi_ok) {
        delete w;
        ResolveStr(env, deferred, "napi_create_async_work failed");
        return promise;
    }
    st = napi_queue_async_work(env, w->work);
    if (st != napi_ok) {
        napi_delete_async_work(env, w->work);
        delete w;
        ResolveStr(env, deferred, "napi_queue_async_work failed");
    }
    return promise;
}

struct LoadDirWork {
    std::string path;
    std::string err;
    napi_deferred deferred;
    napi_async_work work;
};

static void LoadDirExecute(napi_env env, void *data)
{
    (void)env;
    auto *w = static_cast<LoadDirWork *>(data);
    w->err = AdapterLoadDir(w->path);
}

static void LoadDirComplete(napi_env env, napi_status status, void *data)
{
    (void)status;
    auto *w = static_cast<LoadDirWork *>(data);
    ResolveStr(env, w->deferred, w->err);
    napi_delete_async_work(env, w->work);
    delete w;
}

static napi_value JsLoad(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_deferred deferred;
    napi_value promise = MakePromise(env, &deferred);
    auto *w = new LoadDirWork();
    w->path = GetString(env, args[0]);
    w->deferred = deferred;
    napi_value name;
    napi_create_string_utf8(env, "clash_load_dir", NAPI_AUTO_LENGTH, &name);
    napi_status st = napi_create_async_work(env, nullptr, name, LoadDirExecute, LoadDirComplete, w, &w->work);
    if (st != napi_ok) {
        delete w;
        ResolveStr(env, deferred, "napi_create_async_work failed");
        return promise;
    }
    st = napi_queue_async_work(env, w->work);
    if (st != napi_ok) {
        napi_delete_async_work(env, w->work);
        delete w;
        ResolveStr(env, deferred, "napi_queue_async_work failed");
    }
    return promise;
}

static napi_value JsFetch(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    bool force = false;
    napi_get_value_bool(env, args[2], &force);
    std::string path = GetString(env, args[0]);
    std::string url = GetString(env, args[1]);
    return StartWait(env, [path, url, force](CompleteFn done) {
        AdapterFetch(path, url, force, std::move(done));
    });
}

static napi_value JsTunnel(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value ret;
    auto s = AdapterTunnelState();
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value TrafficObj(napi_env env, TrafficPair t)
{
    napi_value obj;
    napi_create_object(env, &obj);
    napi_value u;
    napi_value d;
    napi_create_double(env, static_cast<double>(t.upload), &u);
    napi_create_double(env, static_cast<double>(t.download), &d);
    napi_set_named_property(env, obj, "upload", u);
    napi_set_named_property(env, obj, "download", d);
    return obj;
}

static napi_value JsNow(napi_env env, napi_callback_info info)
{
    (void)info;
    return TrafficObj(env, AdapterTrafficNow());
}

static napi_value JsTotal(napi_env env, napi_callback_info info)
{
    (void)info;
    return TrafficObj(env, AdapterTrafficTotal());
}

static napi_value JsNames(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    bool ex = true;
    napi_get_value_bool(env, args[0], &ex);
    napi_value ret;
    auto s = AdapterGroupNames(ex);
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsGroup(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_value ret;
    auto s = AdapterGroup(GetString(env, args[0]), GetString(env, args[1]));
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsPatch(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_value ret;
    napi_get_boolean(env, AdapterPatch(GetString(env, args[0]), GetString(env, args[1])), &ret);
    return ret;
}

static napi_value JsStartTun(napi_env env, napi_callback_info info)
{
    size_t argc = 5;
    napi_value args[5] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t fd = -1;
    napi_get_value_int32(env, args[0], &fd);
    int rc = AdapterStartTun(fd, GetString(env, args[1]), GetString(env, args[2]),
                             GetString(env, args[3]), GetString(env, args[4]));
    napi_value ret;
    napi_create_int32(env, rc, &ret);
    return ret;
}

static napi_value JsStopTun(napi_env env, napi_callback_info info)
{
    (void)info;
    AdapterStopTun();
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsProviders(napi_env env, napi_callback_info info)
{
    (void)info;
    napi_value ret;
    auto s = AdapterProviders();
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsUpdate(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    std::string type = GetString(env, args[0]);
    std::string name = GetString(env, args[1]);
    return StartWait(env, [type, name](CompleteFn done) {
        AdapterUpdateProvider(type, name, std::move(done));
    });
}

static napi_value JsHealth(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    napi_deferred deferred;
    napi_value promise = MakePromise(env, &deferred);
    AdapterHealthCheck(GetString(env, args[0]), [env, deferred](const std::string &err) {
        napi_value u;
        napi_get_undefined(env, &u);
        if (err.empty()) {
            napi_resolve_deferred(env, deferred, u);
        } else {
            napi_value v;
            napi_create_string_utf8(env, err.c_str(), err.size(), &v);
            napi_reject_deferred(env, deferred, v);
        }
    });
    return promise;
}

static napi_value JsHealthAll(napi_env env, napi_callback_info info)
{
    (void)info;
    AdapterHealthCheckAll();
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsReadOv(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t slot = 0;
    napi_get_value_int32(env, args[0], &slot);
    napi_value ret;
    auto s = AdapterReadOverride(slot);
    napi_create_string_utf8(env, s.c_str(), s.size(), &ret);
    return ret;
}

static napi_value JsWriteOv(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t slot = 0;
    napi_get_value_int32(env, args[0], &slot);
    AdapterWriteOverride(slot, GetString(env, args[1]));
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsClearOv(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    int32_t slot = 0;
    napi_get_value_int32(env, args[0], &slot);
    AdapterClearOverride(slot);
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value JsSubLog(napi_env env, napi_callback_info info)
{
    (void)info;
    AdapterSubscribeLogcat();
    napi_value u;
    napi_get_undefined(env, &u);
    return u;
}

static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        {"ping", nullptr, JsPing, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"coreVersion", nullptr, JsVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"coreInit", nullptr, JsInit, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"reset", nullptr, JsReset, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"load", nullptr, JsLoad, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"fetchAndValid", nullptr, JsFetch, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryTunnelState", nullptr, JsTunnel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryTrafficNow", nullptr, JsNow, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryTrafficTotal", nullptr, JsTotal, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryGroupNames", nullptr, JsNames, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryGroup", nullptr, JsGroup, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"patchSelector", nullptr, JsPatch, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"startTun", nullptr, JsStartTun, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopTun", nullptr, JsStopTun, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"queryProviders", nullptr, JsProviders, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"updateProvider", nullptr, JsUpdate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"healthCheck", nullptr, JsHealth, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"healthCheckAll", nullptr, JsHealthAll, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"readOverride", nullptr, JsReadOv, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"writeOverride", nullptr, JsWriteOv, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"clearOverride", nullptr, JsClearOv, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"subscribeLogcat", nullptr, JsSubLog, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setSocketProtect", nullptr, JsSetSocketProtect, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"protectDone", nullptr, JsProtectDone, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}

static napi_module gModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "clash_ohos",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterModule(void)
{
    napi_module_register(&gModule);
    OH_LOG_INFO(LOG_APP, "RegisterModule clash_ohos pid=%{public}d", static_cast<int>(getpid()));
}
