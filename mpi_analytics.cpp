#include <mpi.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <cmath>
#include <algorithm>
#include <iomanip>
#include <numeric>
#include <queue>

// Structure to hold timing results on Rank 0
struct TaskTime {
    std::string name;
    double time_ms;
};

// P-way merge helper structure
struct MergeElement {
    double value;
    int array_idx;
    size_t element_idx;

    bool operator>(const MergeElement& other) const {
        return value > other.value;
    }
};

// Function for P-way merge of sorted arrays
std::vector<double> mergeSortedArrays(const std::vector<double>& flat_data, size_t local_N, int P) {
    std::vector<double> result;
    result.reserve(flat_data.size());

    // Min-heap
    std::priority_queue<MergeElement, std::vector<MergeElement>, std::greater<MergeElement>> min_heap;

    // Initialize heap with the first element of each chunk
    for (int i = 0; i < P; ++i) {
        if (local_N > 0) {
            min_heap.push({flat_data[i * local_N], i, 0});
        }
    }

    while (!min_heap.empty()) {
        MergeElement smallest = min_heap.top();
        min_heap.pop();

        result.push_back(smallest.value);

        size_t next_idx = smallest.element_idx + 1;
        if (next_idx < local_N) {
            min_heap.push({flat_data[smallest.array_idx * local_N + next_idx], smallest.array_idx, next_idx});
        }
    }

    return result;
}

