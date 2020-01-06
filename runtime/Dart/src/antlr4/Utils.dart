/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

import 'dart:math';
import 'package:collection/collection.dart';


String arrayToString(a) {
    return "[" + a.join(", ") + "]";
}

seed() => (Random().nextDouble() * pow(2, 32)).round();

// TODO zero fill hash code
hashCode(String content) {
    var remainder, bytes, h1, h1b, c1, c1b, c2, c2b, k1, i,
        key = content.toString();

    remainder = key.length & 3; // key.length % 4
    bytes = key.length - remainder;
    h1 = 0xcc9e2d51;
    c2 = 0x1b873593;
    i = 0;

    while (i < bytes) {
        k1 =
            ((key.codeUnitAt(i) & 0xff)) |
            ((key.codeUnitAt(++i) & 0xff) << 8) |
            ((key.codeUnitAt(++i) & 0xff) << 16) |
            ((key.codeUnitAt(++i) & 0xff) << 24);
        ++i;

        k1 = ((((k1 & 0xffff) * c1) + ((((k1 >> 16) * c1) & 0xffff) << 16))) & 0xffffffff;
        k1 = (k1 << 15) | (k1 >> 17);
        k1 = ((((k1 & 0xffff) * c2) + ((((k1 >> 16) * c2) & 0xffff) << 16))) & 0xffffffff;

        h1 ^= k1;
        h1 = (h1 << 13) | (h1 >> 19);
        h1b = ((((h1 & 0xffff) * 5) + ((((h1 >> 16) * 5) & 0xffff) << 16))) & 0xffffffff;
        h1 = (((h1b & 0xffff) + 0x6b64) + ((((h1b >> 16) + 0xe654) & 0xffff) << 16));
    }

    k1 = 0;

    switch (remainder) {
        case 3:
            k1 ^= (key.codeUnitAt(i + 2) & 0xff) << 16;
            break;
        case 2:
            k1 ^= (key.codeUnitAt(i + 1) & 0xff) << 8;
            break;
        case 1:
            k1 ^= (key.codeUnitAt(i) & 0xff);

            k1 = (((k1 & 0xffff) * c1) + ((((k1 >> 16) * c1) & 0xffff) << 16)) & 0xffffffff;
            k1 = (k1 << 15) | (k1 >> 17);
            k1 = (((k1 & 0xffff) * c2) + ((((k1 >> 16) * c2) & 0xffff) << 16)) & 0xffffffff;
            h1 ^= k1;
    }

    h1 ^= key.length;

    h1 ^= h1 >> 16;
    h1 = (((h1 & 0xffff) * 0x85ebca6b) + ((((h1 >> 16) * 0x85ebca6b) & 0xffff) << 16)) & 0xffffffff;
    h1 ^= h1 >> 13;
    h1 = ((((h1 & 0xffff) * 0xc2b2ae35) + ((((h1 >> 16) * 0xc2b2ae35) & 0xffff) << 16))) & 0xffffffff;
    h1 ^= h1 >> 16;

    return h1 >> 0;
}

standardEqualsFunction(a, b) {
    return a.equals(b);
}

standardHashCodeFunction(Object a) {
    return a.hashCode();
}

class Set {
  var data = {};
  final hashFunction;
  final equalsFunction;
  Set({this.hashFunction=standardHashCodeFunction, this.equalsFunction=standardEqualsFunction});



  get length {
      var l = 0;
      for (var key in this.data.keys) {
          if (key.indexOf("hash_") == 0) {
              l = l + this.data[key].length;
          }
      }
      return l;
  }


add (value) {
    var hash = this.hashFunction(value);
    var key = "hash_" + hash;
    if (this.data.keys.contains(key)) {
        var values = this.data[key];
        for (var i = 0; i < values.length; i++) {
            if (this.equalsFunction(value, values[i])) {
                return values[i];
            }
        }
        values.push(value);
        return value;
    } else {
        this.data[key] = [value];
        return value;
    }
}

contains (value) {
    return this.get(value) != null;
}

get (value) {
    var hash = this.hashFunction(value);
    var key = "hash_" + hash;
    if (this.data.keys.contains(key)) {
        var values = this.data[key];
        for (var i = 0; i < values.length; i++) {
            if (this.equalsFunction(value, values[i])) {
                return values[i];
            }
        }
    }
    return null;
}

values() {
    var l = [];
    for (var key in this.data.keys) {
        if (key.indexOf("hash_") == 0) {
            l += this.data[key];
        }
    }
    return l;
}

toString () {
    return arrayToString(this.values());
}
}

class BitSet {
  final data = [];


add (value) {
    this.data[value] = true;
}

or (st) {
    var bits = this;
    Object.keys(st.data).map((alt) {
        bits.add(alt);
    });
}

remove (value) {
    this.data.remove(value);
}

contains (value) {
    return this.data[value] == true;
}

List values () {
    return Object.keys(this.data);
}

minValue () {
    return min.apply(null, this.values());
}

hashCode () {
    var hash = new Hash();
    hash.update(this.values());
    return hash.finish();
}

equals (other) {
    if (!(other is BitSet)) {
        return false;
    }
    return this.hashCode() == other.hashCode();
}


