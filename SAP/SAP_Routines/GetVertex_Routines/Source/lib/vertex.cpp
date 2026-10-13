/***************************************************************************

				  Vertesx化関連のプログラム

modified by 勇希 (yûki)
last update: 2013-01-23

***************************************************************************/

#include <iostream>
#include <fstream>
#include <highgui.h>

#include "vertex.h"
#include "openCV_util.h"

using namespace std;

/***
    number of boundary cells
    ***/
int vxSet_RNUM(vector<Junction> junc)
{
    int r_num=0;
    for(int i=0;i<(int)junc.size();i++) r_num+=(junc[i].inout=='o');
    return r_num;
}

//
// Junction
//

/***
    sort用の関数 (to be used to sort Junctions)
    ***/
static bool JInOut(const Junction &rLeft, const Junction &rRight)
{
    return rLeft.Cells.size() < rRight.Cells.size();
}

/***
    sort用の関数 (to be used to sort Edges)
    ***/
static bool EInOut(const Edge &rLeft, const Edge &rRight)
{
    return ( rLeft.inout=='o' && rRight.inout=='i' ?  true : false );
}

/***
    junc sort用の関数
    ***/
static vector<Junction> Set_Junction(IplImage *timg, char *ctypes, int *CellID)
{
    std::vector<Junction> vjuncs;
    Junction tjunc;
    // neighbourhood (近傍)
    int npb[8] = { -timg->width, -1, 1, timg->width, -timg->width-1, -timg->width+1, timg->width-1, timg->width+1 };

    // 交差点・分岐点または，端点の設定
    for( int y=1; y<timg->height-1; y++ )
    {
        for( int x=1; x<timg->width-1; x++ )
        {
            // pixel index
            int id = timg->width*y+x;
            if( ctypes[id]=='t' || ctypes[id]=='j' || ctypes[id]=='f' )
            {
                tjunc.Cells.clear();
                tjunc.x= x;
                tjunc.y= y;
                // iterate on neighbourhood
                for( int k=0; k<8; k++ )
                    if(CellID[id+npb[k]]!= 0 && CellID[id+npb[k]]!=1) tjunc.Cells.push_back( CellID[id+npb[k]] );
                // sort the cellIDs
                sort(tjunc.Cells.begin(), tjunc.Cells.end());
                // remove duplicate elements
                tjunc.Cells.erase(unique( tjunc.Cells.begin(), tjunc.Cells.end() ), tjunc.Cells.end());
                // set in/out
                tjunc.inout = (tjunc.Cells.size()==0 ? 'o':'i');
                // set ctype
                tjunc.ctype = ctypes[id];
                // add in the vector
                vjuncs.push_back(tjunc);
            }
        }//x
    }//y
    // sort the junctions (ソートする)
    sort( vjuncs.begin(), vjuncs.end(), JInOut );
    // set ids
    for(int i=0; i<(int)vjuncs.size() ; i++) vjuncs[i].id = i;

    return vjuncs;
}


/***
    edgeを設定するための関数
    ***/
