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

long calc_avg(std::vector<long>::iterator begin, std::vector<long>::iterator end) {
  long sum = 0, cnt = 0;
  for (std::vector<long>::iterator it = begin; it != end; it++) {
    sum += *it;
    cnt++;
  }
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

  std::sort(data.begin(), data.end());

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
