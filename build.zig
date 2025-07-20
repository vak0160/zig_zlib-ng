const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("zlib_ng", .{});

    const lib = b.addStaticLibrary(.{
        .name = "zlib_ng",
        .target = target,
        .optimize = optimize,
    });

    // generate files from .in.h files
    const zlibng_file = upstream.path(".").getPath3(b, null).openFile("zlib-ng.h.in", .{}) catch @panic("Unable to open file");
    defer zlibng_file.close();
    const zlibng_content = zlibng_file.readToEndAlloc(b.allocator, std.math.maxInt(usize)) catch @panic("Unable to read file");
    defer b.allocator.free(zlibng_content);
    const zlibng_replaced = std.mem.replaceOwned(u8, b.allocator, zlibng_content, "@ZLIB_SYMBOL_PREFIX@", "") catch @panic("Unable to replace string");
    defer b.allocator.free(zlibng_replaced);

    const wf = b.addWriteFiles();
    _ = wf.add("zlib-ng.h", zlibng_replaced);
    _ = wf.addCopyFile(upstream.path("zlib_name_mangling.h.empty"), "zlib_name_mangling-ng.h");
    _ = wf.addCopyFile(upstream.path("zconf-ng.h.in"), "zconf-ng.h");

    // add C files & headers
    var c_sources = std.ArrayList([]const u8).init(b.allocator);
    defer c_sources.deinit();

    c_sources.appendSlice(&.{
        "adler32.c",
        "compress.c",
        "cpu_features.c",
        "crc32.c",
        "crc32_braid_comb.c",
        "deflate.c",
        "deflate_fast.c",
        "deflate_huff.c",
        "deflate_medium.c",
        "deflate_quick.c",
        "deflate_rle.c",
        "deflate_slow.c",
        "deflate_stored.c",
        "functable.c",
        "infback.c",
        "inflate.c",
        "inftrees.c",
        "insert_string.c",
        "insert_string_roll.c",
        "trees.c",
        "uncompr.c",
        "zutil.c",
    }) catch @panic("Failed to add C sources");

    switch (target.result.cpu.arch) {
        .arm, .aarch64 => {
            c_sources.appendSlice(&.{
                "arch/arm/adler32_neon.c",
                "arch/arm/arm_features.c",
                "arch/arm/chunkset_neon.c",
                "arch/arm/compare256_neon.c",
                "arch/arm/crc32_acle.c",
                "arch/arm/slide_hash_armv6.c",
                "arch/arm/slide_hash_neon.c",
            }) catch @panic("Failed to add C sources");
        },
        .powerpc, .powerpc64, .powerpc64le, .powerpcle => {
            c_sources.appendSlice(&.{
                "arch/power/adler32_power8.c",
                "arch/power/adler32_vmx.c",
                "arch/power/chunkset_power8.c",
                "arch/power/compare256_power9.c",
                "arch/power/crc32_power8.c",
                "arch/power/power_features.c",
                "arch/power/slide_hash_power8.c",
                "arch/power/slide_hash_vmx.c",
            }) catch @panic("Failed to add C sources");
        },
        .riscv32, .riscv64 => {
            c_sources.appendSlice(&.{
                "arch/riscv/adler32_rvv.c",
                "arch/riscv/chunkset_rvv.c",
                "arch/riscv/compare256_rvv.c",
                "arch/riscv/riscv_features.c",
                "arch/riscv/slide_hash_rvv.c",
            }) catch @panic("Failed to add C sources");
        },
        .s390x => {
            c_sources.appendSlice(&.{
                "arch/s390/crc32-vx.c",
                "arch/s390/dfltcc_deflate.c",
                "arch/s390/dfltcc_inflate.c",
                "arch/s390/s390_features.c",
            }) catch @panic("Failed to add C sources");
        },
        .x86, .x86_64 => {
            c_sources.appendSlice(&.{
                "arch/x86/x86_features.c",
            }) catch @panic("Failed to add C sources");

            if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse2)) {
                c_sources.appendSlice(&.{
                    "arch/x86/chunkset_sse2.c",
                    "arch/x86/compare256_sse2.c",
                    "arch/x86/slide_hash_sse2.c",
                }) catch @panic("Failed to add C sources");
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse3)) {
                c_sources.appendSlice(&.{
                    "arch/x86/adler32_ssse3.c",
                    "arch/x86/chunkset_ssse3.c",
                }) catch @panic("Failed to add C sources");
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .sse4_2)) {
                c_sources.appendSlice(&.{
                    "arch/x86/adler32_sse42.c",
                }) catch @panic("Failed to add C sources");
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .pclmul)) {
                c_sources.appendSlice(&.{
                    "arch/x86/crc32_pclmulqdq.c",
                }) catch @panic("Failed to add C sources");
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .avx2)) {
                c_sources.appendSlice(&.{
                    "arch/x86/slide_hash_avx2.c",
                    "arch/x86/chunkset_avx2.c",
                    "arch/x86/compare256_avx2.c",
                    "arch/x86/adler32_avx2.c",
                }) catch @panic("Failed to add C sources");
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .avx512f)) {
                c_sources.appendSlice(&.{
                    "arch/x86/adler32_avx512.c",
                    "arch/x86/chunkset_avx512.c",
                }) catch @panic("Failed to add C sources");

                if (std.Target.x86.featureSetHas(target.result.cpu.features, .pclmul)) {
                    c_sources.appendSlice(&.{
                        "arch/x86/crc32_pclmulqdq.c",
                    }) catch @panic("Failed to add C sources");
                }
            }
            if (std.Target.x86.featureSetHas(target.result.cpu.features, .avx512vnni)) {
                c_sources.appendSlice(&.{
                    "arch/x86/adler32_avx512_vnni.c",
                }) catch @panic("Failed to add C sources");
            }
        },
        else => {
            c_sources.appendSlice(&.{
                "arch/generic/adler32_c.c",
                "arch/generic/adler32_fold_c.c",
                "arch/generic/chunkset_c.c",
                "arch/generic/compare256_c.c",
                "arch/generic/crc32_braid_c.c",
                "arch/generic/crc32_fold_c.c",
                "arch/generic/slide_hash_c.c",
            }) catch @panic("Failed to add C sources");
        },
    }

    lib.linkLibC();
    lib.addCSourceFiles(.{
        .root = upstream.path("."),
        .files = c_sources.items,
        .flags = &.{
            "-std=c11",
            "-O3",
        },
    });
    lib.addIncludePath(upstream.path("."));
    lib.addIncludePath(wf.getDirectory());
    lib.installHeadersDirectory(upstream.path("."), "", .{});
    lib.installHeadersDirectory(wf.getDirectory(), "", .{});

    b.installArtifact(lib);
}