static vector<Edge> Set_Edge(IplImage *timg, char *ctypes, contours_t conts, vector<Junction> &ijunc)
{
    std::vector<Edge> vedges;
    int W=timg->width, H=timg->height;

    // allocate memory
    int *JuncID= new int[W*H];

    // 各ピクセルからjunctionIDへの変換テーブルを作っておく
    for(int id=0; id<W*H; id++) JuncID[id]=-1;
    for(int j=0; j<ijunc.size(); j++) JuncID[(int)(ijunc[j].y*W+ijunc[j].x)]= ijunc[j].id;

    //  edgeの設定
    for( int i=0; i<(int)conts.size(); i++)
    {
        Edge tedge;
        std::vector<CvPoint> pts = conts[i];
        int fx=pts.front().x, fy=pts.front().y, bx=pts.back().x, by=pts.back().y;
        tedge.X[0] = pts.front();
        tedge.junction_id[0] = JuncID[fy*W+fx];
        tedge.X[1] = pts.back();
        tedge.junction_id[1] = JuncID[by*W+bx];
        tedge.inout = ( ctypes[fy*W+fx]=='t' ||  ctypes[by*W+bx]=='t' ? 'o' : 'i' );
        tedge.sdist = sqrt((fx-bx)*(fx-bx)+(fy-by)*(fy-by));
        //tedge.angle = atan2(-fy+by,fx-bx);  if( tedge.angle<0 )tedge.angle+=PI; // Opencvでのyは下向きが正
        tedge.angle = -atan2(fy-by,fx-bx);
        if( tedge.angle<0 )tedge.angle+=PI; // Opencvでのyは下向きが正
        tedge.line_pts = pts;
        vedges.push_back(tedge);
    }
    // ソートする // 順序が重要
    sort( vedges.begin(), vedges.end(), EInOut );
    // idをふる
    for(int i=0; i<vedges.size(); i++) vedges[i].id= i;

    // for check
    int jr_num = vxSet_RNUM(ijunc), er_num=0;
    for( int i=0; i<vedges.size(); i++ ) er_num+= (vedges[i].inout == 'o');
    assert( jr_num==er_num );

    //  端点をセット
    for( int i=0; i<vedges.size(); i++)
    {
        int sl=vedges[i].line_pts.size();
        vedges[i].X[0].x = vedges[i].line_pts[0].x;
        vedges[i].X[0].y = vedges[i].line_pts[0].y;
        vedges[i].X[1].x = vedges[i].line_pts[sl-1].x;
        vedges[i].X[1].y = vedges[i].line_pts[sl-1].y;
    }

    // deallocate memory
    delete[] JuncID;

    return vedges;
}


/***
    内部細胞の設定
    ***/
static void Set_InsideCells( vector<VCell> &vcells, vector<Junction> &ijunc, int cell_num )
{
    vector<VCell> wcells(cell_num);

    // junctionの隣接細胞. offsetに注意
    for( vector<Junction>::iterator it=ijunc.begin(); it!=ijunc.end(); it++ )
        for( vector<int>::iterator ij=it->Cells.begin(); ij!=it->Cells.end(); ij++ )
            wcells[(*ij)-2].JUNCTION.push_back(&*it);

    // 各細胞の重心を求める
    for( vector<VCell>::iterator it=wcells.begin(); it!=wcells.end(); it++ )
    {
        for( vector<Junction*>::iterator ij=it->JUNCTION.begin(); ij!=it->JUNCTION.end(); ij++ )
        {
            it->cx +=  (*ij)->x;
            it->cy += -(*ij)->y; /** yは反転して計算 **/
        }
        it->cx /= (double)it->JUNCTION.size();
        it->cy /= (double)it->JUNCTION.size();
    }

    //  角度を求めてsort
    for( vector<VCell>::iterator it=wcells.begin(); it!=wcells.end(); it++ )
    {
        vector<Junction*> wjunc = it->JUNCTION;
        double angles[it->JUNCTION.size()];

        for( int nj=0; nj<(int)wjunc.size(); nj++ )
        {
            double dx= wjunc[nj]->x - it->cx, dy= (-wjunc[nj]->y) - it->cy;
            angles[nj] = atan2(dy,dx);
        }

        for( int nj=0; nj<it->JUNCTION.size(); nj++ )
        {
            // find min angle
            int minid=nj;
            for( int nxj=nj+1; nxj<(int)it->JUNCTION.size(); nxj++ )
                if( angles[nxj]<angles[minid] ) minid = nxj;

            if( minid!=nj )
            {
                SWAP( double, angles[nj], angles[minid] );
                SWAP( Junction*, wjunc[nj], wjunc[minid] );
            }
        }
        it->JUNCTION = wjunc;
        it->inout = 'i';
    }

    for( int i=0; i<wcells.size(); i++ ) vcells.push_back(wcells[i]);
}


