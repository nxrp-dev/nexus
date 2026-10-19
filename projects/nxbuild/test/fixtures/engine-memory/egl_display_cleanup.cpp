// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
// Isolate the installed EGL stack's display cleanup without engine or SDL code.
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <dlfcn.h>
#include <cstdio>

int main()
{
    void* library = dlopen("libEGL.so.1", RTLD_NOW | RTLD_LOCAL);
    if (!library) { std::fprintf(stderr, "%s\n", dlerror()); return 2; }
    auto getProc = reinterpret_cast<PFNEGLGETPROCADDRESSPROC>(dlsym(library, "eglGetProcAddress"));
    auto initialize = reinterpret_cast<PFNEGLINITIALIZEPROC>(dlsym(library, "eglInitialize"));
    auto terminate = reinterpret_cast<PFNEGLTERMINATEPROC>(dlsym(library, "eglTerminate"));
    auto releaseThread = reinterpret_cast<PFNEGLRELEASETHREADPROC>(dlsym(library, "eglReleaseThread"));
    if (!getProc || !initialize || !terminate || !releaseThread) return 3;
    auto queryDevices = reinterpret_cast<PFNEGLQUERYDEVICESEXTPROC>(getProc("eglQueryDevicesEXT"));
    auto getDisplay = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(getProc("eglGetPlatformDisplayEXT"));
    if (!queryDevices || !getDisplay) return 4;
    EGLDeviceEXT devices[32];
    EGLint count = 0;
    if (!queryDevices(32, devices, &count) || count < 1) return 5;
    EGLDisplay display = getDisplay(EGL_PLATFORM_DEVICE_EXT, devices[0], nullptr);
    if (display == EGL_NO_DISPLAY || !initialize(display, nullptr, nullptr)) return 6;
    if (!terminate(display) || !releaseThread()) return 7;
    if (dlclose(library) != 0) return 8;
    std::fprintf(stderr, "NXTEST_EGL_CLEANUP_COMPLETE\n");
    return 0;
}
