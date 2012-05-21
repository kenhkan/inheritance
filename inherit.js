// Dependencies are automatically added on build


// Deep copying
//
// @param {Object} original The object to copy
// @returns {Object} A copy of the original object
copy = owl.deepCopy;

// Merge a value (`original`) by introducing another value (`introduced`) and "return" the result in Continuation-Passing Style (CPS).
//
// The merge follows these guidelines:
//
// 1. If the values are arrays, concatenate them using `concat()`.
// 2. If the values are objects, combine them. Conflicting properties are further merged.
// 3. If the values are objects *and* there is a conflicting property that is a function, things get hairy. Let's say the original function is `f` and the introduced function is `g`. Here's the guidelines for function properties:
//    a. `g` is called with `f` passed as the *last* argument. Calling `f` within `g` is the equivalent of calling super in other programming languages.
//    b. A new function `h` is created to wrap around `g`. `h` becomes the method of the same name of the conflicting property of the new class.
//    c. `h` takes the same list of arguments as `f` and `g` but the last argument of `h` is passed to `f` as the super of `f`.
//    d. This setup allows this `h` to be further combined with child classes by chaining two sets of functions.
// 4. If the values are functions *and* **either** values have a prototype property `isClass` with the value `true`, the two values are function class, create a new function class whose constructor would call the two functions' constructors (the original's first) and merge the prototype.
// 5. Otherwise, the introduced value always takes precedence.
// 6. However, if either one is undefined, use the other one, or `null` when both are undefined.
// 7. No properties are ever removed, even when the value is `null`.
//
// This always deep copies everything to achieve blending multiple parents' prototype without modifying the parents' own prototype. As a result, this implementation is by definition *MUCH LESS* space-efficient than the default implementation of single inheritance in JavaScript.
//
// Prototype chain is also by definition "broken". For instance, if `A` is a subclass of `B` and `C`, `A.prototype !== B.prototype !== C.prototype`. It wouldn't make sense to have prototype chains, because there's only one prototype for any object class in JavaScript. In this example, should A use B or C's prototype? For consistency's sake, no prototype chain is used.
//
// Methods (properties that are functions) are tricky. Most of the time defining a method with the same name as the parent's means replacing the parent's implementation. However, because of the nature of multiple inheritance, sometimes you want to expand the functionality of a specific method rather than replace it. This is when we need #4 in the guidelines above. Note that either object can unilaterally declare merging.
//
// CPS is used in this implementation to allow the child function object's constructor to invoke both parents' constructors. You can also capture the return value if that is not needed.
//
// @param original The original value
// @param introduced The introduced value
// @param {Object} [context] The result of the merge will be stored into the property by the name of the next parameter in this object
// @param {String} [key] This is the key of the context to store the merge in
// @returns Whatever the merged value is
merge = function( original, introduced, context, key ) {

  var ret = function( value ) {
    if( !_.isUndefined( key ) && !_.isNull( key ) ) {
      context[key] = value;
    }

    return value;
  }

  // If either one is undefined or null, no need to merge, just copy the other one over
  if( _.isUndefined( original ) || _.isNull( original ) ||
      _.isUndefined( introduced ) || _.isNull( introduced ) ) {
    ret( copy( original || introduced || null ) );
  }

  // If they're both arrays, concatenate them
  else if( Object.prototype.toString.apply( original ) === '[object Array]' &&
           Object.prototype.toString.apply( introduced ) === '[object Array]' ) {
    ret( copy( original.concat( introduced ) ) );
  }

  // If they're both strings, prefer `introduced`
  else if( Object.prototype.toString.apply( original ) === '[object String]' &&
           Object.prototype.toString.apply( introduced ) === '[object String]' ) {
    ret( copy( introduced ) );
  }

  // If they're both objects, merge down
  else if( typeof original === 'object' &&
           typeof introduced === 'object' ) {
    var i, len, k, h;
    var obj = {};
    var oKeys = _.keys( original );
    var iKeys = _.keys( introduced );
    var commonKeys = _.intersection( oKeys, iKeys );
    var oUniqKeys = _.difference( oKeys, commonKeys );
    var iUniqKeys = _.difference( iKeys, commonKeys );

    // Merge common properties
    for( i=0, len=commonKeys.length; i<len; i++ ) {
      k = commonKeys[i];

      // Call both methods if the property is a method
      if( ( typeof original[k] === 'function' ) &&
          ( typeof introduced[k] === 'function' ) ) {
        // Wrapping function is needed to create a new scope for value preservation
        obj[k] = (function() {
          var f = original[k];
          var g = introduced[k];

          return function() {
            var args = _.toArray(arguments);
            var fSuper = args[args.length-1]; // Potentially the super function object for `f` 
            var gSuper;
            var that = this;

            // If the last argument is the super function object, extract it
            if( typeof fSuper === 'object' && fSuper.isSuper === true ) {
              args.pop();
            }

            // There is no provided super function
            else {
              fSuper = { isSuper: true, uper: function() {} };
            }

            // A new function of `f` to call `f` with the passed super
            f2 = function() { return f.apply(that, args.concat([fSuper])); }
            gSuper = { isSuper: true, uper: f2 };

            // Call `g` with `f` as super
            return g.apply(that, args.concat([gSuper]));
          };
        })();
      }

      // Merge otherwise
      else {
        merge( original[k], introduced[k], obj, k );
      }
    }

    // Copy over unique properties
    for( i=0, len=oUniqKeys.length; i<len; i++ ) {
      k = oUniqKeys[i];

      obj[k] = copy( original[k] );
    }

    for( i=0, len=iUniqKeys.length; i<len; i++ ) {
      k = iUniqKeys[i];

      obj[k] = copy( introduced[k] );
    }

    // Return
    ret( obj );
  }

  // If they're both function objects *and* `isClass` is specified, it means that both objects are function objects. Create a cross-constructor and merge the prototype.
  else if( typeof original === 'function' &&
           typeof introduced === 'function' &&
           ( original.prototype.isClass === true ||
             introduced.prototype.isClass === true ) ) {
    var staticKeys, staticKey, i, len;

    // Create child function object
    function Class() {
      // Call constructors
      original.apply( this, arguments );
      introduced.apply( this, arguments );
    }

    // Merge the prototypes
    merge( original.prototype, introduced.prototype, Class, 'prototype' );

    // Set constructor
    Class.prototype.constructor = Class;

    // Merge its class properties but cannot use `merge()` because it'd trigger a stack overflow
    ks = _.union( Object.keys(original), Object.keys(introduced) );

    for( i=0, len=ks.length; i<len; i++ ) {
      k = ks[i];

      // Prototype has been copied over through merging
      if( k !== 'prototype' ) {
        merge( original[k], introduced[k], Class, k );
      }
    }

    // Add a `create()` method so you can create truly separate instances
    /*
      Create a truly separate instance from this class

      Modified from [Use of .apply() with 'new' operator. Is this possible?](http://stackoverflow.com/questions/1606797/use-of-apply-with-new-operator-is-this-possible/#1608546)

      @param args* The argument list to be passed to the constructor
      @returns {Class} An instance of this class
    */
    Class.prototype.create = function() {
      var args = _.toArray(arguments);
      var ctor = this.constructor;
      var C = function() { ctor.apply(this, args); }

      C.prototype = copy(this);
      return new C;
    };

    // Return the merged function class
    ret( Class );
  }

  // Otherwise, copy over `introduced` as it takes precedence
  else {
    ret( copy( introduced ) );
  }
};

