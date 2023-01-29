#!/bin/bash

START_TIME_MIN=`date +%M`
START_TIME_SEC=`date +%s`
START_TIME_MIL=`date +%s%3N`

BUILD_ALL=true

MSG_PREFIX='\033[1;33mBUILD:\033[0;0m'
INFO='\033[1;96m'
WARN='\033[1;35m'
ERROR='\033[1;31m'
SUCCESS='\033[1;92m'
WHITE='\033[1;37m'
RESET_COLOR='\033[0;0m'
BASENAME="${0##*/}"

# Target default to host. Must change if target is invalid
TARGET="$HOSTTYPE-elf"
PREFIX=/usr/local/${TARGET}

NEEDED_DEPS=("build-essential" "bison" "flex" "libgmp3-dev" "libmpc-dev" "libmpfr-dev" \ 
            "texinfo" "libisl-dev" "g++" "libssl-dev" "make" "wget" "libipt-dev" \ 
             "expat" "python3" "pkg-config")

BINUTILS_VER=2.38
GCC_VER=11.3.0
GDB_VER=12.1

EXITED=false
execution_end() {
    END_TIME_MIL=`date +%s%3N`
    END_TIME_SEC=`date +%s`
    END_TIME_MIN=`date +%M`


    runtime_mil=$((10#$END_TIME_MIL-$START_TIME_MIL))
    runtime_sec=$((10#$END_TIME_SEC-$START_TIME_SEC))
    runtime_min=$((10#$END_TIME_MIN-$START_TIME_MIN))
    if [[ $runtime_mil -ge 500 ]]; then
        if [[ $runtime_sec -gt 0 ]]; then
            runtime_sec=$((($END_TIME_SEC-$START_TIME_SEC)-1));
        else
            if [[ $runtime_min -gt 0 ]]; then
                runtime_sec=59;
                let runtime_min=runtime_min-1;
            fi
        fi
    fi

    printf "\n${MSG_PREFIX} ${INFO}Process finished in ${runtime_min}m${runtime_sec}.${runtime_mil}s${RESET_COLOR}\n"
    if [[ ! -z $1 ]]; then
        EXITED=true
        exit $1
    fi
}

INTERRUPT=false
function trap_exit() {
    if [[ ! $EXITED == true ]]; then
        execution_end $1
    fi
}

trap_int() {
    printf "${ERROR}Interrupted.${RESET_COLOR}\n";
    exit 1
}

trap trap_exit $? EXIT
trap trap_int INT

show_help() {
    printf "Usage: $BASENAME [-t | target] [-bv | binutils-version] [-gv | gcc-version]\n"
    printf "        [-dv | gdb-version] [binutils | build-binutils-only] [gcc | build-gcc-only]\n"
    printf "        [gdb | build-gdb-only] [env | setup-enviroment-only]\n"
    printf "Can combine 'binutils', 'gcc', 'gdb' and 'env'\n"
    execution_end 0
}

STATUS=0
check_command() {
    STATUS=0

    command -v $1 >/dev/null 2>&1 || STATUS=1
}

check_on_target() {
    check_command $TARGET-gcc
    check_command $TARGET-ld
    check_command $TARGET-gdb
}

BUILD_BINUTILS=false
BUILD_GCC=false
BUILD_GDB=false
ENV_ONLY=false
BUILD_TO_SYSTEM=false

set -e

if [ $# -eq 0 ]; then
    BUILD_BINUTILS=true
    BUILD_GCC=true
    BUILD_GDB=true

    args="binutils gcc gdb"
else    
    args=$@
fi

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    binutils)                       BUILD_BINUTILS=true;    BUILD_ALL=false; shift ;;
    gcc)                            BUILD_GCC=true;         BUILD_ALL=false; shift ;;
    gdb)                            BUILD_GDB=true;         BUILD_ALL=false; shift ;;
    env)                            ENV_ONLY=true                          ; shift ;;
    -s|--system)                    BUILD_TO_SYSTEM=true                   ; shift ;;
    -d|--directory)                 PREFIX="$2"; ANOTHER_PREFIX=true       ; shift; shift ;;
    -t|--target)                    TARGET="$2"                            ; shift; shift ;;
    -bv|--binutils-version)         BINUTILS_VER="$2"                      ; shift; shift ;;
    -gv|--gcc-version)              GCC_VER="$2"                           ; shift; shift ;;
    -dv|--gdb-version)              GDB_VER="$2"                           ; shift; shift ;;
    -h|--help)                      show_help                              ; shift ;;
    *)                              printf "$BASENAME: Invalid option -- '$1'\n"; show_help; shift ;;
