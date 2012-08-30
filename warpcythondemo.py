import warpcython
from PIL import Image

if __name__ == "__main__":
	#Load source image
	srcIm = Image.open("lena.jpg")	

	#Create destination image
	dstIm = Image.new("RGB",(500,500))

	#Define control points for warp
	srcCloud = [(100,100),(400,100),(400,400),(100,400)]
	dstCloud = [(150,120),(374,105),(410,267),(105,390)]

	#Perform transform
	warpcython.PiecewiseAffineTransform(srcIm, srcCloud, dstIm, dstCloud)

	#Visualise result
	dstIm.show()

	

