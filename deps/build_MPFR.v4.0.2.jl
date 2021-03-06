using BinaryProvider # requires BinaryProvider 0.3.0 or later

# Parse some basic command-line arguments
const verbose = "--verbose" in ARGS
const prefix = Prefix(get([a for a in ARGS if a != "--verbose"], 1, joinpath(@__DIR__, "usr")))
products = [
    LibraryProduct(prefix, ["libmpfr"], :libmpfr),
]

# Download binaries from hosted location
bin_prefix = "https://github.com/JuliaBinaryWrappers/MPFR_jll.jl/releases/download/MPFR-v4.0.2+2"

# Listing of files generated by BinaryBuilder:
download_info = Dict(
    Linux(:aarch64, libc=:glibc) => ("$bin_prefix/MPFR.v4.0.2.aarch64-linux-gnu.tar.gz", "59831a83ec6e77311c2726936f03976c6a4fa24db10168189260eba2a403a038"),
    Linux(:aarch64, libc=:musl) => ("$bin_prefix/MPFR.v4.0.2.aarch64-linux-musl.tar.gz", "9fdacfaa54fb1fbfc2f1c7be8d04549438d35897f42151728adf3e1790ed3c07"),
    Linux(:armv7l, libc=:glibc, call_abi=:eabihf) => ("$bin_prefix/MPFR.v4.0.2.armv7l-linux-gnueabihf.tar.gz", "3779f74ac34afc6b746d672f896d4174a804cc80cf3272e11a9e20928af36ea7"),
    Linux(:armv7l, libc=:musl, call_abi=:eabihf) => ("$bin_prefix/MPFR.v4.0.2.armv7l-linux-musleabihf.tar.gz", "09b89c05f5726fc920c4db311c4027573ff7025ade5d570625b0b84c78959c0a"),
    Linux(:i686, libc=:glibc) => ("$bin_prefix/MPFR.v4.0.2.i686-linux-gnu.tar.gz", "263416d4779f0f18865581487c3dacd1cf9c61f3ef801374dc2f8d762621f7ec"),
    Linux(:i686, libc=:musl) => ("$bin_prefix/MPFR.v4.0.2.i686-linux-musl.tar.gz", "663128695369365a55cb7c8c115fcb219f9f96eaad8e91936ef2b76c81eaa242"),
    Windows(:i686) => ("$bin_prefix/MPFR.v4.0.2.i686-w64-mingw32.tar.gz", "494832d8383d141c042a8d42249634fb566ad26748cbfa7f13ad0b048b598ea3"),
    Linux(:powerpc64le, libc=:glibc) => ("$bin_prefix/MPFR.v4.0.2.powerpc64le-linux-gnu.tar.gz", "b9f1ff23eafa8de4694cbb182713d11788e0fa405562231402d3caf2978c8e9d"),
    MacOS(:x86_64) => ("$bin_prefix/MPFR.v4.0.2.x86_64-apple-darwin14.tar.gz", "c94934ececef9817750c16e3ef5d3660521656ecc4c8afb3e2a39afe7fc6325b"),
    Linux(:x86_64, libc=:glibc) => ("$bin_prefix/MPFR.v4.0.2.x86_64-linux-gnu.tar.gz", "c77f9f5e926f7245eed9d8db2b05e175d2030bad8e760e56c6eeb8fe465fddf8"),
    Linux(:x86_64, libc=:musl) => ("$bin_prefix/MPFR.v4.0.2.x86_64-linux-musl.tar.gz", "c7320331de2f61fdd6fed71d336a7843023efe7601ac18ec5dc7136e72223a46"),
    FreeBSD(:x86_64) => ("$bin_prefix/MPFR.v4.0.2.x86_64-unknown-freebsd11.1.tar.gz", "52afe44547762bda507a99aa5dcc1e04d2866f9483a9c1bc31789e8a7a12bedf"),
    Windows(:x86_64) => ("$bin_prefix/MPFR.v4.0.2.x86_64-w64-mingw32.tar.gz", "7ef5c44de77a6e6d53caa14d98547b2e02023a83314c492e001cf4f88f6bbd73"),
)

# Install unsatisfied or updated dependencies:
unsatisfied = any(!satisfied(p; verbose=verbose) for p in products)
dl_info = choose_download(download_info, platform_key_abi())
if dl_info === nothing && unsatisfied
    # If we don't have a compatible .tar.gz to download, complain.
    # Alternatively, you could attempt to install from a separate provider,
    # build from source or something even more ambitious here.
    error("Your platform (\"$(Sys.MACHINE)\", parsed as \"$(triplet(platform_key_abi()))\") is not supported by this package!")
end

# If we have a download, and we are unsatisfied (or the version we're
# trying to install is not itself installed) then load it up!
if unsatisfied || !isinstalled(dl_info...; prefix=prefix)
    # Download and install binaries
    install(dl_info...; prefix=prefix, force=true, verbose=verbose)
end

# Write out a deps.jl file that will contain mappings for our products
# write_deps_file(joinpath(@__DIR__, "deps.jl"), products, verbose=verbose)
