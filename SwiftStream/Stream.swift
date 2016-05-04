//
//  Stream.swift
//  SwiftStream
//
//  Created by Donnacha Oisín Kidney on 04/05/2016.
//  Copyright © 2016 Donnacha Oisín Kidney. All rights reserved.
//

public enum SizeGuess {
  case LargerThan(Int), SmallerThan(Int), Exactly(Int), Infinite, Unknown
}

private extension SizeGuess {
  var smaller: SizeGuess {
    switch self {
    case .LargerThan: return .Unknown
    case let .Exactly(n): return .SmallerThan(n)
    default: return self
    }
  }
}

extension SizeGuess: CustomStringConvertible {
  public var description: String {
    switch self {
    case let .LargerThan(n): return "Larger than \(n)"
    case let .SmallerThan(n): return "Smaller than \(n)"
    case let .Exactly(n): return "Exactly \(n)"
    case .Infinite: return "Infinite"
    case .Unknown: return "Unknown"
    }
  }
}

public struct StatefulStream<Source: SequenceType, State, Element> {
  private let source: Source
  public  let size: SizeGuess
  private let transform: (State, Source.Generator.Element) -> (State, Step<Element>)
}

public struct Stream<Source: SequenceType, State, Element> {
  private let stateful: StatefulStream<Source, State, Element>
  private let initialState: State
  public var size: SizeGuess { return stateful.size }
}

extension StatefulStream {
  public func map<Result>(f: Element -> Result) -> StatefulStream<Source, State, Result> {
    return StatefulStream<Source, State, Result>(source: source, size: size) { (s,x) in
      let (t,y) = self.transform(s,x)
      return (t, y.map(f))
    }
  }
  public func mapAccum<Result>(f: (accumulator: State, element: Element) -> (accumulator: State, result: Result)) -> StatefulStream<Source, State, Result> {
    return StatefulStream<Source, State, Result>(source: source, size: size) { (s,x) in
      let (t,y) = self.transform(s,x)
      return y.map(t, f: f)
    }
  }
  public func filter(p: Element -> Bool) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { (s,x) in
      let (t,y) = self.transform(s,x)
      return (t, y.filter(p))
    }
  }
  public func filterAccum(p: (State, Element) -> (State, Bool)) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { (s,x) in
      let (t,y) = self.transform(s,x)
      return y.filter(t, p: p)
    }
  }
  public func takeWhile(p: Element -> Bool) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { (s,x) in
      let (t,y) = self.transform(s,x)
      return (t, y.takeWhile(p))
    }
  }
  public func takeWhileAccum(p: (State, Element) -> (State, Bool)) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { (s,x) in
      let (t,y) = self.transform(s,x)
      return y.takeWhile(t, p: p)
    }
  }
  // Not at all likt Haskell's mapState. More of a lensy kind of thing.
  public func mapState<NewState>(f: NewState -> (State, State -> NewState)) -> StatefulStream<Source, NewState, Element> {
    let t: (NewState, Source.Generator.Element) -> (NewState, Step<Element>) = { (s,x) in
      let (r,b) = f(s)
      let (u,y) = self.transform(r,x)
      return (b(u), y)
    }
    return StatefulStream<Source, NewState, Element>(source: source, size: size, transform: t)
  }
}

extension Stream {
  public func map<Result>(f: Element -> Result) -> Stream<Source, State, Result> {
    return Stream<Source, State, Result> (stateful: stateful.map(f), initialState: initialState)
  }
  public func filter(p: Element -> Bool) -> Stream {
    return Stream(stateful: stateful.filter(p), initialState: initialState)
  }
  public func takeWhile(p: Element -> Bool) -> Stream {
    return Stream(stateful: stateful.takeWhile(p), initialState: initialState)
  }
}

public protocol _UnitType { init() }
public struct Unit: _UnitType { public init() {} }