int main(int argc, char** argv) {
    // Initialize MPI
    MPI_Init(&argc, &argv);

    int world_size;
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    int world_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);

    char processor_name[MPI_MAX_PROCESSOR_NAME];
    int name_len;
    MPI_Get_processor_name(processor_name, &name_len);

    std::string datasetPath = "";
    if (world_rank == 0) {
        if (argc < 2) {
            std::cerr << "Usage: mpiexec -n <P> " << argv[0] << " <dataset_path>" << std::endl;
            MPI_Abort(MPI_COMM_WORLD, 1);
        }
        datasetPath = argv[1];
        std::cout << "=== Starting Parallel MPI Data Analytics (" << world_size << " Nodes) ===" << std::endl;
    }

    // 1. Broadcast dataset path size to determine total N
    size_t N = 0;
    std::vector<double> global_data;

    if (world_rank == 0) {
        std::ifstream file(datasetPath, std::ios::binary | std::ios::ate);
        if (file.is_open()) {
            std::streamsize size = file.tellg();
            N = size / sizeof(double);
            file.close();
        } else {
            std::cerr << "[Error] Failed to open dataset on Master node!" << std::endl;
            N = 0;
        }
    }

    // Broadcast N to all nodes
    MPI_Bcast(&N, 1, MPI_UINT64_T, 0, MPI_COMM_WORLD);

    if (N == 0) {
        MPI_Finalize();
        return 1;
    }

    // Ensure chunks split evenly and local_N is even for Pearson pairs
    size_t local_N = N / world_size;
    if (local_N % 2 != 0) {
        local_N--; // make local chunk size even
    }

    // Master node reads the entire dataset
    if (world_rank == 0) {
        std::ifstream file(datasetPath, std::ios::binary);
        if (file.is_open()) {
            global_data.resize(local_N * world_size);
            file.read(reinterpret_cast<char*>(global_data.data()), global_data.size() * sizeof(double));
            file.close();
            std::cout << "Data loaded successfully. Processing " << global_data.size() << " points (" 
                      << local_N << " points per node)." << std::endl;
        }
    }

    // Allocate buffer for local data chunk
    std::vector<double> local_data(local_N);

    // Scatter data to all nodes
    MPI_Scatter(global_data.data(), local_N, MPI_DOUBLE, local_data.data(), local_N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    std::vector<TaskTime> task_times;
    double t_start, t_end;

    // Synchronize before starting tasks
    MPI_Barrier(MPI_COMM_WORLD);

    // =========================================================================
    // Task 1: Basic Statistics
    // =========================================================================
    t_start = MPI_Wtime();

    double local_min = local_data[0];
    double local_max = local_data[0];
    double local_sum = 0.0;
    double local_sum_sq = 0.0;

    for (double x : local_data) {
        if (x < local_min) local_min = x;
        if (x > local_max) local_max = x;
        local_sum += x;
        local_sum_sq += x * x;
    }

    // Reduce results to Rank 0
    double global_min, global_max, global_sum, global_sum_sq;
    MPI_Reduce(&local_min, &global_min, 1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_max, &global_max, 1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum, &global_sum, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum_sq, &global_sum_sq, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    t_end = MPI_Wtime();
    double t1_time = (t_end - t_start) * 1000.0; // convert to ms

    double mean = 0.0, variance = 0.0, stddev = 0.0;
    if (world_rank == 0) {
        size_t total_points = local_N * world_size;
        mean = global_sum / total_points;
        variance = (global_sum_sq / total_points) - (mean * mean);
        stddev = std::sqrt(variance);

        std::cout << "\nTask 1: Basic Statistics Complete" << std::endl;
        std::cout << "  Mean: " << mean << std::endl;
        std::cout << "  Variance: " << variance << std::endl;
        std::cout << "  Std Dev: " << stddev << std::endl;
        std::cout << "  Min: " << global_min << std::endl;
        std::cout << "  Max: " << global_max << std::endl;
        std::cout << "  Time: " << t1_time << " ms" << std::endl;
        task_times.push_back({"Basic Statistics", t1_time});
    }

    // =========================================================================
    // Task 2: Histogram Generation
    // =========================================================================
    MPI_Barrier(MPI_COMM_WORLD);
    t_start = MPI_Wtime();

    const int NUM_BINS = 10;
    const double RANGE_MIN = 0.0;
    const double RANGE_MAX = 10000.0;
    const double BIN_WIDTH = (RANGE_MAX - RANGE_MIN) / NUM_BINS;
    std::vector<long long> local_histogram(NUM_BINS, 0);

    for (double x : local_data) {
        int bin_idx = static_cast<int>((x - RANGE_MIN) / BIN_WIDTH);
        if (bin_idx >= NUM_BINS) bin_idx = NUM_BINS - 1;
        if (bin_idx < 0) bin_idx = 0;
        local_histogram[bin_idx]++;
    }

    std::vector<long long> global_histogram(NUM_BINS, 0);
    MPI_Reduce(local_histogram.data(), global_histogram.data(), NUM_BINS, MPI_LONG_LONG, MPI_SUM, 0, MPI_COMM_WORLD);

    t_end = MPI_Wtime();
    double t2_time = (t_end - t_start) * 1000.0;

    if (world_rank == 0) {
        std::cout << "\nTask 2: Histogram Generation Complete" << std::endl;
        for (int i = 0; i < NUM_BINS; ++i) {
            std::cout << "    Bin " << i << " [" << RANGE_MIN + i * BIN_WIDTH << " - " << RANGE_MIN + (i + 1) * BIN_WIDTH << "]: " << global_histogram[i] << std::endl;
        }
        std::cout << "  Time: " << t2_time << " ms" << std::endl;
        task_times.push_back({"Histogram Generation", t2_time});
    }

    // =========================================================================
    // Task 4: Pearson Correlation (Column X = Even indices, Column Y = Odd indices)
    // =========================================================================
    MPI_Barrier(MPI_COMM_WORLD);
    t_start = MPI_Wtime();

    size_t local_pairs = local_N / 2;
    double local_sum_x = 0.0, local_sum_y = 0.0;
    double local_sum_x2 = 0.0, local_sum_y2 = 0.0;
    double local_sum_xy = 0.0;

    for (size_t i = 0; i < local_pairs; ++i) {
        double x = local_data[2 * i];
        double y = local_data[2 * i + 1];

        local_sum_x += x;
        local_sum_y += y;
        local_sum_x2 += x * x;
        local_sum_y2 += y * y;
        local_sum_xy += x * y;
    }

    double global_sum_x, global_sum_y, global_sum_x2, global_sum_y2, global_sum_xy;
    MPI_Reduce(&local_sum_x, &global_sum_x, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum_y, &global_sum_y, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum_x2, &global_sum_x2, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum_y2, &global_sum_y2, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&local_sum_xy, &global_sum_xy, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);

    t_end = MPI_Wtime();
    double t4_time = (t_end - t_start) * 1000.0;

    if (world_rank == 0) {
        size_t total_pairs = local_pairs * world_size;
        double numerator = (total_pairs * global_sum_xy) - (global_sum_x * global_sum_y);
        double denominator = std::sqrt(((total_pairs * global_sum_x2) - (global_sum_x * global_sum_x)) * ((total_pairs * global_sum_y2) - (global_sum_y * global_sum_y)));
        double correlation = (denominator != 0.0) ? (numerator / denominator) : 0.0;

        std::cout << "\nTask 4: Pearson Correlation Complete" << std::endl;
        std::cout << "  Correlation r: " << correlation << std::endl;
        std::cout << "  Time: " << t4_time << " ms" << std::endl;
        task_times.push_back({"Pearson Correlation", t4_time});
    }

    // =========================================================================
    // Task 5: Moving Average (Rolling Window of W = 5 with Halo Exchange)
    // =========================================================================
    MPI_Barrier(MPI_COMM_WORLD);
    t_start = MPI_Wtime();

    const int W = 5;
    std::vector<double> prev_halo(W - 1, 0.0);

    // Halo exchange: Send last W-1 elements to the next process, receive from the previous
    if (world_rank < world_size - 1) {
        // Send last W-1 elements to rank + 1
        MPI_Send(local_data.data() + local_N - (W - 1), W - 1, MPI_DOUBLE, world_rank + 1, 100, MPI_COMM_WORLD);
    }
    if (world_rank > 0) {
        // Receive W-1 elements from rank - 1
        MPI_Recv(prev_halo.data(), W - 1, MPI_DOUBLE, world_rank - 1, 100, MPI_COMM_WORLD, MPI_STATUS_IGNORE);
    }

    // Calculate moving average
    std::vector<double> local_moving_avg(local_N, 0.0);
    
    // For the first W-1 elements, we include the received halo elements if rank > 0
    for (size_t i = 0; i < local_N; ++i) {
        double window_sum = 0.0;
        int count = 0;

        for (int k = 0; k < W; ++k) {
            int idx = static_cast<int>(i) - k;
            if (idx >= 0) {
                window_sum += local_data[idx];
                count++;
            } else if (world_rank > 0) {
                // Read from halo buffer
                window_sum += prev_halo[W - 1 + idx];
                count++;
            } else {
                // For rank 0, start elements have partial window
                window_sum += local_data[i]; // just keep same index
            }
        }
        local_moving_avg[i] = window_sum / count;
    }

    t_end = MPI_Wtime();
    double t5_time = (t_end - t_start) * 1000.0;

    if (world_rank == 0) {
        std::cout << "\nTask 5: Moving Average Complete" << std::endl;
        std::cout << "  Time: " << t5_time << " ms" << std::endl;
        task_times.push_back({"Moving Average", t5_time});
    }

    // =========================================================================
    // Task 6: Outlier Detection (Z-score |Z| > 3 using Broadcast mean/stddev)
    // =========================================================================
    MPI_Barrier(MPI_COMM_WORLD);
    t_start = MPI_Wtime();

    // Broadcast global mean and stddev computed by Rank 0
    MPI_Bcast(&mean, 1, MPI_DOUBLE, 0, MPI_COMM_WORLD);
    MPI_Bcast(&stddev, 1, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    size_t local_outliers = 0;
    for (double x : local_data) {
        double z = (x - mean) / stddev;
        if (std::abs(z) > 3.0) {
            local_outliers++;
        }
    }

    size_t global_outliers;
    MPI_Reduce(&local_outliers, &global_outliers, 1, MPI_UINT64_T, MPI_SUM, 0, MPI_COMM_WORLD);

    t_end = MPI_Wtime();
    double t6_time = (t_end - t_start) * 1000.0;

    if (world_rank == 0) {
        size_t total_points = local_N * world_size;
        std::cout << "\nTask 6: Outlier Detection Complete" << std::endl;
        std::cout << "  Outliers detected: " << global_outliers << " (" << (static_cast<double>(global_outliers) / total_points) * 100.0 << "%)" << std::endl;
        std::cout << "  Time: " << t6_time << " ms" << std::endl;
        task_times.push_back({"Outlier Detection", t6_time});
    }

    // =========================================================================
    // Task 3: Sorting (Local Sort + Gather + P-Way Merge)
    // =========================================================================
    MPI_Barrier(MPI_COMM_WORLD);
    t_start = MPI_Wtime();

    // Sort local chunk
    std::sort(local_data.begin(), local_data.end());

    // Gather sorted chunks back to Rank 0
    std::vector<double> gathered_data;
    if (world_rank == 0) {
        gathered_data.resize(local_N * world_size);
    }

    MPI_Gather(local_data.data(), local_N, MPI_DOUBLE, gathered_data.data(), local_N, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // Merge sorted chunks on Rank 0
    if (world_rank == 0) {
        std::vector<double> final_sorted = mergeSortedArrays(gathered_data, local_N, world_size);
    }

    t_end = MPI_Wtime();
    double t3_time = (t_end - t_start) * 1000.0;

    if (world_rank == 0) {
        std::cout << "\nTask 3: Sorting Complete" << std::endl;
        std::cout << "  Time: " << t3_time << " ms" << std::endl;
        task_times.push_back({"Sorting", t3_time});

        // Save Results to CSV Log
        std::string logFilename = "C:\\MPI_Project\\mpi_results.csv";
        std::ofstream logFile(logFilename, std::ios::app);
        if (logFile.is_open()) {
            logFile.seekp(0, std::ios::end);
            if (logFile.tellp() == 0) {
                logFile << "Dataset,Nodes,Task,N,Time_MS\n";
            }
            size_t total_points = local_N * world_size;
            for (const auto& res : task_times) {
                logFile << datasetPath << "," << world_size << "," << res.name << "," << total_points << "," << res.time_ms << "\n";
            }
            logFile.close();
            std::cout << "\nResults logged to " << logFilename << std::endl;
        }
        std::cout << "\n================ Parallel MPI Baseline Complete ================" << std::endl;
    }

    // Finalize MPI
    MPI_Finalize();
    return 0;
}
