#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdbool.h>
#include <wchar.h>

static const int module_anchor=0;
static bool launched=false;

static bool parent_directory(wchar_t *path) {
    wchar_t *end=wcsrchr(path,L'\\');
    if(!end) return false;
    *end=L'\0';
    return true;
}

static bool resolve_root(wchar_t *root,DWORD capacity) {
    HMODULE module=NULL;
    if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,(LPCWSTR)&module_anchor,&module)) return false;
    DWORD length=GetModuleFileNameW(module,root,capacity);
    if(!length || length>=capacity) return false;
    // <game>/reframework/plugins/IssenImpactLauncher.dll
    return parent_directory(root) && parent_directory(root) && parent_directory(root);
}

__declspec(dllexport) bool issen_impact_get_launcher_path(wchar_t *out,DWORD capacity) {
    wchar_t root[4096];
    if(!out || capacity<1 || !resolve_root(root,4096)) return false;
    int count=swprintf(out,capacity,L"%ls\\reframework\\data\\IssenImpact\\Start-Impact.ps1",root);
    return count>0 && (DWORD)count<capacity && GetFileAttributesW(out)!=INVALID_FILE_ATTRIBUTES;
}

// REFramework's documented optional initialization export. No engine API calls
// or game-memory modifications are needed by this launcher.
__declspec(dllexport) bool reframework_plugin_initialize(const void *parameters) {
    (void)parameters;
    if(launched) return true;
    wchar_t root[4096],script[8192],system[4096],powershell[8192],command[32768];
    if(!resolve_root(root,4096) || !issen_impact_get_launcher_path(script,8192)) return false;
    if(!GetSystemDirectoryW(system,4096)) return false;
    if(swprintf(powershell,8192,L"%ls\\WindowsPowerShell\\v1.0\\powershell.exe",system)<0) return false;
    int length=swprintf(command,32768,
        L"\"%ls\" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%ls\" -GameDir \"%ls\" -ParentProcessId %lu",
        powershell,script,root,(unsigned long)GetCurrentProcessId());
    if(length<0 || length>=32768) return false;
    STARTUPINFOW startup={0};
    PROCESS_INFORMATION process={0};
    startup.cb=sizeof(startup);
    startup.dwFlags=STARTF_USESHOWWINDOW;
    startup.wShowWindow=SW_HIDE;
    if(!CreateProcessW(powershell,command,NULL,NULL,FALSE,CREATE_NO_WINDOW,NULL,root,&startup,&process)) return false;
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    launched=true;
    return true;
}
