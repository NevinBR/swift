// RUN: %target-run-simple-swiftgyb
// REQUIRES: executable_test

import StdlibUnittest

var FloatingPointRandom = TestSuite("FloatingPointRandom")
defer { runAllTests() }

extension BinaryFloatingPoint where RawSignificand: FixedWidthInteger {
  // Basic sanity check
  static func isRandomInRange(_ range: Range<Self>) -> Bool {
    let x = Self.random(in: range)
    return range.contains(x)
  }
  
  // Basic sanity check
  static func isRandomInRange(_ range: ClosedRange<Self>) -> Bool {
    let x = Self.random(in: range)
    return range.contains(x)
  }
  
  // The previous version of `random(in:)` would trap if the span of the range
  // overflowed to infinity. This test ensures that a result is produced.
  static func isFullRangeRandomFinite() -> Bool {
    let x = Self.greatestFiniteMagnitude
    return Self.random(in: -x...x).isFinite
  }
  
  // The previous version of `random(in: -1..<1)` would never set the low bit.
  static func isRandomLowBitEverSet() -> Bool {
    for _ in 0 ..< 256 {
      let r = Self.random(in: -1..<1)
      let lowBit = r.significandBitPattern._lowWord & 1
      if lowBit == 1 { return true }
    }
    // The probability of a spurious failure is less than 1 in 10^77
    return false
  }
  
  // This is not a robust statistical test of randomness. It is only intended
  // to distinguish between 1:1 odds (desired) and 2:1 odds (previous version)
  static func isSmallRangeRandomUnbiased() -> Bool {
    func randomWalk(_ steps: Int) -> Int {
      let mid = 3 as Self
      let range = mid.nextDown ..< mid.nextUp
      var result = 0
      for _ in 0 ..< steps {
        let x = Self.random(in: range)
        result += (x == mid) ? 1 : -1
      }
      return result
    }
    
    var steps = 256
    var sum = randomWalk(steps)
    
    // This could be a `while true` loop, but we put a bound on it to guarantee
    // a result in finite time. The bound should never be reached in practice.
    for _ in 0 ..< 1<<16 {
      // An unbiased random walk of n steps is well-approximated by a normal
      // distribution of mean 0 and standard deviation sqrt(n)
      let sigma = Double(steps).squareRoot()
      let a = abs(sum)
      let x = Double(a)
      
      if x < 2 * sigma {
        // There is a 95% chance that a normal variate is within 2 sigma of the
        // mean, so a correct implementation should pass the test very quickly.
        return true
      } else if x > 16 * sigma {
        // The probability that a normal variate exceeds 16 sigma from the mean
        // is less than 1 in 10^56, so a correct implementation should not fail
        // spuriously until long after the collapse of the solar system.
        //
        // The expectation of a biased random walk, however, grows linearly, so
        // an incorrect implementation should fail within a few thousand steps.
        return false
      }
      
      sum += randomWalk(a)
      steps += a
    }
    
    // The test was inconclusive, so it did not definitively fail.
    return true
  }
  
  static var testValues: [Self] {
    let x = Self.ulpOfOne
    let y = Self.leastNormalMagnitude
    return [-2, -1.9, -1.1, -1, -0.9, -x, -y, -0, 0, y, x, 0.9, 1, 1.1, 1.9, 2]
  }
}


% for Self in [`Float`, `Double`, `Float80`]:

%   if Self == `Float80`:
#if !os(Windows) && (arch(i386) || arch(x86_64))
%   end

FloatingPointRandom.test("${Self}/random/rangeContains") {
  for a in ${Self}.testValues {
    for b in ${Self}.testValues where b >= a {
      expectTrue(${Self}.isRandomInRange(a...b))
      if b != a {
        expectTrue(${Self}.isRandomInRange(a..<b))
      }
    }
  }
}

FloatingPointRandom.test("${Self}/random/infiniteRange") {
  expectCrashLater()
  _ = ${Self}.random(in: 0 ..< .infinity)
}

FloatingPointRandom.test("${Self}/random/emptyRange") {
  expectCrashLater()
  _ = ${Self}.random(in: 0..<0)
}

FloatingPointRandom.test("${Self}/random/fullRange") {
  expectTrue(${Self}.isFullRangeRandomFinite())
}

FloatingPointRandom.test("${Self}/random/lowBit") {
  expectTrue(${Self}.isRandomLowBitEverSet())
}

FloatingPointRandom.test("${Self}/random/smallRange") {
  expectTrue(${Self}.isSmallRangeRandomUnbiased())
}

%   if Self == `Float80`:
#endif
%   end

% end
