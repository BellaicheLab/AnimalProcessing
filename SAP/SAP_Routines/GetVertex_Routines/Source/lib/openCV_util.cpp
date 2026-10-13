/***
    util.c and OpenCV_Util.h merged into a single file.

    modified by 勇希 (yûki)
    Last update: 2013-01-23
***/

#include "openCV_util.h"

#include <highgui.h>

#include <fstream>
#include <iostream>


using namespace std;

// unused code
#if 0
//
//  AVIファイルを取り込む
//  AVIファイルは　~/lib/bin/tif2avi　で変換できる
//
IplImage  **Set_DataFile( char *filename_AVI, int &NFrames )
{
  IplImage **tsrcimg = NULL;
  CvCapture* capture = NULL;
  //指定したAVIファイルが見つからない場合
  if( NULL==( capture=cvCaptureFromAVI( filename_AVI ) ) ){
    fprintf(stderr,"指定のaviファイルが見つかりませんでした．");
    exit(10);
  }
  NFrames = (int) cvGetCaptureProperty(capture,CV_CAP_PROP_FRAME_COUNT);
  tsrcimg = new IplImage* [NFrames];
  for(int n=0; n<NFrames; n++){
    IplImage *stimg;
    if( NULL==(stimg=cvQueryFrame(capture))){ break; }
    tsrcimg[n] = cvCloneImage( stimg );
  }
  cvReleaseCapture(&capture);   //解放
  return tsrcimg;
}

IplImage  **Set_GrayDataFile( char *filename_AVI, int &NFrames )
{
  IplImage **tsrcimg = NULL;
  IplImage **grayimg = NULL;
  CvCapture* capture = NULL;
  //指定したAVIファイルが見つからない場合
  if( NULL==( capture=cvCaptureFromAVI( filename_AVI ) ) ){
    fprintf(stderr,"指定のaviファイルが見つかりませんでした．");
    exit(10);
  }
  tsrcimg = Set_DataFile( filename_AVI, NFrames );
  grayimg = new IplImage* [NFrames];
  for(int n=0; n<NFrames; n++){
	grayimg[n] = cvCreateImage( cvGetSize(tsrcimg[n]),IPL_DEPTH_8U,1);
	cvCvtColor(tsrcimg[n], grayimg[n], CV_BGR2GRAY);
  }
  cvReleaseImage(tsrcimg);      //解放
  cvReleaseCapture(&capture);   //解放
  return grayimg;
}
#endif

/***
    get type of pixel
    @param tv a pointer to the pixel array
    @param id the pixel linear index
    @param mw the image width
    @return the pixel type
    ***/
char CVUTIL_GetPixelType(char *tv, int id, int mw )
{
    // index in CVUTIL_NCELL_TYPE
    int cindex;
    // background
    if(tv[id] == 0 ) return 'i';
    else
    {
        /* compute index
            a b c
            d X e
            f g h
            cindex = a+2*b+4*c+8*d+16*e+32*f+64*g+128*h;
         */
        cindex= (tv[id-mw-1]==(char)255)
                +2*(tv[id-mw]==(char)255)
                +4*(tv[id-mw+1]==(char)255)
                +8*(tv[id-1]==(char)255)
                +16*(tv[id+1]==(char)255)
                +32*(tv[id+mw-1]==(char)255)
                +64*(tv[id+mw]==(char)255)
                +128*(tv[id+mw+1]==(char)255);

        return CVUTIL_NCELL_TYPE[cindex];
    }
}

/***
    各ピクセルの8近傍タイプ
    set 8-neighborhood type of each pixel
    @param timg a pointer to the seg image
    @param ctypes the type array to fill
    @param name the output image name [optional, empty by default]
    @param zerr a boolean to exit in case of z pixel error [optional, true by default]
    ***/