// Provide multiple inheritance of a bunch of objects. Return the combined object.
//
// This builds on top of `merge()`. It allows the child to inherit from multiple parents by chaining merges. It is also a wrapper to make it more user-friendly by using the regular `return` mechanism rather than CPS.
//
// @see merge
// @param {Object} sources[] The parent objects
// @returns {Object} The child object
inherit = function() {
  var i, len, a, b, c;
  var container;
  var sources;

  // Setup
  sources = _.toArray( arguments );

  // Iteratively merge sources
  a = sources[0]; // Initial
  c = { result: null }; // Result container

  for(i=1, len=sources.length; i<len; i++) {
    b = sources[i]; // Next source

    merge( a, b, c, "result" ); // Merge

    // For next iteration
    a = c.result;
  }

  // Result
  return a;
};

// A helper function to parse the arguments so it returns only the super.
//
// @see inherit.args
// @param {Object[]} functionArgs The function arguments to parse
// @returns The super function; null if there is none
inherit.supr = function(functionArgs) {
  var args = _.toArray(functionArgs);
  var s = args[args.length-1];

  if(typeof s !== "undefined" && s !== null &&
     s.isSuper === true) {
    return s.uper;
  } else {
    return null;
  }
};

// A helper function to parse the arguments so it returns only true arguments. You use this for inherited functions because the function arguments contain a reference to super as the last argument
//
// @see inherit.super
// @param {Object[]} functionArgs The function arguments to parse
// @returns The true arguments
inherit.args = function(functionArgs) {
  var args = _.toArray(functionArgs);
  var s = args[args.length-1];

  // Returns all but the last if there is a super
  if(typeof s !== "undefined" && s !== null &&
     s.isSuper === true) {
    return args.slice(0, args.length-1);
  // Otherwise, return the entire argument list
  } else {
    return args;
  }
};


inherit.merge = merge;
module.exports = inherit;
