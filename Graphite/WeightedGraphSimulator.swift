//
//  WeightedGraphSimulator.swift
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
import Accelerate
import SceneKit
import ARKit

open class WeightedGraphSimulator {
	open var graph: Graph
	
	private var weights: [Int: [Int: Double]] = [:]
	
	public private(set) var nodes: [Int: (position: [Float], velocity: [Float])] = [:]
	open var damping: Float = 2
	public let dimensions: Int
	open var radius: Float = 1
	open var collisionRadius: Float = 0.5
	
	public private(set) var interactedTags: Set<Int> = []
	
	open var center: [Float] {
		didSet {
			assert(center.count == dimensions, "Number of dimensions and dimensionality of center point must match.")
		}
	}
	
	public init(dimensions: Int, graph: Graph, center: [Float]) {
		precondition(dimensions == center.count, "Number of dimensions and dimensionality of center point must match.")
		
		self.dimensions = dimensions
		self.center = center
		self.graph = graph
	}
	
	open func update(interval: TimeInterval) {
		
		let previousNodes = self.nodes
		
		for (key: node, value: (position: position, velocity: velocity)) in previousNodes where !interactedTags.contains(node) {
			
			var newPosition = position
			var newVelocity = velocity
			
			for (key: otherNode, value: (position: otherPosition, velocity: _)) in previousNodes where otherNode != node {
				if position == otherPosition {
					newPosition = self.position(for: node)
					break
				}
				
				let weight = Float(weights[node]?[otherNode] ?? 0)
				
				let direction = self.direction(from: position, to: otherPosition)
				var distanceSquared: Float = 0
				vDSP_distancesq(position, 1, otherPosition, 1, &distanceSquared, UInt(dimensions))
				let distance = sqrt(distanceSquared)
				
				let strength: Float = weight * 0.3 + 0.2
				//				let expectedDistance: Float = radius * 0.5 * (1 - 0.7 * weight)
				let expectedDistance: Float = radius * 0.5
				
				let acceleration: Float
				
				if distance < collisionRadius {
					acceleration = (-1 / distance + 1 / collisionRadius) * 20
				} else if weight == 0 && distance > expectedDistance {
					acceleration = -1 / distanceSquared * 0.1 * radius * radius
				} else {
					acceleration = (distance - expectedDistance) / distance * strength * 50
				}
				
				vDSP_vsma(direction, 1, [acceleration * Float(interval)], newVelocity, 1, &newVelocity, 1, UInt(dimensions))
			}
			
			vDSP_vsma(centerAcceleration(from: newPosition), 1, [3 * Float(interval) / radius], newVelocity, 1, &newVelocity, 1, UInt(dimensions))
			
			vDSP_vsmul(newVelocity, 1, [1 - damping * Float(interval)], &newVelocity, 1, UInt(dimensions))
			
			self.nodes[node] = (position: newPosition, velocity: newVelocity)
		}
		
		var driftVelocity = nodes.reduce(into: [Float](repeating: 0, count: dimensions)) { (result: inout ([Float]), element) in
			vDSP_vadd(result, 1, element.value.velocity, 1, &result, 1, UInt(self.dimensions))
		}
		vDSP_vsdiv(driftVelocity, 1, [Float(max(1, previousNodes.count))], &driftVelocity, 1, UInt(dimensions))
		
		for (key: node, value: (position: position, velocity: velocity)) in nodes where !interactedTags.contains(node) {
			var newVelocity = velocity
			var newPosition = position
			vDSP_vsub(driftVelocity, 1, velocity, 1, &newVelocity, 1, UInt(dimensions))
			vDSP_vsma(newVelocity, 1, [Float(interval)], newPosition, 1, &newPosition, 1, UInt(dimensions))
			self.nodes[node] = (position: newPosition, velocity: newVelocity)
		}
		
		var nodeCenter = nodes.reduce(into: [Float](repeating: 0, count: dimensions)) { (result: inout ([Float]), element) in
			vDSP_vadd(result, 1, element.value.position, 1, &result, 1, UInt(self.dimensions))
		}
		vDSP_vsdiv(nodeCenter, 1, [Float(max(1, previousNodes.count))], &nodeCenter, 1, UInt(dimensions))
		let centerDirection = direction(from: nodeCenter, to: self.center)
		
		for (key: node, value: (position: position, velocity: velocity)) in nodes where !interactedTags.contains(node) {
			var newPosition = position
			vDSP_vadd(position, 1, centerDirection, 1, &newPosition, 1, UInt(dimensions))
			self.nodes[node] = (position: newPosition, velocity: velocity)
		}
	}
	
	func position(for tag: Int) -> [Float] {
		if nodes.count >= 4 {
			var average = nodes
				.pick(4)
				.map{$0.value.position}
				.reduce(into: Array<Float>(repeating: 0, count: dimensions)) { (average: inout [Float], point: [Float]) in
					vDSP_vadd(average, 1, point, 1, &average, 1, UInt(dimensions))
			}
			vDSP_vsdiv(average, 1, [4], &average, 1, UInt(dimensions))
			return average
		}
		
		if dimensions == 2 {
			let angle = Float(drand48()) * 2 * .pi
			return [
				cos(angle) * radius * 0.5 + center[0],
				sin(angle) * radius * 0.5 + center[1]
			]
		} else {
			return (0..<dimensions).map({_ in Float(drand48())})
		}
	}
	
	@inline(__always)
	private final func direction(from p1: [Float], to p2: [Float]) -> [Float] {
		var result: [Float] = Array(repeating: 0, count: p1.count)
		vDSP_vsub(p1, 1, p2, 1, &result, 1, UInt(p1.count))
		return result
	}
	
	@inline(__always)
	private final func centerAcceleration(from point: [Float]) -> [Float] {
		var dir = direction(from: point, to: center)
		var distanceSquared: Float = 0
		vDSP_distancesq(point, 1, center, 1, &distanceSquared, UInt(dimensions))
		let distance = sqrt(distanceSquared)
		vDSP_vsmul(dir, 1, [1 / (distance + 1)], &dir, 1, UInt(dimensions))
		return dir
	}
	
	public func set(location: [Float], for key: Int) {
		nodes[key] = (location, Array(repeating: 0, count: dimensions))
	}
	
	public func beginUserInteraction(on node: Int) {
		interactedTags.insert(node)
	}
	
	public func endUserInteraction(on node: Int) {
		interactedTags.remove(node)
	}
	
	public func endUserInteraction(on node: Int, with velocity: [Float]) {
		interactedTags.remove(node)
		nodes[node]?.velocity = velocity
	}
}