void Set_Ctypes( IplImage *timg, char *ctypes, std::string name, bool zerr)
{
    IplImage *vimg;
    // output image print requested
    if(!name.empty())
    {
        vimg = cvCreateImage(cvSize(timg->widthStep,timg->height),IPL_DEPTH_8U,1);
        cvZero(vimg);
    }
    // loop on pixels
    for( int y=1; y<timg->height-1; y++ )
    {
        for( int x=1; x<timg->width-1; x++ )
        {
            // pixel index in ctypes
            int id  = timg->width*y+x;
            // pixel index in timg
            int mid = timg->widthStep*y+x;
            // set type
            ctypes[id] = CVUTIL_GetPixelType( timg->imageData, mid, timg->widthStep );

            // set output image pixel
            if(!name.empty()) vimg->imageData[mid]=ctypes[id];

            // error case (bad skeletonization error)
            if( ctypes[id]=='z' )
            {
                cerr << "Bad skeletonization error: 'z' pixel found at "<< x << " " << y << endl;
                if(zerr) exit(EXIT_FAILURE);
            }
        }
    }
    if(!name.empty())
    {
        cvSaveImage(name.c_str(),vimg);
        cvReleaseImage(&vimg);
    }
}

/***
    ８近傍画素の追跡によるベクトル化 (Vectorization by eight neighboring pixel tracking)
    で分岐点、交差点は'1'がセットされている。 (Branch point, '1 'is set at the intersection)
    @param timg a pointer to the seg image
    @param conts a reference to the contours list to fill
    @param ctypes the type array
    ***/
void Trace( IplImage *timg, contours_t &conts, char *ctypes )
{
    // one channel image only
    assert( timg->nChannels==1 );
    // Width & Height
    int W=timg->width, H=timg->height;
    // neighbours offset
    int npb[8] = { -W, -1, 1, W, -W-1, -W+1, W-1, W+1 }; // 近傍
    // 出力点列ラインデータ
    std::vector<CvPoint> pts;

    // dynamic allocation for ejnum
    int *ejnum= new int[W*H];
    // init with 0s
    for(unsigned int i=0;i<W*H;i++) ejnum[i]=0;

    // dynamic allocation for tV
    char *tV = new char[W*H];
    // fill tV with image pixels
    for( int y=1; y<H-1; y++ )
        for( int x=1; x<W-1; x++ )
            tV[W*y+x] = timg->imageData[timg->widthStep*y+x];

    // 追跡処理開始 (Tracing process starts)
    for( int y=1; y<H-1; y++ )
    {
        for( int x=1; x<W-1; x++ )
        {
            int sid = W*y+x; // 追跡開始点 (Tracing the starting point)
            vector<char*> termid;

            if( ctypes[sid]=='t' ||  ctypes[sid]=='j' || ctypes[sid]=='f' )
            {
                //各Junctionから以下の条件で追跡を始める。 (Under the following conditions from start tracking)
                while( (ctypes[sid]=='t' && ejnum[sid]<1)
                    || (ctypes[sid]=='j' && ejnum[sid]<3)
                    || (ctypes[sid]=='f' && ejnum[sid]<4) )
                {
                    int tid = sid;
                    int counter = 0, tedge_length = 0; //追跡した画素数
                    int tx,ty;

                    // clear vector
                    pts.clear();
                    // add starting point
                    pts.push_back( cvPoint(tid%W,tid/W) );
                    do
                    {
                        // ８近傍の白画素を探す/見つかれば追跡開始
                        // look for white pixel in the neighbourhood
                        bool move=false;
                        for( int k=0; k<8 && !move; k++ )
                        {
                            // if found start tracking
                            if(tV[tid+npb[k]]==(char)255)
                            {
                                // 例外処理 (Exception)
                                if(tedge_length==1 && tid+npb[k]==sid+W ) continue;
                                // update tV
                                tV[tid] = 1;
                                // update position
                                tid = tid+npb[k];
                                // update length
                                tedge_length++;
                                move=true;
                            }
                        }
                        // coordinates
                        tx = tid%W; ty = tid/W;
                        // add point
                        pts.push_back( cvPoint(tx,ty) );

                        if(!move)
                        {
                            cerr<<"ERROR@Trace: stuck in an infinite loop: "<<tx<<" "<<ty<<" "<<ctypes[tid]<<endl;
                            exit(EXIT_FAILURE);
                        }
                    } while( tx>1 && ty>1 && tx<W-1 && ty<H-1 && ctypes[tid]!='t' && ctypes[tid]!='j' && ctypes[tid]!='f' );

                    // update ejnum
                    ejnum[sid]++; ejnum[tid]++;
                    // エラーがないか
                    if( ejnum[sid]>5 )
                    {
                        cerr<<"ERROR@Trace: ejnum>5: "<<x<<" "<<y<<endl;
                        exit(EXIT_FAILURE);
                    }
                    else if( ejnum[tid]>5 )
                    {
                        cerr<<"ERROR@Trace: ejnum>5: "<<tx<<" "<<ty<<endl;
                        exit(EXIT_FAILURE);
                    }
                    // add in the contour
                    conts.push_back(pts);
                    // update tV
                    tV[tid] = 1;
                    // add in termid
                    termid.push_back(tV+tid);
                }//while

                for( int tt=0; tt<termid.size(); tt++ ) *termid[tt]=(char)255;
            }
        }
    }

    // deallocate memory
    delete[] tV;
    delete[] ejnum;
}