esac
done

BUILD_DIR="build-${TARGET}"

if [[ $BUILD_TO_SYSTEM == true ]]; then
    PREFIX="/usr/local/${TARGET}";
elif [[ $ANOTHER_PREFIX == true ]]; then
    if [[ ! "$PREFIX" == *"${TARGET}"* ]]; then
        PREFIX="$PREFIX/${TARGET}";
    fi
else
    PREFIX="$HOME/opt/${TARGET}";
fi

BINUTILS_CONFIG="--target=$TARGET --prefix=$PREFIX --with-sysroot --disable-nls"
GCC_CONFIG="--target=$TARGET --prefix=$PREFIX --disable-nls --enable-languages=c,c++ --without-headers"
GDB_CONFIG="--target=$TARGET --prefix=$PREFIX --disable-werror"


install_deps() {
    printf "${MSG_PREFIX} ${INFO}Checking enviroment requirements...\n${RESET_COLOR}"
    for pkg in ${NEEDED_DEPS[@]};
    do
        PKG_OK=$(dpkg-query -W --showformat='${db:Status-Status}' "$pkg")
        if [[ "" == "$PKG_OK" ]];
        then
            printf "${MSG_PREFIX} ${INFO}Installing '${WHITE}$pkg${INFO}'...\n${RESET_COLOR}"
            sudo apt-get install $pkg -y >/dev/null 2>&1;
            printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";
        else
            printf "${MSG_PREFIX} ${INFO}Package '${WHITE}$pkg${INFO}' is already installed\n${RESET_COLOR}";
        fi
    done

    printf "${MSG_PREFIX} ${SUCCESS}Installed all neccessary dependencies\n\n${RESET_COLOR}"

    if [[ $ENV_ONLY == true ]]; then
        printf "${MSG_PREFIX} ${SUCCESS}Finished setting up enviroment. Exiting now...${RESET_COLOR}\n";
        execution_end 0;
    fi
}

downloadSources() {
    name=$1
    ver=$2

    if [[ -z $3 ]]; then
        sources="https://ftp.gnu.org/gnu/$name/$name-$ver.tar.gz";
    else
        sources=$3
    fi

    if [[ ! -f $name-$ver.tar.gz ]]; then
        printf "${MSG_PREFIX} ${INFO}Downloading '${WHITE}$name-$ver.tar.gz${INFO}'... ${RESET_COLOR}\n";
        wget -q $sources;
        printf "${MSG_PREFIX} ${SUCCESS}Done${RESET_COLOR}\n";
    else
        printf "${MSG_PREFIX} ${WHITE}'$name-$ver.tar.gz'${INFO} is already existed\n${RESET_COLOR}";
    fi

    if [[ ! -d $name-$ver ]]; then
        printf "${MSG_PREFIX} ${INFO}Extracting '${WHITE}$name-$ver.tar.gz${INFO}'...\n${RESET_COLOR}";
        tar -xzf $name-$ver.tar.gz;
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n\n";
    else
        printf "${MSG_PREFIX} ${WHITE}'$name-$ver'${INFO} is already existed\n${RESET_COLOR}"
    fi
}

buildBinutils() {
    printf "${MSG_PREFIX} ${INFO}Attempting to install binutils...${RESET_COLOR}\n"
    if [[ $BUILD_BINUTILS == true || $BUILD_ALL == true ]]; then
        downloadSources "binutils" $BINUTILS_VER
        if [[ -d build-binutils ]]; then rm -rf build-binutils; fi
        mkdir build-binutils
        cd build-binutils

        printf "${MSG_PREFIX} ${INFO}Configuring...\n${RESET_COLOR}";
        ../binutils-$BINUTILS_VER/configure $BINUTILS_CONFIG  > ../binutils_config.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Building...\n${RESET_COLOR}";
        sudo make -j16 > ../binutils_build.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Installing...\n${RESET_COLOR}";
        sudo make install > ../binutils_install.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";
    else
        printf "${MSG_PREFIX} ${INFO}Skipping binutils...\n\n"
    fi
    source $HOME/.bashrc
}

