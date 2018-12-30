#include <Device/Util/SafeCudaAPI.cuh>
#include <Device/Util/SafeCudaAPISync.cuh>
#include <Device/Util/SafeCudaAPIAsync.cuh>
#include <Device/Primitives/SimpleKernels.cuh>
#include <Device/Util/Timer.cuh>
#include <cmath>
#include <limits>
#include <iomanip>
#include <iostream>
#include <vector>

using namespace timer;
using xlib::byte_t;
using ttime_t = float;

int main() {
    size_t size = 1024;
    Timer<DEVICE> TM;

    std::vector<ttime_t> allocation_time;
    std::vector<ttime_t> allocation_pinned_time;
    std::vector<ttime_t> H2D_time;
    std::vector<ttime_t> H2D_pinned_time;
    std::vector<ttime_t> D2D_time;
    std::vector<ttime_t> memcpy_kernel_time;
    std::vector<ttime_t> memset_time;
    std::vector<ttime_t> memset_kernel_time;
    byte_t* d_array, *h_array_pinned;;

    std::cout << "Computing";

    while (true) {
        std::cout << "." << std::flush;
        //======================================================================
        TM.start();

        if (cudaMalloc(&d_array, size) != cudaSuccess)//cudaMalloc instead of cuMalloc to test return value, cuMalloc calls std::exit() on error.
            break;

        TM.stop();
        allocation_time.push_back(TM.duration());
        //----------------------------------------------------------------------
        auto h_array = new byte_t[size];
        TM.start();

        cuMemcpyToDevice(h_array, size, d_array);

        TM.stop();
        delete[] h_array;
        H2D_time.push_back(TM.duration());
        //----------------------------------------------------------------------
        TM.start();

        cuMallocHost(h_array_pinned, size);

        TM.stop();

        allocation_pinned_time.push_back(TM.duration());
        //----------------------------------------------------------------------

        TM.start();

        cuMemcpyToDevice(h_array_pinned, size, d_array);

        TM.stop();
        cuFreeHost(h_array_pinned);
        H2D_pinned_time.push_back(TM.duration());
        //----------------------------------------------------------------------
        TM.start();

        cuMemset0x00(d_array, size);

        TM.stop();
        memset_time.push_back(TM.duration());
        //----------------------------------------------------------------------
        TM.start();

        cu::memset(reinterpret_cast<unsigned char*>(d_array), size,
                   (unsigned char) 0);

        TM.stop();
        CHECK_CUDA_ERROR
        memset_kernel_time.push_back(TM.duration());
        //----------------------------------------------------------------------
        byte_t* d_array2;
        if (cudaMalloc(&d_array2, size) == cudaSuccess) {//cudaMalloc instead of cuMalloc to test return value, cuMalloc calls std::exit() on error.
            TM.start();

            cuMemcpyDevToDev(d_array, size, d_array2);

            TM.stop();
            D2D_time.push_back(TM.duration());
        //----------------------------------------------------------------------
            TM.start();

            cu::memcpy(d_array, size, d_array2);

            TM.stop();
            memcpy_kernel_time.push_back(TM.duration());
            cuFree(d_array2);
        }
        else {
            D2D_time.push_back(std::nan(""));
            memcpy_kernel_time.push_back(std::nan(""));
        }
        cuFree(d_array);
        //----------------------------------------------------------------------
        size *= 2;
    }
    size = 1024;
    std::cout << "\n\n" << std::setprecision(2) << std::right << std::fixed
              << std::setw(8)  << "SIZE"
              << std::setw(11) << "MemcpyHtD"
              << std::setw(14) << "MemcpyHtDPin"
              << std::setw(11) << "MemcpyDtD"
              << std::setw(14) << "MemcpyKernel"
              << std::setw(8)  << "Memset"
              << std::setw(14) << "MemsetKernel" << std::endl;
    xlib::char_sequence('-', 80);

    for (size_t i = 0; i < H2D_time.size(); i++) {
        std::cout << std::setw(8)  << xlib::human_readable(size)
                  << std::setw(11) << H2D_time[i]
                  << std::setw(14) << H2D_pinned_time[i]
                  << std::setw(11) << D2D_time[i]
                  << std::setw(14) << memcpy_kernel_time[i]
                  << std::setw(8)  << memset_time[i]
                  << std::setw(14) << memset_kernel_time[i] << "\n";
        size *= 2;
    }
}
