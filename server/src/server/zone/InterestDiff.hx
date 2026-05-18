package server.zone;

/** Per-observer interest change for one tick. */
typedef InterestDiff = { observerId:Int, entered:Array<Int>, left:Array<Int> };