buildGCC() {
    printf "${MSG_PREFIX} ${INFO}Attempting to install gcc...${RESET_COLOR}\n"
    if [[ $BUILD_GCC == true || $BUILD_ALL == true ]]; then
        downloadSources "gcc" $GCC_VER "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VER}/gcc-${GCC_VER}.tar.gz";
        if [[ -d build-gcc ]]; then rm -rf build-gcc; fi
        mkdir build-gcc
        cd build-gcc

        printf "${MSG_PREFIX} ${INFO}Configuring...\n${RESET_COLOR}";
        ../gcc-$GCC_VER/configure $GCC_CONFIG  > ../gcc_config.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Building gcc...\n${RESET_COLOR}";
        sudo make all-gcc -j16 > ../gcc_build.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Building libgcc...\n${RESET_COLOR}";
        sudo make all-target-libgcc -j16 > ../gcc_libgcc_build.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Installing gcc...\n${RESET_COLOR}";
        sudo make install-gcc > ../gcc_install.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Installing libgcc...\n${RESET_COLOR}";
        sudo make install-target-libgcc > ../gcc_libgcc_install.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";
    else
        printf "${MSG_PREFIX} ${INFO}Skipping gcc...\n\n"
    fi
    source $HOME/.bashrc
}

buildGDB() {
    printf "${MSG_PREFIX} ${INFO}Attempting to install gdb...${RESET_COLOR}\n"
    if [[ $BUILD_GDB == true || $BUILD_ALL == true ]]; then
        downloadSources "gdb" $GDB_VER
        if [[ -d build-gdb ]]; then rm -rf build-gdb; fi
        mkdir build-gdb
        cd build-gdb

        printf "${MSG_PREFIX} ${INFO}Configuring...\n${RESET_COLOR}";
        ../gdb-$GDB_VER/configure $GDB_CONFIG > ../gdb_config.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Building...\n${RESET_COLOR}";
        sudo make all-gdb -j16 > ../gdb_build.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";

        printf "${MSG_PREFIX} ${INFO}Installing...\n${RESET_COLOR}";
        sudo make install-gdb -j16 > ../gdb_install.log
        printf "${MSG_PREFIX} ${SUCCESS}Done.${RESET_COLOR}\n";
    else
        printf "${MSG_PREFIX} ${INFO}Skipping gdb...\n\n"
    fi
    source $HOME/.bashrc
}

main() {
    source ~/.bashrc
    if [[ $BUILD_ALL == true ]]; then
        BUILD_GCC=true;
        BUILD_BINUTILS=true;
        BUILD_GDB=true;
    fi

    sudo rm -rf $BUILD_DIR

    printf "\e[4;94mBuild cross-toolchains utilities by NeonLightions${RESET_COLOR}\n";
    printf "${MSG_PREFIX} ${INFO}Preparing to install '${WHITE}${TARGET}${INFO}'...\n${RESET_COLOR}"
    printf "${MSG_PREFIX} ${INFO}Configuration:\n${RESET_COLOR}";
    printf "    TARGET              $TARGET\n";
    printf "    PREFIX              $PREFIX\n";
    printf "    BUILD_DIR           $BUILD_DIR\n";
    printf "    BUILD_GCC           $BUILD_GCC\n";
    printf "    GCC_VER             $GCC_VER\n";
    printf "    BUILD_BINUTILS      $BUILD_BINUTILS\n";
    printf "    BINUTILS_VER        $BINUTILS_VER\n";
    printf "    BUILD_GDB           $BUILD_GDB\n";
    printf "    GDB_VER             $GDB_VER\n";
    printf "    ENV_ONLY            $ENV_ONLY\n";
    printf "    BUILD_TO_SYSTEM     $BUILD_TO_SYSTEM\n";
    printf "\n";

    
    source $HOME/.bashrc
    if [[ -d "${PREFIX}" ]]; then
        check_on_target
        if [ $STATUS -eq 0 ]; then
            printf "${MSG_PREFIX} ${ERROR}Target '${WHITE}${TARGET}${ERROR}' exist. Exiting...\n${RESET_COLOR}";
            execution_end 1
        fi
    fi

    source $HOME/.bashrc
    if [[ ! "${PATH//:/}" =~ "$PREFIX/bin" ]]; then
        source ~/.bashrc; 
        echo "export PATH=\"$PATH:$PREFIX/bin\"" >> ~/.bashrc; 
        source ~/.bashrc;
    fi
    source $HOME/.bashrc

    
    install_deps

    mkdir -p ${BUILD_DIR}
    cd ${BUILD_DIR}

    check_command $TARGET-ld
    if [ $STATUS -eq 1  ]; then
        buildBinutils
    fi

    check_command $TARGET-gcc
    if [ $STATUS -eq 1 ]; then
        buildGCC
    fi

    check_command $TARGET-gdb
    if [ $STATUS -eq 1 ]; then
        buildGDB
    fi

    printf "${MSG_PREFIX} ${SUCCESS}All done.${RESET_COLOR}\n";
    execution_end 0
}


main 