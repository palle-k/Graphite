//
//  Graph.swift
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

public struct Graph: Codable {
	public struct Edge: Codable {
		public var nodes: Set<Int>
		public var weight: Float
		
		public init(nodes: Set<Int>, weight: Float) {
			self.nodes = nodes
			self.weight = weight
		}
	}
	
	public var nodes: Set<Int>
	public var edges: Set<Edge>
	
	public init<NodeSequence: Sequence, EdgeSequence: Sequence>(nodes: NodeSequence, edges: EdgeSequence) where NodeSequence.Element == Int, EdgeSequence.Element == Edge {
		self.nodes = Set(nodes)
		self.edges = Set(edges)
	}
}

extension Graph.Edge: Hashable {
	public var hashValue: Int {
		return nodes.hashValue ^ weight.hashValue
	}
	
	public static func ==(lhs: Graph.Edge, rhs: Graph.Edge) -> Bool {
		return lhs.nodes == rhs.nodes && lhs.weight == rhs.weight
	}
}

extension Graph: Hashable {
	public var hashValue: Int {
		return nodes.hashValue ^ edges.hashValue
	}
	
	public static func ==(lhs: Graph, rhs: Graph) -> Bool {
		return lhs.nodes == rhs.nodes && lhs.edges == rhs.edges
	}
}
