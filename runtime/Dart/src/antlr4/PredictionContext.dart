//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
///
import './RuleContext.dart';

abstract class PredictionContext {
  var cachedHashCode;
  PredictionContext(this.cachedHashCode);

// Represents {@code $} in local context prediction, which means wildcard.
// {@code//+x =//}.
// /
static final EMPTY = EmptyPredictionContext();

// Represents {@code $} in an array in full context mode, when {@code $}
// doesn't mean wildcard: {@code $ + x = [$,x]}. Here,
// {@code $} = {@link //EMPTY_RETURN_STATE}.
// /
static final EMPTY_RETURN_STATE = 0x7FFFFFFF;

static final globalNodeCount = 1;
static final id = PredictionContext.globalNodeCount;


// Stores the computed hash code of this {@link PredictionContext}. The hash
// code is computed in parts to match the following reference algorithm.
//
// <pre>
// private int referenceHashCode() {
// int hash = {@link MurmurHash//initialize MurmurHash.initialize}({@link
// //INITIAL_HASH});
//
// for (int i = 0; i &lt; {@link //size()} i++) {
// hash = {@link MurmurHash//update MurmurHash.update}(hash, {@link //getParent
// getParent}(i));
// }
//
// for (int i = 0; i &lt; {@link //size()} i++) {
// hash = {@link MurmurHash//update MurmurHash.update}(hash, {@link
// //getReturnState getReturnState}(i));
// }
//
// hash = {@link MurmurHash//finish MurmurHash.finish}(hash, 2// {@link
// //size()});
// return hash;
// }
// </pre>
// /

// This means only the {@link //EMPTY} context is in set.
isEmpty() {
	return this == PredictionContext.EMPTY;
}

hasEmptyPath() {
	return this.getReturnState(this.length - 1) == PredictionContext.EMPTY_RETURN_STATE;
}
int getReturnState(index);
int get length;
hashCode() {
	return this.cachedHashCode;
}


updateHashCode(hash) {
    hash.update(this.cachedHashCode);
}
/*
function calculateHashString(parent, returnState) {
	return "" + parent + returnState;
}
*/
}

// Used to cache {@link PredictionContext} objects. Its used for the shared
// context cash associated with contexts in DFA states. This cache
// can be used for both lexers and parsers.

class PredictionContextCache {
	var cache = {};


// Add a context to the cache and return it. If the context already exists,
// return that one instead and do not add a new context to the cache.
// Protect shared cache from unsafe thread access.
//
add(ctx) {
	if (ctx == PredictionContext.EMPTY) {
		return PredictionContext.EMPTY;
	}
	var existing = this.cache[ctx];
	if (existing != null) {
		return existing;
	}
	this.cache[ctx] = ctx;
	return ctx;
}

get(ctx) {
	return this.cache[ctx];
}

get length {
		return this.cache.length;
	}

}

class SingletonPredictionContext extends PredictionContext {
  var parentCtx;
  int returnState;
  SingletonPredictionContext(parent, returnState) :super(hashCode){
	var hashCode = 0;
	var hash = new Hash();
	if(parent != null) {
		hash.update(parent, returnState);
	} else {
		hash.update(1);
	}
	hashCode = hash.finish();

	this.parentCtx = parent;
	this.returnState = returnState;
}

static create(parent, returnState) {
	if (returnState == PredictionContext.EMPTY_RETURN_STATE && parent == null) {
		// someone can pass in the bits of an array ctx that mean $
		return PredictionContext.EMPTY;
	} else {
		return new SingletonPredictionContext(parent, returnState);
	}
}

int get length {
		return 1;
	}


getParent(index) {
	return this.parentCtx;
}

getReturnState(index) {
	return this.returnState;
}

equals(other) {
	if (this == other) {
		return true;
	} else if (!(other is SingletonPredictionContext)) {
		return false;
	} else if (this.hashCode() != other.hashCode()) {
		return false; // can't be same if hash is different
	} else {
		if(this.returnState != other.returnState)
            return false;
        else if(this.parentCtx==null)
            return other.parentCtx==null;
		else
      return this.parentCtx.equals(other.parentCtx);
	}
}

String toString() {
	var up = this.parentCtx == null ? "" : this.parentCtx.toString();
	if (up.length == 0) {
		if (this.returnState == PredictionContext.EMPTY_RETURN_STATE) {
			return r"$";
		} else {
			return "$returnState";
		}
	} else {
		return "$returnState $up";
	}
}
}

