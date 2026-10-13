#ifndef VERTEX_H_INCLUDED
#define VERTEX_H_INCLUDED
//
//    ** Note the cordinates in OpenCV: y multiplied by -1 for out put
//    ** Edge.angle は計算時に補正した
//

/***
    modified by 勇希 (yûki) on 2012-09-26
***/

#include <vector>
#include <cv.h>

#ifndef ERRORR
#define ERRORR(error_text)  { cerr << "error: " << error_text;  exit(10); }
#endif

#ifndef SWAP
#define SWAP( type, a, b) { type temp = a; a = b; b = temp; }
#endif

static const double PI = 3.14159265358979323846264338327950288;

////点列（一つのベクタデータ）
//typedef std::vector<CvPoint> points_t;
////点列の配列（複数のベクタデータ）
//typedef std::vector<points_t> contours_t;

// この値以下の領域があれば警告。0の時警告なし。
const int SMALL_CELL_THRESHOLD = 3;

/*********************************/
/*     define structures         */
/*********************************/

// Vertex.c
typedef struct Junction
{
    int id,pid;
    double x,y;
    std::vector<int> Cells;
    char ctype;
    char inout;
    int nj_num,nj[4];
    Junction(){ nj_num=0; }
} Junction;

typedef struct Edge
{
    int id,pid;
    int junction_id[2];
    CvPoint X[2];
    char inout;
    std::vector<CvPoint> line_pts;
    int dist_along;
    double sdist,angle; // distance and angle
    double signal_conc;
    Edge() // initialize
    {
        inout = 'i';
        signal_conc = 0.0;
    }
} Edge;

typedef struct VCell
{
    int id,pid;
    double area;
    std::vector<Junction*> JUNCTION;
    std::vector<Edge*> EDGE;
    char inout;
    double cx,cy;
    VCell() // initialize
    {
        inout = 'i';  cx=0.0;  cy=0.0;
        JUNCTION.clear();
    }
} VCell;


/*********************************/
/*    Declaration of functions   */
/*********************************/

//std::vector<VCell> vxSet_Vertex( IplImage *timg, std::vector<Junction> &ijunc, std::vector<Edge> &iedge , std::vector<CvPoint> BPoints);
void vxSet_Vertex( IplImage *timg, std::vector<Junction> &ijunc, std::vector<Edge> &iedge , std::vector<CvPoint> BPoints,std::vector<VCell> &cell);
void vxSetCel_Edge( std::vector<VCell> &vcell,std::vector<Edge> &vedge );
int  vxSet_RNUM( std::vector<Junction> junc );
//void vxOutputGeometry( FILE *fp, int oe_num, std::vector<Edge> oedge );
//void vxDraw_Polygon ( std::vector<Edge> edge, IplImage *src_img, char *outfile );
//void vxDraw_Polygon ( std::vector<Edge> edge, IplImage *src_img );
//void vxOutputDatas( FILE *outfile, std::vector<Junction> ojunc, std::vector<Edge> oedge, std::vector<VCell> ocell );
void vxOutputDatas(const char*, std::vector<Junction>, std::vector<Edge>, std::vector<VCell>); // yûki



#endif // VERTEX_H_INCLUDED
