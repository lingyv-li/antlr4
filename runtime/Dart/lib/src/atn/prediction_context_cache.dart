import '../prediction_context.dart';

/** Used to cache {@link PredictionContext} objects. Its used for the shared
 *  context cash associated with contexts in DFA states. This cache
 *  can be used for both lexers and parsers.
 */
class PredictionContextCache {
  final cache = new Map<PredictionContext, PredictionContext>();

  /** Add a context to the cache and return it. If the context already exists,
   *  return that one instead and do not add a new context to the cache.
   *  Protect shared cache from unsafe thread access.
   */
  PredictionContext add(PredictionContext ctx) {
    if (ctx == PredictionContext.EMPTY) return PredictionContext.EMPTY;
    PredictionContext existing = cache[ctx];
    if (existing != null) {
//			System.out.println(name+" reuses "+existing);
      return existing;
    }
    cache[ctx] = ctx;
    return ctx;
  }

  PredictionContext operator [](PredictionContext ctx) {
    return cache[ctx];
  }

  int get length {
    return cache.length;
  }
}
