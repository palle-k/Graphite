//
//  UIInsetLabel.swift
//  GraphiteDemo
//
//  Created by Palle Klewitz on 18.12.17.
//  Copyright © 2017 Palle Klewitz. All rights reserved.
//

import UIKit

@IBDesignable
class UIInsetLabel: UILabel {
	@IBInspectable var insets: UIEdgeInsets = .zero
	
	override var intrinsicContentSize: CGSize {
		let labelSize = super.intrinsicContentSize
		return CGSize(width: labelSize.width + insets.left + insets.right, height: labelSize.height + insets.top + insets.bottom)
	}
	
	override func drawText(in rect: CGRect) {
		super.drawText(in: rect.inset(by: insets))
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let suggestedSize = super.sizeThatFits(
			CGSize(
				width: max(size.width - insets.left - insets.right, 0),
				height: max(size.height - insets.top - insets.bottom, 0)
			)
		)
		return CGSize(
			width: suggestedSize.width + insets.left + insets.right,
			height: suggestedSize.height + insets.top + insets.bottom
		)
	}
}