/***
    境界部細胞の設定
    ***/
static void Set_OutsideCells( vector<VCell> &vcells, vector<Junction> &ijunc )
{
    Junction *njunc;
    int pid,nid;

    for( int i=0; i<(int)ijunc.size(); i++)
    {
        VCell tcell;
        if( ijunc[i].inout=='o' )
        {
            tcell.inout = 'o';
            tcell.JUNCTION.push_back(&ijunc[i]);
            pid = ijunc[i].id;
            njunc = &ijunc[ijunc[i].nj[0]];

            do
            {
                tcell.JUNCTION.push_back(njunc);
                nid=0;
                while(njunc->nj[nid]!=pid) nid++;
                nid = ( nid!=njunc->nj_num-1 ? nid+1 : 0 );
                pid = njunc->id;
                njunc = &ijunc[ njunc->nj[nid] ];
            } while( njunc->inout != 'o' );
            tcell.JUNCTION.push_back(njunc);

            vcells.push_back(tcell);
        }
    }
}

/***
    junctionのnjuncを設定
    ***/
static void Set_NJuncs( vector<Junction> &ijunc, vector<Edge> &iedge )
{
    for( vector<Edge>::iterator ie=iedge.begin(); ie!=iedge.end(); ie++ )
    {
        int j0 = ie->junction_id[0], j1 = ie->junction_id[1];
        ijunc[j0].nj[ ijunc[j0].nj_num ] =j1;  ijunc[j0].nj_num++;
        ijunc[j1].nj[ ijunc[j1].nj_num ] =j0;  ijunc[j1].nj_num++;
    }

    // sort njunc[] by the angles
    for( vector<Junction>::iterator j=ijunc.begin(); j!=ijunc.end(); j++ )
    {
        double angles[4],dx,dy;
        for(int i=0; i<(j->nj_num); i++)
        {
            dx =  ijunc[ j->nj[i] ].x - (j->x);
            dy = -ijunc[ j->nj[i] ].y + (j->y); // reverse cordinate of y
            angles[i] = atan2(-dy,dx);
        }

        for(int i=0; i<(j->nj_num); i++ )
        {
            int mi = i;
            for( int ii=i+1; ii<(j->nj_num); ii++ )
                if( angles[mi] > angles[ii] ) mi= ii;

            SWAP( double, angles[i], angles[mi] );
            SWAP( int, j->nj[i], j->nj[mi] );
        }
    }
}

// unused
#if 0
// Areas and centroids of Polygon
void vxSet_vcell_center( VCell &e_cell)
{
    e_cell.area=0.0;
    e_cell.cx=0.0;
    e_cell.cy=0.0;

    for( int j=0; j<(int)e_cell.JUNCTION.size(); j++ )
    {
        int nj = (j!=(int)e_cell.JUNCTION.size()-1 ? j+1 : 0 );

        double x1,x2,y1,y2,tarea;
        x1 =  e_cell.JUNCTION[j]->x;
        x2 =  e_cell.JUNCTION[nj]->x;
        y1 = -e_cell.JUNCTION[j]->y;  // reverse corrdinate of y!
        y2 = -e_cell.JUNCTION[nj]->y; // reverse corrdinate of y!
        tarea = (x1*y2-x2*y1);

        e_cell.area += tarea/2;
        e_cell.cx += tarea*(x1+x2);
        e_cell.cy += tarea*(y1+y2);
    }
    e_cell.cx/=(6*e_cell.area);
    e_cell.cy/=(6*e_cell.area);
}

