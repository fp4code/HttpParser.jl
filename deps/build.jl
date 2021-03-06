using BinDeps
using Compat

@BinDeps.setup

version=v"2.7.1"

aliases = []
if is_windows()
    if Sys.WORD_SIZE == 64
        aliases = ["libhttp_parser64"]
    else
        aliases = ["libhttp_parser32"]
    end
end

# This API used for validation was introduced in 2.6.0, and there have no API changes between 2.6 and 2.7
function validate_httpparser(name,handle)
    try
        p = Libdl.dlsym(handle, :http_parser_url_init)
        return p != C_NULL
    catch
        if is_windows()
            warn("Looks like your binary is old. Please run `rm($(sprint(show, joinpath(dirname(@__FILE__), "usr"))); recursive = true)` to delete the old binary and then run `Pkg.build($(sprint(show, "HttpParser")))` again.")
        end
        return false
    end
end

libhttp_parser = library_dependency("libhttp_parser", aliases=aliases,
                                     validate=validate_httpparser)

if is_unix()
    src_arch = "v$version.zip"
    src_url = "https://github.com/nodejs/http-parser/archive/$src_arch"
    src_dir = "http-parser-$version"

    target = "libhttp_parser.$(Libdl.dlext)"
    targetdwlfile = joinpath(BinDeps.downloadsdir(libhttp_parser),src_arch)
    targetsrcdir = joinpath(BinDeps.srcdir(libhttp_parser),src_dir)
    targetlib    = joinpath(BinDeps.libdir(libhttp_parser),target)

    patchfile = joinpath(BinDeps.depsdir(libhttp_parser), "patches", "pull-357.patch")
    if version == v"2.7.1" && !isfile(joinpath(targetsrcdir, "http_parser.c.orig"))
        PatchStep = (@build_steps begin
            pipeline(`cat $patchfile`, `patch --verbose -b -p1 -d $targetsrcdir`)
        end)
    else
        PatchStep = (@build_steps begin end)
    end

    provides(SimpleBuild,
        (@build_steps begin
            CreateDirectory(BinDeps.downloadsdir(libhttp_parser))
            FileDownloader(src_url, targetdwlfile)
            FileUnpacker(targetdwlfile,BinDeps.srcdir(libhttp_parser),targetsrcdir)
            PatchStep
            @build_steps begin
                CreateDirectory(BinDeps.libdir(libhttp_parser))
                @build_steps begin
                    ChangeDirectory(targetsrcdir)
                    `rm -f $src_dir/$target $targetlib`
                    FileRule(targetlib, @build_steps begin
                        ChangeDirectory(BinDeps.srcdir(libhttp_parser))
                        CreateDirectory(dirname(targetlib))
                        MakeTargets(["-C",src_dir,"library"], env=Dict("SONAME"=>target))
                        `cp $src_dir/$target $targetlib`
                    end)
                end
            end
        end), libhttp_parser, os = :Unix)
end

# Windows
if is_windows()
    provides(Binaries,
         URI("https://s3.amazonaws.com/julialang/bin/winnt/extras/libhttp_parser_2_7_1.zip"),
         libhttp_parser, os = :Windows)
end

@BinDeps.install Dict(:libhttp_parser => :lib)
