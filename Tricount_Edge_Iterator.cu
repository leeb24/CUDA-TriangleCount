#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <ctime>
#include <cstdint>
#include <thrust/reduce.h>
#include <cuda.h>
using namespace std;


__device__ int binarySearch(int* arr, int l, int r, int x)
    {

         while (l <= r)
        {
        int m = (l+r)/2;
 
        
        if (arr[m] == x)
            return m;
 
        
        if (arr[m] < x)
            l = m + 1;
 
        
        else
            r = m - 1;
        }
 

    return -1;
    }

/*__device__ int index; 

__global__ void arrfind(int* adjlist, int start , int end,int entries,int find)
{
  int threadID = blockIdx.x * blockDim.x + threadIdx.x;

  if(threadID  < entries)
  {

     if( adjlist[threadID] == find )
    {
      index = threadID;
    }


  }
}*/


__global__ void Tricount(int* beginposition , int* adjlist ,int* d_counts,int* adjver ,int vertices , int entries)
{
	
	int adjindex = blockIdx.x * blockDim.x + threadIdx.x;
	
  //int vertex =0 ;

  // INDENTIFY WHICH VERTEX THE THREAD IS 
  
	if( adjindex < entries )
	{	

    int vertex1 = adjlist[adjindex];

    int sizeofarray1 = beginposition[ vertex1+1 ]-beginposition[ vertex1 ];

    if( adjlist[adjindex]+1 == vertices)
    {
        sizeofarray1 = entries-beginposition[vertex1];
    }


    int vertex2 = adjver[adjindex];

    int sizeofarray2 = beginposition[vertex2+1]-beginposition[vertex2];

    if( vertex2+1 == vertices)
    {
        sizeofarray2 = entries-beginposition[vertex2];
    }

    int posofelement = beginposition[ adjlist[adjindex] ] ;

    for(int i = 0 ; i  < sizeofarray1 ; i++)
    {

      int find = adjlist[ posofelement + i ];

      int result = binarySearch (adjlist ,beginposition[vertex2] , beginposition[vertex2] + sizeofarray2 - 1 ,find);

      if(result != -1)
      {
        //printf("found an triangle with vertex %d and vertex %d with vertex %d \n",adjlist[adjindex],vertex2,find);
        d_counts[adjindex] = d_counts[adjindex] + 1;
      }

    }


  }

}


int mmioread(int* adjlist , int* beginposition) {
  string line;
  string file1 = "facebook_combined_adj.tsv";
  ifstream myfile (file1);

  cout << endl;
  cout  << " reading " << file1 << " ... " <<endl;
  cout <<endl;
  long linecount =0;
   // 0 - adjlist 1 - vertex 2 - N/A 
  
  beginposition[0] = 0;
  long adjlistpos = 0;
  long beginlistpos = 1;

  long prevnum = 0;
  if (myfile.is_open())
  {
    while ( getline (myfile,line) )
    { 
	  istringstream buf(line);

      
      		long type =0;
          for(string word; buf >> word; )
          {	
          	
            if( type == 0 ) // add adjlist
            {
                adjlist[adjlistpos] = stoi(word);
                adjlistpos++;   
                type++; 
            }

            else if( type == 1 ) // add begin pos
            {   

                if(prevnum != stoi(word) )
                {
                	if (prevnum+1 != stoi(word) )
            		{	
                  //printf("now is %d but before was %d\n",stoi(word),prevnum );
            			for(int a = 0 ; a <stoi(word)-prevnum-1 ; a++)
            			{
            				beginposition[beginlistpos] = adjlistpos-1;
                    //printf("IN \n" );
                    //printf("putting %d at beginpos %d\n",int(adjlistpos-1),int(beginlistpos));
            				beginlistpos++;
            			}
                  
            			
            		}	
                  
                  beginposition[beginlistpos] = adjlistpos-1;

                  beginlistpos++;

                  prevnum = stoi(word);
                }

                type++;
            }
            else if (type == 2)
            	type++;

           	

          	//forcount++;

          }
        
      
      linecount++;
    }
    myfile.close();
  }

  else cout << "Unable to open file"; 

  return 1;
};


int main(){

int vertices = 4040;
int entries = 176468;

int* h_beginposition= new int[vertices];
int* h_adjlist= new int[entries];
int* h_adjvertex= new int[entries];
int* h_count = new int [entries];
//h_count=(int *) malloc(1*sizeof(int));

int* d_begin;
int* d_adj;
int* d_counts;
int* d_adjvertex;

cout <<"Converting MMIO to array form..." <<endl;

clock_t startTime = clock();

mmioread(h_adjlist,h_beginposition);

int pos =0;

for(int x = 1 ; x < vertices ; x++)
{
  int size = h_beginposition[x+1] - h_beginposition[x];
  //printf("%d \n ",size);
  if(x+1 == vertices)
    size = entries-h_beginposition[x];


  for(int y = 0 ; y < size ; y++)
  {
    h_adjvertex[pos] = x;
    pos++;
  }
}

//printf("pos is %d is  %d \n",h_adjlist[718264] ,h_adjvertex[718264]);

//printf("last is %d \n", h_beginposition[4]);
/*
printf("adjlist consist of");
for(int a = 0 ; a < entries ; a++)
	printf(" %d ", h_adjlist[a]);

printf("\n");

printf("bp consist of");
for(int a = 0 ; a < vertices ; a++)
	printf(" %d ", h_beginposition[a]);

printf("\n");*/

double secondsPassed = (clock() - startTime) / CLOCKS_PER_SEC;

cout <<"Transform complete : "<< secondsPassed << " seconds have passed" << endl;

cout <<"Allocating space on GPU and transfer data..."<< endl;
cudaMalloc(&d_begin, vertices*sizeof(int)); 
cudaMalloc(&d_adj, entries*sizeof(int));
cudaMalloc(&d_adjvertex, entries*sizeof(int));  
cudaMalloc((void**)&d_counts, entries*sizeof(int));

//cudaMemset((void*)d_counts,0,10*sizeof(int));

cudaMemcpy(d_begin, h_beginposition, vertices*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_adj, h_adjlist, entries*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_adjvertex, h_adjvertex, entries*sizeof(int), cudaMemcpyHostToDevice);


int blocks = (entries/1024)+1;

cout << "Now counting Triangles" <<endl;

Tricount<<<blocks, 1024>>>(d_begin,d_adj,d_counts,d_adjvertex,vertices,entries);

cudaMemcpy(h_count,d_counts,entries*sizeof(int),cudaMemcpyDeviceToHost);
cout << "Done..." <<endl; 
cout << "Done with MEMCOPY...Now counting" <<endl;

int result = thrust::reduce(h_count, h_count+ entries);
 
printf("answer : %d \n",result/6);




cudaFree(d_begin);

cudaFree(d_adj);

cudaFree(d_counts);
//cudaDeviceReset();

//3686467

}
