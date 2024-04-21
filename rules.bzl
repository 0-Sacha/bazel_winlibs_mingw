""

load("@bazel_mingw//:archives.bzl", "MINGW_REGISTRY")
load("@bazel_utilities//toolchains:archives.bzl", "get_archive_from_registry")
load("@bazel_utilities//toolchains:hosts.bzl", "get_host_infos_from_rctx", "HOST_EXTENTION")

def _mingw_compiler_archive_impl(rctx):
    host_os, _, host_name = get_host_infos_from_rctx(rctx.os.name, rctx.os.arch)
    
    substitutions = {
        "%{rctx_name}": rctx.name,
        "%{rctx_path}": "external/{}/".format(rctx.name),
        "%{extention}": HOST_EXTENTION[host_os],
        "%{host_name}": host_name,
        "%{clang_version}": rctx.attr.clang_version,
        "%{gcc_version}": rctx.attr.gcc_version,
    }
    rctx.template(
        "BUILD",
        Label("//templates:BUILD_{}.compiler.tpl".format(rctx.attr.compiler)),
        substitutions
    )

    archives = json.decode(rctx.attr.archives)
    archive = archives[host_name]

    rctx.download_and_extract(
        url = archive["url"],
        sha256 = archive["sha256"],
        stripPrefix = archive["strip_prefix"],
    )

mingw_compiler_archive = repository_rule(
    implementation = _mingw_compiler_archive_impl,
    attrs = {
        'compiler': attr.string(mandatory = True),
        'clang_version': attr.string(mandatory = True),
        'gcc_version': attr.string(mandatory = True),
        'archives': attr.string(mandatory = True),
    },
    local = False,
)


def _mingw_impl(rctx):
    host_os, _, host_name = get_host_infos_from_rctx(rctx.os.name, rctx.os.arch)

    toolchain_id = ""
    if rctx.attr.compiler == "gcc":
        toolchain_id = "mingw_{}_{}".format(rctx.attr.compiler, rctx.attr.gcc_version)
    elif rctx.attr.compiler == "clang":
        toolchain_id = "mingw_{}_{}".format(rctx.attr.compiler, rctx.attr.clang_version)
    else:
        print("Compiler {} not supported by MinGW".format(rctx.attr.compiler)) # buildifier: disable=print
        
    target_compatible_with = []
    target_compatible_with += rctx.attr.target_compatible_with

    flags_packed = {}
    flags_packed.update(rctx.attr.flags_packed)

    substitutions = {
        "%{rctx_name}": rctx.name,
        "%{extention}": HOST_EXTENTION[host_os],
        "%{toolchain_path_prefix}": "external/{}/".format(rctx.name),
        "%{host_name}": host_name,
        "%{toolchain_id}": toolchain_id,
        "%{clang_version}": rctx.attr.clang_version,
        "%{gcc_version}": rctx.attr.gcc_version,
        "%{compiler_package}": "@{}//".format(rctx.attr.compiler_package) if rctx.attr.compiler_package != "" else "",
        "%{compiler_package_path}": "external/{}/".format(rctx.attr.compiler_package),
        
        "%{target_name}": rctx.attr.target_name,
        "%{target_cpu}": rctx.attr.target_cpu,
        "%{target_compatible_with}": json.encode(target_compatible_with),
        
        "%{copts}": json.encode(rctx.attr.copts),
        "%{conlyopts}": json.encode(rctx.attr.conlyopts),
        "%{cxxopts}": json.encode(rctx.attr.cxxopts),
        "%{linkopts}": json.encode(rctx.attr.linkopts),
        "%{defines}": json.encode(rctx.attr.defines),
        "%{includedirs}": json.encode(rctx.attr.includedirs),
        "%{linkdirs}": json.encode(rctx.attr.linkdirs),

        "%{flags_packed}": json.encode(flags_packed),
    }
    rctx.template(
        "BUILD",
        Label("//templates:BUILD_{}.tpl".format(rctx.attr.compiler)),
        substitutions
    )
    rctx.template(
        "vscode.bzl",
        Label("//templates:vscode.bzl.tpl"),
        substitutions
    )

    archives = json.decode(rctx.attr.archives)
    archive = archives[host_name]

    if rctx.attr.local_download:
        rctx.download_and_extract(
            url = archive["url"],
            sha256 = archive["sha256"],
            stripPrefix = archive["strip_prefix"],
        )