class EmptyPredictionContext extends SingletonPredictionContext{ 
  EmptyPredictionContext(): super(null, PredictionContext.EMPTY_RETURN_STATE);
isEmpty() {
	return true;
}

getParent(index) {
	return null;
}

getReturnState(index) {
	return this.returnState;
}

equals(other) {
	return this == other;
}

toString() {
	return r"$";
}
}

class ArrayPredictionContext extends PredictionContext{ 
  var parents;
  var returnStates;
  ArrayPredictionContext(parents, returnStates) :super(hashCode) {
	// Parent can be null only if full ctx mode and we make an array
	// from {@link //EMPTY} and non-empty. We merge {@link //EMPTY} by using
	// null parent and
	// returnState == {@link //EMPTY_RETURN_STATE}.
	var h = new Hash();
	h.update(parents, returnStates);
	var hashCode = h.finish();

	this.parents = parents;
	this.returnStates = returnStates;

}

isEmpty() {
	// since EMPTY_RETURN_STATE can only appear in the last position, we
	// don't need to verify that size==1
	return this.returnStates[0] == PredictionContext.EMPTY_RETURN_STATE;
}

get length{
		return this.returnStates.length;
	}


getParent(index) {
	return this.parents[index];
}

getReturnState(index) {
	return this.returnStates[index];
}

equals(other) {
	if (this == other) {
		return true;
	} else if (!(other is ArrayPredictionContext)) {
		return false;
	} else if (this.hashCode() != other.hashCode()) {
		return false; // can't be same if hash is different
	} else {
		return this.returnStates == other.returnStates &&
				this.parents == other.parents;
	}
}

toString() {
	if (this.isEmpty()) {
		return "[]";
	} else {
		var s = "[";
		for (var i = 0; i < this.returnStates.length; i++) {
			if (i > 0) {
				s = s + ", ";
			}
			if (this.returnStates[i] == PredictionContext.EMPTY_RETURN_STATE) {
				s = s + r"$";
				continue;
			}
			s = s + this.returnStates[i];
			if (this.parents[i] != null) {
				s = s + " " + this.parents[i];
			} else {
				s = s + "null";
			}
		}
		return s + "]";
	}
}
}
// Convert a {@link RuleContext} tree to a {@link PredictionContext} graph.
// Return {@link //EMPTY} if {@code outerContext} is empty or null.
// /
 predictionContextFromRuleContext(atn, outerContext) {
	if (outerContext == null) {
		outerContext = RuleContext.EMPTY;
	}
	// if we are in RuleContext of start rule, s, then PredictionContext
	// is EMPTY. Nobody called us. (if we are empty, return empty)
	if (outerContext.parentCtx == null || outerContext == RuleContext.EMPTY) {
		return PredictionContext.EMPTY;
	}
	// If we have a parent, convert it to a PredictionContext graph
	var parent = predictionContextFromRuleContext(atn, outerContext.parentCtx);
	var state = atn.states[outerContext.invokingState];
	var transition = state.transitions[0];
	return SingletonPredictionContext.create(parent, transition.followState.stateNumber);
}
/*
function calculateListsHashString(parents, returnStates) {
	var s = "";
	parents.map(function(p) {
		s = s + p;
	});
	returnStates.map(function(r) {
		s = s + r;
	});
	return s;
}
*/
merge(a, b, rootIsWildcard, mergeCache) {
	// share same graph if both same
	if (a == b) {
		return a;
	}
	if (a is SingletonPredictionContext && b is SingletonPredictionContext) {
		return mergeSingletons(a, b, rootIsWildcard, mergeCache);
	}
	// At least one of a or b is array
	// If one is $ and rootIsWildcard, return $ as// wildcard
	if (rootIsWildcard) {
		if (a is EmptyPredictionContext) {
			return a;
		}
		if (b is EmptyPredictionContext) {
			return b;
		}
	}
	// convert singleton so both are arrays to normalize
	if (a is SingletonPredictionContext) {
		a = new ArrayPredictionContext([a.getParent()], [a.returnState]);
	}
	if (b is SingletonPredictionContext) {
		b = new ArrayPredictionContext([b.getParent()], [b.returnState]);
	}
	return mergeArrays(a, b, rootIsWildcard, mergeCache);
}