// Vcellのセット
vector<VCell> vxSet_Vertex( IplImage *timg, vector<Junction> &ijunc, vector<Edge> &iedge)
{
    assert( timg->nChannels==1 );
    int W=timg->width, H=timg->height;

    int *CellID=(int *)malloc(W*H*sizeof(int));
    //int CellID[W*H];

    //char ctypes[W*H];
    char *ctypes=(char *)malloc(W*H*sizeof(char));

    contours_t edge_conts;
    vector<VCell> vcells;
    VCell tcell;
    int cell_num;

    Set_Ctypes( timg, ctypes ); // 各ピクセルの8近傍タイプ
    Trace( timg, edge_conts, ctypes ); // edge_contsを取得

    // set CellID
    const int small_cell_threshold = 3; // この値以下の領域があれば警告。0の時警告なし。
    cell_num = utlSet_CellID( timg, CellID, small_cell_threshold );

    // set Junction
    ijunc = Set_Junction( timg, ctypes, CellID );

    // set edge
    iedge = Set_Edge( timg, ctypes, edge_conts, ijunc );

    {
    Set_NJuncs( ijunc, iedge );						//　準備
    Set_OutsideCells( vcells, ijunc );				// Outside Cellsをセット
    Set_InsideCells( vcells, ijunc, cell_num );     // Inside Cellsをセット

    for( int i=0; i<(int)vcells.size(); i++ ){ vcells[i].id=i; }

    //check cell area
    for( int i=0; i<(int)vcells.size(); i++){
      int jnum = (int)vcells[i].JUNCTION.size();
      double area=0.0;
      vcells[i].cx=0.0; vcells[i].cy=0.0;

      for( int j=0; j<(int)vcells[i].JUNCTION.size() -1; j++ ){
        area +=  vcells[i].JUNCTION[j]->x*(-vcells[i].JUNCTION[j+1]->y) - (-vcells[i].JUNCTION[j]->y)*vcells[i].JUNCTION[j+1]->x;
      }
      area +=  vcells[i].JUNCTION[jnum-1]->x*(-vcells[i].JUNCTION[0]->y) - (-vcells[i].JUNCTION[jnum-1]->y)*vcells[i].JUNCTION[0]->x;
      if( area<0.0 ){
        printf("ERROR:  negative area at cell %d, %c area= %f\n",i,vcells[i].inout, 0.5*area );
        exit(10);
      }
    }
    }
    // free memory
    free(CellID);
    free(ctypes);

    return vcells;
}

vector<VCell> vxSet_Vertex( IplImage *timg, vector<Junction> &ijunc, vector<Edge> &iedge , vector<CvPoint> BPoints)
{
    vector<VCell> vcells;
    vcells = vxSet_Vertex( timg, ijunc, iedge);
    //
    for( int i=0; i<(int)BPoints.size(); i++ )
    {
        int fx=BPoints[i].x, fy=BPoints[i].y;
        for( int k=0; k<(int)ijunc.size(); k++ )
        {
            if( abs(ijunc[k].x-fx) <=1 && abs(ijunc[k].y-fy) <=1 )
            {
                ijunc[k].x = fx;
                ijunc[k].y = fy;
                CV_IMAGE_ELEM( timg, unsigned char, fy, fx )=255;
                break;
            }
        }
    }
    return vcells;
}

#endif


/***
    Vcellのセット (void version)
    ***/
