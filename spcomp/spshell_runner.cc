#include <cstdio>
#include <memory>
#include <string>
#include <vector>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#else
#include <unistd.h>
#endif

#include "rules_cc/cc/runfiles/runfiles.h"

using rules_cc::cc::runfiles::Runfiles;

namespace {

#ifdef _WIN32
std::string QuoteWin32Arg(const std::string& arg) {
    std::string out = "\"";
    for (char c : arg) {
        if (c == '"') {
            out += "\\\"";
        } else {
            out += c;
        }
    }
    out += "\"";
    return out;
}
#endif

}  // namespace

int main(int argc, char** argv) {
    if (argc < 3) {
        std::fprintf(stderr, "usage: %s <spshell_rlocation> <smx_rlocation> [spshell_args...]\n", argv[0]);
        return 2;
    }

    std::string error;
    std::unique_ptr<Runfiles> runfiles(Runfiles::CreateForTest(BAZEL_CURRENT_REPOSITORY, &error));
    if (!runfiles) {
        error.clear();
        runfiles.reset(Runfiles::Create(argv[0], BAZEL_CURRENT_REPOSITORY, &error));
    }
    if (!runfiles) {
        std::fprintf(stderr, "failed to initialize runfiles: %s\n", error.c_str());
        return 1;
    }

    const std::string shell_path = runfiles->Rlocation(argv[1]);
    const std::string smx_path = runfiles->Rlocation(argv[2]);
    if (shell_path.empty() || smx_path.empty()) {
        std::fprintf(stderr, "failed to resolve runfiles ('%s', '%s')\n", argv[1], argv[2]);
        return 1;
    }

#ifdef _WIN32
    std::string cmdline = QuoteWin32Arg(shell_path);
    for (int i = 3; i < argc; ++i) {
        cmdline += " " + QuoteWin32Arg(argv[i]);
    }
    cmdline += " " + QuoteWin32Arg(smx_path);

    STARTUPINFOA si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};
    std::vector<char> mutable_cmd(cmdline.begin(), cmdline.end());
    mutable_cmd.push_back('\0');

    if (!CreateProcessA(shell_path.c_str(), mutable_cmd.data(), nullptr, nullptr, TRUE, 0, nullptr, nullptr, &si, &pi)) {
        std::fprintf(stderr, "CreateProcessA failed for %s (error %lu)\n", shell_path.c_str(), GetLastError());
        return 1;
    }
    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exit_code = 1;
    GetExitCodeProcess(pi.hProcess, &exit_code);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return static_cast<int>(exit_code);
#else
    std::vector<char*> child_argv;
    child_argv.push_back(const_cast<char*>(shell_path.c_str()));
    for (int i = 3; i < argc; ++i) {
        child_argv.push_back(argv[i]);
    }
    child_argv.push_back(const_cast<char*>(smx_path.c_str()));
    child_argv.push_back(nullptr);

    execv(shell_path.c_str(), child_argv.data());
    std::perror("execv");
    return 1;
#endif
}
