package server.zone;

/** Persistent counter for the Serials allocator. The production
    implementation is `SerialCounterDal`; tests use an in-memory double. */
interface SerialCounter {
  function loadMobileNext():Int;
  function loadItemNext():Int;
  function storeMobileNext(v:Int):Void;
  function storeItemNext(v:Int):Void;
}
