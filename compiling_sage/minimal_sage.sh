# Source these varibles
export PATH=${HOME}/sage/local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:
export SAGE_HOME=${HOME}/sage/sage-10.5
export SAGE_LOCAL=${HOME}/sage/local
export MAKE="make -j4"

./configure --prefix=$SAGE_LOCAL \
	    --enable-4ti2 \
            --enable-d3js=yes \
	    --enable-gap_jupyter \
            --enable-pari_galpol  --enable-pysingular \
            --enable-singular_jupyter --enable-lidia --enable-coxeter3 \
	    --enable-r_jupyter --enable-pari_jupyter \
	    --enable-igraph 

## This is weird, but we have to do this
#
LOCAL_EXT_DATA=${SAGE_LOCAL}/lib/sage/ext_data
SRC_EXT_DATA=$SAGE_HOME/src/sage/ext_data

mkdir -p $LOCAL_EXT_DATA

for MISSING in notebook-ipython threejs pari; do
    cp -r ${SRC_EXT_DATA}/${MISSING} $LOCAL_EXT_DATA
done

# FAILS WITH ERRORS
# using libgivaro from system--not good!
# --enable-cocoalib
# --enable-gap3 is experimental
# --enable-configure UNRECOGNIZED
# --enable-sagemath_categories led to
# pip install pbr
# which helped, but this seems to be failing tests.
# --enable-r_jupyter has trouble
# Don't compile python3. Use the system python or you will regret it.
# Unfortunately, python3.11 moved longintrepr.h to /usr/include/python3/cython
# which breaks --enable-pari_jupyter