/***
    Trace
    @param timg a pointer to the seg image
    @param conts a reference to the contours list to fill
    ***/
void Trace( IplImage *timg, contours_t &conts )
{
    // allocate memory
    char *ctypes= new char[timg->width*timg->height];
    // init ctypes
    Set_Ctypes( timg, ctypes );
    // trace
    Trace( timg, conts, ctypes );
    // deallocate memory
    delete[] ctypes;
}

/***
    細線化処理
    in:入力２値画像
    @param timg a pointer to the seg image to skeletonize
    ***/
void Skeletonize(IplImage *timg)
{
    int x, y, w, h;

    // 画像情報を取得
    assert( timg->nChannels==1 );
    //幅
    w = timg->width;
    //高さ
    h = timg->height;

    // 初期化
    int k;
    int p0, p1, p2, p3, p4, p5, p6, p7, p8;
    bool flag = true;
    // [STEP1]
    while(flag)
    {
        flag = false; // [STEP 2]
        for( k=1; k<=4; k++ ) // [STEP 3]
        {
            //**********************************
            //             [STEP 4]
            //**********************************
            for( y=1; y<h-1; y++ )
            {
                for( x=1; x<w-1; x++ )
                {
                    p0 = CV_IMAGE_ELEM( timg, unsigned char, y, x );
                    if( p0!=0 )continue;

                    p1 = CV_IMAGE_ELEM( timg, unsigned char, y  , x+1 );
                    p2 = CV_IMAGE_ELEM( timg, unsigned char, y-1, x+1 );
                    p3 = CV_IMAGE_ELEM( timg, unsigned char, y-1, x   );
                    p4 = CV_IMAGE_ELEM( timg, unsigned char, y-1, x-1 );
                    p5 = CV_IMAGE_ELEM( timg, unsigned char, y  , x-1 );
                    p6 = CV_IMAGE_ELEM( timg, unsigned char, y+1, x-1 );
                    p7 = CV_IMAGE_ELEM( timg, unsigned char, y+1, x   );
                    p8 = CV_IMAGE_ELEM( timg, unsigned char, y+1, x+1 );

                    if( (k==1 && p1==MAX_UNCHAR) || // C(1)の境界条件
                        (k==2 && p3==MAX_UNCHAR) || // C(2)の境界条件
                        (k==3 && p5==MAX_UNCHAR) || // C(3)の境界条件
                        (k==4 && p7==MAX_UNCHAR) )  // C(4)の境界条件
                    {
                        flag = true;
                        //*******************************
                        //           抽出点条件
                        //*******************************
                        if( ((p1 == MAX_UNCHAR && p5 == MAX_UNCHAR) && (p2 < MAX_UNCHAR || p3 < MAX_UNCHAR || p4 < MAX_UNCHAR) && (p6 < MAX_UNCHAR || p7 < MAX_UNCHAR || p8 < MAX_UNCHAR)) // 条件(i)
                         || ((p3 == MAX_UNCHAR && p7 == MAX_UNCHAR) && (p4 < MAX_UNCHAR || p5 < MAX_UNCHAR || p6 < MAX_UNCHAR) && (p8 < MAX_UNCHAR || p1 < MAX_UNCHAR || p2 < MAX_UNCHAR)) // 条件(ii)
                         || ((p1 == MAX_UNCHAR && p7 == MAX_UNCHAR) && (p2 < MAX_UNCHAR || p3 < MAX_UNCHAR || p4 < MAX_UNCHAR || p5 < MAX_UNCHAR || p6 < MAX_UNCHAR) &&  p8 < MAX_UNCHAR ) // 条件(iii)
                         || ((p1 == MAX_UNCHAR && p3 == MAX_UNCHAR) && (p4 < MAX_UNCHAR || p5 < MAX_UNCHAR || p6 < MAX_UNCHAR || p7 < MAX_UNCHAR || p8 < MAX_UNCHAR) &&  p2 < MAX_UNCHAR ) // 条件(iv)
                         || ((p3 == MAX_UNCHAR && p5 == MAX_UNCHAR) && (p6 < MAX_UNCHAR || p7 < MAX_UNCHAR || p8 < MAX_UNCHAR || p1 < MAX_UNCHAR || p2 < MAX_UNCHAR) &&  p4 < MAX_UNCHAR ) // 条件(v)
                         || ((p7 == MAX_UNCHAR && p5 == MAX_UNCHAR) && (p8 < MAX_UNCHAR || p1 < MAX_UNCHAR || p2 < MAX_UNCHAR || p3 < MAX_UNCHAR || p4 < MAX_UNCHAR) &&  p6 < MAX_UNCHAR ))// 条件(vi)
                            // 上の条件を満たすならば、これは削ってはいけない画素（永久保存画素）
                            CV_IMAGE_ELEM( timg, unsigned char, y, x ) = 2;
                        else
                            CV_IMAGE_ELEM( timg, unsigned char, y, x ) = 3;
                    };// 境界条件
                };// x
            };// y
            //
            //  [STEP5]:削ってもよい画素をまとめて消す
            //
            for(y = 0; y < h; y++)
                for(x = 0; x < w; x++)
                    if( CV_IMAGE_ELEM( timg, unsigned char, y, x ) == 3) CV_IMAGE_ELEM( timg, unsigned char, y, x )=MAX_UNCHAR;
        };//for k
    };// loop flag
    //****************************
    //  永久保存点を結果とする
    //****************************
    for(y = 0; y < h; y++)
        for(x = 0; x < w; x++)
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x ) == 2) CV_IMAGE_ELEM( timg, unsigned char, y, x )=(unsigned char)0;
}


