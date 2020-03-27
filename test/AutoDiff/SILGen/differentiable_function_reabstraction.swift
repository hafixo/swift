// RUN: %empty-directory(%t)
// RUN: %target-build-swift -Xfrontend -enable-experimental-differentiable-programming %s -o %t/main
// RUN: %target-run %t/main

import _Differentiation
import StdlibUnittest

var ReabstractionTests = TestSuite("DifferentiableFunctionReabstraction")

// TODO(TF-843): Uncomment after upstreaming differential operators.
func gradient<T, U>(at x: T, in body: @differentiable (T) -> U) -> T.TangentVector {
  fatalError()
}
func pullback<T, U>(
  at x: T, in body: @differentiable (T) -> U) -> (U.TangentVector
) -> T.TangentVector {
  fatalError()
}

ReabstractionTests.test("diff param concrete => generic") {
  func grad<T: Differentiable>(_ f: @differentiable (T) -> Float, at x: T)
    -> T.TangentVector
  {
    gradient(at: x, in: f)
  }
  func inner(_ x: Float) -> Float {
    7 * x * x
  }
  expectEqual(Float(7 * 2 * 3), grad(inner, at: 3))
}

ReabstractionTests.test("nondiff param concrete => generic") {
  func grad<T: Differentiable>(
    _ f: @escaping @differentiable (Float, @noDerivative T) -> Float, at x: Float, _ y: T
  ) -> Float {
    gradient(at: x) { f($0, y) }
  }
  func inner(_ x: Float, _ y: Float) -> Float {
    7 * x * x + y
  }
  expectEqual(Float(7 * 2 * 3), grad(inner, at: 3, 10))
}

ReabstractionTests.test("diff param and nondiff param concrete => generic") {
  func grad<T: Differentiable>(
    _ f: @escaping @differentiable (T, @noDerivative T) -> Float, at x: T, _ y: T
  ) -> T.TangentVector {
    gradient(at: x) { f($0, y) }
  }
  func inner(_ x: Float, _ y: Float) -> Float {
    7 * x * x + y
  }
  expectEqual(Float(7 * 2 * 3), grad(inner, at: 3, 10))
}

ReabstractionTests.test("result concrete => generic") {
  func grad<T: Differentiable>(
    _ f: @differentiable (Float) -> T, at x: Float, seed: T.TangentVector
  ) -> Float {
    pullback(at: x, in: f)(seed)
  }
  func inner(_ x: Float) -> Float {
    7 * x * x
  }
  expectEqual(Float(7 * 2 * 3), grad(inner, at: 3, seed: 1))
}

protocol HasFloat: Differentiable {
  @differentiable
  var float: Float { get }

  @differentiable
  init(float: Float)
}

extension Float: HasFloat {
  @differentiable
  var float: Float { self }

  @differentiable
  init(float: Float) { self = float }
}

ReabstractionTests.test("diff param generic => concrete") {
  func inner<T: HasFloat>(x: T) -> Float {
    7 * x.float * x.float
  }
  let transformed: @differentiable (Float) -> Float = inner
  expectEqual(Float(7 * 3 * 3), transformed(3))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: transformed))
}

ReabstractionTests.test("nondiff param generic => concrete") {
  func inner<T: HasFloat>(x: Float, y: T) -> Float {
    7 * x * x + y.float
  }
  let transformed: @differentiable (Float, @noDerivative Float) -> Float = inner
  expectEqual(Float(7 * 3 * 3 + 10), transformed(3, 10))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3) { transformed($0, 10) })
}

ReabstractionTests.test("diff param and nondiff param generic => concrete") {
  func inner<T: HasFloat>(x: T, y: T) -> Float {
    7 * x.float * x.float + y.float
  }
  let transformed: @differentiable (Float, @noDerivative Float) -> Float = inner
  expectEqual(Float(7 * 3 * 3 + 10), transformed(3, 10))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3) { transformed($0, 10) })
}

ReabstractionTests.test("result generic => concrete") {
  func inner<T: HasFloat>(x: Float) -> T {
    T(float: 7 * x * x)
  }
  let transformed: @differentiable (Float) -> Float = inner
  expectEqual(Float(7 * 3 * 3), transformed(3))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: transformed))
}

ReabstractionTests.test("diff param concrete => generic => concrete") {
  typealias FnTy<T: Differentiable> = @differentiable (T) -> Float
  func id<T: Differentiable>(_ f: @escaping FnTy<T>) -> FnTy<T> { f }
  func inner(_ x: Float) -> Float {
    7 * x * x
  }
  let transformed = id(inner)
  expectEqual(Float(7 * 3 * 3), transformed(3))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: transformed))
}

ReabstractionTests.test("nondiff param concrete => generic => concrete") {
  typealias FnTy<T: Differentiable> = @differentiable (Float, @noDerivative T)
    -> Float
  func id<T: Differentiable>(_ f: @escaping FnTy<T>) -> FnTy<T> { f }
  func inner(_ x: Float, _ y: Float) -> Float {
    7 * x * x + y
  }
  let transformed = id(inner)
  expectEqual(Float(7 * 3 * 3 + 10), transformed(3, 10))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3) { transformed($0, 10) })
}

ReabstractionTests.test(
  "diff param and nondiff param concrete => generic => concrete"
) {
  typealias FnTy<T: Differentiable> = @differentiable (T, @noDerivative T) ->
    Float
  func id<T: Differentiable>(_ f: @escaping FnTy<T>) -> FnTy<T> { f }
  func inner(_ x: Float, _ y: Float) -> Float {
    7 * x * x + y
  }
  let transformed = id(inner)
  expectEqual(Float(7 * 3 * 3 + 10), transformed(3, 10))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3) { transformed($0, 10) })
}

ReabstractionTests.test("result concrete => generic => concrete") {
  typealias FnTy<T: Differentiable> = @differentiable (Float) -> T
  func id<T: Differentiable>(_ f: @escaping FnTy<T>) -> FnTy<T> { f }
  func inner(_ x: Float) -> Float {
    7 * x * x
  }
  let transformed = id(inner)
  expectEqual(Float(7 * 3 * 3), transformed(3))
  expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: transformed))
}

ReabstractionTests.test(
  "@differentiable function => opaque generic => concrete"
) {
  func id<T>(_ t: T) -> T { t }
  let inner: @differentiable (Float) -> Float = { 7 * $0 * $0 }

  // TODO(TF-1122): Actually using `id` causes a segfault at runtime.
  // let transformed = id(inner)
  // expectEqual(Float(7 * 3 * 3), transformed(3))
  // expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: id(inner)))
}

ReabstractionTests.test("@differentiable function => opaque Any => concrete") {
  func id(_ any: Any) -> Any { any }
  let inner: @differentiable (Float) -> Float = { 7 * $0 * $0 }

  // TODO(TF-1122): Actually using `id` causes a segfault at runtime.
  // let transformed = id(inner)
  // let casted = transformed as! @differentiable (Float) -> Float
  // expectEqual(Float(7 * 3 * 3), casted(3))
  // expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: casted))
}

ReabstractionTests.test("access @differentiable function using KeyPath") {
  struct Container {
    let f: @differentiable (Float) -> Float
  }
  let container = Container(f: { 7 * $0 * $0 })
  let kp = \Container.f

  // TODO(TF-1122): Actually using `kp` causes a segfault at runtime.
  // let extracted = container[keyPath: kp]
  // expectEqual(Float(7 * 3 * 3), extracted(3))
  // expectEqual(Float(7 * 2 * 3), gradient(at: 3, in: extracted))
}

runAllTests()
