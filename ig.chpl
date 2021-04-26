use BlockDist, Random, Time, CommAggregation;
use Memory.Diagnostics;

config const size = 10**8; // number of updates per node
config const vsize = size; // number of entries in the table per node

const numUpdates = size * numLocales;
const tableSize = vsize * numLocales;

config const trials = 6;
var t: Timer;
proc startTimer() {
  t.start();
}
proc stopTimer(name) {
    t.stop(); var sec = t.elapsed(); t.clear();
    const GiB = (3 * tableSize * numBytes(int)):real / (2**30):real;
    writef("%10s:\t%.3dr seconds\t%.3dr GiB/s\n", name, sec, GiB/sec);
}

proc main() {
  for 1..trials {
  const D = newBlockDom(0..#tableSize);
  var A: [D] int = D;

  const UpdatesDom = newBlockDom(0..#numUpdates);
  var Rindex: [UpdatesDom] int;

  fillRandom(Rindex, 208);
  Rindex = mod(Rindex, tableSize);

  var tmp: [UpdatesDom] int = -1;
  coforall loc in Locales do on loc do
    coforall 1..here.maxTaskPar*8 {
      chpl_task_getInfoChapel();
    }

  startTimer();
  //startVerboseMemHere();
  forall (t, r) in zip (tmp, Rindex) with (var agg = new SrcAggregator(int)) {
    agg.copy(t, A[r]);
  }
  //stopVerboseMemHere();
  stopTimer("AGG");
  }
}