void vxSet_Vertex( IplImage *timg, vector<Junction> &ijunc, vector<Edge> &iedge,vector<VCell> &vcells)
{
    // only one channel
    assert(timg->nChannels==1);
    // Width & Height
    int W=timg->width, H=timg->height;
    // cell id array
    int *CellID=new int[W*H];
    // ctypes array
    char *ctypes=new char[W*H];

    contours_t edge_conts;

    // 各ピクセルの8近傍タイプ
    Set_Ctypes( timg, ctypes);
    // edge_contsを取得
    Trace( timg, edge_conts, ctypes );

    map<int,double> areas;

    // set CellID
    int cell_num = utlSet_CellID( timg, CellID, SMALL_CELL_THRESHOLD,areas);

    // set Junction
    ijunc = Set_Junction( timg, ctypes, CellID );
    // set edge
    iedge = Set_Edge( timg, ctypes, edge_conts, ijunc );

    //　準備
    Set_NJuncs( ijunc, iedge );
    // Outside Cellsをセット
    Set_OutsideCells( vcells, ijunc );
    // Inside Cellsをセット
    Set_InsideCells( vcells, ijunc, cell_num );

    for(unsigned int i=0; i<vcells.size(); i++ ) vcells[i].id=i;

    for(map<int,double>::iterator it=areas.begin();it!=areas.end();it++)
        if(it->second<0)
        {
            cerr<<"ERROR: negative area at cell "<<it->first<<endl;
            exit(EXIT_FAILURE);
        }

    for( int i=0; i<vcells.size(); i++)
    {
        int jnum = vcells[i].JUNCTION.size();
        double area=0.0;
        vcells[i].cx=0.0; vcells[i].cy=0.0;

        for( int j=0; j<(int)vcells[i].JUNCTION.size() -1; j++ )
            area+= vcells[i].JUNCTION[j]->x*(-vcells[i].JUNCTION[j+1]->y) - (-vcells[i].JUNCTION[j]->y)*vcells[i].JUNCTION[j+1]->x;

        area+= vcells[i].JUNCTION[jnum-1]->x*(-vcells[i].JUNCTION[0]->y) - (-vcells[i].JUNCTION[jnum-1]->y)*vcells[i].JUNCTION[0]->x;
        if( area<0.0 )
        {
            printf("ERROR:  negative area at cell %d, %c area= %f\n",i,vcells[i].inout, 0.5*area );

            for(unsigned int j=0;j<vcells[i].JUNCTION.size();j++)
                 cerr<<vcells[i].JUNCTION[j]->x<<" "<<vcells[i].JUNCTION[j]->y<<endl;

            exit(EXIT_FAILURE);
        }
    }

    // deallocate memory
    delete[] CellID;
    delete[] ctypes;
}

/***
    Set vertex
    ***/
void vxSet_Vertex( IplImage *timg, vector<Junction> &ijunc, vector<Edge> &iedge , vector<CvPoint> BPoints, vector<VCell> &vcells)
{
    vxSet_Vertex( timg, ijunc, iedge,vcells);
    //
    for( int i=0; i<(int)BPoints.size(); i++ )
    {
        int fx=BPoints[i].x, fy=BPoints[i].y;
        for( int k=0; k<(int)ijunc.size(); k++ )
            if( abs(ijunc[k].x-fx) <=1 && abs(ijunc[k].y-fy) <=1 )
            {
                ijunc[k].x = fx;
                ijunc[k].y = fy;
                CV_IMAGE_ELEM( timg, unsigned char, fy, fx )=255;
                break;
            }
    }
}

/***
    get Edges surrounding a cell
    ***/
void vxSetCel_Edge( vector<VCell> &vcell,vector<Edge> &vedge )
{
    for( int i=0; i<(int)vcell.size(); i++ )
    {
        vector <Junction*> ctj = vcell[i].JUNCTION;
        vcell[i].EDGE.clear();
        for( int j=0; j<(int)ctj.size(); j++ )
        {
            int jid = ctj[j]->id, njid;
            njid = ( j!=(int)ctj.size()-1 ? ctj[j+1]->id : ctj[0]->id );
            for( int k=0; k<(int)vedge.size(); k++)
                if( (vedge[k].junction_id[0]==jid && vedge[k].junction_id[1]==njid ) || (vedge[k].junction_id[1]==jid && vedge[k].junction_id[0]==njid ) )
                {
                    vcell[i].EDGE.push_back(&vedge[k]);
                    break;
                }
        }
    }
}


/*-------------------------------------------------------------------------------------*/


/***
    Check number consistency
    ***/
