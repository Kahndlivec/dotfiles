// ═══════════════════════════════════════════════════════════════════════════
//  bits/stdc++.h  —  macOS shim
//
//  Apple's clang++ ships libc++, which does NOT have this header. Every CP
//  template on the internet includes it, so we provide our own.
//
//  Install to:  ~/.cp/include/bits/stdc++.h
//    mkdir -p ~/.cp/include/bits
//    mv bits-stdc++.h ~/.cp/include/bits/stdc++.h
//
//  The build system already passes -I$HOME/.cp/include.
// ═══════════════════════════════════════════════════════════════════════════
#ifndef CP_BITS_STDCXX_H
#define CP_BITS_STDCXX_H

// C library
#include <cassert>
#include <cctype>
#include <cerrno>
#include <cfloat>
#include <climits>
#include <cmath>
#include <csetjmp>
#include <csignal>
#include <cstdarg>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <cstdint>
#include <cinttypes>

// Containers
#include <array>
#include <bitset>
#include <deque>
#include <forward_list>
#include <list>
#include <map>
#include <queue>
#include <set>
#include <stack>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// Algorithms / numerics
#include <algorithm>
#include <bit>
#include <complex>
#include <functional>
#include <iterator>
#include <limits>
#include <numeric>
#include <random>
#include <ratio>
#include <valarray>

// Strings / streams
#include <fstream>
#include <iomanip>
#include <ios>
#include <iosfwd>
#include <iostream>
#include <istream>
#include <ostream>
#include <sstream>
#include <streambuf>
#include <string>
#include <string_view>
#include <charconv>

// Utilities
#include <chrono>
#include <initializer_list>
#include <memory>
#include <new>
#include <optional>
#include <stdexcept>
#include <tuple>
#include <type_traits>
#include <typeindex>
#include <typeinfo>
#include <utility>
#include <variant>

#if __cplusplus >= 202002L
  #include <concepts>
  #include <compare>
  #include <numbers>
  #include <ranges>
  #include <span>
#endif

#endif  // CP_BITS_STDCXX_H
