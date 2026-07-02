#include <mpi.h>
#include <iostream>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name(processor_name, &name_len);

    if (world_size < 2) {
        std::cerr << "[Error] This test requires at least 2 processors (Master and Worker)!" << std::endl;
        MPI_Finalize();
        return 1;
    }

    if (world_rank == 0) {
        // Master process
        int number = 5;
        std::cout << "[Master] Running on " << processor_name << " (Rank 0). Sending number " << number << " to Rank 1..." << std::endl;
        MPI_Send(&number, 1, MPI_INT, 1, 0, MPI_COMM_WORLD);

        int result;
        MPI_Recv(&result, 1, MPI_INT, 1, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        std::cout << "[Master] Received computation result from Rank 1: " << result << std::endl;
        std::cout << "[Master] MPI Communication Test successful!" << std::endl;
    } else if (world_rank == 1) {
        // Worker process
        int received_num;
        MPI_Recv(&received_num, 1, MPI_INT, 0, 0, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
        std::cout << "[Worker] Running on " << processor_name << " (Rank 1). Received number " << received_num << " from Rank 0." << std::endl;

        int squared = received_num * received_num;
        std::cout << "[Worker] Computing " << received_num << " squared = " << squared << ". Sending back to Rank 0..." << std::endl;
        MPI_Send(&squared, 1, MPI_INT, 0, 0, MPI_COMM_WORLD);
    } else {
        std::cout << "[Node] Running on " << processor_name << " (Rank " << world_rank << ") is idle." << std::endl;
    }

    MPI_Finalize();
    return 0;
}