public extension Stream where State: _UnitType {
  public func filterAccum<NewState>(p: (accumulator: NewState, element: Element) -> (accumulator: NewState, include: Bool)) -> StatefulStream<Source, NewState, Element> {
    let t: (NewState, Source.Generator.Element) -> (NewState, Step<Element>) = { (s,x) in
      let (_,y) = self.stateful.transform(State(),x)
      return y.filter(s, p: p)
    }
    return StatefulStream(
      source: stateful.source,
      size: stateful.size.smaller,
      transform: t
    )
  }
  public func takeWhileAccum<NewState>(p: (accumulator: NewState, element: Element) -> (accumulator: NewState, include: Bool)) -> StatefulStream<Source, NewState, Element> {
    let t: (NewState, Source.Generator.Element) -> (NewState, Step<Element>) = { (s,x) in
      let (_,y) = self.stateful.transform(State(),x)
      return y.takeWhile(s, p: p)
    }
    return StatefulStream(
      source: stateful.source,
      size: stateful.size.smaller,
      transform: t
    )
  }
  public func mapAccum<NewState, Result>(f: (accumulator: NewState, element: Element) -> (accumulator: NewState, result: Result)) -> StatefulStream<Source, NewState, Result> {
    let t: (NewState, Source.Generator.Element) -> (NewState, Step<Result>) = { (s,x) in
      let (_,y) = self.stateful.transform(State(),x)
      return y.map(s, f: f)
    }
    return StatefulStream(
      source: stateful.source,
      size: stateful.size.smaller,
      transform: t
    )
  }
}

extension CollectionType {
  public func toStream() -> Stream<Self, Unit, Generator.Element> {
    let t: (Unit, Generator.Element) -> (Unit, Step<Generator.Element>) = { (s,x) in (s, Step.Continue(x)) }
    let s = StatefulStream(
      source: self,
      size: .Exactly(numericCast(count)),
      transform: t
    )
    return Stream(stateful: s, initialState: Unit())
  }
}

extension SequenceType {
  public func toStream() -> Stream<Self, Unit, Generator.Element> {
    let t: (Unit, Generator.Element) -> (Unit, Step<Generator.Element>) = { (s,x) in (s, Step.Continue(x)) }
    let s = StatefulStream(
      source: self,
      size: .LargerThan(underestimateCount()),
      transform: t
    )
    return Stream(stateful: s, initialState: Unit())
  }
  public func filterAccum<State>(p: (accumulator: State, element: Generator.Element) -> (accumulator: State, include: Bool)) -> StatefulStream<Self, State, Generator.Element> {
    return toStream().filterAccum(p)
  }
  public func takeWhileAccum<State>(p: (accumulator: State, element: Generator.Element) -> (accumulator: State, include: Bool)) -> StatefulStream<Self, State, Generator.Element> {
    return toStream().takeWhileAccum(p)
  }
  public func mapAccum<State, Result>(f: (accumulator: State, element: Generator.Element) -> (accumulator: State, result: Result)) -> StatefulStream<Self, State, Result> {
    return toStream().mapAccum(f)
  }
}

extension StatefulStream {
  public func toStream(withState: State) -> Stream<Source, State, Element> {
    return Stream(stateful: self, initialState: withState)
  }
  public func reduce<Result>(withState: State, initial: Result, combine: (element: Element, accumulator: Result) -> Result) -> (State, Result) {
    var result = initial
    var state = withState
    var g = source.generate()
    while let next = g.next() {
      let (s,x) = transform(state, next)
      state = s
      switch x {
      case let .Continue(y): result = combine(element: y, accumulator: result)
      case .Skip: continue
      case .Stop: return (state, result)
      }
    }
    return (state, result)
  }
}

public struct StreamGenerator<Source: GeneratorType, State, Element> {
  private var generator: Source
  private var state: State
  private let transform: (State, Source.Element) -> (State, Step<Element>)
}

extension StreamGenerator: GeneratorType {
  public mutating func next() -> Element? {
    while let next = generator.next() {
      let (s,x) = transform(state, next)
      state = s
      switch x {
      case let .Continue(y): return y
      case .Skip: continue
      case .Stop: return nil
      }
    }
    return nil
  }
}

extension Stream: SequenceType {
  public func generate() -> StreamGenerator<Source.Generator, State, Element> {
    return StreamGenerator(
      generator: stateful.source.generate(),
      state: initialState,
      transform: stateful.transform
    )
  }
  public func underestimateCount() -> Int {
    switch stateful.size {
    case .SmallerThan, .Infinite, .Unknown: return 0
    case let .Exactly(n): return n
    case let .LargerThan(n): return n
    }
  }
}

public struct InfiniteGenerator: GeneratorType {
  public func next() -> ()? { return () }
}

public struct InfiniteSequence: SequenceType {
  public func generate() -> InfiniteGenerator {
    return InfiniteGenerator()
  }
  public init() {}
}

extension InfiniteSequence {
  func toStream() -> Stream<InfiniteSequence, Unit, ()> {
    let t: (Unit, Generator.Element) -> (Unit, Step<Generator.Element>) = { (s,x) in (s, Step.Continue(x)) }
    let s = StatefulStream(
      source: self,
      size: .Infinite,
      transform: t
    )
    return Stream(stateful: s, initialState: Unit())
  }
}