static bool check_numbers( int c_num, int e_num, int v_num, int ex_num, int f_num )
{
    int tv = v_num - 2*ex_num;
    int te = e_num - 2*ex_num;
    int tc = c_num - ex_num;

    cerr << " v= " << v_num << "  e= " << e_num << "  c= " << c_num << " ex_num = " << ex_num << endl;
    cerr << " 4-way junc. = " << f_num << endl;
    cerr << " v - 2*ex_num =  tv  =  " << tv << endl;
    cerr << " e - 2*ex_num =  te  =  " << te << endl;
    cerr << " c -   ex_num =  tc  =  " << tc << endl;
    cerr << " check..  3*tv + fwj = 2*te ?  " << 3*tv + f_num << " " << 2*te << endl;
    cerr << " check..  tv - te + tc == 1 ?  " << tv - te + tc << endl;

    if( 2*te == 3*tv + f_num && tv - te + tc == 1 ) return true;
    else return false;
}

/***
    Print Data in a file
    ***/
void vxOutputDatas(const char* filename, std::vector<Junction> ojunc, std::vector<Edge> oedge, std::vector<VCell> ocell)
{
    ofstream myfile(filename);

    int c_num = ocell.size();
    int e_num = oedge.size();
    int v_num = ojunc.size();
    int f_num = 0;
    int ex_num = 0;

    for( vector <Junction>::iterator ji=ojunc.begin(); ji!=ojunc.end(); ji++ )
        f_num += (ji->ctype == 'f');

    for( vector <VCell>::iterator ci=ocell.begin(); ci!=ocell.end(); ci++ )
        ex_num += (ci->inout == 'o');

    if( !check_numbers(c_num,e_num,v_num,ex_num,f_num) )
    {
        cerr<<"not consistent number of vertex, edges, and junctions.. "<<endl;
        exit(EXIT_FAILURE);
    }

    myfile << "### C_NUM " << c_num << endl;
    myfile << "###  IN_CNUM " << c_num-ex_num << endl;
    myfile << "###  EX_CNUM " << ex_num << endl;
    myfile << "### E_NUM " << e_num << endl;
    myfile << "###  IN_E_NUM " << e_num-ex_num << endl;
    myfile << "###  EX_E_NUM " << ex_num << endl;
    myfile << "### V_NUM " << v_num << endl;
    myfile << "###  IN_V_NUM " << v_num-ex_num << endl;
    myfile << "###  EX_V_NUM " << ex_num << endl;

    for( int i=0; i<(int)ojunc.size(); i++)
    {
        assert( ojunc[i].id == i );
        myfile<<"J["<<ojunc[i].id<<"] "<<(double)ojunc[i].x<<" "<<-(double)ojunc[i].y;
        if(ojunc[i].inout == 'o') myfile<<" Ext";
        myfile<<endl;
    }
    myfile<<endl;

    for( int i=0; i<(int)oedge.size(); i++)
    {
        myfile<<"E["<<oedge[i].id<<"] "<<oedge[i].junction_id[0]<<" "<<oedge[i].junction_id[1];
        if( oedge[i].inout == 'o' ) myfile<<" Ext";
        myfile<<endl;
    }
    myfile<<endl;

    for( int i=0; i<(int)ocell.size(); i++)
    {
        myfile<<"C["<<ocell[i].id<<"] "<<ocell[i].JUNCTION.size()<<" : ";

        for( int j=0; j<(int)ocell[i].JUNCTION.size(); j++)
            myfile<<ocell[i].JUNCTION[j]->id<<" ";

        if( oedge[i].inout == 'o' ) myfile<<" Ext";
        myfile<<endl;
    }
    myfile<<endl;
    myfile.close();
}

#if 0
// end of file

