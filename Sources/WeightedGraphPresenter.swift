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
	func visibleRange(for node: Int, presenter: WeightedGraphPresenter) -> ClosedRange<Float>?
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
	
	private var interactor: WeightedGraphInteractor
	private let animator: UIWeightedGraphAnimator
	
	public var isRunning: Bool {
		return animator.isRunning
	}
	
	public weak var delegate: WeightedGraphPresenterDelegate?
	
	public var disablesForceOnHiddenNodes: Bool = true {
		didSet {
			updateVisibility()
		}
	}
	public var showsHiddenNodeEdges: Bool {
		get {
			return edgeView.showsHiddenNodeEdges
		}
		set {
			edgeView.showsHiddenNodeEdges = newValue
		}
	}
	
	public var backgroundColor: UIColor {
		get {
			return edgeView.backgroundColor ?? view.backgroundColor ?? .clear
		}
		set {
			edgeView.backgroundColor = newValue
		}
	}
	
	public var edgeColor: UIColor {
		get {
			return edgeView.strokeColor
		}
		set {
			edgeView.strokeColor = newValue
		}
	}
	
	private var isStarted: Bool = false
	private var observations: [NSObjectProtocol] = []
	
	public var radius: CGFloat {
		get {
			return animator.radius
		}
		set {
			animator.radius = newValue
		}
	}
	public var collisionDistance: CGFloat {
		get {
			return animator.collisionDistance
		}
		set {
			animator.collisionDistance = newValue
		}
	}
	
	public var centerAttraction: CGFloat {
		get {
			return animator.centerAttraction
		}
		set {
			animator.centerAttraction = newValue
		}
	}
	
	public init(graph: Graph, view: UIView) {
		self.view = view
		self.edgeView = GraphWeightView()
		
		self.animator = UIWeightedGraphAnimator(bounds: view.bounds, graph: graph)
		self.interactor = WeightedGraphInteractor(view: edgeView, animator: self.animator)
		
		self.graph = graph
		
		self.view.addSubview(self.edgeView)
		
		let topContraint = NSLayoutConstraint(item: edgeView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0)
		let leftConstraint = NSLayoutConstraint(item: edgeView, attribute: .left, relatedBy: .equal, toItem: view, attribute: .left, multiplier: 1, constant: 0)
		let bottomConstraint = NSLayoutConstraint(item: edgeView, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0)
		let rightConstraint = NSLayoutConstraint(item: edgeView, attribute: .right, relatedBy: .equal, toItem: view, attribute: .right, multiplier: 1, constant: 0)
		edgeView.translatesAutoresizingMaskIntoConstraints = false
		
		view.addConstraints([topContraint, leftConstraint, bottomConstraint, rightConstraint])
		
		animator.onUpdate = {
			self.edgeView.layer.setNeedsDisplay()
		}
		animator.integrationSteps = 1
		
		let o1 = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [unowned self] _ in
			if self.isStarted {
				self.animator.stop()
			}
		}
		let o2 = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [unowned self] _ in
			if self.isStarted {
				self.animator.start()
			}
		}
		observations += [o1, o2]
		
		interactor.onPinch = { [weak self] in
			self?.updateVisibility()
		}
	}
	
	deinit {
		observations.forEach(NotificationCenter.default.removeObserver(_:))
	}
	
	func update() {
		let existingNodes = Set(interactor.nodeViews.keys)
		let removedNodes = existingNodes.subtracting(graph.nodes)
        let removedViews = removedNodes.compactMap{interactor.nodeViews[$0]}
		
		let changedNodes = existingNodes.intersection(graph.nodes)
        let changedNodeViews = changedNodes.compactMap{ node in
			interactor.nodeViews[node].map {(node, $0)}
		}
		
		let addedNodes = graph.nodes.subtracting(existingNodes)
		let addedNodeViews = addedNodes.map {($0, self.delegate?.view(for: $0, presenter: self) ?? UIView())}
		interactor.nodeViews.merge(addedNodeViews, uniquingKeysWith: {a, _ in a})
		
		removedNodes.forEach(animator.removeItem)
		removedNodes.forEach { node in
			self.interactor.nodeViews.removeValue(forKey: node)
		}
		
		addedNodeViews.map {$0.1}.forEach(self.edgeView.addSubview)
		addedNodeViews.forEach { node, view in
			self.delegate?.configure(view: view, for: node, presenter: self)
			self.animator.add(item: view, for: node)
			view.alpha = 0
		}
		
		edgeView.weights.removeAll()
		edgeView.weights = graph.edges.reduce([]) { acc, relation in
            let views = relation.nodes.compactMap {self.interactor.nodeViews[$0]}
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
		
		updateVisibility()
	}
	
	public func start() {
		isStarted = true
		animator.start()
	}
	
	public func stop() {
		isStarted = false
		animator.stop()
	}
	
	private func updateVisibility() {
		for (node, view) in self.interactor.nodeViews {
			let visibleRange = self.delegate?.visibleRange(for: node, presenter: self) ?? (-Float.infinity ... Float.infinity)
			let isVisible = visibleRange ~= Float(self.animator.radius)
			view.isHidden = !isVisible
			
			if isVisible || !disablesForceOnHiddenNodes {
				animator.enableForce(from: node)
			} else {
				animator.disableForce(from: node)
			}
		}
	}
}