/***************************************************************************

 			細胞画像のための基本的な処理を行う関数群

(former util.c)
modified by 勇希 (yûki)
last update: 2013-01-23


***************************************************************************/


/////////////////////////////////////////////////////////////////////////////////
//
//			         Define functions
//
/////////////////////////////////////////////////////////////////////////////////


/***
    function to remove boundary whiskers
    @param timg a pointer to the seg image
    ***/
void utlRemoveBoundaryWhisker( IplImage *timg )
{
    //neighbours iteration
    int dx[8] = {1, 1, 0, -1, -1, -1, 0, 1}, dy[8] = {0, -1, -1, -1, 0, 1, 1, 1};
    // fill the image periphery with 1s
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(1) );

    // check the rest of the image
    for(int y=1; y<timg->height-1; y++)
    {
        for(int x=1; x<timg->width-1; x++)
        {
            // if border pixel
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x )==255 )
            {
                bool bflag = false;
                for( int k=0; k<8; k++)
                {
                    // if background pixel
                    if( CV_IMAGE_ELEM( timg, unsigned char, y+dy[k], x+dx[k] ) == 0 )
                    {
                        bflag = true; break;
                    }
                }
                // no background pixel found in the neighbourhood
                if(!bflag) CV_IMAGE_ELEM( timg, unsigned char, y, x )= 1;
            }
        }
    }
    // fill the image periphery with 0s
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(0) );
}

/***
    function for boundary processing : yet rather ad-hoc
    @param timg a pointer to the seg image
    @param BPoints a reference to a vector of points
    ***/
