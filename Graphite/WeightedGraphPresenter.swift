//
//  WeightedGraphPresenter.swift
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

public protocol WeightedGraphPresenterDelegate: class {
	func view(for node: Int, presenter: WeightedGraphPresenter) -> UIView
	func configure(view: UIView, for node: Int, presenter: WeightedGraphPresenter)
}

public class WeightedGraphPresenter {
	public var graph: Graph {
		get {
			return animator.graph
		}
		set {
			animator.graph = newValue
			update()
		}
	}
	public let view: UIView
	private var edgeView: GraphWeightView
	private var nodeViews: [Int: UIView] = [:]
	private var viewIDs: [UIView: Int] {
		return Dictionary(nodeViews.map {($1, $0)}, uniquingKeysWith: {a, _ in a})
	}
	
	private var animator: UIWeightedGraphAnimator
	
	public weak var delegate: WeightedGraphPresenterDelegate?
	
	public init(graph: Graph, view: UIView) {
		self.view = view
		self.edgeView = GraphWeightView()
		
		self.animator = UIWeightedGraphAnimator(bounds: view.bounds, graph: graph)
		self.graph = graph
		
		self.view.addSubview(self.edgeView)
		
		let topContraint = NSLayoutConstraint(item: edgeView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
		let leftConstraint = NSLayoutConstraint(item: edgeView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: 0)
		let bottomConstraint = NSLayoutConstraint(item: edgeView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
		let rightConstraint = NSLayoutConstraint(item: edgeView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1, constant: 0)
		
		view.addConstraints([topContraint, leftConstraint, bottomConstraint, rightConstraint])
		
		animator.onUpdate = {
			self.edgeView.layer.setNeedsDisplay()
		}
		
		let panRecognizer = UIMultiPanGestureRecognizer(target: self, action: #selector(self.didPan(_:)))
		edgeView.addGestureRecognizer(panRecognizer)
		
		let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.didPinch(_:)))
		edgeView.addGestureRecognizer(pinchRecognizer)
	}
	
	func update() {
		let existingNodes = Set(nodeViews.keys)
		let removedNodes = existingNodes.subtracting(graph.nodes)
		let removedViews = removedNodes.flatMap{nodeViews[$0]}
		
		let changedNodes = existingNodes.intersection(graph.nodes)
		let changedNodeViews = changedNodes.flatMap{ node in
			nodeViews[node].map {(node, $0)}
		}
		
		let addedNodes = graph.nodes.subtracting(existingNodes)
		let addedNodeViews = addedNodes.map {($0, self.delegate?.view(for: $0, presenter: self) ?? UIView())}
		
		removedNodes.forEach(animator.removeItem)
		
		addedNodeViews.map {$0.1}.forEach(self.edgeView.addSubview)
		addedNodeViews.forEach { node, view in
			self.delegate?.configure(view: view, for: node, presenter: self)
			self.animator.add(item: view, for: node)
			view.alpha = 0
		}
		
		edgeView.weights.removeAll()
		edgeView.weights = graph.edges.reduce([]) { acc, relation in
			let views = relation.nodes.flatMap {self.nodeViews[$0]}
			return acc + views.cross(views).filter {$0 != $1}.map {($0, $1, Double(relation.weight))}
		}
		
		UIView.animate(
			withDuration: 0.3,
			animations: {
				removedViews.forEach { view in
					view.alpha = 0
				}
				addedNodeViews.forEach { _, view in
					view.alpha = 1
				}
				changedNodeViews.forEach { node, view in
					self.delegate?.configure(view: view, for: node, presenter: self)
				}
			},
			completion: { completed in
				guard completed else {
					return
				}
				removedViews.forEach { view in
					view.removeFromSuperview()
				}
			}
		) // UIView.animate
		
	}
	
	public func start() {
		animator.start()
	}
	
	public func stop() {
		animator.stop()
	}
	
	private var knownTouches: Set<UITouch> = []
	private var pannedViews: [UITouch: UIView] = [:]
	private var velocityTracker = TouchVelocityTracker()
	
	@objc func didPan(_ recognizer: UIMultiPanGestureRecognizer) {
		func updateContainer(newTouches: Set<UITouch>, movedTouches: Set<UITouch>, endedTouches: Set<UITouch>) {
			let newViews = newTouches.flatMap { touch -> (UITouch, UIView)? in
				let location = touch.location(in: self.edgeView)
				guard let view = self
					.edgeView
					.subviews
					.lazy
					.reversed()
					.first(where: {$0.frame.extended(by: 8).contains(location)})
				else {
					return nil
				}
				return (touch, view)
			}
			
			newTouches.forEach(velocityTracker.update)
			movedTouches.forEach(velocityTracker.update)
			endedTouches.forEach(velocityTracker.update)
			
			UIView.animate(withDuration: 0.2) {
				newViews.map{$1}.forEach { view in
					view.transform = view.transform.concatenating(CGAffineTransform(scaleX: 1.3, y: 1.3))
				}
				endedTouches.flatMap {self.pannedViews[$0]}.forEach { view in
					view.transform = view.transform.concatenating(CGAffineTransform(scaleX: 1.3, y: 1.3).inverted())
				}
			}
			
			endedTouches.forEach { touch in
				guard let view = pannedViews[touch], let id = viewIDs[view] else {
					return
				}
				let velocity = self.velocityTracker.velocity(for: touch)
				self.animator.endUserInteraction(on: id, with: velocity)
				self.pannedViews.removeValue(forKey: touch)
			}
			endedTouches.forEach(velocityTracker.endTracking)
			
			newViews.flatMap {viewIDs[$0.1]}.forEach { id in
				self.animator.beginUserInteraction(on: id)
			}
			pannedViews.merge(newViews, uniquingKeysWith: {a, _ in a})
			
			movedTouches.forEach { touch in
				let location = touch.location(in: self.edgeView)
				
				if let view = pannedViews[touch], let id = viewIDs[view] {
					self.animator.moveItem(for: id, to: location)
				} else {
					let previousLocation = touch.previousLocation(in: self.edgeView)
					
					self.animator.center.x += location.x - previousLocation.x
					self.animator.center.y += location.y - previousLocation.y
				}
			}
			
			knownTouches.subtract(endedTouches)
			knownTouches.formUnion(newTouches)
		}
		
		switch recognizer.state {
		case .began:
			updateContainer(newTouches: recognizer.activeTouches, movedTouches: [], endedTouches: knownTouches)
			
		case .changed:
			let newTouches = recognizer.activeTouches.subtracting(knownTouches)
			let movedTouches = recognizer.activeTouches.intersection(knownTouches)
			let endedTouches = knownTouches.subtracting(recognizer.activeTouches)
			
			updateContainer(newTouches: newTouches, movedTouches: movedTouches, endedTouches: endedTouches)
			
		default:
			updateContainer(newTouches: [], movedTouches: [], endedTouches: knownTouches)
			knownTouches.removeAll()
			pannedViews.removeAll()
		}
	}
	
	private var startRadius: CGFloat?
	
	@objc func didPinch(_ recognizer: UIPinchGestureRecognizer) {
		switch recognizer.state {
		case .began:
			startRadius = animator.radius
			
		case .changed:
			if let startRadius = self.startRadius {
				animator.radius = startRadius * recognizer.scale
			}
			break
			
		case .ended:
			if let startRadius = self.startRadius {
				animator.radius = startRadius * recognizer.scale
			}
			startRadius = nil
			
		default:
			break
		}
	}
}
