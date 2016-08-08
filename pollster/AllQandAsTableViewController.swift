//
//  AllQandAsTableViewController.swift
//  pollster
//
//  Created by yesway on 16/7/7.
//  Copyright © 2016年 joker. All rights reserved.
//

import UIKit
import CloudKit


class AllQandAsTableViewController: UITableViewController {
    var allQandAs = [CKRecord]() { didSet { tableView.reloadData() } }
    
    private let dataBase = CKContainer.defaultContainer().publicCloudDatabase
    
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        fetchAllQandAs()
        iCloudSubscribeToQandAs()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        iCloudUnsubscribeToQandAs()
    }
    
    private func fetchAllQandAs () {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        
        let query = CKQuery(recordType: Cloud.Entity.QandA, predicate: predicate)
        
        query.sortDescriptors = [NSSortDescriptor(key: Cloud.Attribute.Question, ascending: true)]
        
        dataBase.performQuery(query, inZoneWithID: nil) { (records, error) in
            guard let qandas = records else { return }
            dispatch_async(dispatch_get_main_queue(), { 
                self.allQandAs = qandas
            })
        }
    }
    
    // MARK: - Subscription
    
    private let subscriptionID = "All QandA Creations and Deletions"
    private var cloudKitObserver: NSObjectProtocol?
    
    
    private func iCloudSubscribeToQandAs() {
        let predicate = NSPredicate(format: "TRUEPREDICATE")
        let subscription = CKSubscription(recordType: Cloud.Entity.QandA, predicate: predicate, subscriptionID: self.subscriptionID, options: [.FiresOnRecordCreation,.FiresOnRecordDeletion])
        
        dataBase.saveSubscription(subscription) { (savedSubsription, error) in
            
            if error?.code == CKErrorCode.ServerRejectedRequest.rawValue {
                
            } else if error != nil {
                
            }
        }
        
        cloudKitObserver = NSNotificationCenter.defaultCenter().addObserverForName(CloudKitNotifications.NotificationReceived, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) in
            
            if let ckqn = notification.userInfo?[CloudKitNotifications.NotificationKey] as? CKQueryNotification {
                self.iCloudHandleSubscriptionNotification(ckqn)
            }
        })
    }
    
    private func iCloudHandleSubscriptionNotification(ckqn: CKQueryNotification) {
        
        if ckqn.subscriptionID == self.subscriptionID {
            if let recordID = ckqn.recordID {
                switch ckqn.queryNotificationReason {
                case .RecordCreated:
                    dataBase.fetchRecordWithID(recordID, completionHandler: { (record, error) in
                        if record != nil {
                            dispatch_async(dispatch_get_main_queue(), { 
                                self.allQandAs = (self.allQandAs + [record!]).sort {
                                    return (($0[Cloud.Attribute.Question] as? String) < ($1[Cloud.Attribute.Question] as? String))
                                }
                            })
                        }
                    })
                case .RecordDeleted:
                    dispatch_async(dispatch_get_main_queue(), {
                        self.allQandAs = self.allQandAs.filter {$0.recordID != recordID}
                    })
                default:
                    break
                }
            }
        }
        
    }
    
    private func iCloudUnsubscribeToQandAs() {
        dataBase.deleteSubscriptionWithID(self.subscriptionID) { (subscription, error) in
            
        }
    }
    
    
    // MARK: - UITableDataSource
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allQandAs.count
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("QandA Cell", forIndexPath: indexPath)
        cell.textLabel?.text = allQandAs[indexPath.row][Cloud.Attribute.Question] as? String
        
        return cell
    }
    
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return allQandAs[indexPath.row].wasCreatedByThisUser
    }
    
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            
            let record = allQandAs[indexPath.row]
            
            dataBase.deleteRecordWithID(record.recordID, completionHandler: { (deleteRecord, error) in
                
            })
            
            allQandAs.removeAtIndex(indexPath.row)
            
        }
    }
    
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "show QandA" {
            if let ckQandATVC = segue.destinationViewController as? CloudQandATableViewController {
                if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPathForCell(cell) {
                    ckQandATVC.ckQandARecord = allQandAs[indexPath.row]
                } else {
                    ckQandATVC.ckQandARecord = CKRecord(recordType: Cloud.Entity.QandA)
                }
            }
        }
    }
    
}