void utlBoundaryprocessing( IplImage *timg, vector<CvPoint> &BPoints )
{
    /* neighbours iteration order for pixel X
        4 3 2
        5 X 1
        6 7 8
    */
    int dx[8] = {1, 1, 0, -1, -1, -1, 0, 1}, dy[8] = {0, -1, -1, -1, 0, 1, 1, 1};

    // dynamic allocation for ctypes
    char *ctypes = new char[timg->width*timg->height];
    char *ctypes0 = new char[timg->width*timg->height];

    // set 8-neighor type of each pixel point for the original image
    Set_Ctypes(timg, ctypes0);

    // temp points vector
    vector<CvPoint> tBPoints;

    // Delete all the image periphery for convenience
    for(unsigned int y=0; y<timg->height; y++) // vertical
    {
        CV_IMAGE_ELEM( timg, unsigned char, y, 0 ) = 0;
        CV_IMAGE_ELEM( timg, unsigned char, y, timg->width-1 ) = 0;
    }
    for(unsigned int x=0; x<timg->width; x++) // horizontal
    {
        CV_IMAGE_ELEM( timg, unsigned char, 0, x ) = 0;
        CV_IMAGE_ELEM( timg, unsigned char, timg->height-1, x ) = 0;
    }

    // remove whiskers
    utlRemoveBoundaryWhisker(timg);

    // set 8-neighor type of each pixel point
    Set_Ctypes(timg, ctypes);

    // make surroundings as '1'
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(1) );

    // Eliminate the most outer pixels except junctional points
    for(int y=1; y<timg->height-1; y++)
        for(int x=1; x<timg->width-1; x++)
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x )==255 )// border pixel
            {
                bool bflag = false;
                // iterate on neighbourhood
                for( int k=0; k<8; k++)
                {
                    // a surrounding pixel in neighbourhood found !
                    if( CV_IMAGE_ELEM( timg, unsigned char, y+dy[k], x+dx[k] )== 1 )
                    {
                        bflag = true;
                        break;
                    }
                }
                // if a surrounding pixel in neighbourhood found
                if( bflag )
                {
                    // remove pixel if type 'e'
                    if(ctypes0[timg->width*y+x] == 'e' ) CV_IMAGE_ELEM(timg, unsigned char, y, x ) =0;
                    else tBPoints.push_back(cvPoint(x,y));
                }
            }

    // fill surroundings with 0s
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(0) );

    // update 8-neighour type of each pixel point
    Set_Ctypes( timg, ctypes);

    // remove pixels of type 'd'
    for( int y=1; y<timg->height-1; y++ )
        for( int x=1; x<timg->width-1; x++ )
            if( ctypes[timg->width*y+x] == 'd' ) CV_IMAGE_ELEM(timg,unsigned char,y,x)=0;

    // update 8-neighour type of each pixel point
    Set_Ctypes( timg, ctypes);

    // remove junctional pixels that became edge pixels
    for(vector<CvPoint>::iterator it=tBPoints.begin();it!=tBPoints.end();it++)
        if( ctypes[timg->width*it->y+it->x]=='e' )
        {
            // special case for 'f' (type 90, cross+ type)
            if(ctypes0[timg->width*it->y+it->x]=='f' &&
               (CV_IMAGE_ELEM(timg,unsigned char,it->y,it->x+1)==255 || CV_IMAGE_ELEM(timg,unsigned char,it->y,it->x-1)==255 ||
                CV_IMAGE_ELEM(timg,unsigned char,it->y+1,it->x)==255 || CV_IMAGE_ELEM(timg,unsigned char,it->y-1,it->x)==255) )
            {
                bool bye= false;
                int p=0; // right pixel first
                // pixels to ignore
                vector<unsigned int> ignoreme;
                // ignore center pixel
                ignoreme.push_back(timg->width*it->y+it->x);
                for(int k=0;k<8;k++) ignoreme.push_back(timg->width*(it->y+dy[k])+it->x+dx[k]); // ignore all neighbours

                while(!bye)
                {
                    if(CV_IMAGE_ELEM(timg,unsigned char,it->y+dy[p],it->x+dx[p])==255)
                    {
                        int cpt=0;
                        for(int k=0;k<8;k++)
                        {
                            if(find(ignoreme.begin(),ignoreme.end(),timg->width*(it->y+dy[p]+dy[k])+it->x+dx[p]+dx[k])==ignoreme.end()) // not in the ignore list
                            {
                                if(ctypes[timg->width*(it->y+dy[k]+dy[p])+it->x+dx[k]+dx[p]]=='j' || ctypes[timg->width*(it->y+dy[k]+dy[p])+it->x+dx[k]+dx[p]]=='f') break;
                                else cpt++;
                            }
                        }
                        if(cpt==3) // all 3 neighbouring pixels are regular
                        {
                            CV_IMAGE_ELEM(timg,unsigned char,it->y+dy[p],it->x+dx[p])=0;
                            bye=true;
                        }
                    }
                    p+=2;
                    if(p>6) bye=true;
                }
            }

            // delete pixel
            CV_IMAGE_ELEM(timg,unsigned char,it->y,it->x)=0;
            BPoints.push_back(*it);
            // remove from list
            tBPoints.erase(it--);
        }

    // 作業用のImageデータ: clone image
    IplImage *tmp = cvCloneImage( timg );

    // update 8-neighor type of each pixel point
    Set_Ctypes( timg, ctypes);
    // contour points
    contours_t all_edges;
    // trace
    Trace( timg, all_edges, ctypes );

    // fill surroundings with 1s
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(1) );
    // inner borders pixels set to 128
    for( int y=1; y<timg->height-1; y++ )
        for( int x=1; x<timg->width-1; x++ )
        {
            // if border pixel
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x )==255 )
            {
                // iterate on neighbourhood
                for( int k=0; k<8; k++)
                {
                    // if background pixel
                    if( CV_IMAGE_ELEM( timg, unsigned char, y+dy[k], x+dx[k] )==0 )
                    {
                        CV_IMAGE_ELEM( timg, unsigned char, y, x ) = 128;
                        break;
                    }
                }
            }
        }

    // delete borders not attached to the inner part
    for( int i=0; i<all_edges.size(); i++ )
    {
        points_t pts = all_edges[i];
        int fx = pts.front().x, fy = pts.front().y, bx = pts.back().x, by = pts.back().y;
        // both extremities are border pixels
        if( CV_IMAGE_ELEM(timg,unsigned char,fy,fx)==255 && CV_IMAGE_ELEM(timg,unsigned char,by,bx)==255 )
            for( int j=1; j<pts.size()-1; j++) // delete the edge pixels but keep the vertices
                CV_IMAGE_ELEM( tmp, unsigned char, pts[j].y, pts[j].x ) = 0;
    }

    // copy image tmp-> timg
    cvCopy(tmp,timg);
    // update ctypes
    Set_Ctypes( timg, ctypes);

    // remove junctional pixels that became edge pixels (mod yuki)
    for(vector<CvPoint>::iterator it=tBPoints.begin();it!=tBPoints.end();it++)
        if( ctypes[timg->width*it->y+it->x]=='e' )
        {
            CV_IMAGE_ELEM(timg,unsigned char,it->y,it->x)=0;
            BPoints.push_back(*it);
            tBPoints.erase(it--);
        }

     // update ctypes
    Set_Ctypes( timg, ctypes);

    // remove pixels of type 'd'
    for( int y=1; y<timg->height-1; y++ )
        for( int x=1; x<timg->width-1; x++ )
            if( ctypes[timg->width*y+x] == 'd' ) CV_IMAGE_ELEM(timg,unsigned char,y,x)=0;

    // clear timg
    utlDelete_Extra_Edges( timg );

    // free image
    cvReleaseImage ( &tmp );
    // deallocate memory
    delete[] ctypes;
    delete[] ctypes0;
}


