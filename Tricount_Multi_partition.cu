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


__global__ void Tricount(int* beginposition , int* graphpartition , int* d_counts , int* adjver , int vertices , int entries,int partitionvertex,int partitionedge,int* adjlist,int part)
{
	
	int thread = blockIdx.x * blockDim.x + threadIdx.x;

  if(thread < partitionedge ) // limit thread to how many edges 
  {

      
    	if( part ==2 ) //SECOND PARTITON
    	{

    		if(graphpartition[thread] > partitionvertex ) // if the first vertex is whithin the partition (POSSUIBEL ERROR)
    		{
    			int vertex1 = graphpartition[thread];

    			int sizeofarray1 = beginposition[ vertex1+1 ]- beginposition[ vertex1 ];

      		if( graphpartition[thread]+1 == vertices) //vertices has to be changed too
      		{
          			sizeofarray1 = entries-beginposition[vertex1];
      		}

      		int vertex2 = adjver[thread];

      		int sizeofarray2 = beginposition[ vertex2+1 ]-beginposition[ vertex2 ];

      		if( vertex2+1 == vertices)
      		{
          		sizeofarray2 = entries-beginposition[vertex2];
      		}

      		int posofelement = beginposition[vertex1];

    			for(int i = 0 ; i  < sizeofarray1 ; i++)
        	{

      			int find = graphpartition[ posofelement + i ];

      			int result = binarySearch (adjlist ,beginposition[vertex2] , beginposition[vertex2] + sizeofarray2 - 1 ,find);

      			if(result != -1)
      			{
        			//printf("found an triangle with vertex %d and vertex %d with vertex %d \n",adjlist[adjindex],vertex2,find);
        			d_counts[thread] = d_counts[thread] + 1;
              //printf("I found a triangle");
          	}

        	}
    		}

    		
    	}



    	else //FIRST PARTITION
    	{
        
    		if(graphpartition[thread] <= partitionvertex ) // if the first vertex is whithin the partition
    		{ 
    			int vertex1 = graphpartition[thread];

        
    			int sizeofarray1 = beginposition[ vertex1+1 ]- beginposition[ vertex1 ];

      		if( graphpartition[thread]+1 == partitionvertex +1) //vertices has to be changed too
      		{
          			sizeofarray1 = entries-beginposition[vertex1];
      		}

      		int vertex2 = adjver[thread];

      		int sizeofarray2 = beginposition[vertex2+1]-beginposition[vertex2];

      		if( vertex2+1 == partitionvertex +1)
      		{
          		sizeofarray2 = entries-beginposition[vertex2];
      		}

      		int posofelement = beginposition[vertex1];

    			for(int i = 0 ; i  < sizeofarray1 ; i++)
        	{

      			int find = graphpartition[ posofelement + i ];

      			int result = binarySearch (adjlist ,beginposition[vertex2] , beginposition[vertex2] + sizeofarray2 - 1 ,find);//adjust (Find Intersection)

      			if(result != -1)
      			{
        			//printf("found an triangle with vertex %d and vertex %d with vertex %d \n",adjlist[adjindex],vertex2,find);
        			d_counts[thread] = d_counts[thread] + 1;
              //printf("I found a triangle");
      			}

        	}
    		}

    	}

  }
	
}


