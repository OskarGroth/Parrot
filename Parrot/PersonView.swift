import Cocoa

/* TODO: Fix NSLayoutConstraints that tend to "not work" until resized. */

// Serves as the "model" behind the view. Technically speaking, this is a translation
// layer between the application model and decouples it from the view.
public struct Person: Equatable {
	var photo: NSImage
	var caption: String
	var highlight: NSColor
	var indicator: Int
	var primary: String
	var secondary: String
	var time: Date
}

// Person: Equatable
public func ==(lhs: Person, rhs: Person) -> Bool {
	return lhs.primary == rhs.primary &&
		lhs.secondary == rhs.secondary &&
		lhs.time == rhs.time
}

// A general person view
public class PersonView : NSTableCellView {
	
	@IBOutlet var photoView: NSImageView?
	@IBOutlet var nameLabel: NSTextField?
	@IBOutlet var textLabel: NSTextField?
	@IBOutlet var timeLabel: NSTextField?
	@IBOutlet var unreadLabel: NSTextField?
	
	var time: Date!
	
	public override init(frame: NSRect) {
		super.init(frame: frame)
	}
	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	// Upon assignment of the represented object, configure the subview contents.
	public override var objectValue: AnyObject? {
		didSet {
			guard let o = (self.objectValue as? Wrapper<Any>)?.element as? Person else {
				return
			}
			
			let f = DateFormatter()
			f.dateStyle = .fullStyle
			f.timeStyle = .longStyle
			self.time = o.time
			
			self.photoView?.image = o.photo
			self.photoView?.toolTip = o.caption
			self.photoView?.layer?.borderColor = o.highlight.cgColor
			self.nameLabel?.stringValue = o.primary
			self.nameLabel?.toolTip = o.primary
			self.textLabel?.stringValue = o.secondary
			self.textLabel?.toolTip = o.secondary
			self.timeLabel?.stringValue = o.time.relativeString()
			self.timeLabel?.toolTip = "\(f.string(from: o.time))"
			self.unreadLabel?.stringValue = "\(o.indicator)"
			//self.unreadLabel?.layer?.backgroundColor = o.highlight.cgColor
			
			// Set the unread label and its spacing constraint visibility.
			self.unreadLabel?.isHidden = o.indicator <= 0
			let c = self.unreadLabel?.constraints.filter { $0.identifier == "UnreadEventSpacing" }
			if o.indicator <= 0 {
				NSLayoutConstraint.deactivate(c ?? [])
			} else {
				NSLayoutConstraint.activate(c ?? [])
			}
			
			if let t = self.textLabel {
				t.font = NSFont.systemFont(ofSize: t.font!.pointSize,
						weight: o.indicator <= 0 ? NSFontWeightBold : NSFontWeightRegular)
			}
			
			// Update the time label in realtime!
			NotificationCenter.default().subscribe(name: "PersonView.UpdateTime") { n in
				self.timeLabel?.stringValue = self.time.relativeString()
			}
		}
	}
	
	// Dynamically adjust subviews based on the indicated row size.
	// Technically should be unimplemented, as AutoLayout does this for free.
	public override var rowSizeStyle: NSTableViewRowSizeStyle {
		didSet {
			// FIXME: What do we do here?
		}
	}
	
	// Return an array of all dragging components corresponding to our subviews.
	public override var draggingImageComponents: [NSDraggingImageComponent] {
		return [self.draggingComponent("Person")]
	}
	
	// Allows the circle crop to dynamically change.
	public override func layout() {
		super.layout()
		if let photo = self.photoView, let layer = photo.layer {
			layer.masksToBounds = true
			layer.borderWidth = 2.0
			layer.cornerRadius = photo.bounds.width / 2.0
		}
		if let unread = self.unreadLabel, let layer = unread.layer {
			layer.masksToBounds = true
			layer.cornerRadius = unread.bounds.width / 2.0
		}
	}
}

// Container-type view for PersonView.
public class PersonsView: ElementContainerView {
	internal override func createView() -> PersonView {
		var view = self.tableView.make(withIdentifier: PersonView.className(), owner: nil) as? PersonView
		if view == nil {
			view = PersonView(frame: NSZeroRect)
			view!.identifier = PersonView.className()
		}
		return view!
	}
}