/***
    境界部の枝を刈り取る関数
    @param timg a pointer to the seg image
    ***/
void utlRemoveBoundaryEdges( IplImage *timg )
{
    int dx[8] = {1, 1, 0, -1, -1, -1, 0, 1}, dy[8] = {0, -1, -1, -1, 0, 1, 1, 1};
    int W=timg->width, H=timg->height;

    // dynamic allocation of ctypes
    char *ctypes= new char[W*H];

    int k;

    // Delete all the image periphery for convenience
    for( int y=0; y<timg->height; y++ )
    {
        CV_IMAGE_ELEM( timg, unsigned char, y, 0 ) = 0;
        CV_IMAGE_ELEM( timg, unsigned char, y, timg->width-1 ) = 0;
    }

    for( int x=0; x<timg->width; x++ )
    {
        CV_IMAGE_ELEM( timg, unsigned char, 0, x ) = 0;
        CV_IMAGE_ELEM( timg, unsigned char, timg->height-1, x ) = 0;
    }

    // set 8-neighor type of each pixel point
    Set_Ctypes( timg, ctypes );

    // make surroundings as '1'
    //  cvFloodFill( timg, cvPoint(0,0), cvRealScalar(1), cvScalarAll(0), cvScalarAll(0), &comp, 4 );
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(1) );

    //判定して削る
    for( int y=1; y<timg->height-1; y++ )
        for( int x=1; x<timg->width-1; x++ )
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x )==255 )
            {
                bool bflag = false;
                for( k=0; k<8; k++)
                    if( CV_IMAGE_ELEM( timg, unsigned char, y+dy[k], x+dx[k] ) == 1 )
                    {
                //	    if( connect_num8( timg, x, y ) == 3 改良の余地有り
                        bflag = true;
                        break;
                    }
                if( bflag )
                {
                    if(ctypes[timg->width*y+x] == 'e' ) CV_IMAGE_ELEM( timg, unsigned char, y, x ) = 0;
                    else CV_IMAGE_ELEM( timg, unsigned char, y, x ) = 2;
                }
            }

    // 孤立点をもどす
    for( int y=1; y<timg->height-1; y++ )
        for( int x=1; x<timg->width-1; x++ )
            if( CV_IMAGE_ELEM( timg, unsigned char, y, x )==2 )
            {
                bool bflag = false;
                for( k=0; k<8; k++ )
                    if( CV_IMAGE_ELEM( timg, unsigned char, y+dy[k], x+dx[k] ) == 255 )
                    {
                        bflag = true;
                        break;
                    }

                if(bflag) CV_IMAGE_ELEM( timg, unsigned char, y, x )=255;
                else CV_IMAGE_ELEM( timg, unsigned char, y, x )=0;
            }

    //外周部をもどす
    cvFloodFill( timg, cvPoint(0,0), cvRealScalar(0) );

    // deallocate memory
    delete[] ctypes;
}


