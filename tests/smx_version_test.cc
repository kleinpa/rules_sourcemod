#include <cstdint>
#include <cstdio>
#include <memory>
#include <string>

#include "rules_cc/cc/runfiles/runfiles.h"

using rules_cc::cc::runfiles::Runfiles;

// Verifies that a compiled .smx file begins with the SPFF magic (0x53504646)
// and SourcePawn 1 major container version (0x01 at byte offset 5).
int main(int argc, char** argv) {
    if (argc != 2) {
        std::fprintf(stderr, "usage: %s <plugin_rlocation>\n", argv[0]);
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

    const std::string path = runfiles->Rlocation(argv[1]);
    std::FILE* fp = std::fopen(path.c_str(), "rb");
    if (!fp) {
        std::fprintf(stderr, "failed to open %s (from %s)\n", path.c_str(), argv[1]);
        return 1;
    }

    std::uint8_t hdr[6] = {};
    const std::size_t n = std::fread(hdr, 1, sizeof(hdr), fp);
    std::fclose(fp);
    if (n != sizeof(hdr)) {
        std::fprintf(stderr, "%s: truncated header (%zu bytes)\n", path.c_str(), n);
        return 1;
    }

    const std::uint32_t magic =
        static_cast<std::uint32_t>(hdr[0]) |
        (static_cast<std::uint32_t>(hdr[1]) << 8) |
        (static_cast<std::uint32_t>(hdr[2]) << 16) |
        (static_cast<std::uint32_t>(hdr[3]) << 24);
    if (magic != 0x53504646u) {
        std::fprintf(stderr, "%s: unexpected magic 0x%08x (expected 0x53504646)\n", path.c_str(), magic);
        return 1;
    }

    if (hdr[5] != 0x01u) {
        std::fprintf(stderr, "%s: .smx major version 0x%02x is not SourcePawn 1 (0x01)\n", path.c_str(), hdr[5]);
        return 1;
    }

    return 0;
}
