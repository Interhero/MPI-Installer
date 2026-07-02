#include <iostream>
#include <vector>
#include <fstream>
#include <chrono>
#include <cmath>
#include <algorithm>
#include <iomanip>
#include <numeric>
#include <queue>

// Structure to hold benchmarking results
struct TaskResult {
    std::string name;
    double elapsed_ms;
};

// Function to load the binary dataset
std::vector<double> loadDataset(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        std::cerr << "[Error] Failed to open dataset file: " << filename << std::endl;
        return {};
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    size_t numDoubles = size / sizeof(double);
    std::vector<double> data(numDoubles);

    if (file.read(reinterpret_cast<char*>(data.data()), size)) {
        std::cout << "Loaded " << numDoubles << " doubles from " << filename << " (" << size / (1024.0 * 1024.0) << " MB)" << std::endl;
    } else {
        std::cerr << "[Error] Failed to read data from " << filename << std::endl;
        return {};
    }

    return data;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "Usage: " << argv[0] << " <dataset_path>" << std::endl;
        return 1;
    }

    std::string datasetPath = argv[1];
    std::cout << "=== Starting Sequential Data Analytics Baseline ===" << std::endl;

    // Load data
    auto loadStart = std::chrono::high_resolution_clock::now();
    std::vector<double> data = loadDataset(datasetPath);
    auto loadEnd = std::chrono::high_resolution_clock::now();
    double loadTime = std::chrono::duration<double, std::milli>(loadEnd - loadStart).count();
    
    if (data.empty()) {
        return 1;
    }

    size_t N = data.size();
    std::vector<TaskResult> results;

    // =========================================================================
    // Task 1: Basic Statistics (Mean, Variance, StdDev, Min, Max)
    // =========================================================================
    std::cout << "\nTask 1: Computing Basic Statistics..." << std::endl;
    auto t1_start = std::chrono::high_resolution_clock::now();

    double min_val = data[0];
    double max_val = data[0];
    double sum = 0.0;
    double sum_sq = 0.0;

    for (double x : data) {
        if (x < min_val) min_val = x;
        if (x > max_val) max_val = x;
        sum += x;
        sum_sq += x * x;
    }

    double mean = sum / N;
    double variance = (sum_sq / N) - (mean * mean);
    double stddev = std::sqrt(variance);

    auto t1_end = std::chrono::high_resolution_clock::now();
    double t1_time = std::chrono::duration<double, std::milli>(t1_end - t1_start).count();
    results.push_back({"Basic Statistics", t1_time});

    std::cout << "  Mean: " << mean << std::endl;
    std::cout << "  Variance: " << variance << std::endl;
    std::cout << "  Std Dev: " << stddev << std::endl;
    std::cout << "  Min: " << min_val << std::endl;
    std::cout << "  Max: " << max_val << std::endl;
    std::cout << "  Time: " << t1_time << " ms" << std::endl;

    // =========================================================================
    // Task 2: Histogram Generation
    // =========================================================================
    std::cout << "\nTask 2: Generating Histogram..." << std::endl;
    auto t2_start = std::chrono::high_resolution_clock::now();

    const int NUM_BINS = 10;
    const double RANGE_MIN = 0.0;
    const double RANGE_MAX = 10000.0;
    const double BIN_WIDTH = (RANGE_MAX - RANGE_MIN) / NUM_BINS;
    std::vector<size_t> histogram(NUM_BINS, 0);

    for (double x : data) {
        int bin_idx = static_cast<int>((x - RANGE_MIN) / BIN_WIDTH);
        if (bin_idx >= NUM_BINS) bin_idx = NUM_BINS - 1;
        if (bin_idx < 0) bin_idx = 0;
        histogram[bin_idx]++;
    }

    auto t2_end = std::chrono::high_resolution_clock::now();
    double t2_time = std::chrono::duration<double, std::milli>(t2_end - t2_start).count();
    results.push_back({"Histogram Generation", t2_time});

    std::cout << "  Histogram Bins:" << std::endl;
    for (int i = 0; i < NUM_BINS; ++i) {
        std::cout << "    Bin " << i << " [" << RANGE_MIN + i * BIN_WIDTH << " - " << RANGE_MIN + (i + 1) * BIN_WIDTH << "]: " << histogram[i] << std::endl;
    }
    std::cout << "  Time: " << t2_time << " ms" << std::endl;

    // =========================================================================
    // Task 4: Pearson Correlation (Column X = Even indices, Column Y = Odd indices)
    // =========================================================================
    std::cout << "\nTask 4: Computing Pearson Correlation..." << std::endl;
    auto t4_start = std::chrono::high_resolution_clock::now();

    size_t num_pairs = N / 2;
    double sum_x = 0.0, sum_y = 0.0;
    double sum_x2 = 0.0, sum_y2 = 0.0;
    double sum_xy = 0.0;

    for (size_t i = 0; i < num_pairs; ++i) {
        double x = data[2 * i];
        double y = data[2 * i + 1];

        sum_x += x;
        sum_y += y;
        sum_x2 += x * x;
        sum_y2 += y * y;
        sum_xy += x * y;
    }

    double numerator = (num_pairs * sum_xy) - (sum_x * sum_y);
    double denominator = std::sqrt(((num_pairs * sum_x2) - (sum_x * sum_x)) * ((num_pairs * sum_y2) - (sum_y * sum_y)));
    double correlation = (denominator != 0.0) ? (numerator / denominator) : 0.0;

    auto t4_end = std::chrono::high_resolution_clock::now();
    double t4_time = std::chrono::duration<double, std::milli>(t4_end - t4_start).count();
    results.push_back({"Pearson Correlation", t4_time});

    std::cout << "  Correlation r: " << correlation << std::endl;
    std::cout << "  Time: " << t4_time << " ms" << std::endl;

    // =========================================================================
    // Task 5: Moving Average (Rolling window of W = 5)
    // =========================================================================
    std::cout << "\nTask 5: Computing Moving Average..." << std::endl;
    auto t5_start = std::chrono::high_resolution_clock::now();

    const int W = 5;
    std::vector<double> moving_avg(N, 0.0);
    double window_sum = 0.0;

    for (int i = 0; i < N; ++i) {
        window_sum += data[i];
        if (i >= W) {
            window_sum -= data[i - W];
            moving_avg[i] = window_sum / W;
        } else {
            moving_avg[i] = window_sum / (i + 1); // partial window for start elements
        }
    }

    auto t5_end = std::chrono::high_resolution_clock::now();
    double t5_time = std::chrono::duration<double, std::milli>(t5_end - t5_start).count();
    results.push_back({"Moving Average", t5_time});
    std::cout << "  Time: " << t5_time << " ms" << std::endl;

    // =========================================================================
    // Task 6: Outlier Detection (Z-score |Z| > 3)
    // =========================================================================
    std::cout << "\nTask 6: Detecting Outliers (Z-score > 3)..." << std::endl;
    auto t6_start = std::chrono::high_resolution_clock::now();

    size_t outlier_count = 0;
    for (double x : data) {
        double z = (x - mean) / stddev;
        if (std::abs(z) > 3.0) {
            outlier_count++;
        }
    }

    auto t6_end = std::chrono::high_resolution_clock::now();
    double t6_time = std::chrono::duration<double, std::milli>(t6_end - t6_start).count();
    results.push_back({"Outlier Detection", t6_time});

    std::cout << "  Outliers detected: " << outlier_count << " (" << (static_cast<double>(outlier_count) / N) * 100.0 << "%)" << std::endl;
    std::cout << "  Time: " << t6_time << " ms" << std::endl;

    // =========================================================================
    // Task 3: Sorting (std::sort - Baseline)
    // =========================================================================
    std::cout << "\nTask 3: Sorting Dataset..." << std::endl;
    auto t3_start = std::chrono::high_resolution_clock::now();

    std::vector<double> sorted_data = data; // copy for sorting
    std::sort(sorted_data.begin(), sorted_data.end());

    auto t3_end = std::chrono::high_resolution_clock::now();
    double t3_time = std::chrono::duration<double, std::milli>(t3_end - t3_start).count();
    results.push_back({"Sorting", t3_time});
    std::cout << "  Time: " << t3_time << " ms" << std::endl;

    // =========================================================================
    // Save Results to CSV Log
    // =========================================================================
    std::string logFilename = "C:\\MPI_Project\\sequential_results.csv";
    std::ofstream logFile(logFilename, std::ios::app);
    if (logFile.is_open()) {
        logFile.seekp(0, std::ios::end);
        if (logFile.tellp() == 0) {
            logFile << "Dataset,Task,N,Time_MS\n";
        }
        for (const auto& res : results) {
            logFile << datasetPath << "," << res.name << "," << N << "," << res.elapsed_ms << "\n";
        }
        logFile.close();
        std::cout << "\nResults logged to " << logFilename << std::endl;
    }

    std::cout << "\n================ Sequential Baseline Complete ================" << std::endl;
    return 0;
}
