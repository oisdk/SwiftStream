//
//  State.swift
//  SwiftStream
//
//  Created by Donnacha Oisín Kidney on 04/05/2016.
//  Copyright © 2016 Donnacha Oisín Kidney. All rights reserved.
//

public struct Stateful<S,A> {
  let runStateful: S -> (A, S)
}

extension Stateful {
  public init(_ f: S -> (A, S)) {
    runStateful = f
  }
  public init(pure: A) {
    runStateful = { s in (pure, s) }
  }
  public func map<B>(f: A -> B) -> Stateful<S,B> {
    return Stateful<S,B> { s in
      let (x,n) = self.runStateful(s)
      return (f(x), n)
    }
  }
  public func flatMap<B>(f: A -> Stateful<S,B>) -> Stateful<S,B> {
    return Stateful<S,B> { s in
      let (x,n) = self.runStateful(s)
      return f(x).runStateful(n)
    }
  }
  public func evalStateful(s: S) -> A {
    return self.runStateful(s).0
  }
  public func execStateful(s: S) -> S {
    return self.runStateful(s).1
  }
}

infix operator <^> { precedence 140 associativity left }

public func <^><S,A,B>(lhs: Stateful<S,A -> B>, rhs: Stateful<S,A>) -> Stateful<S,B> {
  return Stateful<S,B> { s in
    let (x,n) = lhs.runStateful(s)
    return rhs.map(x).runStateful(n)
  }
}

infix operator ^> { precedence 150 associativity left }

public func ^><A,B,S>(lhs: Stateful<S,A>, rhs: Stateful<S,B>) -> Stateful<S,B> {
  return Stateful { s in rhs.runStateful(lhs.execStateful(s)) }
}

infix operator <^ { precedence 150 associativity left }

public func <^<A,B,S>(lhs: Stateful<S,A>, rhs: Stateful<S,B>) -> Stateful<S,A> {
  return lhs.map(const) <^> rhs
}


public func put<S>(s: S) -> Stateful<S,()> {
  return Stateful<S,()> { _ in ((),s) }
}

public func get<S>() -> Stateful<S,S> {
  return Stateful<S,S> { s in (s,s) }
}

public func gets<S,A>(f: S -> A) -> Stateful<S,A> {
  return Stateful<S,A> { s in (f(s), s) }
}

public func modify<S>(f: S -> S) -> Stateful<S,()> {
  return Stateful<S,()> { s in ((), f(s)) }
}

public func mapStateful<S,T,A>(f: T -> (S, S -> T)) -> Stateful<S,A> -> Stateful<T,A> {
  return { state in
    Stateful<T,A> { s in
      let (c,b) = f(s)
      let (x,n) = state.runStateful(c)
      return (x, b(n))
    }
  }
}

public func liftToState<A,B,S>(f: (A,S) -> (B,S)) -> A -> Stateful<S,B> {
  return { x in Stateful(curry(f)(x)) }
}