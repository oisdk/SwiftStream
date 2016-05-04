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
  private let transform: Source.Generator.Element -> Stateful<State,Step<Element>>
}

public struct Stream<Source: SequenceType, State, Element> {
  private let stateful: StatefulStream<Source, State, Element>
  private let initialState: State
  public var size: SizeGuess { return stateful.size }
}

extension StatefulStream {
  public func map<Result>(f: Element -> Result) -> StatefulStream<Source, State, Result> {
    return StatefulStream<Source, State, Result>(source: source, size: size) { x in
      self.transform(x).map { y in y.map(f) }
    }
  }
  public func mapWithState<Result>(f: Element -> Stateful<State,Result>) -> StatefulStream<Source, State, Result> {
    return StatefulStream<Source, State, Result>(source: source, size: size) { x in
      return self.transform(x).flatMap { step in step.mapState(f) }
    }
  }
  public func filter(p: Element -> Bool) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { x in
      self.transform(x).map { step in step.filter(p) }
    }
  }
  public func filterWithState(p: Element -> Stateful<State,Bool>) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { x in
      self.transform(x).flatMap { step in step.filterState(p) }
    }
  }
  public func takeWhile(p: Element -> Bool) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { x in
      self.transform(x).map { step in step.takeWhile(p) }
    }
  }
  public func takeWhileWithState(p: Element -> Stateful<State,Bool>) -> StatefulStream {
    return StatefulStream(source: source, size: size.smaller) { x in
      self.transform(x).flatMap { step in step.takeWhileState(p) }
    }
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
  public func filterWithState<NewState>(p: Element -> Stateful<NewState,Bool>) -> StatefulStream<Source, NewState, Element> {
    let t: Source.Generator.Element -> Stateful<NewState, Step<Element>> = { x in
      self.stateful.transform(x).evalStateful(State()).filterState(p)
    }
    return StatefulStream(
      source: stateful.source,
      size: stateful.size.smaller,
      transform: t
    )
  }
  public func takeWhileWithState<NewState>(p: Element -> Stateful<NewState,Bool>) -> StatefulStream<Source, NewState, Element> {
    let t: Source.Generator.Element -> Stateful<NewState, Step<Element>> = { x in
      self.stateful.transform(x).evalStateful(State()).takeWhileState(p)
    }
    return StatefulStream(
      source: stateful.source,
      size: stateful.size.smaller,
      transform: t
    )
  }
  public func mapWithState<NewState, Result>(p: Element -> Stateful<NewState,Result>) -> StatefulStream<Source, NewState, Result> {
    let t: Source.Generator.Element -> Stateful<NewState, Step<Result>> = { x in
      self.stateful.transform(x).evalStateful(State()).mapState(p)
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
    let t: Generator.Element -> Stateful<Unit, Step<Generator.Element>> = { x in Stateful(pure: Step.Continue(x)) }
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
    let t: Generator.Element -> Stateful<Unit, Step<Generator.Element>> = { x in Stateful(pure: Step.Continue(x)) }
    let s = StatefulStream(
      source: self,
      size: .LargerThan(underestimateCount()),
      transform: t
    )
    return Stream(stateful: s, initialState: Unit())
  }
}

extension StatefulStream {
  public func toStream(withState: State) -> Stream<Source, State, Element> {
    return Stream(stateful: self, initialState: withState)
  }
  public func reduce<Result>(withStateful: State, initial: Result, combine: (element: Element, accumulator: Result) -> Result) -> (State, Result) {
    var result = initial
    var Stateful = withStateful
    var g = source.generate()
    while let next = g.next() {
      let (x,s) = transform(next).runStateful(Stateful)
      Stateful = s
      switch x {
      case let .Continue(y): result = combine(element: y, accumulator: result)
      case .Skip: continue
      case .Stop: return (Stateful, result)
      }
    }
    return (Stateful, result)
  }
  public func toArray(withState: State) -> (State, [Element]) {
    var g = source.generate()
    var a: [Element] = []
    var s = withState
    while let next = g.next() {
      let (x,t) = transform(next).runStateful(s)
      s = t
      switch x {
      case let .Continue(y): a.append(y)
      case .Skip: continue
      case .Stop: break
      }
    }
    return (s, a)
  }
}

public struct StreamGenerator<Source: GeneratorType, State, Element> {
  private var generator: Source
  private var state: State
  private let transform: Source.Element -> Stateful<State,Step<Element>>
}

extension StreamGenerator: GeneratorType {
  public mutating func next() -> Element? {
    while let next = generator.next() {
      let (x,s) = transform(next).runStateful(state)
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
    let t: Generator.Element -> Stateful<Unit, Step<Generator.Element>> = { x in Stateful(pure: Step.Continue(x)) }
    let s = StatefulStream(
      source: self,
      size: .Infinite,
      transform: t
    )
    return Stream(stateful: s, initialState: Unit())
  }
}

// MARK: Accumulator variants

public extension StatefulStream {
  func mapAccum<A>(f: (element: Element, accumulator: State) -> (A, State)) -> StatefulStream<Source, State, A> {
    return mapWithState(liftToState(f))
  }
  func filterAccum(p: (element: Element, accumulator: State) -> (Bool, State)) -> StatefulStream<Source, State, Element> {
    return filterWithState(liftToState(p))
  }
  func takeWhileAccum(p: (element: Element, accumulator: State) -> (Bool, State)) -> StatefulStream<Source, State, Element> {
    return takeWhileWithState(liftToState(p))
  }
}

public extension Stream where State: _UnitType {
  func mapAccum<A,NewState>(f: (element: Element, accumulator: NewState) -> (A, NewState)) -> StatefulStream<Source, NewState, A> {
    return mapWithState(liftToState(f))
  }
  func filterAccum<NewState>(p: (element: Element, accumulator: NewState) -> (Bool, NewState)) -> StatefulStream<Source, NewState, Element> {
    return filterWithState(liftToState(p))
  }
  func takeWhileAccum<NewState>(p: (element: Element, accumulator: NewState) -> (Bool, NewState)) -> StatefulStream<Source, NewState, Element> {
    return takeWhileWithState(liftToState(p))
  }
}

public extension SequenceType {
  func mapWithState<A,State>(f: Generator.Element -> Stateful<State, A>) -> StatefulStream<Self, State, A> {
    return toStream().mapWithState(f)
  }
  func mapAccum<A,State>(f: (element: Generator.Element, accumulator: State) -> (A, State)) -> StatefulStream<Self, State, A> {
    return mapWithState(liftToState(f))
  }
  func filterWithState<State>(p: Generator.Element -> Stateful<State, Bool>) -> StatefulStream<Self,State,Generator.Element> {
    return toStream().filterWithState(p)
  }
  func filterAccum<State>(p: (element: Generator.Element, accumulator: State) -> (Bool, State)) -> StatefulStream<Self, State, Generator.Element>  {
    return filterWithState(liftToState(p))
  }
  func takeWhileWithState<State>(p: Generator.Element -> Stateful<State, Bool>) -> StatefulStream<Self,State,Generator.Element> {
    return toStream().takeWhileWithState(p)
  }
  func takeWhileAccum<State>(p: (element: Generator.Element, accumulator: State) -> (Bool, State)) -> StatefulStream<Self, State, Generator.Element>  {
    return takeWhileWithState(liftToState(p))
  }
}
