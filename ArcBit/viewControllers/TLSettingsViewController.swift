//
//  TLSettingsViewController.swift
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

import UIKit
import AVFoundation

@objc(TLSettingsViewController) class TLSettingsViewController:IASKAppSettingsViewController, IASKSettingsDelegate,LTHPasscodeViewControllerDelegate {
    
    override var preferredStatusBarStyle : (UIStatusBarStyle) {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setColors()
        
        AppDelegate.instance().setSettingsPasscodeViewColors()

        AppDelegate.instance().giveExitAppNoticeForBlockExplorerAPIToTakeEffect = false
        
        LTHPasscodeViewController.sharedUser().delegate = self
        self.delegate = self
        
        TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(TLPreferences.getEnableBackupWithiCloud())
        
        NotificationCenter.default.addObserver(self, selector: #selector(TLSettingsViewController.settingDidChange(_:)), name: NSNotification.Name(rawValue: kIASKAppSettingChanged), object: nil)
        
        self.updateHiddenKeys()
    }
    
    override func viewDidAppear(_ animated: Bool) -> () {
        NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_VIEW_SETTINGS_SCREEN()), object: nil)
        if (AppDelegate.instance().giveExitAppNoticeForBlockExplorerAPIToTakeEffect) {
            TLPrompts.promptSuccessMessage("Notice".localized, message: "You must close the app in order for the API change to take effect.".localized)
            AppDelegate.instance().giveExitAppNoticeForBlockExplorerAPIToTakeEffect = false
        }
    }
    
    @IBAction fileprivate func menuButtonClicked(_ sender: UIButton) {
        self.slidingViewController().anchorTopViewToRight(animated: true)
    }
    
    fileprivate func updateHiddenKeys() {
        let hiddenKeys = NSMutableSet()
        
        if (TLPreferences.enabledInAppSettingsKitDynamicFee()) {
            hiddenKeys.add("transactionfee")
            hiddenKeys.add("settransactionfee")
        } else {
            hiddenKeys.add("dynamicfeeoption")
        }
        
        if (!LTHPasscodeViewController.doesPasscodeExist()) {
            hiddenKeys.add("changepincode")
        }
        
        let blockExplorerAPI = TLPreferences.getBlockExplorerAPI()
        if (blockExplorerAPI == .blockchain) {
            hiddenKeys.add("blockexplorerurl")
            hiddenKeys.add("setblockexplorerurl")
        } else {
            if (blockExplorerAPI == .insight) {
                let blockExplorerURL = TLPreferences.getBlockExplorerURL(blockExplorerAPI)
                TLPreferences.setInAppSettingsKitBlockExplorerURL(blockExplorerURL!)
            }
        }
        
        if (!TLWalletUtils.ENABLE_STEALTH_ADDRESS()) {
            hiddenKeys.add("stealthaddressdefault")
            hiddenKeys.add("stealthaddressfooter")
        }
        
        self.setHiddenKeys(hiddenKeys as Set<NSObject>, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    fileprivate func showPromptForSetBlockExplorerURL() {
        UIAlertController.showAlert(in: self,
            withTitle: "Set Block Explorer URL".localized,
            message: "",
            preferredStyle: .alert,
            cancelButtonTitle: "Cancel".localized,
            destructiveButtonTitle: nil,
            otherButtonTitles: ["OK".localized],
            
            preShow: {(controller:UIAlertController!) in
                
                func addPromptTextField(_ textField: UITextField!){
                    textField.placeholder = ""
                    textField.text = "http://"
                }
                
                controller.addTextField(configurationHandler: addPromptTextField)
            }
            ,
            tap: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    let candidate = (alertView.textFields![0] ).text
                    
                    let candidateURL = URL(string: candidate!)
                    
                    if (candidateURL != nil && candidateURL!.host != nil) {
                        TLPreferences.setInAppSettingsKitBlockExplorerURL(candidateURL!.absoluteString)
                        TLPreferences.setBlockExplorerURL(TLPreferences.getBlockExplorerAPI(), value: candidateURL!.absoluteString)
                        TLPrompts.promptSuccessMessage("Notice".localized, message: "You must exit and kill this app in order for this to take effect.".localized)
                    } else {
                        UIAlertController.showAlert(in: self,
                            withTitle:  "Invalid URL".localized,
                            message: "Enter something like https://example.com".localized,
                            cancelButtonTitle: "OK".localized,
                            destructiveButtonTitle: nil,
                            otherButtonTitles: nil,
                            tap: {(alertView, action, buttonIndex) in
                                self.showPromptForSetBlockExplorerURL()
                        })
                    }
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                }
        })
    }
    
    fileprivate func showPromptForSetTransactionFee() {
        let msg = String(format: "Input a recommended amount. Somewhere between %@ and %@ BTC".localized, TLWalletUtils.MIN_FEE_AMOUNT_IN_BITCOINS(), TLWalletUtils.MAX_FEE_AMOUNT_IN_BITCOINS())
        
        func addTextField(_ textField: UITextField!){
            textField.placeholder = "fee amount".localized
            textField.keyboardType = .decimalPad
        }
        
        UIAlertController.showAlert(in: self,
            withTitle: "Transaction Fee".localized,
            
            message: msg,
            preferredStyle: .alert,
            cancelButtonTitle: "Cancel".localized,
            destructiveButtonTitle: nil,
            otherButtonTitles: ["OK".localized],
            
            preShow: {(controller:UIAlertController!) in
                controller.addTextField(configurationHandler: addTextField)
            }
            ,
            tap: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView.firstOtherButtonIndex) {
                    let feeAmount = (alertView.textFields![0] ).text
                    
                    let feeAmountCoin = TLCurrencyFormat.bitcoinAmountStringToCoin(feeAmount!)
                    if (TLWalletUtils.isValidInputTransactionFee(feeAmountCoin)) {
                        TLPreferences.setInAppSettingsKitTransactionFee(feeAmountCoin.bigIntegerToBitcoinAmountString(.bitcoin))
                        NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_CHANGE_AUTOMATIC_TX_FEE()), object: nil)
                        
                    } else {
                        let msg = String(format: "Too low a transaction fee can cause transactions to take a long time to confirm. Continue anyways?".localized)
                        
                        TLPrompts.promtForOKCancel(self, title: "Non-recommended Amount Transaction Fee".localized, message: msg, success: {
                            () in
                            let amount = TLCurrencyFormat.bitcoinAmountStringToCoin(feeAmount!)
                            TLPreferences.setInAppSettingsKitTransactionFee(amount.bigIntegerToBitcoinAmountString(.bitcoin))
                            NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_CHANGE_AUTOMATIC_TX_FEE()), object: nil)
                            
                            }, failure: {
                                (isCancelled: Bool) in
                                self.showPromptForSetTransactionFee()
                        })
                    }
                } else if (buttonIndex == alertView.cancelButtonIndex) {
                }
        })
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection: Int) -> CGFloat {
        return 30.0
    }
    
    func settingsViewControllerDidEnd(_ sender: IASKAppSettingsViewController) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func settingsViewController(_ settingsViewController: IASKViewController?,
        tableView: UITableView,
        heightForHeaderForSection section: Int) -> CGFloat {
            
            let key = settingsViewController!.settingsReader.key(forSection: section)
            if (key == "IASKLogo") {
                return UIImage(named: "Icon.png")!.size.height + 25
            } else if (key == "IASKCustomHeaderStyle") {
                return 55
            }
            return 0
    }
    
    fileprivate func switchPasscodeType(_ sender: UISwitch) {
        LTHPasscodeViewController.sharedUser().setIsSimple(sender.isOn,
            in: self,
            asModal: true)
    }
    
    fileprivate func showLockViewForEnablingPasscode() {
        LTHPasscodeViewController.sharedUser().showForEnablingPasscode(in: self,
            asModal: true)
    }
    
    fileprivate func showLockViewForChangingPasscode() {
        LTHPasscodeViewController.sharedUser().showForChangingPasscode(in: self, asModal: true)
    }
    
    
    fileprivate func showLockViewForTurningPasscodeOff() {
        LTHPasscodeViewController.sharedUser().showForDisablingPasscode(in: self,
            asModal: true)
    }
    
    
    fileprivate func promptToConfirmOverwriteCloudWalletJSONFileWithLocalWalletJSONFile() {
        UIAlertController.showAlert(in: self,
            withTitle: "iCloud backup will be lost. Are you sure you want to backup your local wallet to iCloud?".localized,
            message: "",
            cancelButtonTitle: "No".localized,
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes".localized],
            
            tap: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView?.firstOtherButtonIndex) {
                    AppDelegate.instance().saveWalletJsonCloudBackground()
                    TLPreferences.setEnableBackupWithiCloud(true)
                } else if (buttonIndex == alertView?.cancelButtonIndex) {
                    TLPreferences.setEnableBackupWithiCloud(false)
                    TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(false)
                }
        })
        
    }
    
    fileprivate func promptToConfirmOverwriteLocalWalletJSONFileWithCloudWalletJSONFile(_ encryptedWalletJSON: String) {
        UIAlertController.showAlert(in: self,
            withTitle: "Local wallet will be lost. Are you sure you want to restore wallet from iCloud?".localized,
            message: "",
            cancelButtonTitle: "No".localized,
            destructiveButtonTitle: nil,
            otherButtonTitles: ["Yes".localized],
            
            tap: {(alertView, action, buttonIndex) in
                if (buttonIndex == alertView?.firstOtherButtonIndex) {
                    NotificationCenter.default.addObserver(self,
                        selector: #selector(TLSettingsViewController.didDismissEnterMnemonicViewController(_:)),
                        name: NSNotification.Name(rawValue: TLNotificationEvents.EVENT_ENTER_MNEMONIC_VIEWCONTROLLER_DISMISSED()),
                        object: nil)
                    
                    let vc = self.storyboard!.instantiateViewController(withIdentifier: "EnterMnemonic") as! TLRestoreWalletViewController
                    vc.isRestoringFromEncryptedWalletJSON = true
                    vc.encryptedWalletJSON = encryptedWalletJSON
                    self.slidingViewController().present(vc, animated: true, completion: nil)
                } else if (buttonIndex == alertView?.cancelButtonIndex) {
                    TLPreferences.setEnableBackupWithiCloud(false)
                    TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(false)
                }
        })
    }
    
    func didDismissEnterMnemonicViewController(_ notification: Notification) {
        TLPreferences.setEnableBackupWithiCloud(false)
        TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(false)
    }
    
    func settingDidChange(_ info: Notification) {
        let userInfo = (info as NSNotification).userInfo! as NSDictionary
        if ((info.object as! String) == "enablecoldwallet") {
            let enabled = (userInfo.object(forKey: "enablecoldwallet")) as! Int == 1
            TLPreferences.setEnableColdWallet(enabled)
        } else if ((info.object as! String) == "enableadvancemode") {
            let enabled = (userInfo.object(forKey: "enableadvancemode")) as! Int == 1
            TLPreferences.setAdvancedMode(enabled)
        } else if ((info.object as! String) == "canrestoredeletedapp") {
            let enabled = (userInfo.object(forKey: "canrestoredeletedapp")) as! Int == 1
            
            TLPreferences.setInAppSettingsCanRestoreDeletedApp(!enabled) // make sure below code completes firstbefore enabling
            if enabled {
                // settingDidChange gets called twice on one change, so need to do this
                if (TLPreferences.getEncryptedWalletPassphraseKey() == nil) {
                    TLPreferences.setInAppSettingsCanRestoreDeletedApp(enabled)
                    return
                }
                TLWalletPassphrase.enableRecoverableFeature(TLPreferences.canRestoreDeletedApp())
            } else {
                // settingDidChange gets called twice on one change, so need to do this
                if (TLPreferences.getEncryptedWalletPassphraseKey() != nil) {
                    TLPreferences.setInAppSettingsCanRestoreDeletedApp(enabled)
                    return
                }
                TLWalletPassphrase.disableRecoverableFeature(TLPreferences.canRestoreDeletedApp())
            }
            TLPreferences.setInAppSettingsCanRestoreDeletedApp(enabled)
            TLPreferences.setCanRestoreDeletedApp(enabled)
        } else if ((info.object as! String) == "enablesoundnotification") {
            let enabled = (userInfo.object(forKey: "enablesoundnotification") as! Int) == 1
            if (enabled) {
                AudioServicesPlaySystemSound(1016)
            }
            
        } else if ((info.object as! String) == "enablebackupwithicloud") {
            let enabled = (userInfo.object(forKey: "enablebackupwithicloud") as! Int) == 1
            if (enabled) {
                if !TLCloudDocumentSyncWrapper.instance().checkCloudAvailability() {
                    // don't need own alert message, OS will give warning for you
                    TLPreferences.setInAppSettingsKitEnableBackupWithiCloud(false)
                    self.updateHiddenKeys()
                    return
                }

                // Why give option to back from cloud or local? A user may want to restore from cloud backup if he get a new phone.
                TLCloudDocumentSyncWrapper.instance().getFileFromCloud(TLPreferences.getCloudBackupWalletFileName()!, completion: {
                    (cloudDocument: UIDocument!, documentData: Data!, error: NSError!) in
                    TLHUDWrapper.hideHUDForView(self.view, animated: true)
                    if (documentData.count != 0) {
                        let cloudWalletJSONDocumentSavedDate = cloudDocument.fileModificationDate
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .medium
                        
                        let msg = String(format: "Your iCloud backup was last saved on %@. Do you want to restore your wallet from iCloud or backup your local wallet to iCloud?".localized, dateFormatter.string(from: cloudWalletJSONDocumentSavedDate!))

                        UIAlertController.showAlert(in: self,
                            withTitle: "iCloud backup found".localized,
                            message: msg,
                            cancelButtonTitle: "Restore from iCloud".localized,
                            destructiveButtonTitle: nil,
                            otherButtonTitles: ["Backup local wallet".localized],
                            tap: {(alertView, action, buttonIndex) in
                                if (buttonIndex == alertView.firstOtherButtonIndex) {
                                    self.promptToConfirmOverwriteCloudWalletJSONFileWithLocalWalletJSONFile()
                                } else if (buttonIndex == alertView.cancelButtonIndex) {
                                    let encryptedWalletJSON = NSString(data: documentData, encoding: String.Encoding.utf8)
                                    self.promptToConfirmOverwriteLocalWalletJSONFileWithCloudWalletJSONFile(encryptedWalletJSON! as String)
                                }
                        })
                        
                    } else {
                        TLPreferences.setEnableBackupWithiCloud(true)
                        AppDelegate.instance().saveWalletJsonCloudBackground()
                    }
                })
            } else {
                TLPreferences.setEnableBackupWithiCloud(false)
            }
        } else if ((info.object as! String) == "enablepincode") {
            let enabled = (userInfo.object(forKey: "enablepincode") as! Int) == 1
            TLPreferences.setEnablePINCode(enabled)
            if (!LTHPasscodeViewController.doesPasscodeExist()) {
                self.showLockViewForEnablingPasscode()
            } else {
                self.showLockViewForTurningPasscodeOff()
            }
        } else if ((info.object as! String) == "displaylocalcurrency") {
            let enabled = (userInfo.object(forKey: "displaylocalcurrency") as! Int) == 1
            TLPreferences.setDisplayLocalCurrency(enabled)
        } else if ((info.object as! String) == "dynamicfeeoption") {
        } else if ((info.object as! String) == "enabledynamicfee") {
            self.updateHiddenKeys()
        } else if ((info.object as! String) == "currency") {
            let currencyIdx = userInfo.object(forKey: "currency") as! String
            TLPreferences.setCurrency(currencyIdx)
        } else if ((info.object as! String) == "bitcoindisplay") {
            let bitcoindisplayIdx = userInfo.object(forKey: "bitcoindisplay") as! String
            TLPreferences.setBitcoinDisplay(bitcoindisplayIdx)
        } else if ((info.object as! String) == "stealthaddressdefault") {
            let enabled = (userInfo.object(forKey: "stealthaddressdefault") as! Int) == 1
            TLPreferences.setEnabledStealthAddressDefault(enabled)
        } else if ((info.object as! String) == "blockexplorerapi") {
            let blockexplorerAPIIdx = userInfo.object(forKey: "blockexplorerapi") as! String
            TLPreferences.setBlockExplorerAPI(blockexplorerAPIIdx)
            TLPreferences.resetBlockExplorerAPIURL()
            self.updateHiddenKeys()
            
            AppDelegate.instance().giveExitAppNoticeForBlockExplorerAPIToTakeEffect = true
            
            NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_CHANGE_BLOCKEXPLORER_TYPE()), object: nil)
        }
    }
    
    func settingsViewController(_ sender: IASKAppSettingsViewController, buttonTappedFor specifier: IASKSpecifier) {
        if (specifier.key() == "changepincode") {
            self.showLockViewForChangingPasscode()
        } else if (specifier.key() == "showpassphrase") {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "Passphrase") 
            self.slidingViewController().present(vc, animated: true, completion: nil)
        } else if (specifier.key() == "restorewallet") {
            let vc = self.storyboard!.instantiateViewController(withIdentifier: "EnterMnemonic") 
            self.slidingViewController().present(vc, animated: true, completion: nil)
            
        } else if (specifier.key() == "settransactionfee") {
            self.showPromptForSetTransactionFee()
        } else if (specifier.key() == "setblockexplorerurl") {
            self.showPromptForSetBlockExplorerURL()
        }
    }
    
    func passcodeViewControllerWillClose() {
        if (LTHPasscodeViewController.doesPasscodeExist()) {
            TLPreferences.setInAppSettingsKitEnablePinCode(true)
            TLPreferences.setEnablePINCode(true)
            NotificationCenter.default.post(name: Notification.Name(rawValue: TLNotificationEvents.EVENT_ENABLE_PIN_CODE()), object: nil)
        } else {
            TLPreferences.setInAppSettingsKitEnablePinCode(false)
            TLPreferences.setEnablePINCode(false)
        }
        self.updateHiddenKeys()
    }
    
    func maxNumberOfFailedAttemptsReached() {
    }
    
    func passcodeWasEnteredSuccessfully() {
    }
    
    func logoutButtonWasPressed() {
    }
 
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
