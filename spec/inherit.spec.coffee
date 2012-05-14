inherit = require("../build/inherit")


describe "multiple inheritance", () ->

  A = class
    isClass: true
    a: 1
    b: [1, 2, 3]
    c: { x: 1, y: 2 }
    d: () -> 1
    e: () -> 3
    f: []
    constructor: () -> @f.push(1)

  A.m = 1
  A.n = 2

  B = inherit A, class
    a: 11
    b: [11, 12, 13]
    c: { x: 11, z: 13 }
    d: () -> 2
    e: (s) -> s.uper() + 7
    constructor: () -> @f.push(2)

  B.m = 3
  B.o = 4

  x = new A
  y = new B
  z = new B

  it "separates the superclass with the subclass and their instances apart", () ->
    expect(A).not.toBe(B)
    expect(A).not.toEqual(B)
    expect(x).not.toBe(y)
    expect(x).not.toEqual(y)

  it "retains the properties for superclass", () ->
    expect(x.a).toEqual(1)
    expect(x.b).toEqual([1, 2, 3])
    expect(x.c).toEqual({ x: 1, y: 2})
    expect(x.d()).toEqual(1)
    expect(x.e()).toEqual(3)
    expect(x.f).toEqual([1])

  it "merges the properties for subclass", () ->
    expect(y.a).toEqual(11)
    expect(y.b).toEqual([1, 2, 3, 11, 12, 13])
    expect(y.c).toEqual({ x: 11, y: 2, z: 13})
    expect(y.d()).toEqual(2)
    expect(y.e()).toEqual(10)
    expect(y.f).toEqual([1, 2, 1, 2]) # The result of both instances

    expect(z.a).toEqual(11)
    expect(z.b).toEqual([1, 2, 3, 11, 12, 13])
    expect(z.c).toEqual({ x: 11, y: 2, z: 13})
    expect(z.d()).toEqual(2)
    expect(z.e()).toEqual(10)
    expect(z.f).toEqual([1, 2, 1, 2]) # The result of both instances

  it "copies over the class (static) properties", () ->
    expect(A.m).toEqual(1)
    expect(A.n).toEqual(2)
    expect(B.m).toEqual(3)
    expect(B.n).toEqual(2)
    expect(B.o).toEqual(4)

  it "does NOT have separate spaces for each instance, just like in normal prototypical code", () ->
    expect(y).not.toBe(z)
    expect(y.a).toBe(z.a)
    expect(y.b).toBe(z.b)
    expect(y.c).toBe(z.c)
    expect(y.d).toBe(z.d)
    expect(y.e).toBe(z.e)
    expect(y.f).toBe(z.f)

  it "however has a `create()` method to create truly separate instances despite JavaScript's prototypical model", () ->
    y = B::create()
    z = B::create()

    expect(y).not.toBe(z)
    expect(y.a).toBe(z.a) # Primitive data
    expect(y.b).not.toBe(z.b)
    expect(y.c).not.toBe(z.c)
    expect(y.d).toBe(z.d) # Function
    expect(y.e).toBe(z.e) # Function
    expect(y.f).not.toBe(z.f)