int mmioread(int* adjlist , int* beginposition) {
  string line;
  string file1 = "amazon0312_adj.tsv";
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
            			for(int a = 0 ; a <stoi(word)-prevnum-1 ; a++) //Parsing Error Fix
            			{
            				beginposition[beginlistpos] = adjlistpos-1;
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

int vertices = 400728;
int entries = 4699738;

int* h_beginposition= new int[vertices];
int* h_adjlist= new int[entries];
int* h_adjvertex= new int[entries];
int* h_count = new int [entries];
int* h_count2 = new int [entries];

int* d_begin;
int* d_adj;
int* d_counts;
int* d_counts2;
int* d_adjvertex;

cout <<"Converting MMIO to array form..." <<endl;

clock_t startTime = clock();

mmioread(h_adjlist,h_beginposition);

int pos =0;

for(int x = 1 ; x < vertices ; x++)
{
  int size = h_beginposition[x+1] - h_beginposition[x];
  //printf("%d \n ",size);
  if( x+1 == vertices )
    size = entries-h_beginposition[x];


  for(int y = 0 ; y < size ; y++)
  {
    h_adjvertex[pos] = x;
    pos++;
  }
}

//*****************************************************************************************************

int partition = vertices/2;
cout << "partition vertex is : " << partition << endl;


int sizeofpart1 = h_beginposition[partition+1];
cout << "sizeof partion is : " << sizeofpart1 << endl;

int* h_graphpartition1 = new int[ sizeofpart1 ];
int* h_graphpartition2 = new int[ entries - sizeofpart1 ];

int* h_adjver1 = new int[h_beginposition[partition+1]];
int* h_adjver2 = new int[entries - sizeofpart1];
 
int* d_graphpartition1;
int* d_graphpartition2;
int* d_adjver1;
int* d_adjver2;

//*****************************************************************************************************
//PARTITION DATASETS 
//**************************************************************************************************

for(int i = 0 ; i < h_beginposition[partition+1] ; i++)
{
	 h_graphpartition1[i] = h_adjlist[i];
	 h_adjver1[i] = h_adjvertex[i];

}
for(int i = 0 ; i < entries - (h_beginposition[partition+1]) ; i++)
{
	 h_graphpartition2[i] = h_adjlist[ i + h_beginposition[partition+1] ];
	 h_adjver2[i] = h_adjvertex[ i + h_beginposition[partition+1] ];
}

cout <<"last is : " << h_graphpartition2[entries - (h_beginposition[partition+1])-1] <<endl;

int checkvertex = h_adjvertex[ h_beginposition[partition+1] -1 ]; //UPTO WHERE TO COPY BP

int* h_BP1 = new int[checkvertex+1]; 
int* h_BP2 = new int[ vertices ];


for(int i = 0 ; i < (checkvertex+1) ; i++)
{
	h_BP1[i] = h_beginposition[i];
}
for(int i =0 ; i < vertices-1 ; i++)
{	
	if(i>checkvertex)
		h_BP2[i] = h_beginposition[i]-h_beginposition[checkvertex+1]; //convert to partition
}
h_BP2[3] =0;
//********************************************************************************************************
//DEBUG SESSION 
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
//********************************************************************************************************
//MEMORY ALLOCATION ON DEVICE & MEMORY TRANSFER TO DEVICE

double secondsPassed = (clock() - startTime) / CLOCKS_PER_SEC;

cout <<"Transform complete : "<< secondsPassed << " seconds have passed" << endl;

cout <<"Allocating space on GPU and transfer data..."<< endl;

cout <<"index 2 value is " << h_graphpartition1[3]<<endl;

cudaMalloc(&d_begin, vertices*sizeof(int)); 
cudaMalloc(&d_adj, entries*sizeof(int));
//cudaMalloc(&d_adjvertex, entries*sizeof(int));  
cudaMalloc((void**)&d_counts, entries*sizeof(int));
cudaMalloc((void**)&d_counts2, entries*sizeof(int));

cudaMalloc(&d_graphpartition1,sizeofpart1*sizeof(int));
cudaMalloc(&d_graphpartition2,(entries-sizeofpart1)*sizeof(int));

cudaMalloc(&d_adjver1,sizeofpart1*sizeof(int));
cudaMalloc(&d_adjver2,(entries-sizeofpart1)*sizeof(int));
//cudaMemset((void*)d_counts,0,10*sizeof(int));

//**********************************************************************************************************************

cudaMemcpy(d_begin, h_beginposition, vertices*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_adj, h_adjlist, entries*sizeof(int), cudaMemcpyHostToDevice);
//cudaMemcpy(d_adjvertex, h_adjvertex, entries*sizeof(int), cudaMemcpyHostToDevice);

cudaMemcpy(d_graphpartition1,h_graphpartition1,sizeofpart1*sizeof(int),cudaMemcpyHostToDevice);
cudaMemcpy(d_graphpartition2,h_graphpartition2,(entries-sizeofpart1)*sizeof(int),cudaMemcpyHostToDevice);
cudaMemcpy(d_adjver1,h_adjver1,sizeofpart1*sizeof(int),cudaMemcpyHostToDevice);
cudaMemcpy(d_adjver2,h_adjver2,(entries-sizeofpart1)*sizeof(int),cudaMemcpyHostToDevice);
cudaMemcpy(d_counts2,h_count2,(entries-sizeofpart1)*sizeof(int),cudaMemcpyHostToDevice);

int blocks = (entries/1024)+1;
cout << "Now counting Triangles" <<endl;

Tricount<<<blocks, 1024>>>(d_begin ,d_graphpartition1 ,d_counts ,d_adjver1 ,vertices , entries,partition,sizeofpart1,d_adj,1);
Tricount<<<blocks, 1024>>>(d_begin ,d_graphpartition2 ,d_counts2 ,d_adjver2 ,vertices , entries,partition,sizeofpart1,d_adj,2);

cudaMemcpy(h_count,d_counts,entries*sizeof(int),cudaMemcpyDeviceToHost);
cudaMemcpy(h_count2,d_counts2,entries*sizeof(int),cudaMemcpyDeviceToHost);
cout << "Done..." <<endl; 
cout << "Done with MEMCOPY...Now counting" <<endl;

int result = thrust::reduce(h_count, h_count+ entries);
int result2 = thrust::reduce(h_count2, h_count2+ entries);
 
printf("First Partition Triangles >>>>> %d \n",result/6);
printf("Second Partition Triangles >>>>> %d \n",result2/6);

printf("Total number is %d\n",(result2+result)/6 );

cudaFree(d_begin);

cudaFree(d_adj);

cudaFree(d_counts);

cudaFree(d_graphpartition1);
cudaFree(d_graphpartition2);
cudaFree(d_adjver1);
cudaFree(d_adjver2);
//cudaDeviceReset();

//3686467

}