/***
    外にある分岐した余分な枝を消す
    (Remove the extra branch that branches located outside)
    @param timg a pointer to the seg image
    ***/
void utlDelete_Extra_Edges( IplImage *timg )
{
    // 作業用のImageデータ
    IplImage *tmp = cvCloneImage( timg );
    // neighbourhood iterator
    int dx[8] = {-1,0,1,-1,1,-1,0,1}, dy[8] = {-1,-1,-1,0,0,1,1,1};
    // cvFloodFillに用いる
    CvConnectedComp comp;
    contours_t all_edges;
    contours_t int_edges;

    cout<<"## Trace start in utlDelete_Extra_Edges"<<endl;
    // trace
    Trace( timg, all_edges );
    cout<<"## .. Trace finised in utlDelete_Extra_Edges"<<endl;

    cvFloodFill( tmp, cvPoint(0,0), cvRealScalar(28), cvScalarAll(0), cvScalarAll(0), &comp, 4 );

    for( int i=0; i<(int)all_edges.size(); i++)
    {
        points_t pts = all_edges[i];
        bool flag = false;
        // extremities coordinates
        int fx = pts.front().x, fy = pts.front().y, bx=pts.back().x, by = pts.back().y;

        for( int k=0; k<8; k++ )
        {
            if( CV_IMAGE_ELEM(tmp,unsigned char,fy+dy[k],fx+dx[k])==0 )
            {
                flag=true;
                break;
            }
        }

        if(!flag)
        {
            for( int k=0; k<8; k++ )
            {
                if( CV_IMAGE_ELEM(tmp,unsigned char,by+dy[k],bx+dx[k])==0 )
                {
                    flag=true;
                    break;
                }
            }
        }
        // 残すedge
        if(flag) int_edges.push_back(pts);
    }

    // reset
    cvZero(timg);

    for( int i=0; i<(int)int_edges.size(); i++)
    {
        points_t pts = int_edges[i];
        for( int j=0; j<(int)pts.size(); j++)
            CV_IMAGE_ELEM( timg, unsigned char, pts[j].y, pts[j].x ) = (char)255;
    }
    // free image
    cvReleaseImage ( &tmp );
}

// unused
#if 0
// ２値化データを出力
void utlOutputBinaryImage( FILE *fp, IplImage *oimg )
{
  for( int y=1; y<oimg->height-1; y++ ){
    for( int x=1; x<oimg->width-1; x++ ){
      if( CV_IMAGE_ELEM( oimg, unsigned char, y, x ) == 255 ){
		printf("%d %d\n",x,-y); // Opencvでのyは下向きが正
      }
    }
  }
}
#endif


