### cython: profile=False
# cython: cdivision=True
# cython: boundscheck=False
# cython: wraparound=False

from PIL import Image
import numpy as np
cimport numpy as np
import math
import scipy.spatial as spatial

cdef GetBilinearPixel(np.ndarray[np.float32_t,ndim=3] imArr, float posX, float posY, np.ndarray[np.int32_t,ndim=1] out):
	cdef float modXf, modYf
	cdef int modXi, modYi, chan
	cdef float bl, br, tl, tr, b, t, pxf

	#Get integer and fractional parts of numbers
	modXi = int(posX)
	modYi = int(posY)
	modXf = posX - modXi
	modYf = posY - modYi

	#Get pixels in four corners
	for chan in range(imArr.shape[2]):
		bl = imArr[modYi, modXi, chan]
		br = imArr[modYi, modXi+1, chan]
		tl = imArr[modYi+1, modXi, chan]
		tr = imArr[modYi+1, modXi+1, chan]
	
		#Calculate interpolation
		b = modXf * br + (1. - modXf) * bl
		t = modXf * tr + (1. - modXf) * tl
		pxf = modYf * t + (1. - modYf) * b
		out[chan] = int(pxf+0.5) #Do fast rounding to integer

	return None #Helps with profiling view

cdef WarpProcessing(inImg, np.ndarray[np.float32_t, ndim=3] inArr, 
	np.ndarray[np.uint8_t, ndim=3] outArr, 
	np.ndarray[np.int_t, ndim=2] inTriangle, 
	triAffines, shape):

	cdef int i, j, tri, chan
	cdef float xmin, xmax, ymin, ymax
	cdef int xmini, xmaxi, ymini, ymaxi
	cdef float normSpaceCoordX, normSpaceCoordY

	#cdef np.ndarray[np.float32_t, ndim=3] inArr = np.asarray(inImg, dtype=np.float32)
	cdef np.ndarray[np.int32_t, ndim=1] px = np.empty((inArr.shape[2],), dtype=np.int32)
	cdef np.ndarray[np.float32_t, ndim=1] homogCoord = np.ones((3,), dtype=np.float32)
	cdef np.ndarray[double, ndim=1] outImgCoord
	cdef np.ndarray[double, ndim=2] affine

	#Calculate ROI in target image
	xmin = shape[:,0].min()
	xmax = shape[:,0].max()
	ymin = shape[:,1].min()
	ymax = shape[:,1].max()
	xmini = int(xmin)
	xmaxi = int(xmax+1.)
	ymini = int(ymin)
	ymaxi = int(ymax+1.)
	#print xmin, xmax, ymin, ymax

	#Synthesis shape norm image		
	for i in range(xmini, xmaxi):
		for j in range(ymini, ymaxi):
			homogCoord[0] = i
			homogCoord[1] = j

			#Determine which tesselation triangle contains each pixel in the shape norm image
			if i < 0 or i >= outArr.shape[1]: continue
			if j < 0 or j >= outArr.shape[0]: continue

			#Determine which triangle the destination pixel occupies
			tri = inTriangle[i,j]
			if tri == -1: 
				continue
				
			#Calculate position in the input image
			affine = triAffines[tri]
			outImgCoord = np.dot(affine, homogCoord)

			#Check destination pixel is within the image
			if outImgCoord[0] < 0 or outImgCoord[0] >= inArr.shape[1]:
				for chan in range(px.shape[0]): outArr[j,i,chan] = 0
				continue
			if outImgCoord[1] < 0 or outImgCoord[1] >= inArr.shape[0]:
				for chan in range(px.shape[0]): outArr[j,i,chan] = 0
				continue

			#Nearest neighbour
			#outImgL[i,j] = inImgL[int(round(inImgCoord[0])),int(round(inImgCoord[1]))]

			#Copy pixel from source to destination by bilinear sampling
			#print i,j,outImgCoord[0:2],im.size
			GetBilinearPixel(inArr, outImgCoord[0], outImgCoord[1], px)
			for chan in range(px.shape[0]):
				outArr[j,i,chan] = px[chan]
			#print outImgL[i,j]

	return None

def PiecewiseAffineTransform(srcIm, srcPoints, dstIm, dstPoints):

	#Convert input to correct types
	srcArr = np.asarray(srcIm, dtype=np.float32)
	dstPoints = np.array(dstPoints)
	srcPoints = np.array(srcPoints)

	#Split input shape into mesh
	tess = spatial.Delaunay(dstPoints)

	#Calculate ROI in target image
	xmin, xmax = dstPoints[:,0].min(), dstPoints[:,0].max()
	ymin, ymax = dstPoints[:,1].min(), dstPoints[:,1].max()
	#print xmin, xmax, ymin, ymax

	#Determine which tesselation triangle contains each pixel in the shape norm image
	inTessTriangle = np.ones(dstIm.size, dtype=np.int) * -1
	for i in range(int(xmin), int(xmax+1.)):
		for j in range(int(ymin), int(ymax+1.)):
			if i < 0 or i >= inTessTriangle.shape[0]: continue
			if j < 0 or j >= inTessTriangle.shape[1]: continue
			normSpaceCoord = (float(i),float(j))
			simp = tess.find_simplex([normSpaceCoord])
			inTessTriangle[i,j] = simp

	#Find affine mapping from input positions to mean shape
	triAffines = []
	for i, tri in enumerate(tess.vertices):
		meanVertPos = np.hstack((srcPoints[tri], np.ones((3,1)))).transpose()
		shapeVertPos = np.hstack((dstPoints[tri,:], np.ones((3,1)))).transpose()

		affine = np.dot(meanVertPos, np.linalg.inv(shapeVertPos)) 
		triAffines.append(affine)

	#Calculate pixel colours
	targetArr = np.copy(np.asarray(dstIm, dtype=np.uint8))
	WarpProcessing(srcIm, srcArr, targetArr, inTessTriangle, triAffines, dstPoints)
	dstIm.paste(Image.fromarray(targetArr))	

