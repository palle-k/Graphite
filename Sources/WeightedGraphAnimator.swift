//
//  WeightedGraphAnimator.swift
//  Graphite
//
//  Created by Palle Klewitz on 18.12.17.
//  Copyright (c) 2017 Palle Klewitz
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation
import UIKit
import QuartzCore

open class UIWeightedGraphAnimator {
	
	public private(set) var items: [Int: UIDynamicItem] = [:]
	open var bounds: CGRect
	open let simulator: WeightedGraphSimulator
	open var onUpdate: (() -> ())? = nil
	
	private var displayLink: CADisplayLink?
	
	open var integrationSteps: Int = 1 {
		didSet {
			assert(integrationSteps > 0, "The number of integration steps must be greater than zero.")
		}
	}
	
	private var transform: CGAffineTransform {
		return CGAffineTransform(scaleX: 20, y: 20).concatenating(CGAffineTransform(translationX: bounds.midX, y: bounds.midY))
	}
	
	open var graph: Graph {
		get {
			return simulator.graph
		}
		set {
			simulator.graph = newValue
		}
	}
	
	public var center: CGPoint {
		return CGPoint(
			x: CGFloat(simulator.center[0]),
			y: CGFloat(simulator.center[1])
		).applying(transform)
	}
	
	open var radius: CGFloat {
		get {
			return CGFloat(simulator.radius) * min(transform.a, transform.d)
		}
		set {
			simulator.radius = Float(newValue / min(transform.a, transform.d))
		}
	}
	
	open var collisionDistance: CGFloat {
		get {
			return CGFloat(simulator.collisionRadius) * min(transform.a, transform.d)
		}
		set {
			simulator.collisionRadius = Float(newValue / min(transform.a, transform.d))
		}
	}
	
	public init(bounds: CGRect, graph: Graph) {
		self.bounds = bounds
		self.simulator = WeightedGraphSimulator(dimensions: 2, graph: graph, center: Array(repeating: 0.5, count: 2))
	}
	
	private var lastUpdate: CFTimeInterval?
	private(set) var isRunning: Bool = false
	
	@objc private func run(link: CADisplayLink) {
		guard isRunning else {
			return
		}
		guard let lastUpdate = self.lastUpdate else {
			self.lastUpdate = link.timestamp
			return
		}
		let delta = link.timestamp - lastUpdate
		self.lastUpdate = link.timestamp
		
		for _ in 0 ..< integrationSteps {
			simulator.update(interval: delta / Double(integrationSteps))
		}
		
		for (key: name, value: (position: position, velocity: _)) in self.simulator.nodes {
			guard let item = self.items[name] else {
				continue
			}
			item.center = CGPoint(x: Double(position[0]), y: Double(position[1])).applying(transform)
		}
		
		onUpdate?()
	}
	
	public func start() {
		guard !isRunning else {
			return
		}
		isRunning = true
		let link = UIScreen.main.displayLink(withTarget: self, selector: #selector(self.run(link:)))
			?? CADisplayLink(target: self, selector: #selector(self.run(link:)))
		link.add(to: .main, forMode: .defaultRunLoopMode)
		self.displayLink = link
	}
	
	public func stop() {
		isRunning = false
		displayLink?.isPaused = true
		displayLink?.invalidate()
		displayLink = nil
		lastUpdate = nil
	}
	
	public func add(item: UIDynamicItem, for key: Int) {
		items[key] = item
	}
	
	public func removeItem(for key: Int) {
		items[key] = nil
	}
	
	public func beginUserInteraction(on node: Int) {
		simulator.beginUserInteraction(on: node)
	}
	
	public func moveItem(for key: Int, to destination: CGPoint) {
		let translatedPoint = destination.applying(transform.inverted())
		simulator.set(location: [translatedPoint.x, translatedPoint.y].map(Float.init), for: key)
	}
	
	public func endUserInteraction(on node: Int) {
		simulator.endUserInteraction(on: node)
	}
	
	public func endUserInteraction(on node: Int, with velocity: CGVector) {
		simulator.endUserInteraction(on: node, with: [Float(velocity.dx / transform.a), Float(velocity.dy / transform.d)])
	}
	
	public func setCenter(_ center: CGPoint) {
		let transformed = center.applying(transform.inverted())
		simulator.center = [transformed.x, transformed.y].map(Float.init)
		simulator.centerVelocity = Array(repeating: 0, count: 2)
	}
	
	public func setCenter(_ center: CGPoint, inerialVelocity: CGVector) {
		let transformed = center.applying(transform.inverted())
		simulator.center = [transformed.x, transformed.y].map(Float.init)
		simulator.centerVelocity = [inerialVelocity.dx / transform.a, inerialVelocity.dy / transform.d].map(Float.init)
	}
}