//
// Merge two {@link SingletonPredictionContext} instances.
//
// <p>Stack tops equal, parents merge is same; return left graph.<br>
// <embed src="images/SingletonMerge_SameRootSamePar.svg"
// type="image/svg+xml"/></p>
//
// <p>Same stack top, parents differ; merge parents giving array node, then
// remainders of those graphs. A new root node is created to point to the
// merged parents.<br>
// <embed src="images/SingletonMerge_SameRootDiffPar.svg"
// type="image/svg+xml"/></p>
//
// <p>Different stack tops pointing to same parent. Make array node for the
// root where both element in the root point to the same (original)
// parent.<br>
// <embed src="images/SingletonMerge_DiffRootSamePar.svg"
// type="image/svg+xml"/></p>
//
// <p>Different stack tops pointing to different parents. Make array node for
// the root where each element points to the corresponding original
// parent.<br>
// <embed src="images/SingletonMerge_DiffRootDiffPar.svg"
// type="image/svg+xml"/></p>
//
// @param a the first {@link SingletonPredictionContext}
// @param b the second {@link SingletonPredictionContext}
// @param rootIsWildcard {@code true} if this is a local-context merge,
// otherwise false to indicate a full-context merge
// @param mergeCache
// /
mergeSingletons(a, b, rootIsWildcard, mergeCache) {
	if (mergeCache != null) {
		var previous = mergeCache.get(a, b);
		if (previous != null) {
			return previous;
		}
		previous = mergeCache.get(b, a);
		if (previous != null) {
			return previous;
		}
	}

	var rootMerge = mergeRoot(a, b, rootIsWildcard);
	if (rootMerge != null) {
		if (mergeCache != null) {
			mergeCache.set(a, b, rootMerge);
		}
		return rootMerge;
	}
	if (a.returnState == b.returnState) {
		var parent = merge(a.parentCtx, b.parentCtx, rootIsWildcard, mergeCache);
		// if parent is same as existing a or b parent or reduced to a parent,
		// return it
		if (parent == a.parentCtx) {
			return a; // ax + bx = ax, if a=b
		}
		if (parent == b.parentCtx) {
			return b; // ax + bx = bx, if a=b
		}
		// else: ax + ay = a'[x,y]
		// merge parents x and y, giving array node with x,y then remainders
		// of those graphs. dup a, a' points at merged array
		// new joined parent so create new singleton pointing to it, a'
		var spc = SingletonPredictionContext.create(parent, a.returnState);
		if (mergeCache != null) {
			mergeCache.set(a, b, spc);
		}
		return spc;
	} else { // a != b payloads differ
		// see if we can collapse parents due to $+x parents if local ctx
		var singleParent = null;
		if (a == b || (a.parentCtx != null && a.parentCtx == b.parentCtx)) { // ax +
																				// bx =
																				// [a,b]x
			singleParent = a.parentCtx;
		}
		if (singleParent != null) { // parents are same
			// sort payloads and use same parent
			var payloads = [ a.returnState, b.returnState ];
			if (a.returnState > b.returnState) {
				payloads[0] = b.returnState;
				payloads[1] = a.returnState;
			}
			var parents = [ singleParent, singleParent ];
			var apc = new ArrayPredictionContext(parents, payloads);
			if (mergeCache != null) {
				mergeCache.set(a, b, apc);
			}
			return apc;
		}
		// parents differ and can't merge them. Just pack together
		// into array; can't merge.
		// ax + by = [ax,by]
		var payloads = [ a.returnState, b.returnState ];
		var parents = [ a.parentCtx, b.parentCtx ];
		if (a.returnState > b.returnState) { // sort by payload
			payloads[0] = b.returnState;
			payloads[1] = a.returnState;
			parents = [ b.parentCtx, a.parentCtx ];
		}
		var a_ = new ArrayPredictionContext(parents, payloads);
		if (mergeCache != null) {
			mergeCache.set(a, b, a_);
		}
		return a_;
	}
}

