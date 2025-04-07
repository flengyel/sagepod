#!/bin/bash

sudo apt-get update
sudo apt-get upgrade
sudo apt-get install -y xauth x11-xserver-utils
sudo apt install -y net-tools bison
sudo apt-add-repository ppa:git-core/ppa 
sudo apt install -y git libgit2-dev libmagick++-dev libharfbuzz-dev libfribidi-dev
sudo apt-get install  -y coinor-cbc coinor-libcbc-dev gpgconf openssh-client pari-gp2c libisl-dev libgraphviz-dev \
lrslib pdf2svg libxml-libxslt-perl libxml-writer-perl libxml2-dev libperl-dev libfile-slurp-perl libjson-perl \
libsvg-perl libterm-readkey-perl libterm-readline-gnu-perl libmongodb-perl polymake libpolymake-dev default-jdk libavdevice-dev

sudo apt-get install  -y bc binutils bzip2 ca-certificates cliquer cmake curl ecl eclib-tools fflas-ffpack flintqs g++ gcc gengetopt gfan gfortran glpk-utils gmp-ecm lcalc libatomic-ops-dev libboost-dev libbraiding-dev libbrial-dev libbrial-groebner-dev libbz2-dev libcdd-dev libcdd-tools libcliquer-dev libcurl4-openssl-dev libec-dev libecm-dev libffi-dev libflint-arb-dev libflint-dev libfplll-dev libfreetype6-dev libgc-dev libgd-dev libgf2x-dev libgiac-dev libgivaro-dev libglpk-dev libgmp-dev libgsl-dev libhomfly-dev libiml-dev liblfunction-dev liblinbox-dev liblrcalc-dev liblzma-dev libm4ri-dev libm4rie-dev libmpc-dev libmpfi-dev libmpfr-dev libncurses5-dev libntl-dev libopenblas-dev libpari-dev libpcre3-dev libplanarity-dev libppl-dev libprimesieve-dev libpython3-dev libqhull-dev libreadline-dev librw-dev libsingular4-dev libsqlite3-dev libssl-dev libsuitesparse-dev libsymmetrica2-dev libz-dev libzmq3-dev libzn-poly-dev m4 make nauty ninja-build openssl palp pari-doc pari-elldata pari-galdata pari-galpol pari-gp2c pari-seadata patch perl pkg-config planarity ppl-dev python3 python3-distutils python3-venv r-base-dev r-cran-lattice singular singular-doc sqlite3 sympow tachyon tar tox xcas xz-utils

sudo apt install  -y git libgit2-dev libmagick++-dev  libmagickcore-dev libmagickwand-dev -y

sudo apt-get install -y  autoconf automake git gpgconf libtool openssh-client pkg-config

sudo apt-get install  -y default-jdk dvipng ffmpeg imagemagick latexmk libavdevice-dev pandoc tex-gyre texlive-fonts-recommended texlive-lang-cyrillic texlive-lang-english texlive-lang-european texlive-lang-french texlive-lang-german texlive-lang-italian texlive-lang-japanese texlive-latex-extra texlive-xetex

