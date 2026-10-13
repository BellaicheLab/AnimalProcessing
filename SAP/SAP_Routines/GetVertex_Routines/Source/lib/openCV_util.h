#ifndef OPENCV_UTIL_H_INCLUDED
#define OPENCV_UTIL_H_INCLUDED

#include <cv.h>

#include <vector>
#include <string>
#include <map>

#ifndef ERRORR
#define ERRORR(error_text)  { cerr << "error: " << error_text;  exit(10); }
#endif

#ifndef SWAP
#define SWAP( type, a, b) { type temp = a; a = b; b = temp; }
#endif

#define MAX_UNCHAR ((unsigned char)255)

//点列（一つのベクタデータ）
typedef std::vector<CvPoint> points_t;
//点列の配列（複数のベクタデータ）
typedef std::vector<points_t> contours_t;


/***
    modified by 勇希 (yûki)
    last update: 2013-01-23
***/


// 8近傍によるピクセルタイプの分類。 char return_ctype()から呼び出される
const char CVUTIL_NCELL_TYPE[]=
{
	'd','t','t','t','t','e','t','d','t','t','e','z','e','e','e','z','t','e','e','e','t','e','z','e',
	'e','e','j','e','e','e','z','z','t','e','e','e','e','j','e','e','t','d','e','z','e','e','e','z',
	'e','j','j','j','e','j','z','z','e','e','j','z','e','e','z','z','t','e','e','e','e','j','e','e',
	'e','e','j','z','j','j','j','z','e','j','j','j','e','j','z','z','j','j','f','z','j','j','z','z',
	't','e','e','e','e','j','e','e','z','z','z','z','z','z','z','z','e','j','j','j','e','j','z','z',
	'z','z','z','z','z','z','z','z','t','e','e','e','e','j','e','e','e','e','j','z','j','j','j','z',
	't','e','e','e','d','e','z','z','e','e','j','z','e','e','z','z','e','j','j','j','j','f','j','j',
	'e','e','j','z','j','j','j','z','e','j','j','j','e','j','z','z','e','e','z','z','e','e','z','z',
	't','e','e','e','e','j','e','e','e','e','j','z','j','j','j','z','z','z','z','z','z','z','z','z',
	'z','z','z','z','z','z','z','z','d','e','e','e','e','j','e','e','z','z','z','z','z','z','z','z',
	'z','z','z','z','z','z','z','z','z','z','z','z','z','z','z','z'
};

// head
char CVUTIL_GetPixelType( char *tv, int id, int W );
//IplImage  **Set_DataFile( char *filename_AVI, int &NFrames );
void Skeletonize( IplImage *timg );
void Set_Ctypes( IplImage *timg, char *ctypes, std::string name="", bool zerr=true); // optional argument: filename for type image output
void Trace(IplImage *timg, std::vector<points_t> &conts, char *ctypes );
void Trace(IplImage *timg, std::vector<points_t> &conts);


// boundary
void utlRemoveBoundaryEdges( IplImage *timg );
void utlDelete_Extra_Edges( IplImage *timg );
void utlBoundaryprocessing( IplImage *timg, std::vector<CvPoint> &BPoints );
void utlBoundaryprocessing(IplImage*,std::vector<CvPoint>&,char*);
void utlRemoveBoundaryWhisker( IplImage *timg );
//void utlOutputBinaryImage( FILE *fp, IplImage *oimg );

// 各pixelの細胞ID
//int utlSet_CellID( IplImage *timg, int *CellID );
int utlSet_CellID( IplImage *timg, int *CellID, int smallC );
int utlSet_CellID( IplImage *timg, int *CellID, int smallC ,std::map<int,double>&); // test


#endif // OPENCV_UTIL_H_INCLUDED