//
// Handle case where at least one of {@code a} or {@code b} is
// {@link //EMPTY}. In the following diagrams, the symbol {@code $} is used
// to represent {@link //EMPTY}.
//
// <h2>Local-Context Merges</h2>
//
// <p>These local-context merge operations are used when {@code rootIsWildcard}
// is true.</p>
//
// <p>{@link //EMPTY} is superset of any graph; return {@link //EMPTY}.<br>
// <embed src="images/LocalMerge_EmptyRoot.svg" type="image/svg+xml"/></p>
//
// <p>{@link //EMPTY} and anything is {@code //EMPTY}, so merged parent is
// {@code //EMPTY} return left graph.<br>
// <embed src="images/LocalMerge_EmptyParent.svg" type="image/svg+xml"/></p>
//
// <p>Special case of last merge if local context.<br>
// <embed src="images/LocalMerge_DiffRoots.svg" type="image/svg+xml"/></p>
//
// <h2>Full-Context Merges</h2>
//
// <p>These full-context merge operations are used when {@code rootIsWildcard}
// is false.</p>
//
// <p><embed src="images/FullMerge_EmptyRoots.svg" type="image/svg+xml"/></p>
//
// <p>Must keep all contexts; {@link //EMPTY} in array is a special value (and
// null parent).<br>
// <embed src="images/FullMerge_EmptyRoot.svg" type="image/svg+xml"/></p>
//
// <p><embed src="images/FullMerge_SameRoot.svg" type="image/svg+xml"/></p>
//
// @param a the first {@link SingletonPredictionContext}
// @param b the second {@link SingletonPredictionContext}
// @param rootIsWildcard {@code true} if this is a local-context merge,
// otherwise false to indicate a full-context merge
// /
 mergeRoot(a, b, rootIsWildcard) {
	if (rootIsWildcard) {
		if (a == PredictionContext.EMPTY) {
			return PredictionContext.EMPTY; // // + b =//
		}
		if (b == PredictionContext.EMPTY) {
			return PredictionContext.EMPTY; // a +// =//
		}
	} else {
		if (a == PredictionContext.EMPTY && b == PredictionContext.EMPTY) {
			return PredictionContext.EMPTY; // $ + $ = $
		} else if (a == PredictionContext.EMPTY) { // $ + x = [$,x]
			var payloads = [ b.returnState,
					PredictionContext.EMPTY_RETURN_STATE ];
			var parents = [ b.parentCtx, null ];
			return new ArrayPredictionContext(parents, payloads);
		} else if (b == PredictionContext.EMPTY) { // x + $ = [$,x] ($ is always first if present)
			var payloads = [ a.returnState, PredictionContext.EMPTY_RETURN_STATE ];
			var parents = [ a.parentCtx, null ];
			return new ArrayPredictionContext(parents, payloads);
		}
	}
	return null;
}

//
// Merge two {@link ArrayPredictionContext} instances.
//
// <p>Different tops, different parents.<br>
// <embed src="images/ArrayMerge_DiffTopDiffPar.svg" type="image/svg+xml"/></p>
//
// <p>Shared top, same parents.<br>
// <embed src="images/ArrayMerge_ShareTopSamePar.svg" type="image/svg+xml"/></p>
//
// <p>Shared top, different parents.<br>
// <embed src="images/ArrayMerge_ShareTopDiffPar.svg" type="image/svg+xml"/></p>
//
// <p>Shared top, all shared parents.<br>
// <embed src="images/ArrayMerge_ShareTopSharePar.svg"
// type="image/svg+xml"/></p>
//
// <p>Equal tops, merge parents and reduce top to
// {@link SingletonPredictionContext}.<br>
// <embed src="images/ArrayMerge_EqualTop.svg" type="image/svg+xml"/></p>
// /
 mergeArrays(a, b, rootIsWildcard, mergeCache) {
	if (mergeCache != null) {
		var previous = mergeCache.get(a, b);
		if (previous != null) {
			return previous;
		}
		previous = mergeCache.get(b, a);
		if (previous != null) {
			return previous;
		}
	}
	// merge sorted payloads a + b => M
	var i = 0; // walks a
	var j = 0; // walks b
	var k = 0; // walks target M array

	var mergedReturnStates = [];
	var mergedParents = [];
	// walk and merge to yield mergedParents, mergedReturnStates
	while (i < a.returnStates.length && j < b.returnStates.length) {
		var a_parent = a.parents[i];
		var b_parent = b.parents[j];
		if (a.returnStates[i] == b.returnStates[j]) {
			// same payload (stack tops are equal), must yield merged singleton
			var payload = a.returnStates[i];
			// $+$ = $
			var bothDollars = payload == PredictionContext.EMPTY_RETURN_STATE &&
					a_parent == null && b_parent == null;
			var ax_ax = (a_parent != null && b_parent != null && a_parent == b_parent); // ax+ax
																							// ->
																							// ax
			if (bothDollars || ax_ax) {
				mergedParents[k] = a_parent; // choose left
				mergedReturnStates[k] = payload;
			} else { // ax+ay -> a'[x,y]
				var mergedParent = merge(a_parent, b_parent, rootIsWildcard, mergeCache);
				mergedParents[k] = mergedParent;
				mergedReturnStates[k] = payload;
			}
			i += 1; // hop over left one as usual
			j += 1; // but also skip one in right side since we merge
		} else if (a.returnStates[i] < b.returnStates[j]) { // copy a[i] to M
			mergedParents[k] = a_parent;
			mergedReturnStates[k] = a.returnStates[i];
			i += 1;
		} else { // b > a, copy b[j] to M
			mergedParents[k] = b_parent;
			mergedReturnStates[k] = b.returnStates[j];
			j += 1;
		}
		k += 1;
	}
	// copy over any payloads remaining in either array
	if (i < a.returnStates.length) {
		for (var p = i; p < a.returnStates.length; p++) {
			mergedParents[k] = a.parents[p];
			mergedReturnStates[k] = a.returnStates[p];
			k += 1;
		}
	} else {
		for (var p = j; p < b.returnStates.length; p++) {
			mergedParents[k] = b.parents[p];
			mergedReturnStates[k] = b.returnStates[p];
			k += 1;
		}
	}
	// trim merged if we combined a few that had same stack tops
	if (k < mergedParents.length) { // write index < last position; trim
		if (k == 1) { // for just one merged element, return singleton top
			var a_ = SingletonPredictionContext.create(mergedParents[0],
					mergedReturnStates[0]);
			if (mergeCache != null) {
				mergeCache.set(a, b, a_);
			}
			return a_;
		}
		mergedParents = mergedParents.sublist(0, k);
		mergedReturnStates = mergedReturnStates.sublist(0, k);
	}

	var M = new ArrayPredictionContext(mergedParents, mergedReturnStates);

	// if we created same array as a or b, return that instead
	// TODO: track whether this is possible above during merge sort for speed
	if (M == a) {
		if (mergeCache != null) {
			mergeCache.set(a, b, a);
		}
		return a;
	}
	if (M == b) {
		if (mergeCache != null) {
			mergeCache.set(a, b, b);
		}
		return b;
	}
	combineCommonParents(mergedParents);

	if (mergeCache != null) {
		mergeCache.set(a, b, M);
	}
	return M;
}