/***
    色分けして各細胞領域にID をつける
    細胞の大きさがsmallC以下の時警告, small_C=0の時警告なし
    @param timg a pointer to the seg image
    @param CellID the array of cell id to fill
    @param smallC the minimal cell size
    @return the number of cells?
***/
int utlSet_CellID( IplImage *timg, int *CellID, int smallC )
{
     // offsetに注意
    int cell_num = 1;
    // Width & Height
    int W=timg->width, H=timg->height;
    // temp image
    IplImage* tpimg = cvCreateImage( cvGetSize(timg), 8, 3 );
    cvZero( tpimg ); // init with zeros

    // temp component
    CvConnectedComp comp;
    // gray
    const int gray=128;

    // copy inverted timg in the Blue channel
    for(unsigned int y=0; y<timg->height; y++ )
    {
        for(unsigned int x=0; x<timg->width; x++)
        {
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3   ) = 0;
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3+1 ) = 0;
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3+2 ) = 255-CV_IMAGE_ELEM( timg, unsigned char, y, x );
        }
    }

    for(unsigned int y=0; y<H; y++ )
    {
        for(unsigned int x=0; x<W; x++ )
        {
            if( CV_IMAGE_ELEM(tpimg,unsigned char, y, x*3+2 ) == (unsigned char)255 )
            {
                CvScalar color = cvScalar( cell_num%255, cell_num/255, gray );
                cvFloodFill( tpimg, cvPoint(x,y), color, cvScalarAll(0), cvScalarAll(0), &comp, 4 );
                if( smallC>0 && comp.area<smallC ) fprintf(stderr,"!!! Area Smaler than %f around  (%d %d)\n",comp.area,x,y );
                cell_num++;
            }
        }
    }

    for( int id=0; id<W*H; id++ )
    {
        int r = (int)CV_IMAGE_ELEM( tpimg, unsigned char, id/W, (id%W)*3 );
        int b = (int)CV_IMAGE_ELEM( tpimg, unsigned char, id/W, (id%W)*3+1 );
        CellID[id] = r + 255*b;
    }

    // release image
    cvReleaseImage ( &tpimg );

    return cell_num-2;
}

/***
    @param timg a pointer to the seg image
    @param CellID the array of cell id to fill
    @param smallC the minimal cell size
    @param the cellid->area map to fill
    @return the number of cells?
    ***/
int utlSet_CellID( IplImage *timg, int *CellID, int smallC ,map<int,double>& area)
{
 // offsetに注意
    int cell_num = 1;
    // Width & Height
    int W=timg->width, H=timg->height;
    // temp image
    IplImage* tpimg = cvCreateImage( cvGetSize(timg), 8, 3 );
    cvZero( tpimg ); // init with zeros

    // temp component
    CvConnectedComp comp;
    // gray
    const int gray=128;

    // copy inverted timg in the Blue channel
    for(unsigned int y=0; y<timg->height; y++ )
    {
        for(unsigned int x=0; x<timg->width; x++)
        {
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3   ) = 0;
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3+1 ) = 0;
            CV_IMAGE_ELEM( tpimg, unsigned char, y, x*3+2 ) = 255-CV_IMAGE_ELEM( timg, unsigned char, y, x );
        }
    }

    for(unsigned int y=0; y<H; y++ )
    {
        for(unsigned int x=0; x<W; x++ )
        {
            if( CV_IMAGE_ELEM(tpimg,unsigned char, y, x*3+2 ) == (unsigned char)255 )
            {
                CvScalar color = cvScalar( cell_num%255, cell_num/255, gray );
                cvFloodFill( tpimg, cvPoint(x,y), color, cvScalarAll(0), cvScalarAll(0), &comp, 4 );
                if( smallC>0 && comp.area<smallC ) fprintf(stderr,"!!! Area Smaler than %f around  (%d %d)\n",comp.area,x,y );
                area[cell_num]=comp.area;
                cell_num++;
            }
        }
    }

    for( int id=0; id<W*H; id++ )
    {
        int r = (int)CV_IMAGE_ELEM( tpimg, unsigned char, id/W, (id%W)*3 );
        int b = (int)CV_IMAGE_ELEM( tpimg, unsigned char, id/W, (id%W)*3+1 );
        CellID[id] = r + 255*b;
    }

    // release image
    cvReleaseImage ( &tpimg );

    return cell_num-2;
}
// end of file
