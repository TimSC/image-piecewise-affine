image-piecewise-affine
======================

A python piecewise affine image warper library. Both pure python and cython implementations are included. The transform is defined by a set of control points in the source and destination images. Demo programs are included in warp.py and warpcythondemo.py.

The cython version can be built using the command: python setup.py build_ext --inplace

On my desktop PC, the native python version runs in 6.992 sec, the cython version in 4.861 seconds.

The method depends on scipy.spatial to perform Delaunay triangularisation.

This software is available under the Simplified BSD License as specified in the COPYING file.

