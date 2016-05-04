//
//  Step.swift
//  SwiftStream
//
//  Created by Donnacha Oisín Kidney on 04/05/2016.
//  Copyright © 2016 Donnacha Oisín Kidney. All rights reserved.
//

public enum Step<Element> {
  case Skip, Stop, Continue(Element)
}

extension Step {
  func map<State,Result>(withState: State, f: (State, Element) -> (State, Result)) -> (State, Step<Result>) {
    switch self {
    case let .Continue(x):
      let (r,n) = f(withState,x)
      return (r, .Continue(n))
    case .Skip: return (withState, .Skip)
    case .Stop: return (withState, .Stop)
    }
  }
  func condition<State>(def: Step, withState: State, p: (State, Element) -> (State, Bool)) -> (State, Step) {
    switch self {
    case let .Continue(x):
      let (r,b) = p(withState,x)
      return (r, b ? .Continue(x) : def)
    case .Skip: return (withState, .Skip)
    case .Stop: return (withState, .Stop)
    }
  }
  func filter<State>(withState: State, p: (State, Element) -> (State, Bool)) -> (State, Step) {
    return condition(.Skip, withState: withState, p: p)
  }
  func takeWhile<State>(withState: State, p: (State, Element) -> (State, Bool)) -> (State, Step) {
    return condition(.Stop, withState: withState, p: p)
  }
}

extension Step {
  func map<Result>(f: Element -> Result) -> Step<Result> {
    switch self {
    case let .Continue(x): return .Continue(f(x))
    case .Skip: return .Skip
    case .Stop: return .Stop
    }
  }
  func condition(def: Step, p: Element -> Bool) -> Step {
    if case let .Continue(x) = self where !p(x) {
      return def
    } else {
      return self
    }
  }
  func filter(p: Element -> Bool) -> Step {
    return condition(.Skip, p: p)
  }
  func takeWhile(p: Element -> Bool) -> Step {
    return condition(.Stop, p: p)
  }
}

extension Step {
  init(fromOptional: Element?) {
    self = fromOptional.map(Step.Continue) ?? .Stop
  }
}