    get length {
        return this.values().length;
    }


  toString () {
      return "{" + this.values().join(", ") + "}";
  }
}

class Map{ 
    final data = {};
  
  final hashFunction;
  final equalsFunction;
  Map({this.hashFunction=standardHashCodeFunction, this.equalsFunction=standardEqualsFunction});



    get length {
        var l = 0;
        for (var hashKey in this.data) {
            if (hashKey.indexOf("hash_") == 0) {
                l = l + this.data[hashKey].length;
            }
        }
        return l;
    }


put (key, value) {
    var hashKey = "hash_" + this.hashFunction(key);
    if (hashKey in this.data) {
        var entries = this.data[hashKey];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (this.equalsFunction(key, entry.key)) {
                var oldValue = entry.value;
                entry.value = value;
                return oldValue;
            }
        }
        entries.push({key:key, value:value});
        return value;
    } else {
        this.data[hashKey] = [{key:key, value:value}];
        return value;
    }
}

containsKey (key) {
    var hashKey = "hash_" + this.hashFunction(key);
    if(hashKey in this.data) {
        var entries = this.data[hashKey];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (this.equalsFunction(key, entry.key))
                return true;
        }
    }
    return false;
}

get (key) {
    var hashKey = "hash_" + this.hashFunction(key);
    if(hashKey in this.data) {
        var entries = this.data[hashKey];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if (this.equalsFunction(key, entry.key))
                return entry.value;
        }
    }
    return null;
}

entries () {
    var l = [];
    for (var key in this.data) {
        if (key.indexOf("hash_") == 0) {
            l += this.data[key];
        }
    }
    return l;
}


getKeys () {
    return this.entries().map((e) {
        return e.key;
    });
}


getValues () {
    return this.entries().map((e) {
            return e.value;
    });
}


toString () {
    var ss = this.entries().map((entry) {
        return '{' + entry.key + ':' + entry.value + '}';
    });
    return '[' + ss.join(", ") + ']';
}
}

class AltDict {
    final data = {};

get (key) {
    key = "k-" + key;
    if (key in this.data) {
        return this.data[key];
    } else {
        return null;
    }
}

put (key, value) {
    key = "k-" + key;
    this.data[key] = value;
}

values () {
    var data = this.data;
    var keys = Object.keys(this.data);
    return keys.map(function (key) {
        return data[key];
    });
}
}

class DoubleDict {
    var defaultMapCtor;
    var cacheMap;
  
  DoubleDict({this.defaultMapCtor=Map}) {
    cacheMap= this.defaultMapCtor();
  }


get (a, b) {
    var d = this.cacheMap.get(a) || null;
    return d == null ? null : (d.get(b) || null);
}

set (a, b, o) {
    var d = this.cacheMap.get(a) ?? null;
    if (d == null) {
        d = this.defaultMapCtor();
        this.cacheMap.put(a, d);
    }
    d.put(b, o);
}
}

class Hash {
    var count = 0;
    var hash = 0;


update () {
    for(var i=0;i<arguments.length;i++) {
        var value = arguments[i];
        if (value == null)
            continue;
        if(Array.isArray(value))
            this.update.apply(this, value);
        else {
            var k = 0;
            switch (typeof(value)) {
                case 'undefined':
                case 'function':
                    continue;
                case 'number':
                case 'boolean':
                    k = value;
                    break;
                case 'string':
                    k = value.hashCode();
                    break;
                default:
                    if(value.updateHashCode)
                        value.updateHashCode(this);
                    else
                        console.log("No updateHashCode for " + value.toString())
                    continue;
            }
            k = k * 0xCC9E2D51;
            k = (k << 15) | (k >> (32 - 15));
            k = k * 0x1B873593;
            this.count = this.count + 1;
            var hash = this.hash ^ k;
            hash = (hash << 13) | (hash >> (32 - 13));
            hash = hash * 5 + 0xE6546B64;
            this.hash = hash;
        }
    }
}

finish () {
    var hash = this.hash ^ (this.count * 4);
    hash = hash ^ (hash >> 16);
    hash = hash * 0x85EBCA6B;
    hash = hash ^ (hash >> 13);
    hash = hash * 0xC2B2AE35;
    hash = hash ^ (hash >> 16);
    return hash;
}

 hashStuff() {
    var hash = new Hash();
    hash.update.apply(hash, arguments);
    return hash.finish();
}

}

escapeWhitespace(String s, bool escapeSpaces) {
    s = s.replaceAll("\t", r"\t")
         .replaceAll("\n", r"\n")
         .replaceAll("\r", r"\r");
    if (escapeSpaces) {
        s = s.replaceAll(" ", "\u00B7");
    }
    return s;
}

titleCase(String str) {
    return str.replaceAllMapped("\w\S*", (txt) {
        return txt.charAt(0).toUpperCase() + txt.substr(1);
    });
}
