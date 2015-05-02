//
//  ViewController.swift
//  Hoverlytics for Mac
//
//  Created by Patrick Smith on 28/03/2015.
//  Copyright (c) 2015 Burnt Caramel. All rights reserved.
//

import Cocoa
import HoverlyticsModel


class ViewController: NSViewController
{
	var modelManager: HoverlyticsModel.ModelManager!
	
	var section: MainSection!
	
	var mainState: MainState! {
		didSet {
			startObservingModelManager()
			updateMainViewForState()
		}
	}
	
	typealias MainStateNotification = MainState.Notification
	
	var mainStateNotificationObservers = [MainStateNotification: AnyObject]()
	
	func startObservingModelManager() {
		let nc = NSNotificationCenter.defaultCenter()
		let mainQueue = NSOperationQueue.mainQueue()
		
		func addObserver(notificationIdentifier: MainState.Notification, block: (NSNotification!) -> Void) {
			let observer = nc.addObserverForName(notificationIdentifier.notificationName, object: mainState, queue: mainQueue, usingBlock: block)
			mainStateNotificationObservers[notificationIdentifier] = observer
		}
		
		addObserver(.ChosenSiteDidChange) { (notification) in
			self.updateMainViewForState()
		}
	}
	
	func stopObservingModelManager() {
		let nc = NSNotificationCenter.defaultCenter()
		
		for (notificationIdentifier, observer) in mainStateNotificationObservers {
			nc.removeObserver(observer)
		}
		mainStateNotificationObservers.removeAll(keepCapacity: false)
	}
	
	
	lazy var pageStoryboard: NSStoryboard = {
		NSStoryboard(name: "Page", bundle: nil)!
	}()
	var mainSplitViewController: NSSplitViewController!
	var pageViewController: PageViewController!
	var statsViewController: StatsViewController!
	
	var lastChosenSite: Site!
	
	func updateMainViewForState() {
		let site = mainState?.chosenSite
		if site === lastChosenSite {
			return
		}
		lastChosenSite = site
		
		if let site = site {
			let initialURL = site.homePageURL
			mainState.initialHost = initialURL.host
			
			pageViewController.GoogleOAuth2TokenJSONString = site.GoogleAPIOAuth2TokenJSONString
			pageViewController.hoverlyticsPanelDidReceiveGoogleOAuth2TokenCallback = { [unowned self] tokenJSONString in
				self.modelManager.setGoogleOAuth2TokenJSONString(tokenJSONString, forSite: site)
			}
			pageViewController.loadURL(initialURL)
			
			
			statsViewController.primaryURL = site.homePageURL
		}
		else {
			statsViewController.primaryURL = nil
			mainState.initialHost = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		mainSplitViewController = NSSplitViewController()
		mainSplitViewController.splitView.vertical = false
		//mainSplitViewController.splitView.dividerStyle = .PaneSplitter
		mainSplitViewController.splitView.dividerStyle = .Thick
		fillWithChildViewController(mainSplitViewController)
		
		let storyboard = self.pageStoryboard
		
		// The top web browser
		let pageViewController = storyboard.instantiateControllerWithIdentifier("Page View Controller") as! PageViewController
		pageViewController.navigatedURLDidChangeCallback = { [unowned self] URL in
			if self.mainState.chosenSite == nil {
				self.mainState.initialHost = URL.host
			}
			
			if pageViewController.crawlWhileBrowsing {
				// Can only crawl the initial 'local' website.
				if let initialHost = self.mainState.initialHost {
					if URL.host != initialHost {
						return
					}
				}
				#if DEBUG
					println("navigatedURLDidChangeCallback \(URL)")
				#endif
				self.statsViewController.crawlNavigatedURL(URL)
			}
		}
		
		// The bottom page crawler table
		let statsViewController = storyboard.instantiateControllerWithIdentifier("Stats View Controller") as! StatsViewController
		statsViewController.didChooseURLCallback = { URL, pageInfo in
			if pageInfo.baseContentType == .LocalHTMLPage {
				self.pageViewController.loadURL(URL)
			}
		}
		
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: pageViewController)
			//item.canCollapse = true
			return item
			}())
		self.pageViewController = pageViewController
		
		mainSplitViewController.addSplitViewItem({
			let item = NSSplitViewItem(viewController: statsViewController)
			//item.canCollapse = true
			return item
		}())
		self.statsViewController = statsViewController
	}
	
	
	lazy var siteSettingsStoryboard = NSStoryboard(name: "SiteSettings", bundle: nil)!
	lazy var addSiteViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateControllerWithIdentifier("Add Site View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		return vc
	}()
	lazy var siteSettingsViewController: SiteSettingsViewController = {
		let vc = self.siteSettingsStoryboard.instantiateControllerWithIdentifier("Site Settings View Controller") as! SiteSettingsViewController
		vc.modelManager = self.modelManager
		return vc
	}()
	
	
	@IBAction func showAddSiteRelativeToView(relativeView: NSView) {
		if addSiteViewController.presentingViewController != nil {
			dismissViewController(addSiteViewController)
		}
		else {
			presentViewController(addSiteViewController, asPopoverRelativeToRect: relativeView.bounds, ofView: relativeView, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}
	
	
	@IBAction func showSiteSettings(button: NSButton) {
		if siteSettingsViewController.presentingViewController != nil {
			dismissViewController(siteSettingsViewController)
		}
		else {
			if let chosenSite = mainState?.chosenSite {
				siteSettingsViewController.site = chosenSite
				//siteSettingsViewController.updateUIWithSiteValues(chosenSite.values)
				
				let modelManager = self.modelManager
				siteSettingsViewController.willClose = { siteSettingsViewController in
					let (siteValues, error) = siteSettingsViewController.copySiteValuesFromUI()
					if let siteValues = siteValues {
						modelManager.updateSiteWithValues(chosenSite, siteValues: siteValues)
					}
				}
				
				presentViewController(siteSettingsViewController, asPopoverRelativeToRect: button.bounds, ofView: button, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
			}
		}
	}
	
	
	override var representedObject: AnyObject? {
		didSet {
			
		}
	}
}

