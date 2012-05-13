inherit = require("../build/inherit")


describe "multiple inheritance", () ->

  it "inherits two or more objects", () ->
    A = class
      isClass: true
      a: 1
      b: [1, 2, 3]
      c: { x: 1, y: 2 }
      d: () -> 1
      e: () -> 3
      f: []
      constructor: () -> @f.push(1)

    B = inherit A, class
      a: 11
      b: [11, 12, 13]
      c: { x: 11, z: 13 }
      d: () -> 2
      e: (s) -> s.uper() + 7
      constructor: () -> @f.push(2)

    x = new B

    expect(x.a).toEqual(11)
    expect(x.b).toEqual([1, 2, 3, 11, 12, 13])
    expect(x.c).toEqual({ x: 11, y: 2, z: 13})
    expect(x.d()).toEqual(2)
    expect(x.e()).toEqual(10)
    expect(x.f).toEqual([1, 2])
