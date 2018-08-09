#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <ctime>
#include <cstdint>
#include <algorithm>
#include <thrust/sort.h>
#include <thrust/functional.h>
#include <thrust/reduce.h>
#include <thrust/host_vector.h>
#include <thrust/device_vector.h>
#include <cuda.h>
using namespace std;


struct node
{
  public:

    int VertexID;
    int Degree;
    int part;
    int* adj= new int[200364];
    int* d_adj;
    node()
    {
      cudaMalloc(&d_adj,200364*sizeof(int));
    }
    void sendGPU()
    {
      cudaMemcpy(d_adj,adj,200364*sizeof(int),cudaMemcpyHostToDevice);
    }
    
};

__device__ __host__ bool cmp(const node node1 ,const node node2)
{
  if(node1.VertexID != node2.VertexID)
    return node1.Degree > node2.Degree;
}

__device__ __host__ bool cmp2(const node node1 ,const node node2)
{
    return node1.VertexID < node2.VertexID;
}


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



__global__ void Tricount2(int* beginposition , int* adjlist ,int* d_counts,int* adjver ,int vertices , int entries , int* degree_array, int* d_partition)
{
  
  int adjindex = blockIdx.x * blockDim.x + threadIdx.x;
  
  ///SECOND PARTITION

  // INDENTIFY WHICH VERTEX THE THREAD IS 
  
  if( adjindex < entries  && adjindex >= (entries/2) + 1 )
  { 

    int vertex1 = adjlist[adjindex];

    if (d_partition[vertex1] == 2)
    {
        int sizeofarray1 = degree_array[vertex1];


        int vertex2 = adjver[adjindex];
        if(d_partition[vertex2] == 2)
        {
          int sizeofarray2 = degree_array[vertex2];

        
          int posofelement = beginposition[ vertex1 ] ;

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
    //
  }

}

//FIRST PARTITION 

__global__ void Tricount(int* beginposition , int* adjlist ,int* d_counts,int* adjver ,int vertices , int entries,int* degree_array,int* d_partition)
{
	
	int adjindex = blockIdx.x * blockDim.x + threadIdx.x;
	
  //int vertex =0 ;

  // INDENTIFY WHICH VERTEX THE THREAD IS 
  
	if( adjindex < entries  && adjindex < (entries/2) + 1)
	{	
    //("In first Kernel\n");
    int vertex1 = adjlist[adjindex];

    if (d_partition[vertex1] == 1) //
    {
        int sizeofarray1 = degree_array[vertex1];

        int vertex2 = adjver[adjindex];
        if(d_partition[vertex2] == 1)
        {
          int sizeofarray2 = degree_array[vertex2];

          int posofelement = beginposition[ vertex1 ] ;

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
    //
  }

}


int mmioread(int* adjlist , int* beginposition) {
  string line;
  string file1 = "email-Enron_adj.tsv";
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

int vertices = 36693;
int entries = 367662;

int* h_beginposition= new int[vertices];
int* h_adjlist= new int[entries];
int* h_adjvertex= new int[entries];
int* h_count = new int [entries];
int* h_count2 = new int[entries];
int* h_degrees = new int [vertices];
int* h_partition = new int [entries];
//h_count=(int *) malloc(1*sizeof(int));

int* d_begin;
int* d_adj;
int* d_counts;
int* d_counts2;
int* d_adjvertex;
int* d_degrees;
int* d_partition;

cout <<"Converting MMIO to array form..." <<endl;

clock_t startTime = clock();

cout << "hi" <<endl;

mmioread(h_adjlist,h_beginposition);

cout<< "BP before " << h_adjlist[ h_beginposition[10000]] << endl;

cout << "BP IS " << h_beginposition[10000] << endl;
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

//*************************************************************************************************************

int k = 0;

node* node_degree = new node[vertices];



for(int i = 1 ; i < vertices ; i++)
{
  int sizeofarray1 = h_beginposition[ i+1 ]- h_beginposition[ i ];

  for(int j  = 0 ; j < sizeofarray1 ; j++)
  {
      node_degree[i].adj[k] = h_adjlist[ h_beginposition[i] + j ];
      k++;
  }

  k=0;
  node_degree[i].VertexID = i;
  node_degree[i].Degree = sizeofarray1;
  
}

//size of each vertex degrees ( sizeof variable )

for(int i = 0 ; i < vertices ; i++)
{
  h_degrees[i] = node_degree[i].Degree; // in order with 1.2.3. Vertex ID  
}


std::sort( node_degree , node_degree + vertices ,cmp );//  Descending order sort 


//************************REBUILD ADJLIST AND OTHER DEPENDENCIES ***************************

int adjpos = 0;
for(int i = 1; i < vertices ; i++ )
{
  int degrees = node_degree[i].Degree;
  int nodepos = 0;

  h_beginposition[node_degree[i].VertexID] = adjpos;// Where it starts on the adjlist

  while(degrees > nodepos)
  {
    h_adjlist[adjpos] = node_degree[i].adj[nodepos]; //sorted adjlist 

    h_adjvertex[adjpos] = node_degree[i].VertexID; // sorted connected vertex 

    nodepos++;
    adjpos++;
  }

  nodepos = 0;
}


// partition array 

node_degree[0].part = 0;
for(int i = 1 ; i < (vertices/2)+1 ; i++)
{
  node_degree[i].part = 1;
}
for (int i = (vertices/2)+1 ; i < vertices ; i++)
{
  node_degree[i].part = 2;
}

std::sort( node_degree , node_degree + vertices , cmp2 ); //sort by vertex id 



for (int i = 0; i < vertices; i++)
{
  h_partition[i] = node_degree[i].part;
}


/*for (int i = 0; i <100 ; i++)
{
  cout << node_degree[i].part <<endl;
}*/


cout << "im here"<<endl;

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

cout<< "BP after " << h_adjlist[ h_beginposition[10000]] << endl;

cout << "BP IS 2" << h_beginposition[10000] << endl;

double secondsPassed = (clock() - startTime) / CLOCKS_PER_SEC;

cout <<"Transform complete : "<< secondsPassed << " seconds have passed" << endl;

cout <<"Allocating space on GPU and transfer data..."<< endl;
cudaMalloc(&d_begin, vertices*sizeof(int)); 
cudaMalloc(&d_adj, entries*sizeof(int));
cudaMalloc(&d_adjvertex, entries*sizeof(int));  
cudaMalloc((void**)&d_counts, entries*sizeof(int));
cudaMalloc((void**)&d_counts2, entries*sizeof(int));
cudaMalloc(&d_degrees,vertices*sizeof(int));
cudaMalloc(&d_partition, entries*sizeof(int));


cudaMemcpy(d_begin, h_beginposition, vertices*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_adj, h_adjlist, entries*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_adjvertex, h_adjvertex, entries*sizeof(int), cudaMemcpyHostToDevice);
cudaMemcpy(d_degrees,h_degrees,vertices*sizeof(int),cudaMemcpyHostToDevice);
cudaMemcpy(d_partition,h_partition,entries*sizeof(int),cudaMemcpyHostToDevice);


int blocks = (entries/1024)+1;

cout << "Now counting Triangles" <<endl;

Tricount<<<blocks, 1024>>>(d_begin,d_adj,d_counts,d_adjvertex,vertices,entries,d_degrees,d_partition);
Tricount2<<<blocks, 1024>>>(d_begin,d_adj,d_counts2,d_adjvertex,vertices,entries,d_degrees,d_partition);

cudaMemcpy(h_count,d_counts,entries*sizeof(int),cudaMemcpyDeviceToHost);
cudaMemcpy(h_count2,d_counts2,entries*sizeof(int),cudaMemcpyDeviceToHost);
cout << "Done..." <<endl; 
cout << "Done with MEMCOPY...Now counting" <<endl;

int result = thrust::reduce(h_count, h_count+ entries);
int result2 = thrust::reduce(h_count2, h_count2+ entries);
 
printf("answer1 : %d \n",result/6);
printf("answer2 ; %d \n",result2/6);

printf("total is : %d \n", (result+result2)/6);



cudaFree(d_begin);

cudaFree(d_adj);

cudaFree(d_counts);

cudaFree(d_counts2);
//cudaDeviceReset();

//3686467

}