_mingw_toolchain = repository_rule(
    attrs = {
        'mingw_version': attr.string(default = "latest"),
        'compiler': attr.string(mandatory = True),
        'clang_version': attr.string(mandatory = True),
        'gcc_version': attr.string(mandatory = True),

        'local_download': attr.bool(default = True),
        'archives': attr.string(mandatory = True),
        'compiler_package': attr.string(mandatory = True),

        'target_name': attr.string(default = "local"),
        'target_cpu': attr.string(default = ""),
        'target_compatible_with': attr.string_list(default = []),

        'copts': attr.string_list(default = []),
        'conlyopts': attr.string_list(default = []),
        'cxxopts': attr.string_list(default = []),
        'linkopts': attr.string_list(default = []),
        'defines': attr.string_list(default = []),
        'includedirs': attr.string_list(default = []),
        'linkdirs': attr.string_list(default = []),

        'flags_packed': attr.string_dict(default = {}),
    },
    local = False,
    implementation = _mingw_impl,
)

def mingw_toolchain(
        name,
        mingw_version = "latest",
        compiler = "gcc",

        target_name = "local",
        target_cpu = "",
        target_compatible_with = [],
        
        copts = [],
        conlyopts = [],
        cxxopts = [],
        linkopts = [],
        defines = [],
        includedirs = [],
        linkdirs = [],
        
        flags_packed = {},
        
        local_download = True,
        registry = MINGW_REGISTRY,
    ):
    """MinGW Toolchain

    This macro create a repository containing all files needded to get an hermetic toolchain

    Args:
        name: Name of the repo that will be created
        mingw_version: The MinGW archive version
        compiler: The compiler to use: `gcc` or `clang` (default=`gcc`)

        target_name: The target name
        target_cpu: The target cpu name
        target_compatible_with: The target_compatible_with list for the toolchain

        copts: copts
        conlyopts: conlyopts
        cxxopts: cxxopts
        linkopts: linkopts
        defines: defines
        includedirs: includedirs
        linkdirs: linkdirs
        
        flags_packed: pack of flags, checkout the syntax at bazel_utilities

        local_download: wether the archive should be downloaded in the same repository (True) or in its own repo
        registry: The arm registry to use, to allow close environement to provide their own mirroir/url
    """
    compiler_package = ""

    archive = get_archive_from_registry(registry, "MinGW", mingw_version)
    compiler_version = archive["details"]["{}_version".format(compiler)]

    if local_download == False:
        compiler_package = "mingw_{}_{}".format(compiler, compiler_version)
        mingw_compiler_archive(
            name = compiler_package,
            compiler = compiler,
            clang_version = archive["details"]["clang_version"],
            gcc_version = archive["details"]["gcc_version"],
            archives = json.encode(archive["archives"]),
        )

    _mingw_toolchain(
        name = name,
        mingw_version = mingw_version,
        compiler = compiler,
        clang_version = archive["details"]["clang_version"],
        gcc_version = archive["details"]["gcc_version"],

        local_download = local_download,
        archives = json.encode(archive["archives"]),
        compiler_package = compiler_package,

        target_name = target_name,
        target_cpu = target_cpu,
        target_compatible_with = target_compatible_with,

        copts = copts,
        conlyopts = conlyopts,
        cxxopts = cxxopts,
        linkopts = linkopts,
        defines = defines,
        includedirs = includedirs,
        linkdirs = linkdirs,

        flags_packed = flags_packed,
    )

    compiler_version = archive["details"]["{}_version".format(compiler)]
    native.register_toolchains("@{}//:toolchain_mingw_{}_{}".format(name, compiler, compiler_version))