void vxOutputDatas( FILE *outfile, vector<Junction> ojunc, vector<Edge> oedge, vector<VCell> ocell )
{
  int c_num = ocell.size();
  int e_num = oedge.size();
  int v_num = ojunc.size();
  int f_num = 0;
  int ex_num = 0;

  for( vector <Junction>::iterator ji=ojunc.begin(); ji!=ojunc.end(); ji++ ){
    f_num += (ji->ctype == 'f');
  }

  for( vector <VCell>::iterator ci=ocell.begin(); ci!=ocell.end(); ci++ ){
    ex_num += (ci->inout == 'o');
  }

  if( !check_numbers(c_num,e_num,v_num,ex_num,f_num) ){
    ERRORR("not consistent number of vertex, edges, and junctions.. ");
  }

  cout << "### C_NUM " << c_num << endl;
  cout << "###  IN_CNUM " << c_num-ex_num << endl;
  cout << "###  EX_CNUM " << ex_num << endl;
  cout << "### E_NUM " << e_num << endl;
  cout << "###  IN_E_NUM " << e_num-ex_num << endl;
  cout << "###  EX_E_NUM " << ex_num << endl;
  cout << "### V_NUM " << v_num << endl;
  cout << "###  IN_V_NUM " << v_num-ex_num << endl;
  cout << "###  EX_V_NUM " << ex_num << endl;

  for( int i=0; i<(int)ojunc.size(); i++){
    assert( ojunc[i].id == i );
    printf("J[%d] %f %f ", ojunc[i].id, (double)ojunc[i].x, -(double)ojunc[i].y ); // Opencvでのyは下向きが正
    if( ojunc[i].inout == 'o' ) printf(" Ext" );
    printf("\n");
  }
  printf("\n");

  for( int i=0; i<(int)oedge.size(); i++){
    printf("E[%d] %d %d ", oedge[i].id, oedge[i].junction_id[0], oedge[i].junction_id[1] );
    if( oedge[i].inout == 'o' ) printf(" Ext" );
    printf("\n");
  }
  printf("\n");

  for( int i=0; i<(int)ocell.size(); i++){
    printf("C[%d] %d : ",ocell[i].id,(int)ocell[i].JUNCTION.size());
    for( int j=0; j<(int)ocell[i].JUNCTION.size(); j++){
      printf("%d ",ocell[i].JUNCTION[j]->id);
    }
    if( ocell[i].inout == 'o' ) printf(" Ext" );
    printf("\n");
  }
  printf("\n");

}


// Output of Vertex
void vxOutputGeometry( FILE *fp, int oe_num, vector<Edge> oedge )
{
  for( int i=0; i<oe_num; i++ ){
    double x0=oedge[i].X[0].x,  y0=-oedge[i].X[0].y; // Opencvでのyは下向きが正
    double x1=oedge[i].X[1].x,  y1=-oedge[i].X[1].y;
    printf("#%f \n",oedge[i].sdist);
    printf("%f %f \n%f %f\n\n",x0,y0,x1,y1);
  }
}


// Draw Polygon
void vxDraw_Polygon ( vector<Edge> edge, IplImage *src_img, char *outfile )
{
  CvPoint pt1,pt2;
  CvScalar rcolor;
  IplImage *vimg = 0;

  vimg = cvCreateImage( cvGetSize (src_img), IPL_DEPTH_8U, 3 );   // vimg を作る: データ型
  cvSetZero( vimg );
  rcolor = CV_RGB( 255,  0, 0 );
  for( vector<Edge>::iterator ei=edge.begin(); ei!=edge.end(); ei++ ){
    pt1 = ei->X[0];   pt2 = ei->X[1];
    cvLine (vimg, pt1, pt2, rcolor, 1, CV_AA, 0);
  }
  cvNamedWindow( "Vertex", 0 );
  cvShowImage( "Vertex", vimg );
  cvWaitKey();
  if( outfile != NULL ){  cvSaveImage( outfile, vimg ); }
  cvDestroyWindow( "Vertex" );
  cvReleaseImage( &vimg );
}

void vxDraw_Polygon ( vector<Edge> edge, IplImage *src_img )
{
  vxDraw_Polygon ( edge, src_img, NULL );
}

#endif