//
// Make pass over all <em>M</em> {@code parents} merge any {@code equals()}
// ones.
// /
 combineCommonParents(parents) {
	var uniqueParents = new Map();

	for (var p = 0; p < parents.length; p++) {
		var parent = parents[p];
		if (!(uniqueParents.containsKey(parent))) {
			uniqueParents[parent] = parent;
		}
	}
	for (var q = 0; q < parents.length; q++) {
		parents[q] = uniqueParents.get(parents[q]);
	}
}

getCachedPredictionContext(context, contextCache, visited) {
	if (context.isEmpty()) {
		return context;
	}
	var existing = visited.get(context) || null;
	if (existing != null) {
		return existing;
	}
	existing = contextCache.get(context);
	if (existing != null) {
		visited.put(context, existing);
		return existing;
	}
	var changed = false;
	var parents = [];
	for (var i = 0; i < parents.length; i++) {
		var parent = getCachedPredictionContext(context.getParent(i), contextCache, visited);
		if (changed || parent != context.getParent(i)) {
			if (!changed) {
				parents = [];
				for (var j = 0; j < context.length; j++) {
					parents[j] = context.getParent(j);
				}
				changed = true;
			}
			parents[i] = parent;
		}
	}
	if (!changed) {
		contextCache.add(context);
		visited.put(context, context);
		return context;
	}
	var updated = null;
	if (parents.length == 0) {
		updated = PredictionContext.EMPTY;
	} else if (parents.length == 1) {
		updated = SingletonPredictionContext.create(parents[0], context
				.getReturnState(0));
	} else {
		updated = new ArrayPredictionContext(parents, context.returnStates);
	}
	contextCache.add(updated);
	visited.put(updated, updated);
	visited.put(context, updated);

	return updated;
}

// ter's recursive version of Sam's getAllNodes()
getAllContextNodes(context, nodes, visited) {
	if (nodes == null) {
		nodes = [];
		return getAllContextNodes(context, nodes, visited);
	} else if (visited == null) {
		visited = new Map();
		return getAllContextNodes(context, nodes, visited);
	} else {
		if (context == null || visited.containsKey(context)) {
			return nodes;
		}
		visited.put(context, context);
		nodes.push(context);
		for (var i = 0; i < context.length; i++) {
			getAllContextNodes(context.getParent(i), nodes, visited);
		}
		return nodes;
	}
}
