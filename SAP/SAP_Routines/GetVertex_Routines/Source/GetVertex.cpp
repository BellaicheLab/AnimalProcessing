/***
    ISHIHARA's code
    modified by 勇希 (yûki)
    last update: 2013-01-23
***/

#include <iostream>
#include <vector>
#include <string>
#include <cmath>

#include <cv.h>
#include <highgui.h>

#include "lib/openCV_util.h"
#include "lib/vertex.h"

using namespace std;

/***
    overlay edges on the source image and save the result.
    @param src_img_r a pointer to the raw image
    @param edge the vector of edges
    @param Outimage_name the output image name
    ***/
void GV_Check_Vertex(IplImage *src_img_r, vector<Edge>& edge, const char *Outimage_name)
{
    CvPoint pt1,pt2;
    // output image
    IplImage *vimg = NULL;
    // edge color
    CvScalar rcolor = CV_RGB(255, 0, 255);
    // initialize the image
    vimg = cvCreateImage( cvSize( src_img_r->widthStep,  src_img_r->height), IPL_DEPTH_8U, 3 );
    cvZero(vimg);
    // copy raw image on green channel
    for(int id1=0, id2=1; id1<src_img_r->height*src_img_r->widthStep; id1++, id2+=3)
        vimg->imageData[id2] = src_img_r->imageData[id1];
    // overlay edges
    for(unsigned int i=0; i<edge.size(); i++ )
    {
        pt1 = edge[i].X[0]; pt2 = edge[i].X[1];
        cvLine (vimg, pt1, pt2, rcolor, 1, CV_AA, 0); // draw line
    }
    // save output image
    cvSaveImage(Outimage_name,vimg);
    // free image
    cvReleaseImage(&vimg);
}


/***
    MAIN
    usage: [raw_img] [seg_img] [out_img] [out_dat]
                                   ^ optional ^
        ***/
int main( int argc, char** argv )
{
    // raw image pointer
    IplImage *src_img_r = NULL;
    // seg image pointer
    IplImage *img = NULL;
    // vector of junctions
    vector<Junction> junc;
    // vector of edges
    vector<Edge> edge;
    // vector of cells
    vector<VCell> cell;
    // vector of points
    vector<CvPoint> BPoints;

    // arguments check
    if(argc<3) ERRORR("Not enough arguments ...\n");

    // load raw image
    src_img_r = cvLoadImage( argv[1], CV_LOAD_IMAGE_GRAYSCALE );
    // load seg image
    img = cvLoadImage( argv[2], CV_LOAD_IMAGE_GRAYSCALE );
    // if unable to read images, exit with ERRORR
    if( src_img_r==0 || img==0 ) ERRORR("Input file error\n");

    cout<<"# raw: "<<argv[1]<<endl<<"# seg: "<<argv[2]<<endl;

    // default image output name
    string imageoutputname="Vertex.png";
    // default data output name
    string dataoutputname="data.dat";

    // if not provided, set it to default name
    if(argc>3) imageoutputname=argv[3];
    if(argc>4) dataoutputname=argv[4];

    // Skeletonize (if necessary)
    cvNot( img, img );
    Skeletonize( img );
    cvNot( img, img );

    // Processing of Boundary
    cout << "# Start Boundary Deletion" << endl;
    utlBoundaryprocessing( img, BPoints );
    cout << "# ... Finish Boundary Deletion" << endl;

#ifdef DISPLAY
    // display seg image
    cvShowImage( "Boundary",img );
    cvWaitKey(0);
    cvDestroyWindow("Boundary");
#endif

    // set information about cell, edge, junc
    cout << "# Start Getting Vertex properties" << endl;
    vxSet_Vertex( img, junc, edge, BPoints,cell );
    // image output (for check)
    GV_Check_Vertex( src_img_r, edge, imageoutputname.c_str() );
    // print data
    vxOutputDatas( dataoutputname.c_str(), junc, edge, cell );

    // console print
    cout << "# ... Finish Getting Vertex properties" << endl;
    cout << "## Number of cells = " << cell.size() << endl;
    cout << "## Number of edges = " << edge.size() << endl;
    cout << "## Number of juncs = " << junc.size() << endl;
    cout << "### VertexImg= " << imageoutputname << endl;
    cout << "### VertexDat= " << dataoutputname << endl;

    // free images
    cvReleaseImage( &img );
    cvReleaseImage(&src_img_r);

    return EXIT_SUCCESS;
}
// end of file
