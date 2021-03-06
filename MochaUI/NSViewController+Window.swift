import AppKit
import Mocha

/* TODO: Support utility, modal, normal windows, AND drawer/panel? */
// NSApp.runModalForWindow(), NSApp.stopModal(), [.utilityWindow]
/* TODO: Deprecate the _rootAnimator property and use presentionAnimator. */

/// Supported objects can allow customization of their behavior within windows using this protocol.
@objc public protocol WindowPresentable: NSWindowDelegate {
    
    /// Provide a type for the NSWindow to be created.
    @objc optional func windowClass() -> NSWindow.Type
    
    /// As the NSWindow is being prepared, a WindowPresentable may customize it as well.
    func prepare(window: NSWindow)
}

public extension NSViewController {
    
    public func presentViewControllerAsWindow(_ viewController: NSViewController) {
        self.presentViewController(viewController, animator: WindowTransitionAnimator())
    }
    
    // For root controllers. The window delegate is set to the VC if it conforms to NSWindowDelegate.
    public func presentAsWindow() {
        (self._rootAnimator ?? WindowTransitionAnimator()).display(viewController: self)
    }
    
    // For root controllers. Use only if presentAsWindow() was used.
    public func dismissFromWindow() {
        self._rootAnimator?.undisplay(viewController: self)
    }
}

public extension NSViewController {
    
    /// Traverses the ViewController hierarchy and returns the closest ancestor ViewController
    /// that matches the `type` provided. If `includingSelf`, then the receiver can be returned.
    public func ancestor<T: NSViewController>(ofType type: T.Type, includingSelf: Bool = true) -> T? {
        if includingSelf /*&& (self is type)*/ { //fixme
            return self as? T
        } else if let p = self.parent {
            return p.ancestor(ofType: type, includingSelf: true)
        }
        return nil
    }
    
    public var splitViewController: NSSplitViewController? {
        return self.ancestor(ofType: NSSplitViewController.self)
    }
    
    public var tabViewController: NSTabViewController? {
        return self.ancestor(ofType: NSTabViewController.self)
    }
    
    /// Accessor for the CALayer backing the NSView.
    public var layer: CALayer {
        if self.view.layer == nil && self.view.wantsLayer == false {
            self.view.wantsLayer = true
        }
        return self.view.layer!
    }
}

public extension NSViewController {
    private static var presentationAnimatorProp = KeyValueProperty<NSViewController, NSViewControllerPresentationAnimator>("presentationAnimator")
    private static var rootAnimatorProp = AssociatedProperty<NSViewController, WindowTransitionAnimator>(.strong)
    
    @nonobjc public fileprivate(set) var presentationAnimator: NSViewControllerPresentationAnimator? {
        get { return NSViewController.presentationAnimatorProp[self] }
        set { NSViewController.presentationAnimatorProp[self] = newValue }
    }
    
    @nonobjc fileprivate var _rootAnimator: WindowTransitionAnimator? {
        get { return NSViewController.rootAnimatorProp[self] }
        set { NSViewController.rootAnimatorProp[self] = newValue }
    }
}

public class WindowTransitionAnimator: NSObject, NSViewControllerPresentationAnimator {
    
    private var window: NSWindow?
    deinit {
        assert(self.window == nil, "WindowTransitionAnimator.animateDismissal(...) was not invoked!")
    }
    
    // for ROOT NSViewController only
    public func display(viewController: NSViewController) {
        guard viewController._rootAnimator == nil else {
            assert(viewController._rootAnimator == self, "the view controller has a different WindowTransitionAnimator already!")
            UI { self.window?.makeKeyAndOrderFront(nil) }
            return
        }
        
        UI {
            viewController.view.layoutSubtreeIfNeeded()
            let p = viewController.view.fittingSize
            
            let clazz = (viewController as? WindowPresentable)?.windowClass?() ?? NSWindow.self
            self.window = clazz.init(contentRect: NSRect(x: 0, y: 0, width: p.width, height: p.height),
                                     styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            self.window?.isReleasedWhenClosed = false
            self.window?.contentView?.superview?.wantsLayer = true // always root-layer-backed
            NotificationCenter.default.addObserver(self, selector: #selector(NSWindowDelegate.windowWillClose(_:)),
                                                   name: NSWindow.willCloseNotification, object: self.window)
            
            self.window?.contentViewController = viewController
            self.window?.bind(.title, to: viewController, withKeyPath: "title", options: nil)
            self.window?.appearance = viewController.view.window?.appearance
            self.window?.delegate = viewController as? NSWindowDelegate
            self.window?.center()
            
            if let vc = viewController as? WindowPresentable, let w = self.window {
                vc.prepare(window: w)
            }
            viewController._rootAnimator = self
            self.window?.makeKeyAndOrderFront(nil)
        }
    }
    
    public func undisplay(viewController: NSViewController) {
        UI {
            NotificationCenter.default.removeObserver(self)
            self.window?.orderOut(nil)
            self.window?.unbind(.title)
            
            self.window = nil
            viewController._rootAnimator = nil
        }
    }
    
    public func animatePresentation(of viewController: NSViewController, from fromViewController: NSViewController) {
        assert(self.window == nil, "WindowTransitionAnimator.animatePresentation(...) was invoked already!")
        self.display(viewController: viewController)
    }
    
    public func animateDismissal(of viewController: NSViewController, from fromViewController: NSViewController) {
        assert(self.window != nil, "WindowTransitionAnimator.animateDismissal(...) invoked before WindowTransitionAnimator.animatePresentation(...)!")
        self.undisplay(viewController: viewController)
    }
    
    @objc public func windowWillClose(_ notification: Notification) {
        guard let c = self.window?.contentViewController else { return }
        if let p = c.presenting {
            UI { p.dismiss(c) }
        } else {
            self.undisplay(viewController: self.window!.contentViewController!)
        }
    }
}
