#!/bin/bash

#############################################################################
# Script to build Cassandra SCL (Software Collection)                       #
#                                                                           #
# Description: - Get specs/patches from github                              #
#              - Download sources from Fedora lookaside cache               #
#              - Create SRPM through rpmbuild                               #
#              - Build through CBS (CentOS Build System)                    #
#                                                                           #
# Author: Augusto Caringi (acaringi@redhat.com) - Date: 8/2017              #
#############################################################################

# list of cassandra dependencies
dep_list=(jamm janino slf4j logback snakeyaml bean-validation-api metrics metrics-reporter-config
          treelayout antlr4 stringtemplate4 hppc stream-lib high-scale-lib concurrent-trees
          concurrentlinkedhashmap-lru json_simple compress-lzf guava airline mvel cpptasks
          lz4-java cglib assertj-core compile-command-annotations stringtemplate antlr3 sigar
          jBCrypt apache-commons-math jopt-simple jmh snowball-java objectweb-asm byteman
          HdrHistogram javapoet caffeine jsr-311 jackson jflex snappy-java
          jackson-module-jaxb-annotations jackson-dataformat-xml powermock replacer
          fasterxml-oss-parent jackson-parent jackson-annotations jackson-dataformat-yaml
          jackson-databind jackson-core apache-commons-csv jeromq jboss-jms-1.1-api
          hibernate-jpa-2.1-api disruptor log4j ohc glassfish-jax-rs-api jsonp jctools jzlib netty
          jnr-constants jnr-ffi jnr-posix jnr-x86asm jffi cassandra-java-driver cassandra)

cassandra=cassandra35
github_repo_org=https://github.com/devexp-db
fedora_sources_repo=https://src.fedoraproject.org/repo/pkgs

##############################################################################
# clone repositories through git #############################################
##############################################################################
function get_from_git()
{
    i=1
    for f in ${dep_list[@]}
    do
        echo Clonning $f "("$i of ${#dep_list[@]}")"
        git clone $github_repo_org/sclo-$cassandra-$f.git
        let i++
    done
}

##############################################################################
# download sources from fedora lookaside cache ###############################
##############################################################################
function download_sources()
{
    i=1
    for f in ${dep_list[@]}
    do
        echo Getting sources for $f "("$i of ${#dep_list[@]}")"
        pushd sclo-$cassandra-$f
        s=$(ls *spec | head -n 1)
        c=${s%.spec}
        cat sources | sed -e 's/^\([a-f0-9]*\)\s*\(.*\)$/\1 \2/' -e 's/SHA512 (\(.*\)) = \(.*\)/\2 \1/' | while read h f ; do
            [ -z "$h" -o -z "$f" ] && continue
            t=md5
            [ ${#h} -gt 32 ] && t=sha512
            # If file was already downloaded, skip it...
            [ -f $f ] && echo "File $f already exists" || wget $fedora_sources_repo/$c/$f/$t/$h/$f
        done
        popd
        let i++
    done
}

##############################################################################
# create SRPM ################################################################
##############################################################################
function create_srpm()
{
    i=1
    for f in ${dep_list[@]}
    do
        echo Creating SRPM for $f "("$i of ${#dep_list[@]}")"
        pushd sclo-$cassandra-$f
        rpmbuild -bs -D "_with_bootstrap 1" -D "_sourcedir ." -D "_srcrpmdir ." -D "dist .el7" -D "scl sclo-cassandra3" *.spec
        popd
        let i++
    done
}

##############################################################################
# add package to cbs tag #####################################################
##############################################################################
function cbs_pkg_add()
{
    i=1
    for f in ${dep_list[@]}
    do
        echo Adding package $f to CBS tag "("$i of ${#dep_list[@]}")"
        cbs add-pkg sclo7-sclo-cassandra3-sclo-candidate --owner=sclo sclo-cassandra3-$f
        let i++
    done
}

##############################################################################
# build package in cbs tag ###################################################
##############################################################################
function cbs_build_pkg()
{
    i=1
    for f in ${dep_list[@]}
    do
        echo Building package $f in CBS "("$i of ${#dep_list[@]}")"
        pushd sclo-$cassandra-$f
        cbs build sclo7-sclo-cassandra3-sclo-el7 sclo-cassandra3-$f-*.el7.src.rpm
        popd
        let i++
    done
}

##############################################################################
# print usage ################################################################
##############################################################################
function usage()
{
    echo "Script to help in the process of building Cassandra SCL (Software Collection)"
    echo ""
    echo "Commands:"
    echo ""
    echo "    gitget     git clone repositories"
    echo "    download   download sources from fedora lookaside cache"
    echo "    srpm       create source rpms"
    echo "    pkgadd     add packages to cbs tag"
    echo "    pkgbuild   build packages on cbs"
    echo "    all        do all steps in correct order (gitget, download, srpm, pkgadd, pkgbuild)"
    echo ""
}

if [ "$#" -ne 1 ]; then
    usage
    exit
fi

case $1 in
    gitget)
        get_from_git
        ;;
    download)
        download_sources
        ;;
    srpm)
        create_srpm
        ;;
    pkgadd)
        cbs_pkg_add
        ;;
    pkgbuild)
        cbs_build_pkg
        ;;
    all)
        get_from_git
        download_sources
        create_srpm
        cbs_pkg_add
        cbs_build_pkg
        ;;
    *)
        usage
esac
