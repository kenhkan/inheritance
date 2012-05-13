_ = require("underscore")
owl = require("deep_copy")


###
  Merge a value (`original`) by introducing another value (`introduced`) and "return" the result in Continuation-Passing Style (CPS).
  
  The merge follows these guidelines:
  
  1. If the values are arrays, concatenate them using `concat()`.
  2. If the values are objects, combine them. Conflicting properties are further merged.
  3. If the values are objects *and* there is a conflicting property that is a function, things get hairy. Let's say the original function is `f` and the introduced function is `g`. Here's the guidelines for function properties:
    a. `g` is called with `f` passed as the *last* argument. Calling `f` within `g` is the equivalent of calling super in other programming languages.
    b. A new function `h` is created to wrap around `g`. `h` becomes the method of the same name of the conflicting property of the new class.
    c. `h` takes the same list of arguments as `f` and `g` but the last argument of `h` is passed to `f` as the super of `f`.
    d. This setup allows this `h` to be further combined with child classes by chaining two sets of functions.
  4. If the values are functions *and* **either** values have a prototype property `isClass` with the value `true`, the two values are function class, create a new function class whose constructor would call the two functions' constructors (the original's first) and merge the prototype.
  5. Otherwise, the introduced value always takes precedence.
  6. However, if either one is undefined, use the other one, or `null` when both are undefined.
  7. No properties are ever removed, even when the value is `null`.
  
  This always deep copies everything to achieve blending multiple parents' prototype without modifying the parents' own prototype. As a result, this implementation is by definition *MUCH LESS* space-efficient than the default implementation of single inheritance in JavaScript.
  
  Prototype chain is also by definition "broken". For instance, if `A` is a subclass of `B` and `C`, `A.prototype !== B.prototype !== C.prototype`. It wouldn't make sense to have prototype chains, because there's only one prototype for any object class in JavaScript. In this example, should A use B or C's prototype? For consistency's sake, no prototype chain is used.
  
  Methods (properties that are functions) are tricky. Most of the time defining a method with the same name as the parent's means replacing the parent's implementation. However, because of the nature of multiple inheritance, sometimes you want to expand the functionality of a specific method rather than replace it. This is when we need #4 in the guidelines above. Note that either object can unilaterally declare merging.
  
  CPS is used in this implementation to allow the child function object's constructor to invoke both parents' constructors.
  
  @param original The original value
  @param introduced The introduced value
  @param {Object} context The result of the merge will be stored into the property by the name of the next parameter in this object
  @param {String} key This is the key of the context to store the merge in
###
merge = (original, introduced, context, key) ->

  ret = ((value) -> context[key] = value)

  # If either one is undefined or null, no need to merge, just copy the other one over
  if not original? or not introduced?
    ret(owl.deepCopy(original or introduced or null ))

  # If they're both arrays, concatenate them
  else if Object.prototype.toString.apply( original ) is "[object Array]" and
          Object.prototype.toString.apply( introduced ) is "[object Array]"
    ret(owl.deepCopy(original.concat(introduced)))

  # If they're both strings, prefer `introduced`
  else if Object.prototype.toString.apply( original ) is "[object String]" and
          Object.prototype.toString.apply( introduced ) is "[object String]"
    ret(owl.deepCopy(introduced))

  # If they're both objects, merge down
  else if typeof original is "object" and
          typeof introduced is "object"
    obj = {}
    oKeys = _.keys(original)
    iKeys = _.keys(introduced)
    commonKeys = _.intersection(oKeys, iKeys)
    oUniqKeys = _.difference(oKeys, commonKeys)
    iUniqKeys = _.difference(iKeys, commonKeys)

    # Merge common properties
    for key in commonKeys

      # Call both methods if the property is a method
      if typeof original[key] is "function" and
         typeof introduced[key] is "function"

        # Wrapping function is needed to create a new scope for value preservation
        obj[key] = ( () ->
          f = original[key]
          g = introduced[key]

          return () ->
            args = _.toArray(arguments)
            fSuper = args[args.length-1] # Potentially the super function object for `f` 

            # If the last argument is the super function object, extract it
            if typeof fSuper is "object" and fSuper.isSuper is true
              args.pop()
            # There is no provided super function
            else
              fSuper = { isSuper: true, uper: (() -> ) }

            # A new function of `f` to call `f` with the passed super
            f2 = () => f.apply(this, args.concat([fSuper]))
            gSuper = { isSuper: true, uper: f2 }

            # Call `g` with `f` as super
            g.apply(this, args.concat([gSuper]))
        )()

      # Merge otherwise
      else
        merge(original[key], introduced[key], obj, key)

    # Copy over unique properties
    for key in oUniqKeys
      obj[key] = owl.deepCopy(original[key])

    for key in iUniqKeys
      obj[key] = owl.deepCopy(introduced[key])

    # Return
    ret(obj)

  # If they're both function objects *and* `isClass` is specified, it means that both objects are function objects. Create a cross-constructor and merge the prototype.
  else if typeof original is "function" and typeof introduced is "function" and
          (original::isClass is true or introduced::isClass is true)
    # Create child function object
    Class = () ->
      # Call constructors
      original.apply(this, arguments)
      introduced.apply(this, arguments)
      return

    # Merge the prototypes
    merge(original.prototype, introduced.prototype, Class, "prototype")

    # Set constructor
    Class::constructor = Class

    # Return the merged function class
    ret(Class)

  # Otherwise, copy over `introduced` as it takes precedence
  else
    ret(owl.deepCopy(introduced))


###
  Provide multiple inheritance of a bunch of objects. Return the combined object.
 
  This builds on top of `merge()`. It allows the child to inherit from multiple parents by chaining merges. It is also a wrapper to make it more user-friendly by using the regular `return` mechanism rather than CPS.
 
  @see merge()
  @param {Object} sources[] The parent objects
  @returns {Object} The child object
###
inherit = () ->
  # Setup
  sources = _.toArray(arguments)

  # Iteratively merge sources
  a = sources[0] # Initial
  c = { result: null } # Result container

  for b in sources
    merge(a, b, c, "result") # Merge

    # For next iteration
    a = c.result

  # Result
  a


module.exports =
  merge: merge
  inherit: inherit
