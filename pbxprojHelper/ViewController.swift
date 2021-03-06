//
//  ViewController.swift
//  pbxprojHelper
//
//  Created by 杨萧玉 on 2016/9/24.
//  Copyright © 2016年 杨萧玉. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var filePathTF: NSTextField!
    @IBOutlet weak var resultTable: NSOutlineView!
    @IBOutlet weak var chooseJSONFileBtn: NSButton!
    @IBOutlet weak var filePathListView: NSView!
    @IBOutlet weak var filePathListHeightConstraint: NSLayoutConstraint!
    
    var propertyListURL: URL?
    var jsonFileURL: URL?
    var filterKeyWord = ""
    
    var originalPropertyList: [String: Any] = [:]
    var currentPropertyList: [String: Any] = [:]
    
    override func viewDidLoad() {
        filePathListView.isHidden = true
        let clickFilePathGesture = NSClickGestureRecognizer(target: self, action: #selector(ViewController.handleClickFilePath(_:)))
        filePathTF.addGestureRecognizer(clickFilePathGesture)
        
        let chooseFilePathGesture = NSClickGestureRecognizer(target: self, action: #selector(ViewController.chooseFilePathGesture(_:)))
        filePathListView.addGestureRecognizer(chooseFilePathGesture)
    }
    
    func refreshFilePathListView() {
        if !filePathListView.isHidden {
            for view in filePathListView.subviews {
                view.removeFromSuperview()
            }
            let textFieldHeight = filePathTF.bounds.size.height
            filePathListHeightConstraint.constant = CGFloat(recentUsePaths.count) * textFieldHeight
            var nextOriginY: CGFloat = CGFloat(recentUsePaths.count-1) * textFieldHeight
            for key in recentUsePaths {
                let path = recentUsePaths[key]
                let textField = NSTextField(string: path)
                textField.toolTip = key
                textField.isBordered = false
                textField.frame = NSRect(x: CGFloat(0), y: nextOriginY, width: filePathListView.bounds.size.width, height: textFieldHeight)
                filePathListView.addSubview(textField)
                nextOriginY -= textFieldHeight
            }
        }
    }
    
    func handleSelectProjectFileURL(_ url: URL) {
        filePathTF.stringValue = url.path
        propertyListURL = url
        originalPropertyList = [:]
        currentPropertyList = [:]
        if let data = PropertyListHandler.parseProject(fileURL: url) {
            let shortURL: URL
            if url.lastPathComponent == "project.pbxproj" {
                shortURL = url.deletingLastPathComponent()
            }
            else {
                shortURL = url
            }
            recentUsePaths[url.path] = shortURL.path
            originalPropertyList = data
            currentPropertyList = data
            resultTable.reloadData()
            refreshFilePathListView()
        }
    }
    
}

//MARK: - User Action

extension ViewController {
    
    @IBAction func selectProjectFile(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedFileTypes = ["pbxproj", "xcodeproj"]
        
        if openPanel.runModal() == NSFileHandlingPanelOKButton {
            if let url = openPanel.url {
                handleSelectProjectFileURL(url)
            }
        }
    }
    
    func handleClickFilePath(_ gesture: NSClickGestureRecognizer) {
        filePathListView.isHidden = !filePathListView.isHidden
        refreshFilePathListView()
    }
    
    func chooseFilePathGesture(_ gesture: NSClickGestureRecognizer) {
        let clickPoint = gesture.location(in: gesture.view)
        for (index, subview) in filePathListView.subviews.enumerated() {
            let pointInSubview = subview.convert(clickPoint, from: filePathListView)
            if subview.bounds.contains(pointInSubview) {
                let path = recentUsePaths[index]
                handleSelectProjectFileURL(URL(fileURLWithPath: path))
            }
        }
        filePathListView.isHidden = true
    }
    
    @IBAction func chooseJSONFile(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.prompt = "Select"
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == NSFileHandlingPanelOKButton {
            if let url = openPanel.url,
                let data = PropertyListHandler.parseJSON(fileURL: url) as? [String: [String: Any]] {
                jsonFileURL = url
                currentPropertyList = PropertyListHandler.apply(json: data, onProjectData: originalPropertyList)
                chooseJSONFileBtn.title = url.lastPathComponent
                resultTable.reloadData()
            }
        }
    }
    
    @IBAction func applyJSONConfiguration(_ sender: NSButton) {
        if let propertyURL = propertyListURL, let jsonURL = jsonFileURL {
            if let propertyListData = PropertyListHandler.parseProject(fileURL: propertyURL),
                let jsonFileData = PropertyListHandler.parseJSON(fileURL: jsonURL) as? [String: [String: Any]]{
                originalPropertyList = propertyListData
                currentPropertyList = PropertyListHandler.apply(json: jsonFileData, onProjectData: originalPropertyList)
                resultTable.reloadData()
            }
            DispatchQueue.global().async {
                PropertyListHandler.generateProject(fileURL: propertyURL, withPropertyList: self.currentPropertyList)
            }
        }
    }
    
    @IBAction func revertPropertyList(_ sender: NSButton) {
        if let url = propertyListURL {
            if PropertyListHandler.revertProject(fileURL: url), let data = PropertyListHandler.parseProject(fileURL: url) {
                originalPropertyList = data
                currentPropertyList = data
            }
            else {
                currentPropertyList = originalPropertyList
            }
            chooseJSONFileBtn.title = "Choose JSON File"
            resultTable.reloadData()
        }
    }
    
    @IBAction func click(_ sender: NSOutlineView) {
        if sender.clickedRow >= 0 && sender.clickedColumn >= 0 {
            let item = sender.item(atRow: sender.clickedRow)
            let column = sender.tableColumns[sender.clickedColumn]
            if let selectedString = self.outlineView(sender, objectValueFor: column, byItem: item) as? String {
                writePasteboard(selectedString)
            }
        }
    }
    
    @IBAction func doubleClick(_ sender: NSOutlineView) {
        if sender.selectedRow >= 0 {
            let item = sender.item(atRow: sender.clickedRow)
            let path = keyPath(forItem: item)
            writePasteboard(path)
        }
    }
}

//MARK: - NSOutlineViewDataSource
extension ViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil {
            if filterKeyWord != "" {
                return elementsOfDictionary(currentPropertyList, containsKeyWord: filterKeyWord).count
            }
            return currentPropertyList.count
        }
        
        let itemValue = (item as? Item)?.value
        if let dictionary = itemValue as? [String: Any] {
            if filterKeyWord != "" && !((item as? Item)?.key.lowercased().contains(filterKeyWord.lowercased()) ?? false) {
                return elementsOfDictionary(dictionary, containsKeyWord: filterKeyWord).count
            }
            return dictionary.count
        }
        if let array = itemValue as? [Any] {
            if filterKeyWord != "" && !((item as? Item)?.key.lowercased().contains(filterKeyWord.lowercased()) ?? false) {
                return elementsOfArray(array, containsKeyWord: filterKeyWord).count
            }
            return array.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return self.outlineView(outlineView, numberOfChildrenOfItem: item) > 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let itemValue = (item as? Item)?.value
        if var dictionary = item == nil ? currentPropertyList : (itemValue as? [String: Any]) {
            if filterKeyWord != "" && !((item as? Item)?.key.lowercased().contains(filterKeyWord.lowercased()) ?? false) {
                dictionary = elementsOfDictionary(dictionary, containsKeyWord: filterKeyWord)
            }
            let keys = Array(dictionary.keys)
            let key = keys[index]
            let value = dictionary[key] ?? ""
            let childItem = Item(key: key, value: value, parent: item)
            return childItem
        }
        if var array = (itemValue as? [String]) {
            if filterKeyWord != "" && !((item as? Item)?.key.lowercased().contains(filterKeyWord.lowercased()) ?? false) {
                array = elementsOfArray(array, containsKeyWord: filterKeyWord) as! [String]
            }
            return Item(key: array[index], value: "", parent: item)
        }
        return Item(key: "", value: "", parent: item)
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        if let pair = item as? Item {
            if tableColumn?.identifier == "Key" {
                return pair.key
            }
            if tableColumn?.identifier == "Value" {
                if let value = pair.value as? [String: Any] {
                    return "Dictionary (\(value.count) elements)"
                }
                if let value = pair.value as? [Any] {
                    return "Array (\(value.count) elements)"
                }
                return pair.value
            }
        }
        return nil
    }
}

//MARK: - NSOutlineViewDelegate

extension ViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
        return false
    }
}

//MARK: - NSTextFieldDelegate
extension ViewController: NSTextFieldDelegate {
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        if let text = fieldEditor.string {
            filterKeyWord = text
            resultTable.reloadData()
            resultTable.expandItem(nil, expandChildren: true)
        }
        return true
    }
}
