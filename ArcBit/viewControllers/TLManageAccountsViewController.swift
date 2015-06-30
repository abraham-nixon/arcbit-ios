//
//  TLManageAccountsViewController.swift
//  ArcBit
//
//  Created by Timothy Lee on 3/14/15.
//  Copyright (c) 2015 Timothy Lee <stequald01@gmail.com>
//
//   This library is free software; you can redistribute it and/or
//   modify it under the terms of the GNU Lesser General Public
//   License as published by the Free Software Foundation; either
//   version 2.1 of the License, or (at your option) any later version.
//
//   This library is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//   Lesser General Public License for more details.
//
//   You should have received a copy of the GNU Lesser General Public
//   License along with this library; if not, write to the Free Software
//   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
//   MA 02110-1301  USA

import Foundation
import UIKit

@objc(TLManageAccountsViewController) class TLManageAccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CustomIOS7AlertViewDelegate {

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    let MAX_ACTIVE_CREATED_ACCOUNTS = 8
    let MAX_IMPORTED_ACCOUNTS = 8
    let MAX_IMPORTED_ADDRESSES = 32
    @IBOutlet private var accountsTableView: UITableView?
    private var QRImageModal: TLQRImageModal?
    private var accountActionsArray: NSArray?
    private var numberOfSections: Int = 0
    private var accountListSection: Int = 0
    private var importedAccountSection: Int = 0
    private var importedWatchAccountSection: Int = 0
    private var importedAddressSection: Int = 0
    private var importedWatchAddressSection: Int = 0
    private var archivedAccountSection: Int = 0
    private var archivedImportedAccountSection: Int = 0
    private var archivedImportedWatchAccountSection: Int = 0
    private var archivedImportedAddressSection: Int = 0
    private var archivedImportedWatchAddressSection: Int = 0
    private var accountActionSection: Int = 0
    private var accountRefreshControl: UIRefreshControl?
    private var showAddressListAccountObject: TLAccountObject?
    private var showAddressListShowBalances: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setColors()

        self.setLogoImageView()

        self.navigationController!.view.addGestureRecognizer(self.slidingViewController().panGesture)

        accountListSection = 0

        self.accountsTableView!.delegate = self
        self.accountsTableView!.dataSource = self
        self.accountsTableView!.tableFooterView = UIView(frame: CGRectZero)

        NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "refreshWalletAccountsNotification:",
                name: TLNotificationEvents.EVENT_DISPLAY_LOCAL_CURRENCY_TOGGLED(), object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "refreshWalletAccountsNotification:",
                name: TLNotificationEvents.EVENT_FETCHED_ADDRESSES_DATA(), object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "accountsTableViewReloadDataWrapper:",
                name: TLNotificationEvents.EVENT_ADVANCE_MODE_TOGGLED(), object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self,
                selector: "accountsTableViewReloadDataWrapper:", name: TLNotificationEvents.EVENT_MODEL_UPDATED_NEW_UNCONFIRMED_TRANSACTION(), object: nil)

        accountRefreshControl = UIRefreshControl()
        accountRefreshControl!.addTarget(self, action: "refresh:", forControlEvents: .ValueChanged)
        self.accountsTableView!.addSubview(accountRefreshControl!)

        checkToRecoverAccounts()
        refreshWalletAccounts(false)
    }

    func refresh(refresh:UIRefreshControl) -> () {
        self.refreshWalletAccounts(true)
        accountRefreshControl!.endRefreshing()
    }

    override func viewWillAppear(animated: Bool) -> () {
        // TODO: better way
        if AppDelegate.instance().scannedEncryptedPrivateKey != nil {
            TLPrompts.promptForEncryptedPrivKeyPassword(self, view:self.slidingViewController().topViewController.view,
                encryptedPrivKey:AppDelegate.instance().scannedEncryptedPrivateKey!,
                success:{(privKey: String!) in
                    let privateKey = privKey
                    let encryptedPrivateKey = AppDelegate.instance().scannedEncryptedPrivateKey
                    self.checkAndImportAddress(privateKey!, encryptedPrivateKey: encryptedPrivateKey)
                    AppDelegate.instance().scannedEncryptedPrivateKey = nil
                }, failure:{(isCanceled: Bool) in
                    AppDelegate.instance().scannedEncryptedPrivateKey = nil
            })
        }
    }
    
    override func viewDidAppear(animated: Bool) -> () {
        NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_MANAGE_ACCOUNTS_SCREEN(),
                object: nil)
    }

    func checkToRecoverAccounts() {
        if (AppDelegate.instance().aAccountNeedsRecovering()) {
            TLHUDWrapper.showHUDAddedTo(self.slidingViewController().topViewController.view, labelText: "Recovering Accounts", animated: true)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                AppDelegate.instance().checkToRecoverAccounts()
                dispatch_async(dispatch_get_main_queue()) {
                    self.refreshWalletAccounts(false)
                    TLHUDWrapper.hideHUDForView(self.view, animated: true)
                }
            }
        }
    }

    private func refreshImportedAccounts(fetchDataAgain: Bool) -> () {
        for (var i = 0; i < AppDelegate.instance().importedAccounts!.getNumberOfAccounts(); i++) {
            let accountObject = AppDelegate.instance().importedAccounts!.getAccountObjectForIdx(i)
            let indexPath = NSIndexPath(forRow: i, inSection: importedAccountSection)
            if self.accountsTableView!.cellForRowAtIndexPath(indexPath) == nil {
                return
            }
            if (!accountObject.hasFetchedAccountData() || fetchDataAgain) {
                let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell
                if cell != nil {
                    (cell!.accessoryView! as! UIActivityIndicatorView).hidden = false
                    cell!.accountBalanceButton!.hidden = true
                    (cell!.accessoryView! as! UIActivityIndicatorView).startAnimating()
                }
                AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: fetchDataAgain, success: {
                    if cell != nil {
                        (cell!.accessoryView as! UIActivityIndicatorView).stopAnimating()
                        (cell!.accessoryView as! UIActivityIndicatorView).hidden = true
                        cell!.accountBalanceButton!.hidden = false
                        if accountObject.downloadState == .Downloaded {
                            let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                            cell!.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                        }
                        cell!.accountBalanceButton!.hidden = false
                    }
                })
            } else {
                if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                    cell.accountNameLabel!.text = accountObject.getAccountName()
                    let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                    cell.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
                }
            }
        }
    }

    private func refreshImportedWatchAccounts(fetchDataAgain: Bool) -> () {
        for (var i = 0; i < AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts(); i++) {
            let accountObject = AppDelegate.instance().importedWatchAccounts!.getAccountObjectForIdx(i)
            let indexPath = NSIndexPath(forRow: i, inSection: importedWatchAccountSection)
            if self.accountsTableView!.cellForRowAtIndexPath(indexPath) == nil {
                return
            }
            if (!accountObject.hasFetchedAccountData() || fetchDataAgain) {
                let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell
                if cell != nil {
                    (cell!.accessoryView! as! UIActivityIndicatorView).hidden = false
                    (cell!.accessoryView! as! UIActivityIndicatorView).startAnimating()
                    cell!.accountBalanceButton!.hidden = true
                }
                AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: fetchDataAgain, success: {
                    if cell != nil {
                        (cell!.accessoryView as! UIActivityIndicatorView).stopAnimating()
                        (cell!.accessoryView as! UIActivityIndicatorView).hidden = true
                        cell!.accountBalanceButton!.hidden = false
                        if accountObject.downloadState == .Downloaded {
                            let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                            cell!.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                        }
                        cell!.accountBalanceButton!.hidden = false
                    }
                })
            } else {
                if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                    cell.accountNameLabel!.text = accountObject.getAccountName()
                    let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                    cell.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
                }
            }
        }
    }

    private func refreshImportedAddressBalances(fetchDataAgain: Bool) {
        if (AppDelegate.instance().importedAddresses!.getCount() > 0 &&
            (!AppDelegate.instance().importedAddresses!.hasFetchedAddressesData() || fetchDataAgain)) {
                for (var i = 0; i < AppDelegate.instance().importedAddresses!.getCount(); i++) {
                    let indexPath = NSIndexPath(forRow: i, inSection: importedAddressSection)
                    if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                        (cell.accessoryView as! UIActivityIndicatorView).hidden = false
                        cell.accountBalanceButton!.hidden = true
                        (cell.accessoryView as! UIActivityIndicatorView).startAnimating()
                    }
                }
                
                AppDelegate.instance().pendingOperations.addSetUpImportedAddressesOperation(AppDelegate.instance().importedAddresses!, fetchDataAgain: fetchDataAgain, success: {
                    for (var i = 0; i < AppDelegate.instance().importedAddresses!.getCount(); i++) {
                        let indexPath = NSIndexPath(forRow: i, inSection: self.importedAddressSection)
                        if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                            (cell.accessoryView as! UIActivityIndicatorView).stopAnimating()
                            (cell.accessoryView as! UIActivityIndicatorView).hidden = true
                            if AppDelegate.instance().importedAddresses!.downloadState == .Downloaded {
                                let importAddressObject = AppDelegate.instance().importedAddresses!.getAddressObjectAtIdx(i)
                                let balance = TLWalletUtils.getProperAmount(importAddressObject.getBalance()!)
                                cell.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                            }
                            cell.accountBalanceButton!.hidden = false
                        }
                    }
                })
        }
    }

    private func refreshImportedWatchAddressBalances(fetchDataAgain: Bool) {
        if (AppDelegate.instance().importedWatchAddresses!.getCount() > 0 && (!AppDelegate.instance().importedWatchAddresses!.hasFetchedAddressesData() || fetchDataAgain)) {
            for (var i = 0; i < AppDelegate.instance().importedWatchAddresses!.getCount(); i++) {
                let indexPath = NSIndexPath(forRow: i, inSection: importedWatchAddressSection)
                if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                    (cell.accessoryView as! UIActivityIndicatorView).hidden = false
                    cell.accountBalanceButton!.hidden = true
                    (cell.accessoryView as! UIActivityIndicatorView).startAnimating()
                }
            }
            
            AppDelegate.instance().pendingOperations.addSetUpImportedAddressesOperation(AppDelegate.instance().importedWatchAddresses!, fetchDataAgain: fetchDataAgain, success: {
                for (var i = 0; i < AppDelegate.instance().importedWatchAddresses!.getCount(); i++) {
                    let indexPath = NSIndexPath(forRow: i, inSection: self.importedWatchAddressSection)
                    if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                        (cell.accessoryView as! UIActivityIndicatorView).stopAnimating()
                        (cell.accessoryView as! UIActivityIndicatorView).hidden = true
                        
                        if AppDelegate.instance().importedWatchAddresses!.downloadState == .Downloaded {
                            let importAddressObject = AppDelegate.instance().importedWatchAddresses!.getAddressObjectAtIdx(i)
                            let balance = TLWalletUtils.getProperAmount(importAddressObject.getBalance()!)
                            cell.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                        }
                        cell.accountBalanceButton!.hidden = false
                    }
                }
            })
        }
    }

    private func refreshAccountBalances(fetchDataAgain: Bool) -> () {
        for (var i = 0; i < AppDelegate.instance().accounts!.getNumberOfAccounts(); i++) {
            let accountObject = AppDelegate.instance().accounts!.getAccountObjectForIdx(i)
            let indexPath = NSIndexPath(forRow: i, inSection: accountListSection)
            if self.accountsTableView?.cellForRowAtIndexPath(indexPath) == nil {
                return
            }
            if (!accountObject.hasFetchedAccountData() || fetchDataAgain) {
                let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell
                if cell != nil {
                    (cell!.accessoryView! as! UIActivityIndicatorView).hidden = false
                    cell!.accountBalanceButton!.hidden = true
                    (cell!.accessoryView! as! UIActivityIndicatorView).startAnimating()
                }
                AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: fetchDataAgain, success: {
                    if cell != nil {
                        (cell!.accessoryView as! UIActivityIndicatorView).stopAnimating()
                        (cell!.accessoryView as! UIActivityIndicatorView).hidden = true
                        cell!.accountBalanceButton!.hidden = false
                        if accountObject.downloadState != .Failed {
                            let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                            cell!.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                            cell!.accountBalanceButton!.hidden = false
                        }
                    }
                })
            } else {
                if let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell {
                    cell.accountNameLabel!.text = (accountObject.getAccountName())
                    let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                    cell.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
                }
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) -> () {
        if (segue.identifier == "SegueAddressList") {
            let vc = segue.destinationViewController as! TLAddressListViewController
            vc.navigationItem.title = "Addresses"
            vc.accountObject = showAddressListAccountObject
            vc.showBalances = showAddressListShowBalances
        }
    }

    func refreshWalletAccountsNotification(notification: NSNotification) -> () {
        self.refreshWalletAccounts(false)
    }

    private func refreshWalletAccounts(fetchDataAgain: Bool) -> () {
        self._accountsTableViewReloadDataWrapper()
        self.refreshAccountBalances(fetchDataAgain)
        if (TLPreferences.enabledAdvanceMode()) {
            self.refreshImportedAccounts(fetchDataAgain)
            self.refreshImportedWatchAccounts(fetchDataAgain)
            self.refreshImportedAddressBalances(fetchDataAgain)
            self.refreshImportedWatchAddressBalances(fetchDataAgain)
        }
    }

    private func setUpCellAccounts(accountObject: TLAccountObject, cell: TLAccountTableViewCell, cellForRowAtIndexPath indexPath: NSIndexPath) -> () {
        cell.accountNameLabel!.hidden = false
        cell.accountBalanceButton!.hidden = false
        cell.textLabel!.hidden = true

        cell.accountNameLabel!.text = accountObject.getAccountName()

        if (accountObject.hasFetchedAccountData()) {
            (cell.accessoryView! as! UIActivityIndicatorView).hidden = true
            (cell.accessoryView! as! UIActivityIndicatorView).stopAnimating()
            let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
            cell.accountBalanceButton!.setTitle(balance as? String, forState: UIControlState.Normal)
            cell.accountBalanceButton!.hidden = false
        } else {
            (cell.accessoryView! as! UIActivityIndicatorView).hidden = false
            (cell.accessoryView! as! UIActivityIndicatorView).startAnimating()
            AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: false, success: {
                (cell.accessoryView as! UIActivityIndicatorView).stopAnimating()
                (cell.accessoryView as! UIActivityIndicatorView).hidden = true
                if accountObject.downloadState == .Downloaded {
                    let balance = TLWalletUtils.getProperAmount(accountObject.getBalance())
                    cell.accountBalanceButton!.setTitle(balance as String, forState: .Normal)
                    cell.accountBalanceButton!.hidden = false
                }
            })
        }
    }

    private func setUpCellImportedAddresses(importedAddressObject: TLImportedAddress, cell: TLAccountTableViewCell, cellForRowAtIndexPath indexPath: NSIndexPath) -> () {
        cell.accountNameLabel!.hidden = false
        cell.accountBalanceButton!.hidden = false
        cell.textLabel!.hidden = true

        let label = importedAddressObject.getLabel()
        cell.accountNameLabel!.text = label


        if (importedAddressObject.hasFetchedAccountData()) {
            (cell.accessoryView! as! UIActivityIndicatorView).hidden = true
            (cell.accessoryView! as! UIActivityIndicatorView).stopAnimating()
            let balance = TLWalletUtils.getProperAmount(importedAddressObject.getBalance()!)
            cell.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
        }
    }

    private func setUpCellArchivedImportedAddresses(importedAddressObject: TLImportedAddress, cell: TLAccountTableViewCell, cellForRowAtIndexPath indexPath: NSIndexPath) -> () {
        cell.accountNameLabel!.hidden = true
        cell.accountBalanceButton!.hidden = true
        cell.textLabel!.hidden = false

        let label = importedAddressObject.getLabel()
        cell.textLabel!.text = label
    }

    private func setUpCellArchivedAccounts(accountObject: TLAccountObject, cell: TLAccountTableViewCell, cellForRowAtIndexPath indexPath: NSIndexPath) -> () {

        cell.accountNameLabel!.hidden = true
        cell.accountBalanceButton!.hidden = true
        cell.textLabel!.hidden = false

        cell.textLabel!.text = accountObject.getAccountName()
        (cell.accessoryView! as! UIActivityIndicatorView).hidden = true
    }

    private func promptForTempararyImportExtendedPrivateKey(success: TLWalletUtils.SuccessWithString, error: TLWalletUtils.ErrorWithString) -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Account private key missing",
                message: "Do you want to temporary import your account private key?",
                cancelButtonTitle: "NO",
            destructiveButtonTitle: nil,
                otherButtonTitles: ["YES"],

            tapBlock: {(alertView, action, buttonIndex) in
                
                if (buttonIndex == alertView.firstOtherButtonIndex) {

                AppDelegate.instance().showExtendedPrivateKeyReaderController(self, success: {
                    (data: String!) in
                    success(data)

                }, error: {
                    (data: String?) in
                    error(data)
                })

            } else if (buttonIndex == alertView.cancelButtonIndex) {
                error("")
            }
        })
    }

    private func promtForLabel(success: TLPrompts.UserInputCallback, failure: TLPrompts.Failure) -> () {
        func addTextField(textField: UITextField!){
            textField.placeholder = "label"
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: "Enter Label",
            message: "",
            preferredStyle: .Alert,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Save"],
            preShowBlock: {(controller:UIAlertController!) in
                controller.addTextFieldWithConfigurationHandler(addTextField)
            },
            tapBlock: {(alertView, action, buttonIndex) in
            if (buttonIndex == alertView.firstOtherButtonIndex) {
                if(alertView.textFields != nil) {
                    let label = (alertView.textFields![0] as! UITextField).text
                    success(label)
                }
            } else if (buttonIndex == alertView.cancelButtonIndex) {
                failure(true)
            }
        })
    }

    private func promtForNameAccount(success: TLPrompts.UserInputCallback, failure: TLPrompts.Failure) -> () {
        func addTextField(textField: UITextField!){
            textField.placeholder = "account name"
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: "Enter Label",
            message: "",
            preferredStyle: .Alert,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Save"],
            preShowBlock: {(controller:UIAlertController!) in
                controller.addTextFieldWithConfigurationHandler(addTextField)
            },
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    let accountName = (alertView.textFields![0] as! UITextField).text//alertView.textFieldAtIndex(0)!.text
                    
                    if (AppDelegate.instance().accounts!.accountNameExist(accountName) == true) {
                        UIAlertController.showAlertInViewController(self,
                            withTitle: "Account name is taken",
                            message: "",
                            cancelButtonTitle: "Cancel",
                            destructiveButtonTitle: nil,
                            otherButtonTitles: ["Rename"],
                            tapBlock: {(alertView, action, buttonIndex) in
                                if (buttonIndex == alertView.firstOtherButtonIndex) {
                                    self.promtForNameAccount(success, failure: failure)
                                } else if (buttonIndex == alertView.cancelButtonIndex) {
                                    failure(true)
                                }
                        })
                    } else {
                        success(accountName)
                    }
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    failure(true)
                }
        })
    }
    
    func _accountsTableViewReloadDataWrapper() -> () {
        accountActionsArray = TLHelpDoc.getAccountActionsArray()
        
        numberOfSections = 2
        
        var sectionCounter = 1
        if (TLPreferences.enabledAdvanceMode()) {
            if (AppDelegate.instance().importedAccounts!.getNumberOfAccounts() > 0) {
                importedAccountSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                importedAccountSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts() > 0) {
                importedWatchAccountSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                importedWatchAccountSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedAddresses!.getCount() > 0) {
                importedAddressSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                importedAddressSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedWatchAddresses!.getCount() > 0) {
                importedWatchAddressSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                importedWatchAddressSection = NSIntegerMax
            }
        } else {
            importedAccountSection = NSIntegerMax
            importedWatchAccountSection = NSIntegerMax
            importedAddressSection = NSIntegerMax
            importedWatchAddressSection = NSIntegerMax
        }
        
        if (AppDelegate.instance().accounts!.getNumberOfArchivedAccounts() > 0) {
            archivedAccountSection = sectionCounter
            sectionCounter++
            numberOfSections++
        } else {
            archivedAccountSection = NSIntegerMax
        }
        
        
        if (TLPreferences.enabledAdvanceMode()) {
            if (AppDelegate.instance().importedAccounts!.getNumberOfArchivedAccounts() > 0) {
                archivedImportedAccountSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                archivedImportedAccountSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedWatchAccounts!.getNumberOfArchivedAccounts() > 0) {
                archivedImportedWatchAccountSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                archivedImportedWatchAccountSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedAddresses!.getArchivedCount() > 0) {
                archivedImportedAddressSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                archivedImportedAddressSection = NSIntegerMax
            }
            
            if (AppDelegate.instance().importedWatchAddresses!.getArchivedCount() > 0) {
                archivedImportedWatchAddressSection = sectionCounter
                sectionCounter++
                numberOfSections++
            } else {
                archivedImportedWatchAddressSection = NSIntegerMax
            }
        } else {
            archivedImportedAccountSection = NSIntegerMax
            archivedImportedWatchAccountSection = NSIntegerMax
        }
        
        accountActionSection = sectionCounter
        
        self.accountsTableView!.reloadData()
    }
    
    func accountsTableViewReloadDataWrapper(notification: NSNotification) -> () {
        _accountsTableViewReloadDataWrapper()
    }

    private func promptAccountsActionSheet(idx: Int) -> () {
        let accountObject = AppDelegate.instance().accounts!.getAccountObjectForIdx(idx)
        let accountHDIndex = accountObject.getAccountHDIndex()
        let title = String(format: "Account ID: %u", accountHDIndex)
        
        let otherButtonTitles:[String]
        if (TLPreferences.enabledAdvanceMode()) {
            otherButtonTitles = ["View account public key QR code", "View account private key QR code", "View Addresses", "Scan For Forward Address Payment", "Edit Account Name", "Archive Account"]
        } else {
            otherButtonTitles = ["View Addresses", "Edit Account Name", "Archive Account"]
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: title,
            message: "",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtonTitles as [AnyObject],
            tapBlock: {(actionSheet, action, buttonIndex) in
                var VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                var VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex+1
                var VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex+2
                var MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX = actionSheet.firstOtherButtonIndex+3
                var RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+4
                var ARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+5
                if (!TLPreferences.enabledAdvanceMode()) {
                    VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = -1
                    VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = -1
                    MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX = -1
                    VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                    RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+1
                    ARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+2
                }
                
                if (buttonIndex == VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX) {
                    self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPubKey(), buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(), object: accountObject, userInfo: nil)
                    
                    
                } else if (buttonIndex == VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX) {
                    self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPrivKey()!, buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PRIVATE_KEY(),
                        object: accountObject, userInfo: nil)
                    
                } else if (buttonIndex == MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX) {
                    self.promptInfoAndToManuallyScanForStealthTransactionAccount(accountObject)
                } else if (buttonIndex == VIEW_ADDRESSES_BUTTON_IDX) {
                    self.showAddressListAccountObject = accountObject
                    self.showAddressListShowBalances = true
                    self.performSegueWithIdentifier("SegueAddressList", sender: self)
                } else if (buttonIndex == RENAME_ACCOUNT_BUTTON_IDX) {
                    self.promtForNameAccount({
                        (accountName: String!) in
                        AppDelegate.instance().accounts!.renameAccount(accountObject.getAccountIdxNumber(), accountName: accountName)
                        NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_EDIT_ACCOUNT_NAME(),
                            object: accountObject, userInfo: nil)
                        
                        self._accountsTableViewReloadDataWrapper()
                        
                        }, failure: ({
                            (isCanceled: Bool) in
                        }))
                } else if (buttonIndex == ARCHIVE_ACCOUNT_BUTTON_IDX) {
                    self.promptToArchiveAccountHDWalletAccount(accountObject)
                    
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                    
                }
        })
    }

    private func promptImportedAccountsActionSheet(indexPath: NSIndexPath) -> () {
        let accountObject = AppDelegate.instance().importedAccounts!.getAccountObjectForIdx(indexPath.row)
        let accountHDIndex = accountObject.getAccountHDIndex()
        let title = String(format: "Account ID: %u", accountHDIndex)
        
        UIAlertController.showAlertInViewController(self,
            withTitle: title,
            message: "",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["View account public key QR code", "View account private key QR code", "View Addresses", "Manually Scan For Stealth Transaction", "Edit Account Name", "Archive Account"],
            tapBlock: {(actionSheet, action, buttonIndex) in
                if (buttonIndex == actionSheet.firstOtherButtonIndex) {
                    self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPubKey(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(), object: accountObject, userInfo: nil)
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+1) {
                    self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPrivKey()!,
                        buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PRIVATE_KEY(), object: accountObject, userInfo: nil)
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+2) {
                    self.showAddressListAccountObject = accountObject
                    self.showAddressListShowBalances = true
                    self.performSegueWithIdentifier("SegueAddressList", sender: self)
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+3) {
                    self.promptInfoAndToManuallyScanForStealthTransactionAccount(accountObject)
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+4) {
                    
                    self.promtForNameAccount({
                        (accountName: String!) in
                        AppDelegate.instance().importedAccounts!.editLabel(accountName, accountIdx: accountObject.getAccountIdx())
                        NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_EDIT_ACCOUNT_NAME(), object: nil, userInfo: nil)
                        self._accountsTableViewReloadDataWrapper()
                        }
                        , failure: ({
                            (isCanceled: Bool) in
                        }))}
                else if (buttonIndex == actionSheet.firstOtherButtonIndex+5) {
                    self.promptToArchiveAccount(accountObject)
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                }
        })
    }

    private func promptImportedWatchAccountsActionSheet(indexPath: NSIndexPath) -> () {
        let accountObject = AppDelegate.instance().importedWatchAccounts!.getAccountObjectForIdx(indexPath.row)
        let accountHDIndex = accountObject.getAccountHDIndex()
        let title = String(format: "Account ID: %u", accountHDIndex)
        var addClearPrivateKeyButton = false
        let otherButtons:[String]
        if (accountObject.hasSetExtendedPrivateKeyInMemory()) {
            addClearPrivateKeyButton = true
            otherButtons = ["Clear account private key from memory", "View account public key QR code", "View Addresses", "Manually Scan For Stealth Transaction",  "Edit Account Name", "Archive Account"]
        } else {
            otherButtons = ["View account public key QR code", "View Addresses", "Manually Scan For Stealth Transaction", "Edit Account Name", "Archive Account"]
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: title,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtons as [AnyObject],
            tapBlock: {(actionSheet, action, buttonIndex) in
                var CLEAR_ACCOUNT_PRIVATE_KEY_BUTTON_IDX = -1
                var VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                var VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex+1
                var MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX = actionSheet.firstOtherButtonIndex+2
                var RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+3
                var ARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+4

                if (accountObject.hasSetExtendedPrivateKeyInMemory()) {
                    CLEAR_ACCOUNT_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                    VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex+1
                    VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex+2
                    MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX = actionSheet.firstOtherButtonIndex+3
                    RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+4
                    ARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex+5
                }

                if (addClearPrivateKeyButton && buttonIndex == CLEAR_ACCOUNT_PRIVATE_KEY_BUTTON_IDX) {
                assert(accountObject.hasSetExtendedPrivateKeyInMemory(), "")
                accountObject.clearExtendedPrivateKeyFromMemory()
                TLPrompts.promptSuccessMessage(nil, message: "Account private key cleared from memory")
            } else if (buttonIndex == VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX) {
                self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPubKey(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()
                NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(), object: accountObject, userInfo: nil)
            } else if (buttonIndex == VIEW_ADDRESSES_BUTTON_IDX) {
                self.showAddressListAccountObject = accountObject
                self.showAddressListShowBalances = true
                self.performSegueWithIdentifier("SegueAddressList", sender: self)

            } else if (buttonIndex == MANUALLY_SCAN_TX_FOR_STEALTH_TRANSACTION_BUTTON_IDX) {
                self.promptInfoAndToManuallyScanForStealthTransactionAccount(accountObject)

            } else if (buttonIndex == RENAME_ACCOUNT_BUTTON_IDX) {
                self.promtForNameAccount({
                    (accountName: String!) in
                    AppDelegate.instance().importedWatchAccounts!.editLabel(accountName, accountIdx: accountObject.getAccountIdx())
                    self._accountsTableViewReloadDataWrapper()
                }, failure: {
                    (isCancelled: Bool) in
                })
            } else if (buttonIndex == ARCHIVE_ACCOUNT_BUTTON_IDX) {
                self.promptToArchiveAccount(accountObject)
            } else if (buttonIndex == actionSheet.cancelButtonIndex) {

            }
        })    }

    private func promptImportedAddressActionSheet(importedAddressIdx: Int) -> () {
        let importAddressObject = AppDelegate.instance().importedAddresses!.getAddressObjectAtIdx(importedAddressIdx)
        
        UIAlertController.showAlertInViewController(self,
            withTitle: nil,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["View address QR code", "View private key QR code", "View address in web", "Edit Label", "Archive address"],
            
            tapBlock: {(actionSheet, action, buttonIndex) in
     
        
            if (buttonIndex == actionSheet.firstOtherButtonIndex) {
                self.QRImageModal = TLQRImageModal(data: importAddressObject.getAddress(), buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()
            } else if (buttonIndex == actionSheet.firstOtherButtonIndex+1) {
                self.QRImageModal = TLQRImageModal(data: importAddressObject.getEitherPrivateKeyOrEncryptedPrivateKey()!, buttonCopyText: "Copy To Clipboard", vc: self)

                self.QRImageModal!.show()

            } else if (buttonIndex == actionSheet.firstOtherButtonIndex+2) {
                TLBlockExplorerAPI.instance().openWebViewForAddress(importAddressObject.getAddress())

            } else if (buttonIndex == actionSheet.firstOtherButtonIndex+3) {

                self.promtForLabel({
                    (inputText: String!) in

                    AppDelegate.instance().importedAddresses!.setLabel(inputText, positionInWalletArray: Int(importAddressObject.getPositionInWalletArrayNumber()))

                    self._accountsTableViewReloadDataWrapper()
                }, failure: {
                    (isCancelled: Bool) in
                })
            } else if (buttonIndex == actionSheet.firstOtherButtonIndex+4) {
                self.promptToArchiveAddress(importAddressObject)
            } else if (buttonIndex == actionSheet.cancelButtonIndex) {
            }
        })
    }

    private func promptArchivedImportedAddressActionSheet(importedAddressIdx: Int) -> () {
        let importAddressObject = AppDelegate.instance().importedAddresses!.getArchivedAddressObjectAtIdx(importedAddressIdx)
        UIAlertController.showAlertInViewController(self,
            withTitle: nil,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["View address QR code", "View private key QR code", "View address in web", "Edit Label", "Unarchived address", "Delete address"],
            
            tapBlock: {(actionSheet, action, buttonIndex) in
                
                if (buttonIndex == actionSheet.firstOtherButtonIndex) {
                    self.QRImageModal = TLQRImageModal(data: importAddressObject.getAddress(), buttonCopyText: "Copy To Clipboard", vc: self)
                    
                    self.QRImageModal!.show()
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+1) {
                    self.QRImageModal = TLQRImageModal(data: importAddressObject.getEitherPrivateKeyOrEncryptedPrivateKey()!, buttonCopyText: "Copy To Clipboard", vc: self)
                    
                    self.QRImageModal!.show()
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+2) {
                    TLBlockExplorerAPI.instance().openWebViewForAddress(importAddressObject.getAddress())
                    
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+3) {
                    
                    self.promtForLabel({
                        (inputText: String!) in
                        
                        
                        AppDelegate.instance().importedAddresses!.setLabel(inputText, positionInWalletArray: Int(importAddressObject.getPositionInWalletArrayNumber()))
                        self._accountsTableViewReloadDataWrapper()
                        }, failure: ({
                            (isCanceled: Bool) in
                        }))
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+4) {
                    self.promptToUnarchiveAddress(importAddressObject)
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex+5) {
                    self.promptToDeleteImportedAddress(importedAddressIdx)
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                }
        })
    }

    private func promptImportedWatchAddressActionSheet(importedAddressIdx: Int) -> () {
        let importAddressObject = AppDelegate.instance().importedWatchAddresses!.getAddressObjectAtIdx(importedAddressIdx)
        var addClearPrivateKeyButton = false
        var CLEAR_PRIVATE_KEY_BUTTON_IDX = 0
        var VIEW_ADDRESS_BUTTON_IDX = 0
        var VIEW_ADDRESS_IN_WEB_BUTTON_IDX = 1
        var RENAME_ADDRESS_BUTTON_IDX = 2
        var ARCHIVE_ADDRESS_BUTTON_IDX = 3
        let otherButtonTitles:[String]
        if (importAddressObject.hasSetPrivateKeyInMemory()) {
            addClearPrivateKeyButton = true
            VIEW_ADDRESS_BUTTON_IDX = 1
            VIEW_ADDRESS_IN_WEB_BUTTON_IDX = 2
            RENAME_ADDRESS_BUTTON_IDX = 3
            ARCHIVE_ADDRESS_BUTTON_IDX = 4
            otherButtonTitles = ["Clear private key from memory", "View address QR code", "View address in web", "Edit Label", "Archive address"]
        } else {
            otherButtonTitles = ["View address QR code", "View address in web", "Edit Label", "Archive address"]
        }

        UIAlertController.showAlertInViewController(self,
            withTitle: nil,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtonTitles as [AnyObject],
            
            tapBlock: {(actionSheet, action, buttonIndex) in

                var CLEAR_PRIVATE_KEY_BUTTON_IDX = -1
                var VIEW_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                var VIEW_ADDRESS_IN_WEB_BUTTON_IDX = actionSheet.firstOtherButtonIndex+1
                var RENAME_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex+2
                var ARCHIVE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex+3
                if (importAddressObject.hasSetPrivateKeyInMemory()) {
                    CLEAR_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                    VIEW_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                    VIEW_ADDRESS_IN_WEB_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                    RENAME_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                    ARCHIVE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                }

                if (addClearPrivateKeyButton && buttonIndex == CLEAR_PRIVATE_KEY_BUTTON_IDX) {
                assert(importAddressObject.hasSetPrivateKeyInMemory(), "")
                importAddressObject.clearPrivateKeyFromMemory()
                TLPrompts.promptSuccessMessage(nil, message: "Private key cleared from memory")
            }
            if (buttonIndex == VIEW_ADDRESS_BUTTON_IDX) {
                self.QRImageModal = TLQRImageModal(data: importAddressObject.getAddress(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()

            } else if (buttonIndex == VIEW_ADDRESS_IN_WEB_BUTTON_IDX) {
                TLBlockExplorerAPI.instance().openWebViewForAddress(importAddressObject.getAddress())

            } else if (buttonIndex == RENAME_ADDRESS_BUTTON_IDX) {

                self.promtForLabel({
                    (inputText: String!) in

                    AppDelegate.instance().importedWatchAddresses!.setLabel(inputText, positionInWalletArray: Int(importAddressObject.getPositionInWalletArrayNumber()))
                    self._accountsTableViewReloadDataWrapper()
                }, failure: ({
                    (isCanceled: Bool) in
                }))
            } else if (buttonIndex == ARCHIVE_ADDRESS_BUTTON_IDX) {
                self.promptToArchiveAddress(importAddressObject)
            } else if (buttonIndex == actionSheet.cancelButtonIndex) {

            }
        })    }

    private func promptArchivedImportedWatchAddressActionSheet(importedAddressIdx: Int) -> () {
        let importAddressObject = AppDelegate.instance().importedWatchAddresses!.getArchivedAddressObjectAtIdx(importedAddressIdx)
        var addClearPrivateKeyButton = false
        let otherButtonTitles:[String]
        if (importAddressObject.hasSetPrivateKeyInMemory()) {
            addClearPrivateKeyButton = true
            otherButtonTitles = ["Clear private key from memory", "View address QR code", "View address in web", "Edit Label", "Unarchived address", "Delete address"]
        } else {
            otherButtonTitles = ["View address QR code", "View address in web", "Edit Label", "Unarchived address", "Delete address"]
        }

        UIAlertController.showAlertInViewController(self,
            withTitle: nil,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtonTitles as [AnyObject],
            
            tapBlock: {(actionSheet, action, buttonIndex) in

                var CLEAR_PRIVATE_KEY_BUTTON_IDX = -1
                var VIEW_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 0
                var VIEW_ADDRESS_IN_WEB_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                var RENAME_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                var UNARCHIVE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                var DELETE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                if (importAddressObject.hasSetPrivateKeyInMemory()) {
                    CLEAR_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex
                    VIEW_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                    VIEW_ADDRESS_IN_WEB_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                    RENAME_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                    UNARCHIVE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                    DELETE_ADDRESS_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 5
                } else {
                }

                if (addClearPrivateKeyButton && buttonIndex == CLEAR_PRIVATE_KEY_BUTTON_IDX) {
                assert(importAddressObject.hasSetPrivateKeyInMemory(), "")
                importAddressObject.clearPrivateKeyFromMemory()
                TLPrompts.promptSuccessMessage(nil, message: "Private key cleared from memory")
            }
            if (buttonIndex == VIEW_ADDRESS_BUTTON_IDX) {
                self.QRImageModal = TLQRImageModal(data: importAddressObject.getAddress(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()

            } else if (buttonIndex == VIEW_ADDRESS_IN_WEB_BUTTON_IDX) {
                TLBlockExplorerAPI.instance().openWebViewForAddress(importAddressObject.getAddress())

            } else if (buttonIndex == RENAME_ADDRESS_BUTTON_IDX) {

                self.promtForLabel({
                    (inputText: String!) in
                    
                    AppDelegate.instance().importedWatchAddresses!.setLabel(inputText, positionInWalletArray: Int(importAddressObject.getPositionInWalletArrayNumber()))
                    self._accountsTableViewReloadDataWrapper()
                    }, failure: ({
                        (isCanceled: Bool) in
                    }))
            } else if (buttonIndex == UNARCHIVE_ADDRESS_BUTTON_IDX) {
                self.promptToUnarchiveAddress(importAddressObject)
            } else if (buttonIndex == DELETE_ADDRESS_BUTTON_IDX) {
                self.promptToDeleteImportedWatchAddress(importedAddressIdx)
            } else if (buttonIndex == actionSheet.cancelButtonIndex) {

            }
        })
    }

    private func promptArchivedImportedAccountsActionSheet(indexPath: NSIndexPath, accountType: TLAccountType) -> () {
        assert(accountType == .Imported || accountType == .ImportedWatch, "not TLAccountTypeImported or TLAccountTypeImportedWatch")
        var accountObject: TLAccountObject?
        if (accountType == .Imported) {
            accountObject = AppDelegate.instance().importedAccounts!.getArchivedAccountObjectForIdx(indexPath.row)
        } else if (accountType == .ImportedWatch) {
            accountObject = AppDelegate.instance().importedWatchAccounts!.getArchivedAccountObjectForIdx(indexPath.row)
        }
        
        let accountHDIndex = accountObject!.getAccountHDIndex()
        let title = String(format: "Account ID: %u", accountHDIndex)
        let otherButtonTitles:[String]
        if (accountObject!.getAccountType() == .Imported) {
            otherButtonTitles = ["View account public key QR code", "View account private key QR code", "View Addresses", "Edit Account Name", "Unarchive Account", "Delete Account"]
        } else {
            otherButtonTitles = ["View account public key QR code", "View Addresses", "Edit Account Name", "Unarchive Account", "Delete Account"]
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: title,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtonTitles as [AnyObject],
            
            tapBlock: {(actionSheet, action, buttonIndex) in
                var VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 0
                var VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                var VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                var RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                var UNARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                var DELETE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 5
                if (accountObject!.getAccountType() == .Imported) {
                } else {
                    VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = -1
                    VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                    RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                    UNARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                    DELETE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                }
                if (buttonIndex == VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX) {
                    self.QRImageModal = TLQRImageModal(data: accountObject!.getExtendedPubKey(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(),
                        object: accountObject, userInfo: nil)
                    
                } else if (buttonIndex == VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX) {
                    self.QRImageModal = TLQRImageModal(data: accountObject!.getExtendedPrivKey()!,
                        buttonCopyText: "Copy To Clipboard", vc: self)
                    self.QRImageModal!.show()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(),
                        object: accountObject, userInfo: nil)
                    
                } else if (buttonIndex == VIEW_ADDRESSES_BUTTON_IDX) {
                    self.showAddressListAccountObject = accountObject
                    self.showAddressListShowBalances = false
                    self.performSegueWithIdentifier("SegueAddressList", sender: self)
                } else if (buttonIndex == RENAME_ACCOUNT_BUTTON_IDX) {
                    self.promtForNameAccount({
                        (accountName: String!) in
                        if (accountType == .Imported) {
                            AppDelegate.instance().importedAccounts!.renameAccount(accountObject!.getAccountIdxNumber(), accountName: accountName)
                        } else if (accountType == .ImportedWatch) {
                            AppDelegate.instance().importedWatchAccounts!.renameAccount(accountObject!.getAccountIdxNumber(), accountName: accountName)
                        }
                        self._accountsTableViewReloadDataWrapper()
                        }, failure: ({
                            (isCanceled: Bool) in
                        }))
                } else if (buttonIndex == UNARCHIVE_ACCOUNT_BUTTON_IDX) {
                    if (AppDelegate.instance().importedAccounts!.getNumberOfAccounts() + AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts() >= self.MAX_IMPORTED_ACCOUNTS) {
                        TLPrompts.promptErrorMessage("Maximum accounts reached.", message: "You need to archived an account in order to unarchive a different one.")
                        return
                    }
                    
                    self.promptToUnarchiveAccount(accountObject!)
                } else if (buttonIndex == DELETE_ACCOUNT_BUTTON_IDX) {
                    if (accountType == .Imported) {
                        self.promptToDeleteImportedAccount(indexPath)
                    } else if (accountType == .ImportedWatch) {
                        self.promptToDeleteImportedWatchAccount(indexPath)
                    }
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                    
                }
        })
    }

    private func promptArchivedAccountsActionSheet(idx: Int) -> () {
        let accountObject = AppDelegate.instance().accounts!.getArchivedAccountObjectForIdx(idx)
        let accountHDIndex = accountObject.getAccountHDIndex()
        let title = String(format: "Account ID: %u", accountHDIndex)
        let otherButtonTitles:[String]
        if (TLPreferences.enabledAdvanceMode()) {
            otherButtonTitles = ["View account public key QR code", "View account private key QR code", "View Addresses", "Edit Account Name", "Unarchive Account"]
        } else {
            otherButtonTitles = ["View Addresses", "Edit Account Name", "Unarchive Account"]
        }

        UIAlertController.showAlertInViewController(self,
            withTitle: title,
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: otherButtonTitles as [AnyObject],
            tapBlock: {(actionSheet, action, buttonIndex) in
                var VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 0
                var VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                var VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                var RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 3
                var UNARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 4
                var otherButtonTitles = []
                if (!TLPreferences.enabledAdvanceMode()) {
                    VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX = -1
                    VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX = -1
                    VIEW_ADDRESSES_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 0
                    RENAME_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 1
                    UNARCHIVE_ACCOUNT_BUTTON_IDX = actionSheet.firstOtherButtonIndex + 2
                }
            
            if (buttonIndex == VIEW_EXTENDED_PUBLIC_KEY_BUTTON_IDX) {
                self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPubKey(),
                        buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()
                NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PUBLIC_KEY(), object: accountObject, userInfo: nil)

            } else if (buttonIndex == VIEW_EXTENDED_PRIVATE_KEY_BUTTON_IDX) {
                self.QRImageModal = TLQRImageModal(data: accountObject.getExtendedPrivKey()!,
                        buttonCopyText: "Copy To Clipboard", vc: self)
                self.QRImageModal!.show()
                NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_VIEW_EXTENDED_PRIVATE_KEY(), object: accountObject, userInfo: nil)

            } else if (buttonIndex == VIEW_ADDRESSES_BUTTON_IDX) {
                self.showAddressListAccountObject = accountObject
                self.showAddressListShowBalances = false
                self.performSegueWithIdentifier("SegueAddressList", sender: self)
            } else if (buttonIndex == RENAME_ACCOUNT_BUTTON_IDX) {
                self.promtForNameAccount({
                    (accountName: String!) in
                    AppDelegate.instance().accounts!.renameAccount(accountObject.getAccountIdxNumber(), accountName: accountName)
                    self._accountsTableViewReloadDataWrapper()
                }, failure: ({
                    (isCanceled: Bool) in
                }))
            } else if (buttonIndex == UNARCHIVE_ACCOUNT_BUTTON_IDX) {
                if (AppDelegate.instance().accounts!.getNumberOfAccounts() >= self.MAX_ACTIVE_CREATED_ACCOUNTS) {
                    TLPrompts.promptErrorMessage("Maximum accounts reached.", message: "You need to archived an account in order to unarchive a different one.")
                    return
                }

                self.promptToUnarchiveAccount(accountObject)

            } else if (buttonIndex == actionSheet!.cancelButtonIndex) {

            }
        })
    }

    private func promptToManuallyScanForStealthTransactionAccount(accountObject: TLAccountObject) -> () {
        func addTextField(textField: UITextField!){
            textField.placeholder = "transaction ID"
        }
        
        UIAlertController.showAlertInViewController(self,
            withTitle: "Scan for forward address transaction",
            message: "",
            preferredStyle: .Alert,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            
            preShowBlock: {(controller:UIAlertController!) in
                controller.addTextFieldWithConfigurationHandler(addTextField)
            }
            ,
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    let txid = (alertView.textFields![0] as! UITextField).text
                    self.manuallyScanForStealthTransactionAccount(accountObject, txid: txid)
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    
                }
            }
        )
    }

    private func manuallyScanForStealthTransactionAccount(accountObject: TLAccountObject, txid: String) -> () {
        if accountObject.stealthWallet!.paymentTxidExist(txid) {
            TLPrompts.promptSuccessMessage("", message: String(format: "Transaction %@ already accounted for.", txid))
            return
        }
        
        if count(txid) != 64 || TLWalletUtils.hexStringToData(txid) == nil {
            TLPrompts.promptErrorMessage("Inputed Txid is invalid", message: "Txid must be a 64 character hex string.")
            return
        }

        TLHUDWrapper.showHUDAddedTo(self.slidingViewController().topViewController.view, labelText: "Checking Transaction", animated: true)

        TLBlockExplorerAPI.instance().getTx(txid, success: {
            (jsonData: AnyObject!) in
            let stealthDataScriptAndOutputAddresses = TLStealthWallet.getStealthDataScriptAndOutputAddresses(jsonData as! NSDictionary)
            if stealthDataScriptAndOutputAddresses == nil || stealthDataScriptAndOutputAddresses!.stealthDataScript == nil {
                TLHUDWrapper.hideHUDForView(self.view, animated: true)
                TLPrompts.promptSuccessMessage("", message: "Txid is not a forward address transaction.")
                return
            }
            
            let scanPriv = accountObject.stealthWallet!.getStealthAddressScanKey()
            let spendPriv = accountObject.stealthWallet!.getStealthAddressSpendKey()
            let stealthDataScript = stealthDataScriptAndOutputAddresses!.stealthDataScript!
            if let secret = TLStealthAddress.getPaymentAddressPrivateKeySecretFromScript(stealthDataScript, scanPrivateKey: scanPriv, spendPrivateKey: spendPriv) {
                let paymentAddress = TLCoreBitcoinWrapper.getAddressFromSecret(secret)
                if find(stealthDataScriptAndOutputAddresses!.outputAddresses, paymentAddress!) != nil {
                    
                    TLBlockExplorerAPI.instance().getUnspentOutputs([paymentAddress!], success: {
                        (jsonData: AnyObject!) in
                        if ((jsonData as! NSDictionary).count > 0) {
                            let privateKey = TLCoreBitcoinWrapper.privateKeyFromSecret(secret)
                            let txObject = TLTxObject(dict:jsonData as! NSDictionary)
                            let txTime = txObject.getTxUnixTime()
                            accountObject.stealthWallet!.addStealthAddressPaymentKey(privateKey, paymentAddress: paymentAddress!,
                                txid: txid, txTime: txTime, stealthPaymentStatus: TLStealthPaymentStatus.Unspent)
                            
                            TLHUDWrapper.hideHUDForView(self.view, animated: true)
                            TLPrompts.promptSuccessMessage("Success", message: String(format: "Transaction %@ belongs to this account. Funds imported", txid))
                            
                            AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: true, success: {
                                self.refreshWalletAccounts(false)
                            })
                        } else {
                            TLHUDWrapper.hideHUDForView(self.view, animated: true)
                            TLPrompts.promptSuccessMessage("", message: "Funds have been claimed already.")
                        }
                        }, failure: {(code: Int, status: String!) in
                            TLHUDWrapper.hideHUDForView(self.view, animated: true)
                            TLPrompts.promptSuccessMessage("", message: "Funds have been claimed already.")
                    })
                } else {
                    TLHUDWrapper.hideHUDForView(self.view, animated: true)
                    TLPrompts.promptSuccessMessage("", message: String(format: "Transaction %@ does not belong to this account.", txid))
                }
            } else {
                TLHUDWrapper.hideHUDForView(self.view, animated: true)
                TLPrompts.promptSuccessMessage("", message: String(format: "Transaction %@ does not belong to this account.", txid))
            }
            
            }, failure: {
                (code: Int, status: String!) in
                TLHUDWrapper.hideHUDForView(self.view, animated: true)
                TLPrompts.promptSuccessMessage("Error", message: "Error fetching Transaction.")
        })
    }
    
    private func promptInfoAndToManuallyScanForStealthTransactionAccount(accountObject: TLAccountObject) -> () {
        if (TLSuggestions.instance().enabledShowManuallyScanTransactionForStealthTxInfo()) {
            TLPrompts.promtForOK(self, title:"", message: "This feature allows you to manually input a transaction id and see if the corresponding transaction contains a forwarding payment to your forward address. If so, then the funds will be added to your wallet. Normally the app will discover forwarding payments automatically for you, but if you believe a payment is missing you can use this feature.", success: {
                () in
                self.promptToManuallyScanForStealthTransactionAccount(accountObject)
                TLSuggestions.instance().setEnabledShowManuallyScanTransactionForStealthTxInfo(false)
            })
        } else {
            self.promptToManuallyScanForStealthTransactionAccount(accountObject)
        }
    }

    private func promptToUnarchiveAccount(accountObject: TLAccountObject) -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Unarchive account",
            message: String(format: "Are you sure you want to unarchive account %@", accountObject.getAccountName()),
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    if (accountObject.getAccountType() == .HDWallet) {
                        AppDelegate.instance().accounts!.unarchiveAccount(accountObject.getAccountIdxNumber())
                    } else if (accountObject.getAccountType() == .Imported) {
                        AppDelegate.instance().importedAccounts!.unarchiveAccount(accountObject.getPositionInWalletArrayNumber())
                    } else if (accountObject.getAccountType() == .ImportedWatch) {
                        AppDelegate.instance().importedWatchAccounts!.unarchiveAccount(accountObject.getPositionInWalletArrayNumber())
                    }
                    
                    if !accountObject.isWatchOnly() && !accountObject.stealthWallet!.hasUpdateStealthPaymentStatuses {
                        accountObject.stealthWallet!.updateStealthPaymentStatusesAsync()
                    }
                    self._accountsTableViewReloadDataWrapper()
                    AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: true, success: {
                        self._accountsTableViewReloadDataWrapper()
                    })
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                }
            }
        )
    }

    private func promptToArchiveAccount(accountObject: TLAccountObject) -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle:  "Archive account",
            message: String(format: "Are you sure you want to archive account %@", accountObject.getAccountName()),
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],

            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    if (accountObject.getAccountType() == .HDWallet) {
                        AppDelegate.instance().accounts!.archiveAccount(accountObject.getAccountIdxNumber())
                    } else if (accountObject.getAccountType() == .Imported) {
                        AppDelegate.instance().importedAccounts!.archiveAccount(accountObject.getPositionInWalletArrayNumber())
                    } else if (accountObject.getAccountType() == .ImportedWatch) {
                        AppDelegate.instance().importedWatchAccounts!.archiveAccount(accountObject.getPositionInWalletArrayNumber())
                    }
                    self._accountsTableViewReloadDataWrapper()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_ARCHIVE_ACCOUNT(), object: nil, userInfo: nil)
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                }
            }
        )
    }

    private func promptToArchiveAccountHDWalletAccount(accountObject: TLAccountObject) -> () {
        if (accountObject.getAccountIdx() == 0) {
            let av = UIAlertView(title: "Cannot archive your first account",
                    message: "",
                    delegate: nil,
                    cancelButtonTitle: nil,
                    otherButtonTitles: "OK")

            av.show()
        } else if (AppDelegate.instance().accounts!.getNumberOfAccounts() <= 1) {
            let av = UIAlertView(title: "Cannot archive your one and only account",
                    message: "",
                    delegate: nil,
                    cancelButtonTitle: nil,
                    otherButtonTitles: "OK")

            av.show()
        } else {
            self.promptToArchiveAccount(accountObject)
        }
    }

    private func promptToArchiveAddress(importedAddressObject: TLImportedAddress) -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Archive address",
            message: String(format: "Are you sure you want to archive address %@", importedAddressObject.getLabel()),
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    if (importedAddressObject.isWatchOnly()) {
                        AppDelegate.instance().importedWatchAddresses!.archiveAddress(Int(importedAddressObject.getPositionInWalletArrayNumber()))
                    } else {
                        AppDelegate.instance().importedAddresses!.archiveAddress(Int(importedAddressObject.getPositionInWalletArrayNumber()))
                    }
                    self._accountsTableViewReloadDataWrapper()
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_ARCHIVE_ACCOUNT(), object: nil, userInfo: nil)
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    
                }
            }
        )
    }

    private func promptToUnarchiveAddress(importedAddressObject: TLImportedAddress) -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Unarchive address",
            message:  String(format: "Are you sure you want to unarchive address %@", importedAddressObject.getLabel()),
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    if (importedAddressObject.isWatchOnly()) {
                        AppDelegate.instance().importedWatchAddresses!.unarchiveAddress(Int(importedAddressObject.getPositionInWalletArrayNumber()))
                    } else {
                        AppDelegate.instance().importedAddresses!.unarchiveAddress(Int(importedAddressObject.getPositionInWalletArrayNumber()))
                    }
                    self._accountsTableViewReloadDataWrapper()
                    importedAddressObject.getSingleAddressData({
                        () in
                        self._accountsTableViewReloadDataWrapper()
                        }, failure: {
                            () in
                            
                    })
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    
                }
            }
        )
    }

    private func promptToDeleteImportedAccount(indexPath: NSIndexPath) -> () {
        let accountObject = AppDelegate.instance().importedAccounts!.getArchivedAccountObjectForIdx(indexPath.row)

        UIAlertController.showAlertInViewController(self,
            withTitle: String(format: "Delete %@", accountObject.getAccountName()),
            message: "Are you sure you want to delete this account?",
            cancelButtonTitle: "No",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    AppDelegate.instance().importedAccounts!.deleteAccount(indexPath.row)
                    
                    self.accountsTableView!.beginUpdates()
                    let index = NSIndexPath(indexes: [self.archivedImportedAccountSection, indexPath.row], length:2)
                    let deleteIndexPaths = [index]
                    self.accountsTableView!.deleteRowsAtIndexPaths(deleteIndexPaths, withRowAnimation: .Fade)
                    self.accountsTableView!.endUpdates()
                    self._accountsTableViewReloadDataWrapper()
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    self.accountsTableView!.editing = false
                }
            }
        )
    }

    private func promptToDeleteImportedWatchAccount(indexPath: NSIndexPath) -> () {
        let accountObject = AppDelegate.instance().importedWatchAccounts!.getArchivedAccountObjectForIdx(indexPath.row)
        
        UIAlertController.showAlertInViewController(self,
            withTitle: String(format: "Delete %@", accountObject.getAccountName()),
            message: "Are you sure you want to delete this account?",
            cancelButtonTitle: "No",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
                
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    AppDelegate.instance().importedWatchAccounts!.deleteAccount(indexPath.row)
                    //*
                    self.accountsTableView!.beginUpdates()
                    let index = NSIndexPath(indexes:[self.archivedImportedWatchAccountSection, indexPath.row], length:2)
                    let deleteIndexPaths = NSArray(objects: index)
                    self.accountsTableView!.deleteRowsAtIndexPaths(deleteIndexPaths as [AnyObject], withRowAnimation: .Fade)
                    self.accountsTableView!.endUpdates()
                    //*/
                    self._accountsTableViewReloadDataWrapper()
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                    self.accountsTableView!.editing = false
                }
        })
    }

    private func promptToDeleteImportedAddress(importedAddressIdx: Int) -> () {
        let importedAddressObject = AppDelegate.instance().importedAddresses!.getArchivedAddressObjectAtIdx(importedAddressIdx)

        UIAlertController.showAlertInViewController(self,
            withTitle: String(format: "Delete %@", importedAddressObject.getLabel()),
            message: "Are you sure you want to delete this account?",
            cancelButtonTitle: "No",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],
            tapBlock: {(alertView, action, buttonIndex) in
        
            if (buttonIndex == alertView.firstOtherButtonIndex) {
                self.accountsTableView!.setEditing(true, animated: true)
                AppDelegate.instance().importedAddresses!.deleteAddress(importedAddressIdx)
                self._accountsTableViewReloadDataWrapper()
                self.accountsTableView!.setEditing(false, animated: true)
            } else if (buttonIndex == alertView.cancelButtonIndex) {
                self.accountsTableView!.editing = false
            }
        })
    }

    private func promptToDeleteImportedWatchAddress(importedAddressIdx: Int) -> () {
        let importedAddressObject = AppDelegate.instance().importedWatchAddresses!.getArchivedAddressObjectAtIdx(importedAddressIdx)

        UIAlertController.showAlertInViewController(self,
            withTitle:  String(format: "Delete %@", importedAddressObject.getLabel()),
            message: "Are you sure you want to delete this watch only address?",
            cancelButtonTitle: "No",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes"],

            tapBlock: {(alertView, action, buttonIndex) in

            if (buttonIndex == alertView.firstOtherButtonIndex) {
                self.accountsTableView!.setEditing(true, animated: true)
                AppDelegate.instance().importedWatchAddresses!.deleteAddress(importedAddressIdx)
                self._accountsTableViewReloadDataWrapper()
                self.accountsTableView!.setEditing(false, animated: true)
            } else if (buttonIndex == alertView.cancelButtonIndex) {
                self.accountsTableView!.editing = false
            }
        })
    }

    private func setEditingAndRefreshAccounts() -> () {
        self.accountsTableView!.setEditing(true, animated: true)
        self.refreshWalletAccounts(false)
        self._accountsTableViewReloadDataWrapper()
        self.accountsTableView!.setEditing(false, animated: true)
    }
    
    private func importAccount(extendedPrivateKey: String) -> (Bool) {
        let handleImportAccountFail = {
            dispatch_async(dispatch_get_main_queue()) {
                AppDelegate.instance().importedAccounts!.deleteAccount(AppDelegate.instance().importedAccounts!.getNumberOfAccounts() - 1)
                TLHUDWrapper.hideHUDForView(self.view, animated: true)
                TLPrompts.promptErrorMessage("Error importing account", message: "")
                self.setEditingAndRefreshAccounts()
            }
        }
        
        if (TLHDWalletWrapper.isValidExtendedPrivateKey(extendedPrivateKey)) {
            AppDelegate.instance().saveWalletJsonCloudBackground()
            AppDelegate.instance().saveWalletJSONEnabled = false
            let accountObject = AppDelegate.instance().importedAccounts!.addAccountWithExtendedKey(extendedPrivateKey)
            TLHUDWrapper.showHUDAddedTo(self.slidingViewController().topViewController.view, labelText: "Importing Account", animated: true)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                SwiftTryCatch.try({
                    () -> () in
                    accountObject.recoverAccount(false, recoverStealthPayments: true)
                    AppDelegate.instance().saveWalletJSONEnabled = true
                    AppDelegate.instance().saveWalletJsonCloudBackground()
                    
                    let handleImportAccountSuccess = {
                        dispatch_async(dispatch_get_main_queue()) {
                            TLHUDWrapper.hideHUDForView(self.view, animated: true)
                            self.promtForNameAccount({
                                (_accountName: String?) in
                                var accountName = _accountName
                                if (accountName == nil || accountName == "") {
                                    accountName = accountObject.getDefaultNameAccount()
                                }
                                AppDelegate.instance().importedAccounts!.editLabel(accountName!, accountIdx: accountObject.getAccountIdx())
                                let av = UIAlertView(title: String(format: "Account %@ imported", accountName!),
                                    message: nil,
                                    delegate: nil,
                                    cancelButtonTitle: "OK")
                                
                                av.show()
                                self.setEditingAndRefreshAccounts()
                                }, failure: ({
                                    (isCanceled: Bool) in
                                    self.setEditingAndRefreshAccounts()
                                }))
                        }
                    }
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_IMPORT_ACCOUNT(),
                        object: nil, userInfo: nil)
                    TLStealthWebSocket.instance().sendMessageGetChallenge()
                    AppDelegate.instance().pendingOperations.addSetUpAccountOperation(accountObject, fetchDataAgain: true, success: {
                        self.refreshWalletAccounts(false)
                        handleImportAccountSuccess()
                    })
                }, catch: {
                        (e: NSException!) -> Void in
                    handleImportAccountFail()
                    
                }, finally: { () in })
            }
            return true

        } else {
            let av = UIAlertView(title: "Invalid account private key",
                    message: "",
                    delegate: nil,
                    cancelButtonTitle: "OK",
                    otherButtonTitles: "")

            av.show()
            return false
        }
    }

    private func importWatchOnlyAccount(extendedPublicKey: String) -> (Bool) {
        if (TLHDWalletWrapper.isValidExtendedPublicKey(extendedPublicKey)) {
            AppDelegate.instance().saveWalletJsonCloudBackground()
            AppDelegate.instance().saveWalletJSONEnabled = false
            let accountObject = AppDelegate.instance().importedWatchAccounts!.addAccountWithExtendedKey(extendedPublicKey)
            
            TLHUDWrapper.showHUDAddedTo(self.slidingViewController().topViewController.view, labelText: "Importing Watch Account", animated: true)
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
                SwiftTryCatch.try({
                    () -> () in
                    accountObject.recoverAccount(false, recoverStealthPayments: true)
                    AppDelegate.instance().saveWalletJSONEnabled = true
                    AppDelegate.instance().saveWalletJsonCloudBackground()

                    NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_IMPORT_WATCH_ONLY_ACCOUNT(),
                        object: nil)
                    // don't need to call do accountObject.getAccountData like in importAccount() cause watch only account does not see stealth payments. yet
                    dispatch_async(dispatch_get_main_queue()) {
                        TLHUDWrapper.hideHUDForView(self.view, animated: true)
                        self.promtForNameAccount({
                            (_accountName: String?) in
                                var accountName = _accountName
                                if (accountName == nil || accountName == "") {
                                    accountName = accountObject.getDefaultNameAccount()
                                }
                                AppDelegate.instance().importedWatchAccounts!.editLabel(accountName!, accountIdx: Int(accountObject.getAccountIdx()))
                            
                                let titleStr = String(format: "Account %@ imported", accountName!)
                                let av = UIAlertView(title: titleStr,
                                    message: "",
                                    delegate: nil,
                                    cancelButtonTitle: "OK")
                            
                                av.show()
                                self.setEditingAndRefreshAccounts()
                            }, failure: {
                                (isCanceled: Bool) in
                                
                                self.setEditingAndRefreshAccounts()
                        })
                    }
                }, catch: {
                    (exception: NSException!) -> Void in
                    dispatch_async(dispatch_get_main_queue()) {
                        AppDelegate.instance().importedWatchAccounts!.deleteAccount(AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts() - 1)
                        TLHUDWrapper.hideHUDForView(self.view, animated: true)
                        TLPrompts.promptErrorMessage("Error importing watch only account", message: "Try Again")
                        self.setEditingAndRefreshAccounts()
                    }
                }, finally: { () in })
            }
            
            return true
        } else {
            let av = UIAlertView(title: "Invalid account public Key",
                message: "",
                delegate: nil,
                cancelButtonTitle: "OK",
                otherButtonTitles: "")
            
            av.show()
            return false
        }
    }

    private func checkAndImportAddress(privateKey: String, encryptedPrivateKey: String?) -> (Bool) {        
        if (TLCoreBitcoinWrapper.isValidPrivateKey(privateKey)) {
            if (encryptedPrivateKey != nil) {
                UIAlertController.showAlertInViewController(self,
                    withTitle: "Import private key encrypted or unencrypted?",
                    message: "Importing key encrypted will require you to input the password everytime you want to send bitcoins from it.",
                    cancelButtonTitle: "encrypted",
                    destructiveButtonTitle: nil,
                    otherButtonTitles: ["unencrypted"],

                    tapBlock: {(alertView, action, buttonIndex) in
                    if (buttonIndex == alertView.firstOtherButtonIndex) {
                        let importedAddressObject = AppDelegate.instance().importedAddresses!.addImportedPrivateKey(privateKey,
                                encryptedPrivateKey: nil)
                        self.refreshAfterImportAddress(importedAddressObject)
                    } else if (buttonIndex == alertView.cancelButtonIndex) {
                        let importedAddressObject = AppDelegate.instance().importedAddresses!.addImportedPrivateKey(privateKey,
                                encryptedPrivateKey: encryptedPrivateKey)
                        self.refreshAfterImportAddress(importedAddressObject)
                    }
                })
            } else {
                let importedAddressObject = AppDelegate.instance().importedAddresses!.addImportedPrivateKey(privateKey,
                    encryptedPrivateKey: nil)
                self.refreshAfterImportAddress(importedAddressObject)
            }

            return true
        } else {
            let av = UIAlertView(title: "Invalid private key",
                    message: "",
                    delegate: nil,
                    cancelButtonTitle: "OK")

            av.show()
            return false
        }
    }

    private func refreshAfterImportAddress(importedAddressObject: TLImportedAddress) -> () {
        let lastIdx = AppDelegate.instance().importedAddresses!.getCount()
        let indexPath = NSIndexPath(forRow: lastIdx, inSection: importedAddressSection)
        let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell
        if cell != nil {
            (cell!.accessoryView! as! UIActivityIndicatorView).hidden = false
            (cell!.accessoryView! as! UIActivityIndicatorView).startAnimating()
        }

        importedAddressObject.getSingleAddressData({
            () in
            if cell != nil {
                (cell!.accessoryView! as! UIActivityIndicatorView).stopAnimating()
                (cell!.accessoryView! as! UIActivityIndicatorView).hidden = true
                
                let balance = TLWalletUtils.getProperAmount(importedAddressObject.getBalance()!)
                cell!.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
                self.setEditingAndRefreshAccounts()
            }
        }, failure: {
            () in
            if cell != nil {
                (cell!.accessoryView! as! UIActivityIndicatorView).stopAnimating()
                (cell!.accessoryView! as! UIActivityIndicatorView).hidden = true
            }
        })

        let address = importedAddressObject.getAddress()
        let msg = String(format: "Address %@ imported", address)
        let av = UIAlertView(title: msg,
                message: "",
                delegate: nil,
                cancelButtonTitle: "OK")

        av.show()

        NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_IMPORT_PRIVATE_KEY(), object: nil, userInfo: nil)
    }

    private func checkAndImportWatchAddress(address: String) -> (Bool) {
        if (TLCoreBitcoinWrapper.isValidAddress(address, isTestnet: TLWalletUtils.STATIC_MEMBERS.IS_TESTNET)) {
            if (TLStealthAddress.isStealthAddress(address, isTestnet: TLWalletUtils.STATIC_MEMBERS.IS_TESTNET)) {
                TLPrompts.promptErrorMessage("Error", message: "Cannot import forward address")
                return false
            }
            
            let importedAddressObject = AppDelegate.instance().importedWatchAddresses!.addImportedWatchAddress(address)
            let lastIdx = AppDelegate.instance().importedWatchAddresses!.getCount()
            let indexPath = NSIndexPath(forRow: lastIdx, inSection: importedWatchAddressSection)
            let cell = self.accountsTableView!.cellForRowAtIndexPath(indexPath) as? TLAccountTableViewCell
            if cell != nil {
                (cell!.accessoryView! as! UIActivityIndicatorView).hidden = false
                (cell!.accessoryView! as! UIActivityIndicatorView).startAnimating()
            }
            importedAddressObject.getSingleAddressData(
                {
                    () in
                    if cell != nil {
                        (cell!.accessoryView! as! UIActivityIndicatorView).stopAnimating()
                        (cell!.accessoryView! as! UIActivityIndicatorView).hidden = true
                        
                        let balance = TLWalletUtils.getProperAmount(importedAddressObject.getBalance()!)
                        cell!.accountBalanceButton!.setTitle(balance as String, forState: UIControlState.Normal)
                        self.setEditingAndRefreshAccounts()
                    }
                }, failure: {
                    () in
                    if cell != nil {
                        (cell!.accessoryView! as! UIActivityIndicatorView).stopAnimating()
                        (cell!.accessoryView! as! UIActivityIndicatorView).hidden = true
                    }
            })
            
            let av = UIAlertView(title: String(format: "Address %@ imported", address),
                message: "",
                delegate: nil,
                cancelButtonTitle: "OK")
            
            av.show()
            NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_IMPORT_WATCH_ONLY_ADDRESS(), object: nil, userInfo: nil)
            return true
        } else {
            TLPrompts.promptErrorMessage("Invalid address", message: "")
            return false
        }
    }


    private func promptImportAccountActionSheet() -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Import Account",
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Import via QR code", "Import via text input"],
            tapBlock: {(actionSheet, action, buttonIndex) in
            if (buttonIndex == actionSheet.firstOtherButtonIndex + 0) {
                AppDelegate.instance().showExtendedPrivateKeyReaderController(self, success: {
                    (data: String!) in
                    self.importAccount(data)
                }, error: {
                    (data: String?) in
                })

            } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
                TLPrompts.promtForInputText(self, title: "Import Account", message: "Input account private key", textFieldPlaceholder: nil, success: {
                    (inputText: String!) in
                    self.importAccount(inputText)
                }, failure: {
                    (isCanceled: Bool) in
                })
            } else if (buttonIndex == actionSheet.cancelButtonIndex) {
            }
        })
    }

    private func promptImportWatchAccountActionSheet() -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Import Watch Account",
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Import via QR code", "Import via text input"],
            tapBlock: {(actionSheet, action, buttonIndex) in
                if (buttonIndex == actionSheet.firstOtherButtonIndex + 0) {
                    AppDelegate.instance().showExtendedPublicKeyReaderController(self, success: {
                        (data: String!) in
                        self.importWatchOnlyAccount(data)
                        }, error: {
                            (data: String?) in
                    })
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
                    TLPrompts.promtForInputText(self, title: "Import Watch Account", message: "Input account public key", textFieldPlaceholder: nil, success: {
                        (inputText: String!) in
                        self.importWatchOnlyAccount(inputText)
                        }, failure: {
                            (isCanceled: Bool) in
                    })
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                }
        })
    }

    private func promptImportPrivateKeyActionSheet() -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Import Private Key",
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Import via QR code", "Import via text input"],
            tapBlock: {(actionSheet, action, buttonIndex) in
                if (buttonIndex == actionSheet.firstOtherButtonIndex + 0) {
                    AppDelegate.instance().showPrivateKeyReaderController(self, success: {
                        (data: NSDictionary) in
                        let privateKey = data.objectForKey("privateKey") as? String
                        let encryptedPrivateKey = data.objectForKey("encryptedPrivateKey") as? String
                        if encryptedPrivateKey == nil {
                            self.checkAndImportAddress(privateKey!, encryptedPrivateKey: encryptedPrivateKey)
                        }
                        }, error: {
                            (data: String?) in
                    })
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
                    TLPrompts.promtForInputText(self, title: "Import Private Key", message: "Input private key", textFieldPlaceholder: nil, success: {
                        (inputText: String!) in
                        if (TLCoreBitcoinWrapper.isBIP38EncryptedKey(inputText)) {
                            TLPrompts.promptForEncryptedPrivKeyPassword(self, view:self.slidingViewController().topViewController.view, encryptedPrivKey: inputText, success: {
                                (privKey: String!) in
                                self.checkAndImportAddress(privKey, encryptedPrivateKey: inputText)
                                }, failure: {
                                    (isCanceled: Bool) in
                            })
                        } else {
                            self.checkAndImportAddress(inputText, encryptedPrivateKey: nil)
                        }
                        }, failure: {
                            (isCanceled: Bool) in
                    })
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                }
        })
    }

    private func promptImportWatchAddressActionSheet() -> () {
        UIAlertController.showAlertInViewController(self,
            withTitle: "Import Watch Address",
            message:"",
            preferredStyle: .ActionSheet,
            cancelButtonTitle: "Cancel",
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Import via QR code", "Import via text input"],
            tapBlock: {(actionSheet, action, buttonIndex) in
                if (buttonIndex == actionSheet.firstOtherButtonIndex + 0) {
                    AppDelegate.instance().showAddressReaderControllerFromViewController(self, success: {
                        (data: String!) in
                        self.checkAndImportWatchAddress(data)
                        }, error: {
                            (data: String?) in
                    })
                } else if (buttonIndex == actionSheet.firstOtherButtonIndex + 1) {
                    TLPrompts.promtForInputText(self, title: "Import Watch Address", message: "Input watch address", textFieldPlaceholder: nil, success: {
                        (inputText: String!) in
                        self.checkAndImportWatchAddress(inputText)
                        }, failure: {
                            (isCanceled: Bool) in
                    })
                } else if (buttonIndex == actionSheet.cancelButtonIndex) {
                }
        })
    }

    private func doAccountAction(accountSelectIdx: Int) -> () {
        if (accountSelectIdx == 0) {
            if (AppDelegate.instance().accounts!.getNumberOfAccounts() >= MAX_ACTIVE_CREATED_ACCOUNTS) {
                TLPrompts.promptErrorMessage("Maximum accounts reached.", message: "You need to archive an account in order to create a new one.")
                return
            }

            self.promtForNameAccount({
                (accountName: String!) in
                AppDelegate.instance().accounts!.createNewAccount(accountName, accountType: .Normal)

                NSNotificationCenter.defaultCenter().postNotificationName(TLNotificationEvents.EVENT_CREATE_NEW_ACCOUNT(), object: nil, userInfo: nil)

                self.refreshWalletAccounts(false)
                TLStealthWebSocket.instance().sendMessageGetChallenge()
            }, failure: {
                (isCanceled: Bool) in
            })
        } else if (accountSelectIdx == 1) {
            if (AppDelegate.instance().importedAccounts!.getNumberOfAccounts() + AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts() >= MAX_IMPORTED_ACCOUNTS) {
                TLPrompts.promptErrorMessage("Maximum imported accounts and watch only accounts reached.", message: "You need to archive an imported account or imported watch only account in order to import a new one.")
                return
            }
            self.promptImportAccountActionSheet()
        } else if (accountSelectIdx == 2) {
            if (AppDelegate.instance().importedAccounts!.getNumberOfAccounts() + AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts() >= MAX_IMPORTED_ACCOUNTS) {
                TLPrompts.promptErrorMessage("Maximum imported accounts and watch only accounts reached.", message: "You need to archive an imported account or imported watch only account in order to import a new one.")
                return
            }
            self.promptImportWatchAccountActionSheet()
        } else if (accountSelectIdx == 3) {
            if (AppDelegate.instance().importedAddresses!.getCount() + AppDelegate.instance().importedWatchAddresses!.getCount() >= MAX_IMPORTED_ADDRESSES) {
                TLPrompts.promptErrorMessage("Maximum imported addresses and private keys reached.", message: "You need to archive an imported private key or address in order to import a new one.")
                return
            }
            self.promptImportPrivateKeyActionSheet()
        } else if (accountSelectIdx == 4) {
            if (AppDelegate.instance().importedAddresses!.getCount() + AppDelegate.instance().importedWatchAddresses!.getCount() >= MAX_IMPORTED_ADDRESSES) {
                TLPrompts.promptErrorMessage("Maximum imported addresses and private keys reached.", message: "You need to archive an imported private key or address in order to import a new one.")
                return
            }
            self.promptImportWatchAddressActionSheet()
        }
    }

    @IBAction private func menuButtonClicked(sender: UIButton) {
        self.slidingViewController().anchorTopViewToRightAnimated(true)
    }

    func tableView(tableView: UITableView, heightForRowAtIndexPath: NSIndexPath) -> CGFloat {
        // hard code height here to prevent cell auto-resizing
        return 74
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return numberOfSections
    }

    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (TLPreferences.enabledAdvanceMode()) {
            if (section == accountListSection) {
                return "Accounts"
            } else if (section == importedAccountSection) {
                return "Imported Accounts"
            } else if (section == importedWatchAccountSection) {
                return "Imported Watch Accounts"
            } else if (section == importedAddressSection) {
                return "Imported Addresses"
            } else if (section == importedWatchAddressSection) {
                return "Imported Watch Addresses"
            } else if (section == archivedAccountSection) {
                return "Archived Accounts"
            } else if (section == archivedImportedAccountSection) {
                return "Archived Imported Accounts"
            } else if (section == archivedImportedWatchAccountSection) {
                return "Archived Imported Watch Accounts"
            } else if (section == archivedImportedAddressSection) {
                return "Archived Imported Addresses"
            } else if (section == archivedImportedWatchAddressSection) {
                return "Archived Imported Watch Addresses"
            } else {
                return "Account Actions"
            }
        } else {
            if (section == accountListSection) {
                return "Accounts"
            } else if (section == archivedAccountSection) {
                return "Archived Accounts" } else {
                return "Account Actions"
            }
        }
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (TLPreferences.enabledAdvanceMode()) {
            if (section == accountListSection) {
                return AppDelegate.instance().accounts!.getNumberOfAccounts()
            } else if (section == importedAccountSection) {
                return AppDelegate.instance().importedAccounts!.getNumberOfAccounts()
            } else if (section == importedWatchAccountSection) {
                return AppDelegate.instance().importedWatchAccounts!.getNumberOfAccounts()
            } else if (section == importedAddressSection) {
                return AppDelegate.instance().importedAddresses!.getCount()
            } else if (section == importedWatchAddressSection) {
                return AppDelegate.instance().importedWatchAddresses!.getCount()
            } else if (section == archivedAccountSection) {
                return AppDelegate.instance().accounts!.getNumberOfArchivedAccounts()
            } else if (section == archivedImportedAccountSection) {
                return AppDelegate.instance().importedAccounts!.getNumberOfArchivedAccounts()
            } else if (section == archivedImportedWatchAccountSection) {
                return AppDelegate.instance().importedWatchAccounts!.getNumberOfArchivedAccounts()
            } else if (section == archivedImportedAddressSection) {
                return AppDelegate.instance().importedAddresses!.getArchivedCount()
            } else if (section == archivedImportedWatchAddressSection) {
                return AppDelegate.instance().importedWatchAddresses!.getArchivedCount()
            } else {
                return accountActionsArray!.count
            }
        } else if (section == accountListSection) {
            return AppDelegate.instance().accounts!.getNumberOfAccounts()
        } else if (section == archivedAccountSection) {
            return AppDelegate.instance().accounts!.getNumberOfArchivedAccounts()
        } else {
            return accountActionsArray!.count
        }
    }


    private func setUpCellAccountActions(cell: UITableViewCell, cellForRowAtIndexPath indexPath: NSIndexPath) -> () {
        cell.accessoryType = UITableViewCellAccessoryType.None
        cell.textLabel!.text = accountActionsArray!.objectAtIndex(indexPath.row) as? String
        if(cell.accessoryView != nil) {
            (cell.accessoryView as! UIActivityIndicatorView).hidden = true
        }
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if (indexPath.section == accountActionSection) {
            let MyIdentifier = "AccountActionCellIdentifier"

            var cell = tableView.dequeueReusableCellWithIdentifier(MyIdentifier) as! UITableViewCell?
            if (cell == nil) {
                cell = UITableViewCell(style: UITableViewCellStyle.Default,
                        reuseIdentifier: MyIdentifier)
            }

            cell!.textLabel!.textAlignment = .Center
            cell!.textLabel!.font = UIFont.boldSystemFontOfSize(cell!.textLabel!.font.pointSize)
            self.setUpCellAccountActions(cell!, cellForRowAtIndexPath: indexPath)

            if (indexPath.row % 2 == 0) {
                cell!.backgroundColor = TLColors.evenTableViewCellColor()
            } else {
                cell!.backgroundColor = TLColors.oddTableViewCellColor()
            }

            return cell!
        } else {
            let MyIdentifier = "AccountCellIdentifier"

            var cell = tableView.dequeueReusableCellWithIdentifier(MyIdentifier) as? TLAccountTableViewCell
            if (cell == nil) {
                cell = UITableViewCell(style: UITableViewCellStyle.Default,
                        reuseIdentifier: MyIdentifier) as? TLAccountTableViewCell
            }

            cell!.accountNameLabel!.textAlignment = .Natural
            let activityView = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
            cell!.accessoryView = activityView

            if (TLPreferences.enabledAdvanceMode()) {
                if (indexPath.section == accountListSection) {
                    let accountObject = AppDelegate.instance().accounts!.getAccountObjectForIdx(indexPath.row)
                    self.setUpCellAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == importedAccountSection) {
                    let accountObject = AppDelegate.instance().importedAccounts!.getAccountObjectForIdx(indexPath.row)

                    self.setUpCellAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)

                } else if (indexPath.section == importedWatchAccountSection) {
                    let accountObject = AppDelegate.instance().importedWatchAccounts!.getAccountObjectForIdx(indexPath.row)
                    self.setUpCellAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == importedAddressSection) {
                    let importedAddressObject = AppDelegate.instance().importedAddresses!.getAddressObjectAtIdx(indexPath.row)
                    self.setUpCellImportedAddresses(importedAddressObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == importedWatchAddressSection) {
                    let importedAddressObject = AppDelegate.instance().importedWatchAddresses!.getAddressObjectAtIdx(indexPath.row)
                    self.setUpCellImportedAddresses(importedAddressObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedAccountSection) {
                    let accountObject = AppDelegate.instance().accounts!.getArchivedAccountObjectForIdx(indexPath.row)
                    self.setUpCellArchivedAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedImportedAccountSection) {
                    let accountObject = AppDelegate.instance().importedAccounts!.getArchivedAccountObjectForIdx(indexPath.row)
                    self.setUpCellArchivedAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedImportedWatchAccountSection) {
                    let accountObject = AppDelegate.instance().importedWatchAccounts!.getArchivedAccountObjectForIdx(indexPath.row)
                    self.setUpCellArchivedAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedImportedAddressSection) {
                    let importedAddressObject = AppDelegate.instance().importedAddresses!.getArchivedAddressObjectAtIdx(indexPath.row)
                    self.setUpCellArchivedImportedAddresses(importedAddressObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedImportedWatchAddressSection) {
                    let importedAddressObject = AppDelegate.instance().importedWatchAddresses!.getArchivedAddressObjectAtIdx(indexPath.row)
                    self.setUpCellArchivedImportedAddresses(importedAddressObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else {
                }
            } else {
                if (indexPath.section == accountListSection) {
                    let accountObject = AppDelegate.instance().accounts!.getAccountObjectForIdx(indexPath.row)
                    self.setUpCellAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else if (indexPath.section == archivedAccountSection) {
                    let accountObject = AppDelegate.instance().accounts!.getArchivedAccountObjectForIdx(indexPath.row)
                    self.setUpCellArchivedAccounts(accountObject, cell: cell!, cellForRowAtIndexPath: indexPath)
                } else {
                }
            }

            if (indexPath.row % 2 == 0) {
                cell!.backgroundColor = TLColors.evenTableViewCellColor()
            } else {
                cell!.backgroundColor = TLColors.oddTableViewCellColor()
            }

            return cell!
        }
    }

    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if (TLPreferences.enabledAdvanceMode()) {
            if (indexPath.section == accountListSection) {
                self.promptAccountsActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == importedAccountSection) {
                self.promptImportedAccountsActionSheet(indexPath)
                return nil
            } else if (indexPath.section == importedWatchAccountSection) {
                self.promptImportedWatchAccountsActionSheet(indexPath)
                return nil
            } else if (indexPath.section == importedAddressSection) {
                self.promptImportedAddressActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == importedWatchAddressSection) {
                self.promptImportedWatchAddressActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == archivedAccountSection) {
                self.promptArchivedAccountsActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == archivedImportedAccountSection) {
                self.promptArchivedImportedAccountsActionSheet(indexPath, accountType: .Imported)
                return nil
            } else if (indexPath.section == archivedImportedWatchAccountSection) {
                self.promptArchivedImportedAccountsActionSheet(indexPath, accountType: .ImportedWatch)
                return nil
            } else if (indexPath.section == archivedImportedAddressSection) {
                self.promptArchivedImportedAddressActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == archivedImportedWatchAddressSection) {
                self.promptArchivedImportedWatchAddressActionSheet(indexPath.row)
                return nil
            } else {
                self.doAccountAction(indexPath.row)
                return nil
            }
        } else {
            if (indexPath.section == accountListSection) {
                self.promptAccountsActionSheet(indexPath.row)
                return nil
            } else if (indexPath.section == archivedAccountSection) {
                self.promptArchivedAccountsActionSheet(indexPath.row)
                return nil
            } else {
                self.doAccountAction(indexPath.row)
                return nil
            }
        }
    }

    func customIOS7dialogButtonTouchUpInside(alertView: AnyObject!, clickedButtonAtIndex buttonIndex: Int) -> () {
        if (buttonIndex == 0) {
            iToast.makeText("Copied To clipboard").setGravity(iToastGravityCenter).setDuration(1000).show()
            let pasteboard = UIPasteboard.generalPasteboard()
            pasteboard.string = self.QRImageModal!.QRcodeDisplayData
        } else {

        }

        alertView.close()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}