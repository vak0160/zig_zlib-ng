const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zlibng = b.dependency("zlib_ng", .{
        .target = target,
        .optimize = optimize,
    });

    // Build options
    const with_gzfileops = b.option(bool, "with-gzfileops", "Enable gzfile operations (default: true)") orelse true;
    const prefix = b.option([]const u8, "prefix", "Installation prefix (default: /usr/local)") orelse "/usr/local";
    const warn = b.option(bool, "warn", "Enable extra compiler warnings (default: false)") orelse false;
    const debug = b.option(bool, "debug", "Enable debug prints (default: false)") orelse false;

    // Architecture-specific options
    const with_neon = b.option(bool, "with-neon", "Enable ARM Neon SIMD (default: true)") orelse true;
    const with_armv8 = b.option(bool, "with-armv8", "Enable ARMv8 CRC32 (default: true)") orelse true;
    const with_avx2 = b.option(bool, "with-avx2", "Enable AVX2 optimizations (default: true)") orelse true;
    const with_sse2 = b.option(bool, "with-sse2", "Enable SSE2 optimizations (default: true)") orelse true;

    // Source files (core zlib-ng sources)
    const zlib_sources = &[_][]const u8{
        "adler32.c",
        "compress.c",
        "crc32.c",
        "deflate.c",
        "infback.c",
        "inffast.c",
        "inflate.c",
        "inftrees.c",
        "trees.c",
        "uncompr.c",
        "zutil.c",
    };

    // Gzfile operation sources (optional)
    const gzfile_sources = &[_][]const u8{
        "gzlib.c",
        "gzread.c",
        "gzwrite.c",
    };

    // Architecture-specific sources
    const arch_sources = &[_][]const u8{
        if (with_neon) "arch/arm/adler32_neon.c" else "",
        if (with_armv8) "arch/arm/crc32_armv8.c" else "",
        if (with_avx2) "arch/x86/adler32_avx2.c" else "",
        if (with_sse2) "arch/x86/crc32_sse2.c" else "",
    };

    // Combine sources
    var sources = std.ArrayList([]const u8).init(b.allocator);
    defer sources.deinit();
    sources.appendSlice(zlib_sources) catch @panic("Failed to add sources");
    if (with_gzfileops) {
        sources.appendSlice(gzfile_sources) catch @panic("Failed to add gzfile sources");
    }
    for (arch_sources) |src| {
        if (src.len > 0) sources.append(src) catch @panic("Failed to add arch source");
    }

    // Static library
    const lib = b.addStaticLibrary(.{
        .name = "zlibstatic-ng",
        .target = target,
        .optimize = optimize,
    });

    // Compiler flags
    lib.root_module.addCMacro("ZLIB_COMPAT", "");
    if (with_gzfileops) {
        lib.root_module.addCMacro("WITH_GZFILEOP", "");
    }
    if (debug) {
        lib.root_module.addCMacro("ZLIB_DEBUG", "");
    } else {
        lib.root_module.addCMacro("DNDEBUG", "");
    }

    // Compiler flags
    var c_flags = std.ArrayList([]const u8).init(b.allocator);
    defer c_flags.deinit();
    c_flags.append("-Wall") catch @panic("Failed to add flag");
    c_flags.append("-std=c11") catch @panic("Failed to add flag");
    if (warn) {
        c_flags.append("-Wextra") catch @panic("Failed to add flag");
    }

    lib.linkLibC();
    lib.addCSourceFiles(.{ .root = zlibng.path("."), .files = sources.items, .flags = c_flags.items });
    lib.addIncludePath(zlibng.path("."));

    // Installation
    b.installArtifact(lib);

    // Install headers
    const install_headers = b.addInstallFile(zlibng.path("zlib-ng.h"), "include/zlib-ng.h");
    const install_zconf = b.addInstallFile(zlibng.path("zconf-ng.h"), "include/zconf-ng.h");
    b.getInstallStep().dependOn(&install_headers.step);
    b.getInstallStep().dependOn(&install_zconf.step);

    // Set install prefix
    b.install_prefix = prefix;
}
