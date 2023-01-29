# Building and installing Cross Compiler utility for OSDever
This small script will help you build your favourite cross-compiler and its neccessary dependencies which are needed for OS/Embedded Development. Inspired from [https://github.com/lordmilko/i686-elf-tools]
# Features
  - Config, build and install gcc (Support C/C++, other language must edit GCC_CONFIG), binutils and gdb automatically. Can specify which will be installed by flags.
  - Compare and build toolchain that suits your system host compiler version (older or present).
  - Can specify which version will be installed by specifying flags.
  - Can specify which target compiler will be installed by specifying flags.
  - Supports only setup enviroment.
  - Can build to system by specifying flag.
  - Current supported flags:
    + [-s | --system]: Install to system
    + [-t | --target]: Specify target to build.
    + [-bv | binutils-version]: Specify Binutils version. Cannot leave blank.
    + [-gv | gcc-version]: Specify GCC version. Cannot leave blank. 
    + [-dv | gdb-version]: Specify GDB version. Cannot leave blank .
    + [binutils | build-binutils-only]: Only build Binutils. Can combine with 'gcc' and 'gdb'. 
    + [gcc | build-gcc-only]: Only build GCC. Can combine with 'binutils' and 'gdb'. 
    + [gdb | build-gdb-only]: Only build GDB. Can combine with 'binutils' and 'gcc'.
    + [env | setup-enviroment-only]: Only setup enviroment
    (Can combine 'binutils', 'gcc', 'gdb' and 'env')
# How to use
Simply just type run toolchain.sh and wait for it to complete. 
Default target will be $HOSTTYPE-elf target, change it if you need other target by --target flag. Every build will be in $HOME/build-$TARGET. 
Specify -s to install to system (need root privilege). 
That's all.
    
