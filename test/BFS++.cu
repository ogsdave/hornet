#include "cuStingerAlg/cuStingerAlg.cuh"    //cuStingerAlg
#include "cuStingerAlg/Queue/TwoLevelQueue.cuh"   //Queue
#include "cuStingerAlg/LoadBalancing/BinarySearch.cuh"
#include "cuStingerAlg/Operator++.cuh"      //Operator
#include <GraphIO/BFS.hpp>                  //BFS
#include <GraphIO/GraphStd.hpp>             //GraphStd
#include <Support/Device/Algorithm.cuh>     //cu::equal
#include <Support/Host/Timer.hpp>           //Timer

using dist_t = int;
const dist_t INF = std::numeric_limits<dist_t>::max();

int main(int argc, char* argv[]) {
    using namespace cu_stinger;
    using namespace cu_stinger_alg;
    using namespace timer;
    cudaSetDevice(1);
    vid_t bfs_source = 0;
    //--------------------------------------------------------------------------
    //////////////
    // HOST BFS //
    //////////////
    graph::GraphStd<vid_t, eoff_t> graph;
    graph.read(argv[1]);
    graph::BFS<vid_t, eoff_t> bfs(graph);
    bfs.run(bfs_source);

    auto h_distances = bfs.distances();
    //--------------------------------------------------------------------------
    /////////////////
    // DEVICE INIT //
    /////////////////
    cuStingerInit custinger_init(graph.nV(), graph.nE(),
                                 graph.out_offsets_array(),
                                 graph.out_edges_array());

    cuStinger custiger_graph(custinger_init);
    dist_t* d_distances;
    Allocate alloc(d_distances, graph.nV());
    //--------------------------------------------------------------------------
    //////////////
    // BFS INIT //
    //////////////
    forAllnumV( [=] __device__ (int i){ d_distances[i] = INF; } );
    cuMemcpyToDevice(0, d_distances + bfs_source);

    dist_t level = 1;
    TwoLevelQueue<vid_t> queue(graph.nV() * 2);
    queue.insert(bfs_source);

    auto extern_lambda = [=] __device__ (Vertex vertex, Edge edge, dist_t level1) {
                            dist_t dst = edge.dst();
                            if (d_distances[dst] == INF) {
                                d_distances[dst] = level1;
                                return true;
                            }
                            return false;
                        };

    Timer<DEVICE> TM;
    TM.start();
    //--------------------------------------------------------------------------
    ///////////////////
    // BFS ALGORITHM //
    ///////////////////
    while (queue.size() > 0) {
        auto lambda = [=] __device__ (Vertex vertex, Edge edge)
                        { return extern_lambda(vertex, edge, level); };
        queue.traverse_edges(lambda);
        level++;
    }
    //--------------------------------------------------------------------------
    ////////////////////
    // BFS VALIDATION //
    ////////////////////
    TM.stop();
    TM.print("BFS");

    auto is_correct = cu::equal(h_distances, h_distances + graph.nV(),
                                d_distances);
    std::cout << (is_correct ? "\nCorrect <>\n\n" : "\n! Not Correct\n\n");
}