#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>

/*
 * Read FILE.TSV and create NUM_BINS equally sized bins. Output a TSV of
 * (bin avg, frequency)
 */

using std::cout;
using std::endl;


unsigned long percentile(std::vector<long> &v, double percent) {
    auto nth = v.begin() + (percent*v.size())/100;
    std::nth_element(v.begin(), nth, v.end());
    return *nth;
}

long calc_avg(std::vector<long>::iterator begin, std::vector<long>::iterator end) {
  long sum = 0, cnt = 0;
  for (std::vector<long>::iterator it = begin; it != end; it++) {
    sum += *it;
    cnt++;
  }
  if (cnt == 0) return 0;
  return sum / cnt;
}

char *progname;
void usage() {
  std::cerr << "Usage: " << progname << " FILE.TSV|- NUM_BINS" << endl << endl;
  exit(1);
}

int main(int argc, char * argv[]) {

  progname = argv[0];
  if (argc < 3)
    usage();

  std::string fn = argv[1];
  unsigned num_bins = atoi(argv[2]);

  std::vector<long> data;
  unsigned a;

  if (fn == "-")
    while (std::cin >> a) data.push_back(a);
  else {
    std::fstream is = std::fstream(fn, std::ios_base::in);
    while (is >> a) data.push_back(a);
  }

  if (data.size() == 0) {
    std::cerr << "No data." << std::endl;
    return 0;
  }

  std::sort(data.begin(), data.end());

  std::vector<double> percentiles = {50.0, 90.0, 95.0, 99.0, 99.9, 99.99};
  std::cerr << "Mean: " << calc_avg(data.begin(), data.end()) << std::endl;
  std::cerr << "Percentiles: ";
  for (auto p : percentiles) {
    std::cerr << "  " << p << ": " << percentile(data, p) << ",";
  }
  std::cerr << std::endl;

  std::vector<long> xs;
  unsigned bin_size = data.size() / num_bins;

  for (int bin = 0; bin < num_bins; bin++)
    xs.push_back(calc_avg(data.begin() + (bin*bin_size),
                          data.begin() + ((bin+1) * bin_size)));

  std::vector<float> ys(num_bins, bin_size);

  for (int i = 0; i < xs.size(); i++)
    cout << xs[i] << "\t" << ys[i] << endl;

  return 0;
}
